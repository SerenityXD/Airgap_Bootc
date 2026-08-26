# Contributing to Bootc

Welcome! This guide will help you understand the repository structure, common workflows, and conventions used in this project.

## Repository Structure

```
<repo-root>/
├── bootc_ostree/fedora/           # Main build orchestration
│   ├── image/                     # Container image definition
│   │   ├── Containerfile          # Main image build (1000+ lines)
│   │   ├── config/                # Build-time configuration inputs
│   │   ├── assets/                # Custom image assets
│   │   ├── docs/                  # Documentation copied into the image
│   │   └── offline-repo/          # Vendor offline artifacts (RPMs, binaries, etc)
│   ├── fetch-scripts/             # Fetch scripts for individual tools
│   ├── build-scripts/             # ISO and export orchestration
│   │   ├── build_export_iso.sh    # Main build entry point
│   │   ├── verify_iso_contents.sh # Post-build verification
│   │   └── lib/common.sh          # Build helper utilities
│   ├── fetch_all_offline.sh       # Orchestrator for all fetch scripts
│   ├── output/                    # Generated ISO and OCI artifacts
│   └── tests/                     # Shell syntax and integration tests
├── docs/                          # Project documentation
│   ├── CONVENTIONS.md             # Naming and file organization standards
│   ├── architecture/              # System design and structure
│   ├── operations/                # Workflows and operational guides
│   └── decisions/                 # Architecture decision records (ADRs)
├── Makefile                       # High-level build targets
└── README.md                      # Project quick-start
```

## Getting Started

### Prerequisites
- Linux system (Fedora, RHEL, or WSL2)
- `podman` or Docker
- `bash 4+`
- `git`, `unzip`, `wget`, `tar`, `xz`
- ~70 GB free disk space
- Internet access (for fetching offline artifacts)

### Quick Start for Development

1. **Clone and explore:**
   ```bash
   git clone https://github.com/SerenityXD/Airgap_Bootc.git
   cd Airgap_Bootc
   make help  # See all available targets
   ```

2. **Fetch offline artifacts (required for air-gapped builds):**
   ```bash
   make fetch-full  # Downloads all offline packages, VS Code extensions, and npm tarballs
   ```

3. **Test your environment:**
   ```bash
   make test-syntax  # Quick shell syntax validation
   make test-dry-run # Dry-run fetch orchestration
   ```

4. **Build the image (takes 30-60 minutes):**
   ```bash
   make build-iso-bare # builds the bare minimum ISO
   make build-oci-full # builds the full OCI archive from the built image

   make build-iso  # Builds the full ISO
   ```


## Common Development Workflows

### Adding a New Offline Artifact

1. **Create a fetch script** in `bootc_ostree/fedora/fetch-scripts/`:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   
   LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
   source "${LIB_DIR}/common.sh"
   
   OFFLINE_DIR="$(get_offline_dir "mytool" "${BASH_SOURCE[0]}")"
   mkdir -p "$OFFLINE_DIR"
   
   # Add fetch logic here
   # Use log_info, log_warn, log_error for output
   # Use require_cmd to check for dependencies
   ```

2. **Add to fetch orchestrator** in `bootc_ostree/fedora/fetch_all_offline.sh`:
   ```bash
   FETCH_TASKS=(
       "existing_task.sh|Description|"
       "fetch_mytool.sh|My Tool Description|"  # Add your task
   )
   ```

3. **Reference in Containerfile** in `bootc_ostree/fedora/image/Containerfile`:
   ```dockerfile
   # Copy mytool offline artifact
   COPY offline-repo/mytool/ /tmp/mytool/
   RUN if [[ -f /tmp/mytool/mytool-binary ]]; then \
       install -m 0755 /tmp/mytool/mytool-binary /usr/local/bin/; \
   fi
   ```

4. **Test locally:**
   ```bash
   chmod +x bootc_ostree/fedora/fetch-scripts/fetch_mytool.sh
   ./bootc_ostree/fedora/fetch-scripts/fetch_mytool.sh
   ls bootc_ostree/fedora/image/offline-repo/mytool/
   ```

### Modifying the Containerfile

**Always follow this safe-edit checklist:**

1. **Prefer offline artifacts** — If adding packages, ensure they're available in `offline-repo/`.
2. **Keep DNF atomic** — Use this pattern for all DNF operations:
   ```dockerfile
   RUN dnf -y --setopt=install_weak_deps=False install package1 package2 \
       && dnf -y clean all && rm -rf /var/cache/dnf
   ```
3. **Test locally before committing:**
   ```bash
   podman build --format docker -t bootc-test \
       -f bootc_ostree/fedora/image/Containerfile \
       bootc_ostree/fedora/image
   ```
4. **Keep helper scripts in sync** — If changing install paths or caches, update:
   - `/usr/local/bin/bootc/install-python-wheels.sh`
   - `/usr/local/bin/bootc/bootc-post-install.sh`
5. **Document your changes** — Update relevant docs in `docs/operations/` or `bootc_ostree/fedora/README.md`.

### Customizing Builds Without Editing Containerfile

Use build arguments to control what gets excluded:

```bash
# Full build with all optional packages (default behavior)
make build-iso

# Exclude Blender only
make build-iso EXTRA_BUILD_ARGS='--build-arg EXCLUDE_BLENDER=yes'

# Bare ISO (GUI + podman baseline)
make build-iso-bare

# Full ISO with everything
make build-iso
```

Available build arguments (see Containerfile for full list):
- `EXCLUDE_DOCKER_DESKTOP=yes` — Exclude Docker Desktop (~404MB)
- `EXCLUDE_GIMP_KRITA=yes` — Exclude GIMP and Krita (~511MB)
- `EXCLUDE_RATIONS=yes` — Exclude Rations / portablemc payload
- `EXCLUDE_BLENDER=yes` — Exclude Blender (~300MB)

### Adding Python Packages (Offline)

1. **Update the package list** in `bootc_ostree/fedora/fetch-scripts/package-versions.txt`:
   ```
   numpy==1.24.0
   pandas@2.0.0
   matplotlib
   ```

2. **Generate tarballs:**
   ```bash
   ./bootc_ostree/fedora/fetch-scripts/create-npm-tarballs.sh
   ```

3. **Commit generated `.tgz` files** to the repository.

### Testing Your Changes

3. **Run validation tests:**
   ```bash
   make test                  # All tests
   make test-syntax           # Shell syntax only
   make test-dry-run          # Fetch orchestration
   ```

2. **Verify build locally:**
   ```bash
   # Dry test: doesn't actually build but validates configuration
   ./bootc_ostree/fedora/build-scripts/build_export_iso.sh \
       --help  # Shows all available options

   # Quick build (no optional packages)
   make build-iso-bare

3. **Check ISO contents:**
   ```bash
   make verify-iso
   ```

## Code Style & Conventions

### Shell Scripts
- Use `set -euo pipefail` at the top of all scripts
- Source `lib/common.sh` for shared utilities (logging, path resolution)
- Use `log_info`, `log_warn`, `log_error` for output
- Quote all variables: `"$var"` instead of `$var`
- Use `[[ ]]` for conditionals instead of `[ ]`
- Indent with 4 spaces

### Documentation
- Keep README files focused on their scope (root README → quick-start, fedora/README → detailed workflows)
- Use relative paths rooted at `bootc_ostree/fedora/` for all commands
- When documenting paths, use markdown formatting: `bootc_ostree/fedora/image/offline-repo/`
- One canonical source for each topic (avoid duplicating information across docs)

### Naming
- Shell scripts: `kebab-case` (e.g., `fetch_gimp.sh`, `build_export_iso.sh`)
- Markdown files: `kebab-case` (e.g., `offline-artifacts.md`)
- Build modes: `interactive`, `non-interactive` (not `int`, `ni`)
- Environment variables: `UPPER_CASE`

## Architecture Principles

### Offline-First
- All third-party dependencies should have offline fallbacks
- Fetch scripts download artifacts before build time
- Containerfile prefers offline copies when present
- Never commit large binaries; store in `offline-repo/` instead

### Modularity
- Keep orchestration scripts (fetch, build) thin and focused
- Isolate reusable helpers in `lib/` directories
- Each fetch script is independent (can run individually)
- Build script should be decomposable into distinct phases (image, export, ISO)

### Reproducibility
- Document all version pinning (Fedora base, tool versions)
- Pin npm packages in `package-versions.txt`
- Keep offline artifacts in version control (or reference a stable archive)
- Containerfile should produce the same image given the same inputs

## Troubleshooting Development Issues

### Build fails with "offline artifact missing"
- Run fetch scripts: `make fetch-full`
- Check artifact directory: `ls bootc_ostree/fedora/image/offline-repo/<vendor>/`

### Script doesn't find common.sh
- Verify you're sourcing from the correct directory:
  ```bash
  LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
  source "${LIB_DIR}/common.sh"
  ```

### Container build takes forever
- First build (especially with `--no-cache`) is slow; subsequent builds use cache
- Use `make build-iso-bare` for faster iteration
- Check disk space: `df -h`

### ISO verification fails
- Verify ISO was generated: `ls bootc_ostree/fedora/output/bootiso/`
- Check logs: `cat bootc_ostree/fedora/build-scripts/logs/*.log`
- Rebuild with verbose output: `bash -x bootc_ostree/fedora/build-scripts/build_export_iso.sh interactive`

## Getting Help

- **Documentation:** `docs/README.md` → start here for guides
- **Architecture:** [docs/architecture/system-overview.md](docs/architecture/system-overview.md)
- **Operations:** [docs/operations/](docs/operations/) for detailed workflows
- **Quick reference:** [.github/copilot-instructions.md](.github/copilot-instructions.md)
- **Issues:** File issues on GitHub with build logs (use sanitized paths)

## Review Checklist for PRs

When submitting changes, ensure:

- [ ] Shell scripts pass syntax check: `bash -n script.sh`
- [ ] Containerfile builds locally: `podman build ...` (see above)
- [ ] Offline artifacts are staged if adding packages
- [ ] Documentation is updated (README.md or relevant ops guide)
- [ ] Commit messages are clear and reference any related issues
- [ ] Temporary files and logs are not committed

## Resources

- **Fedora documentation:** https://docs.fedoraproject.org/
- **Bootc/Ostree:** https://github.com/containers/bootc
- **Podman:** https://podman.io/
- **bootc-image-builder:** https://github.com/osbuild/bootc-image-builder
