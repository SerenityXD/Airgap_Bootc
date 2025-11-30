#!/bin/bash
# Script to build air-gapped ISO using prepared repository cache
set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Allow overriding the repo path (useful for Slim Mode separate cache)
REPO_DIR="${REPO_DIR:-${SCRIPT_DIR}/../airgap-packages-full}"
# Minimal cache used by livemedia-creator to speed up preflights
REPO_DIR_MIN="${REPO_DIR_MIN:-}" # if empty, will be derived into TMP_DIR
RESULT_DIR="${SCRIPT_DIR}/../out-airgap"
TMP_DIR="/var/tmp/bootc-build"
PROJECT_NAME="${PROJECT_NAME:-SCVU}"
FEDORA_RELEASE="${FEDORA_RELEASE:-43}"
TIMEOUT_MINUTES="${TIMEOUT_MINUTES:-120}"
CHECK_INTERVAL_SECONDS="${CHECK_INTERVAL_SECONDS:-60}"

PHASE="init"

log_note() {
  printf "[checkpoint] %s | %s | %s\n" "$(date '+%F %T')" "$PHASE" "$1"
}

guard_start_timer() {
  START_TS=$(date +%s)
}

guard_check_timeout() {
  local now=$(date +%s)
  local elapsed=$((now - START_TS))
  local limit=$((TIMEOUT_MINUTES * 60))
  if (( elapsed > limit )); then
    echo "ERROR: Timeout exceeded (${TIMEOUT_MINUTES} min) during phase '$PHASE'"
    echo "Last 80 lines of build log:"
    sudo tail -n 80 "$TMP_DIR/build.log" 2>/dev/null || true
    exit 124
  fi
}

progress_watch() {
  # Emit periodic progress hints while waiting
  while true; do
    sleep "$CHECK_INTERVAL_SECONDS" || break
    guard_check_timeout
    if sudo test -f "$TMP_DIR/build.log"; then
      local last_line
      last_line=$(sudo tail -n 1 "$TMP_DIR/build.log" 2>/dev/null || echo "")
      printf "[progress] %s | %s | %s\n" "$(date '+%T')" "$PHASE" "${last_line}" | sed 's/\r//'
    else
      printf "[progress] %s | %s | log not yet created\n" "$(date '+%T')" "$PHASE"
    fi
  done
}

echo "=== Building Air-Gapped Bootable ISO ==="
echo "Project: $PROJECT_NAME"
echo "Fedora Release: $FEDORA_RELEASE"
echo "Repository: $REPO_DIR"
echo "Output: $RESULT_DIR"
echo ""

log_note "Starting validations"
guard_start_timer

# Verify repository exists
if [ ! -d "$REPO_DIR" ]; then
  echo "ERROR: Repository not found at $REPO_DIR"
  echo "Please run prepare_airgap_repo.sh first"
  exit 1
fi

# Verify required directories exist
for dir in fedora nvidia vscode rpmfusion-free rpmfusion-nonfree winehq nodejs; do
  if [ ! -d "$REPO_DIR/$dir" ]; then
    echo "WARNING: Missing repository directory: $REPO_DIR/$dir"
  fi
done

log_note "Validation complete"

# Preflight: ensure required repos have repodata to avoid Anaconda stalls (especially in Slim Mode)
echo "Performing repo preflight checks..."
missing=0
for req in fedora fedora-updates; do
  if [ ! -d "$REPO_DIR/$req" ]; then
    echo "ERROR: Required repo directory missing: $REPO_DIR/$req"
    missing=1
    continue
  fi
  if [ ! -d "$REPO_DIR/$req/repodata" ]; then
    echo "WARNING: $req has no repodata. Attempting to generate metadata..."
    sudo createrepo_c "$REPO_DIR/$req" >/dev/null 2>&1 || true
    if [ ! -d "$REPO_DIR/$req/repodata" ]; then
      echo "ERROR: $req still lacks repodata after attempted generation."
      missing=1
    fi
  fi
done
if [ "$missing" -eq 1 ]; then
  echo "Cannot proceed: Fedora repos incomplete. Ensure Slim Mode prepared 'fedora' and 'fedora-updates' with metadata."
  exit 1
fi

# Check if result directory exists (livemedia-creator requires it to NOT exist)
if [ -d "$RESULT_DIR" ]; then
  echo "WARNING: Result directory already exists: $RESULT_DIR"
  echo "livemedia-creator requires a non-existent results directory."
  read -p "Delete existing directory? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing $RESULT_DIR with elevated permissions..."
    sudo rm -rf "$RESULT_DIR"
    echo "Deleted $RESULT_DIR"
  else
    echo "ERROR: Cannot proceed with existing results directory"
    exit 1
  fi
fi

echo "Setting up repository access..."
sudo mkdir -p "$TMP_DIR"

# Prepare minimal cache containing only fedora and fedora-updates
MIN_CACHE_PATH="$TMP_DIR/airgap-packages-min"
FULL_CACHE_PATH="$TMP_DIR/airgap-packages-full"
sudo mkdir -p "$MIN_CACHE_PATH" "$FULL_CACHE_PATH"

# Populate minimal cache directories for Anaconda speed
for sub in fedora fedora-updates; do
  if [ -d "$REPO_DIR/$sub" ]; then
    sudo mkdir -p "$MIN_CACHE_PATH/$sub"
    echo "Preparing minimal cache: $sub"
    # Use rsync to copy only the needed repo subtree including repodata
    sudo rsync -a --delete "$REPO_DIR/$sub/" "$MIN_CACHE_PATH/$sub/" || true
    # Ensure repodata exists
    if [ ! -d "$MIN_CACHE_PATH/$sub/repodata" ]; then
      echo "Generating repodata for $sub in minimal cache..."
      sudo createrepo_c "$MIN_CACHE_PATH/$sub" >/dev/null 2>&1 || true
    fi
  else
    echo "WARNING: $REPO_DIR/$sub not found; minimal cache may be incomplete"
  fi
done

# Allow override via REPO_DIR_MIN env var
if [ -n "$REPO_DIR_MIN" ]; then
  echo "Using user-provided minimal cache: $REPO_DIR_MIN"
  MIN_CACHE_PATH="$REPO_DIR_MIN"
fi

# Mount the minimal cache at the path expected by the kickstart repos
EXPECTED_PATH="$TMP_DIR/airgap-packages-full"
echo "Mounting minimal cache to expected path for Anaconda: $EXPECTED_PATH"
sudo mkdir -p "$EXPECTED_PATH"
sudo mount --bind "$MIN_CACHE_PATH" "$EXPECTED_PATH"

# Mount full cache at a separate path for %post access
FULL_CACHE_COMPLETE="$TMP_DIR/airgap-packages-full-complete"
echo "Mounting full repository cache to $FULL_CACHE_COMPLETE for %post..."
sudo mkdir -p "$FULL_CACHE_COMPLETE"
sudo mount --bind "$REPO_DIR" "$FULL_CACHE_COMPLETE"

# Cleanup function
cleanup() {
  echo "Cleaning up..."
  sudo umount "$EXPECTED_PATH" 2>/dev/null || true
  sudo umount "$FULL_CACHE_COMPLETE" 2>/dev/null || true
  sudo rm -rf "$TMP_DIR" || true
}
on_signal() {
  echo "\nReceived interrupt; attempting graceful shutdown..."
  # Stop background progress watcher if running
  if [ -n "$WATCH_PID" ] && kill -0 "$WATCH_PID" 2>/dev/null; then
    kill "$WATCH_PID" 2>/dev/null || true
  fi
  if sudo test -f "$TMP_DIR/build.log"; then
    echo "Last 40 lines of log before exit:"
    sudo tail -n 40 "$TMP_DIR/build.log" || true
  fi
  cleanup
  exit 130
}
trap cleanup EXIT
trap on_signal INT TERM

echo ""
echo "Building ISO with livemedia-creator..."
echo "This may take 30-60 minutes depending on your system..."
echo ""

PHASE="lmc-start"
log_note "Launching livemedia-creator"
guard_start_timer
progress_watch &
WATCH_PID=$!

# Guard against stale anaconda pid file from prior runs
if sudo test -f "/var/run/anaconda.pid"; then
  echo "WARNING: Stale /var/run/anaconda.pid detected. Checking for live anaconda..."
  if ps aux | grep -E "[a]naconda" >/dev/null; then
    echo "Anaconda appears to be running. Aborting to avoid conflict."
    kill "$WATCH_PID" 2>/dev/null || true
    exit 1
  else
    echo "No running anaconda found. Removing stale pid file."
    sudo rm -f "/var/run/anaconda.pid" || true
  fi
fi

# Build the ISO (logfile must be outside resultdir to avoid directory creation conflict)
sudo livemedia-creator --make-iso --no-virt \
  --ks "$SCRIPT_DIR/bootc-airgap.ks" \
  --project "$PROJECT_NAME" \
  --releasever "$FEDORA_RELEASE" \
  --resultdir "$RESULT_DIR" \
  --tmp "$TMP_DIR" \
  --logfile "$TMP_DIR/build.log"

# After livemedia-creator returns, stop watcher
kill "$WATCH_PID" 2>/dev/null || true

PHASE="lmc-complete"
log_note "livemedia-creator finished"

echo ""
echo "=== ISO Build Complete ==="
echo "ISO location: $RESULT_DIR/"
ls -lh "$RESULT_DIR"/*.iso 2>/dev/null || echo "No ISO found - check $TMP_DIR/build.log for errors"
echo "Build log: $TMP_DIR/build.log"
echo ""
echo "Next steps:"
echo "1. Write ISO to USB: sudo dd if=$RESULT_DIR/*.iso of=/dev/sdX bs=4M status=progress"
echo "2. Boot from USB and follow installation prompts"
echo ""
