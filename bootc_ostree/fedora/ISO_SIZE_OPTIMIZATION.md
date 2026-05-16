# ISO Size Optimization Guide

## Overview

This document describes optimizations made to reduce the BOOTC Bootc Workstation ISO size from ~12GB to a more manageable size without affecting core functionality.

## Size Reduction Strategies

### 1. **Duplicate RPM Elimination** (~200-400 MB savings)

**Problem:** The offline-repo had 968 duplicate RPM files (381 unique packages) across different vendor folders (obs/, krita/, gimp/, rpmfusion/).

**Solution:** 
- Created deduplication script: `bootc_ostree/fedora/image/scripts/deduplicate-offline-repo.sh`
- Consolidates duplicates into a shared folder
- Can be run before ISO build

**Usage:**
```bash
# Dry-run (preview what would be removed)
DRY_RUN=true ./bootc_ostree/fedora/image/scripts/deduplicate-offline-repo.sh

# Apply deduplication
./bootc_ostree/fedora/image/scripts/deduplicate-offline-repo.sh
```

### 2. **Optional Package Build Arguments** (~1-2 GB savings)

Large optional packages are now included by default and can be excluded when a smaller image is needed.

#### Available Build Arguments:

| Argument | Impact | Default | Usage |
|----------|--------|---------|-------|
| `EXCLUDE_DOCKER_DESKTOP=yes` | Remove Docker Desktop (404MB) | no | Omit container desktop tooling |
| `EXCLUDE_GIMP_KRITA=yes` | Remove GIMP + Krita (511MB total) | no | Omit image editing tools |
| `EXCLUDE_RATIONS=yes` | Remove Rations / portablemc payload | no | Omit pre-seeded game assets |
| `EXCLUDE_BLENDER=yes` | Remove Blender (250-350MB) | no | Omit 3D modeling software |

#### Size Impact of Optional Packages:
- Docker Desktop: 404 MB
- GIMP: 161 MB
- Krita: 350 MB
- Rations / portablemc payload: varies by staged content
- Blender: ~300 MB
- **Total potential savings: 1-1.4 GB** (when all excluded)

**Build Examples:**

```bash
# Minimal image (no optional packages)
cd bootc_ostree/fedora/build-scripts
./build_export_iso.sh --iso-name bootc-minimal.iso \
  --build-arg EXCLUDE_DOCKER_DESKTOP=yes \
  --build-arg EXCLUDE_GIMP_KRITA=yes \
  --build-arg EXCLUDE_RATIONS=yes \
  --build-arg EXCLUDE_BLENDER=yes

# Keep Docker Desktop only
./build_export_iso.sh --iso-name bootc-with-docker.iso \
  --build-arg EXCLUDE_GIMP_KRITA=yes \
  --build-arg EXCLUDE_RATIONS=yes \
  --build-arg EXCLUDE_BLENDER=yes

# Full image (default behavior)
./build_export_iso.sh --iso-name bootc-full.iso

# Exclude selected packages
podman build --format docker \
  -t bootc-bootc \
  --build-arg EXCLUDE_GIMP_KRITA=yes \
  --build-arg EXCLUDE_BLENDER=yes \
  -f bootc_ostree/fedora/image/Containerfile \
  bootc_ostree/fedora/image
```

### 3. **Python Version Optimization** (~200-300 MB savings)

**Changes Made:**
- Reduced from Python 3.9-3.13 (5 versions) to Python 3.11-3.13 (3 versions)
- Keeps compatibility and includes latest Python features
- Older versions (3.9, 3.10) rarely needed for modern development

**Impact:** 
- ~100-150 MB per Python version
- Estimated 200-300 MB total savings

**Note:** To include Python 3.9-3.10, would need additional build-time flag (not currently implemented).

### 4. **Optional Blender Exclusion** (~250-350 MB savings)

**Changes Made:**
- Blender remains available by default
- Can be excluded via `EXCLUDE_BLENDER=yes` build argument
- Still available for users who need the full workstation image

**Rationale:** 
- Heavyweight 3D modeling software not needed for typical emulation/development workflows
- Takes 250-350 MB of space
- Available on demand

## Summary of Expected Size Reductions

| Optimization | Baseline | Savings | New Size |
|--------------|----------|---------|----------|
| ISO (all optional included) | ~12 GB | - | ~12 GB |
| **Dedup RPMs** | 12 GB | 200-400 MB | ~11.6-11.8 GB |
| **Remove Docker Desktop** | 11.6 GB | 404 MB | ~11.2 GB |
| **Remove GIMP/Krita** | 11.2 GB | 511 MB | ~10.7 GB |
| **Remove Rations** | 10.7 GB | variable | ~10.6 GB |
| **Python optimization** | 10.6 GB | 200-300 MB | **~10.3-10.4 GB** |
| **All optimizations applied** | 12 GB | 1.4-2 GB | **~10-10.5 GB** |

### Minimal Configuration (No Optional Packages)
- ISO Size: **~8-9 GB** (with all optimizations)
- Only essential tools, GNOME desktop, VS Code, dev tools
- 1.3+ GB savings vs. full configuration

## How to Use These Optimizations

### For Smallest ISO:

1. Run deduplication:
```bash
cd bootc_ostree/fedora/image/scripts
./deduplicate-offline-repo.sh
```

2. Build minimal ISO (no optional packages):
```bash
cd bootc_ostree/fedora/build-scripts
./build_export_iso.sh --iso-name bootc-minimal.iso \
  --build-arg EXCLUDE_DOCKER_DESKTOP=yes \
  --build-arg EXCLUDE_GIMP_KRITA=yes \
  --build-arg EXCLUDE_RATIONS=yes \
  --build-arg EXCLUDE_BLENDER=yes
```

### For Targeted Configuration:

Build with only the packages you need:
```bash
./build_export_iso.sh --iso-name bootc-custom.iso \
  --build-arg EXCLUDE_GIMP_KRITA=yes \
  --build-arg EXCLUDE_RATIONS=yes
```

## Verification

After building, verify the ISO size:
```bash
ls -lh bootc_ostree/fedora/output/bootiso/*.iso
```

## Post-Install Optional Software

Users can still install optional software after deployment:

```bash
# On the deployed system
sudo dnf install docker-desktop  # Via repo or offline
sudo dnf install gimp             # From Fedora repos
sudo dnf install krita            # From Fedora repos
sudo dnf install blender          # From Fedora repos
```

## Technical Details

### Deduplication Script

Located at: `bootc_ostree/fedora/image/scripts/deduplicate-offline-repo.sh`

**How it works:**
1. Scans all RPM files in offline-repo
2. Groups by filename (basenamed packages)
3. Moves duplicates to `offline-repo/shared-deps/`
4. Keeps track of first occurrence (canonical copy)
5. Reports space recovered

**Safety:**
- DRY_RUN=true mode previews changes
- Doesn't proceed without explicit confirmation
- Preserves at least one copy of each unique RPM

### Containerfile Changes

Key modifications to `bootc_ostree/fedora/image/Containerfile`:

1. **Build arguments at top:**
  ```dockerfile
  ARG EXCLUDE_DOCKER_DESKTOP=no
  ARG EXCLUDE_GIMP_KRITA=no
  ARG EXCLUDE_RATIONS=no
  ARG EXCLUDE_BLENDER=no
   ```

2. **Conditional installations:**
     ```dockerfile
     RUN if [ "$EXCLUDE_DOCKER_DESKTOP" != "yes" ]; then \
       echo "Installing Docker Desktop..."; \
       dnf -y install /path/to/docker-desktop/*.rpm; \
     else \
       echo "Docker Desktop skipped"; \
     fi
   ```

## Performance Notes

- **No performance impact** with optimizations enabled
- Optional packages can be installed post-deployment if needed
- Deduplication improves build speed (fewer files to copy)
- Reduced disk footprint aids in air-gapped environments with limited storage

## Future Optimization Opportunities

1. **Language packs**: Currently only installs `langpacks-en`. Could be further reduced.
2. **Documentation**: DNF already set to skip documentation (`tsflags=nodocs`)
3. **Large library dependencies**: Could optimize OBS, CEF dependencies
4. **VS Code extensions**: Currently ~24 MB - could be post-install only
5. **npm packages cache**: 53 MB - could use lazy install approach

