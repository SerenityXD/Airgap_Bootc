# Justfile: task runner for air-gapped ISO workflow
# Requires: just (https://github.com/casey/just)

# Environment variables are read from the shell; override per invocation.

# Paths
REPO_DIR := 'airgap-packages-full'
TMP_DIR := '/var/tmp/bootc-build'
RESULT_DIR := 'kickstart/../out-airgap'
SCRIPT_DIR := 'kickstart'

# Versions
FEDORA_RELEASE := '43'
PROJECT_NAME := 'SCVU'

# Common helpers

# Show useful commands
default:
  @just --list

# Prepare full cache (Fedora + updates + extras)
prepare-full:
  @echo '=== Prepare: Full Mirror ==='
  @bash {{SCRIPT_DIR}}/prepare_airgap_repo.sh

# Prepare slim cache into separate folder
# Override REPO_DIR to keep slim beside full: REPO_DIR=airgap-packages-slim
prepare-slim:
  @echo '=== Prepare: Slim Mode into {{REPO_DIR}} ==='
  @REPO_DIR={{REPO_DIR}} SLIM_MODE=1 bash {{SCRIPT_DIR}}/prepare_airgap_repo.sh

# Clean temp/output and stale pid
clean:
  @echo '=== Clean temp/output and stale pid ==='
  @sudo rm -rf {{TMP_DIR}} {{RESULT_DIR}} /var/run/anaconda.pid || true

# Build ISO using current REPO_DIR (override to use slim)
build:
  @echo '=== Build ISO (repo: {{REPO_DIR}}) ==='
  @REPO_DIR={{REPO_DIR}} TIMEOUT_MINUTES=180 CHECK_INTERVAL_SECONDS=30 \
    bash {{SCRIPT_DIR}}/build_iso.sh

# Build ISO detached (background), logs to build_iso.out
detached-build:
  @echo '=== Detached Build (repo: {{REPO_DIR}}) ==='
  @nohup env REPO_DIR={{REPO_DIR}} TIMEOUT_MINUTES=180 CHECK_INTERVAL_SECONDS=30 \
    bash {{SCRIPT_DIR}}/build_iso.sh > build_iso.out 2>&1 &
  @echo 'PID:' $$!

# Show live build progress
watch-log:
  @sudo tail -f {{TMP_DIR}}/build.log

# Verify local repos (repodata presence)
preflight:
  @echo '=== Preflight: repodata check ==='
  @test -d {{REPO_DIR}}/fedora/repodata || (echo 'Missing repodata in fedora' && exit 1)
  @test -d {{REPO_DIR}}/fedora-updates/repodata || (echo 'Missing repodata in fedora-updates' && exit 1)
  @echo 'OK: repodata present in fedora and fedora-updates'

# Seed minimal updates repo (use on prep machine)
seed-updates:
  @echo '=== Seeding fedora-updates minimal set ==='
  @UPDATES_URL="https://download.fedoraproject.org/pub/fedora/linux/updates/{{FEDORA_RELEASE}}/Everything/x86_64/" \
  dnf --disablerepo='*' --repofrompath="updates,$UPDATES_URL" \
    download --resolve --destdir={{REPO_DIR}}/fedora-updates dnf glibc || true
  @createrepo_c {{REPO_DIR}}/fedora-updates || true

# Kill stale anaconda/livemedia processes
kill-stale:
  @echo '=== Killing stale anaconda/livemedia ==='
  @for pid in $(pgrep -f 'anaconda'; pgrep -f 'livemedia-creator'); do \
    [ -n "$pid" ] && sudo kill -TERM "$pid" || true; \
  done
  @sleep 2
  @for pid in $(pgrep -f 'anaconda'; pgrep -f 'livemedia-creator'); do \
    kill -0 "$pid" 2>/dev/null && sudo kill -KILL "$pid" || true; \
  done

# Show artifacts
artifacts:
  @ls -lh {{RESULT_DIR}} || true

# Show repo sizes
sizes:
  @du -sh {{REPO_DIR}}/* 2>/dev/null || true
