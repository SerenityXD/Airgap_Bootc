#!/bin/bash
# Deduplication script for offline-repo: consolidates duplicate RPMs into shared folders
# This recovers ~200-400MB of space by eliminating redundant copies of dependencies
# Skips packages known to have version or architecture conflicts

set -u

# Calculate offline-repo path relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${1:-${SCRIPT_DIR}/../offline-repo}"
SHARED_DIR="${REPO_DIR}/shared-deps"
DRY_RUN="${DRY_RUN:-false}"

# Packages with known conflicts - do NOT consolidate these to avoid DNF resolver issues
CONFLICT_PATTERNS=(
    "obs-studio-libs"        # Multiple conflicting versions
    "ffmpeg-libs"            # Architecture/version conflicts
    "ffmpeg"                 # Architecture/version conflicts
    "ocl-icd"                # Conflicts with OpenCL-ICD-Loader
    "OpenCL-ICD-Loader"      # Conflicts with ocl-icd
    "libavcodec-free"        # Part of conflicting ffmpeg family
    "libavdevice"            # Part of conflicting ffmpeg family
    "libavformat-free"       # Part of conflicting ffmpeg family
    "libavutil-free"         # Part of conflicting ffmpeg family
    "libswresample-free"     # Part of conflicting ffmpeg family
    "libswscale-free"        # Part of conflicting ffmpeg family
    "docker-ce-cli"          # May have dependency issues
)

if [ ! -d "$REPO_DIR" ]; then
    echo "Error: offline-repo not found at $REPO_DIR" >&2
    exit 1
fi

echo "[dedup] Scanning for duplicate RPMs in $REPO_DIR..."
mkdir -p "$SHARED_DIR" 2>/dev/null ||  true

# Remove legacy marker files from older dedupe implementations.
# Current logic does not create any persistent .seen.* files.
find "$SHARED_DIR" -maxdepth 1 -type f -name '.seen.*' -delete 2>/dev/null || true

# Helper to check if a package matches any conflict pattern
is_conflict_package() {
    local pkg="$1"
    for pattern in "${CONFLICT_PATTERNS[@]}"; do
        if [[ "$pkg" =~ ^${pattern} ]]; then
            return 0  # Found conflict pattern
        fi
    done
    return 1  # No conflict pattern found
}

# Count unique RPM filenames to identify duplicates (excluding conflicts)
total_count=0
unique_count=0
conflict_count=0
dedup_count=0

rpms=$(find "$REPO_DIR" -type f -name "*.rpm" ! -path "*/shared-deps/*" 2>/dev/null)

for rpm in $rpms; do
    fname=$(basename "$rpm")
    pkg_name="${fname%%-[0-9]*}"  # Extract package name (before version)
    
    if is_conflict_package "$pkg_name"; then
        ((conflict_count++))
    else
        ((total_count++))
    fi
done

# Count unique non-conflicting packages
unique_count=$(find "$REPO_DIR" -type f -name "*.rpm" ! -path "*/shared-deps/*" 2>/dev/null | while read r; do
    fname=$(basename "$r")
    pkg_name="${fname%%-[0-9]*}"
    ! is_conflict_package "$pkg_name" && echo "$fname"
done | sort -u | wc -l)

dedup_count=$((total_count - unique_count))

echo "[dedup] Summary:"
echo "[dedup]   Total RPM files: $((total_count + conflict_count))"
echo "[dedup]   Skipped (known conflicts): $conflict_count"
echo "[dedup]   Unique (safe to deduplicate): $unique_count"
echo "[dedup]   Duplicate copies: $dedup_count"

if [ "$dedup_count" -gt 0 ] && [ "$DRY_RUN" != "true" ]; then
    echo "[dedup] Consolidating non-conflicting duplicates to $SHARED_DIR ..."
    
    # First pass: consolidate files to shared-deps (avoids subshell issues)
    for folder in "$REPO_DIR"/*/; do
        # Skip shared-deps itself
        [ "$(basename "$folder")" = "shared-deps" ] && continue
        
        [ -d "$folder" ] || continue
        for rpm in "$folder"/*.rpm; do
            [ -f "$rpm" ] || continue
            fname=$(basename "$rpm")
            pkg_name="${fname%%-[0-9]*}"
            
            # Skip conflict packages
            if is_conflict_package "$pkg_name"; then
                continue
            fi
            
            # Consolidate to shared-deps (if not already there)
            if [ ! -f "$SHARED_DIR/$fname" ]; then
                ln "$rpm" "$SHARED_DIR/$fname" 2>/dev/null || cp "$rpm" "$SHARED_DIR/$fname" 2>/dev/null || true
            fi
        done
    done
    
    # Second pass: delete originals (now that all are safely in shared-deps)
    # IMPORTANT: Skip shared-deps directory itself to avoid deleting consolidated files!
    for folder in "$REPO_DIR"/*/; do
        # Skip shared-deps itself
        [ "$(basename "$folder")" = "shared-deps" ] && continue
        
        [ -d "$folder" ] || continue
        for rpm in "$folder"/*.rpm; do
            [ -f "$rpm" ] || continue
            fname=$(basename "$rpm")
            pkg_name="${fname%%-[0-9]*}"
            
            # Skip conflict packages
            if is_conflict_package "$pkg_name"; then
                continue
            fi
            
            # Delete original if it exists in shared-deps
            if [ -f "$SHARED_DIR/$fname" ]; then
                rm -f "$rpm"
            fi
        done
    done
    
    echo "[dedup]   Deduplication complete!"
elif [ "$DRY_RUN" = "true" ]; then
    echo "[dedup] DRY-RUN mode - to apply deduplication, run: DRY_RUN=false $0"
fi

echo "[dedup] Done."
exit 0

