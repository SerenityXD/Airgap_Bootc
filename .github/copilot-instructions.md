## Purpose
This repository builds an air-gapped Fedora/bootc system image and ISO. The guidance below surfaces the minimal, high-value knowledge an AI coding assistant needs to be productive in this codebase.

## Big picture (high-level architecture)
- `bootc_ostree/image/Containerfile` — the single large container build that assembles the system image (KDE, drivers, offline caches). Treat it as the main entrypoint for image-level changes.
- `bootc_ostree/` — orchestration, build scripts and ISO packaging. Key scripts live under `bootc_ostree/build-scripts/`.
- `bootc_ostree/image/offline-repo/` — vendor-provided offline artifacts (RPMS, VSIX, npm tarballs). The Containerfile prefers these when present.
- Generated artifacts: ISO in `bootc_ostree/output/bootiso/`, OCI image in `bootc_ostree/oci-image/`.

## Critical developer workflows (commands & locations)
- Prepare offline npm tarballs (used by Containerfile):
  - `chmod +x bootc_ostree/image/scripts/create-npm-tarballs.sh`
  - `./bootc_ostree/image/scripts/create-npm-tarballs.sh`
  - Tarballs are written to `bootc_ostree/image/offline-repo/npm-packages/` and are copied into the image by the Containerfile.
- Full fetch of offline payloads (recommended before building air-gapped ISO):
  - `./bootc_ostree/fetch_all_offline.sh`
- Build helper (ISO):
  - `cd bootc_ostree/build-scripts && ./build-iso-helper.sh interactive` (or `non-interactive`, `compare`)
- Direct export (full control):
  - `./bootc_ostree/build-scripts/build_export_iso.sh --iso-type anaconda-iso --iso-name SCVU-Interactive.iso`
- Local container build (iterate on image changes):
  - `podman build -t scvu-bootc -f bootc_ostree/image/Containerfile bootc_ostree/image`

## Project-specific conventions & patterns
- Offline-first: Many steps check `bootc_ostree/image/offline-repo/*` and prefer offline assets. When adding packages prefer committing artifacts under that directory.
- Multi-python wheels: pre-downloaded wheels are placed under `/opt/python-wheels/pyXY` in the image; source is `bootc_ostree/image/` produced content.
- Helper scripts installed into the image live under `/usr/local/bin/scvu/` (e.g. `scvu-post-install.sh`, `install-python-wheels.sh`, `install-js-frameworks.sh`). These scripts are authoritative for runtime/first-boot behavior.
- Container/DNF pattern: the Containerfile uses long chained `RUN` steps with `dnf --setopt=install_weak_deps=False` and `dnf -y clean all && rm -rf /var/cache/dnf` — when editing, follow the same style to avoid extra layers and keep image size minimal.

## Integration points & external dependencies
- Offline rpms and tools: `bootc_ostree/image/offline-repo/<vendor>/` (e.g. `vscode`, `docker-desktop`, `obs`, `rpmfusion`, `winehq`). Adding or updating offline artifacts requires placing new files there and updating build scripts if necessary.
- OpenShift/CRC/triton: Stage binaries under `bootc_ostree/image/offline-repo/openshift`, `crc`, `triton` — the Containerfile copies these into `/usr/local/bin/scvu` or `/usr/share/triton`.
- VS Code extensions: drop `*.vsix` into `bootc_ostree/image/vscode-extensions/` to be installed by `scvu-post-install.sh`.

## Common gotchas and checks for PRs
- If you change package lists in `Containerfile`, the build may fail offline unless the corresponding packages are added under `offline-repo/` or network access is available.
- Many build-time actions run systemd-related commands inside a container (e.g. `systemctl enable`): expect non-fatal warnings during container builds; do not remove those lines unless you understand runtime consequences.
- NVIDIA akmods: the Containerfile attempts to build kernel modules when kernel packages are present — edits here require understanding of kernel package availability during the build.

## Quick examples to include in PR descriptions
- To test changes that affect npm tarballs: run `./bootc_ostree/image/scripts/create-npm-tarballs.sh` and include resulting `*.tgz` files in `bootc_ostree/image/offline-repo/npm-packages/`.
- To verify post-install behavior locally after image build: run (inside created system or container) `sudo /usr/local/bin/scvu/scvu-post-install.sh` and `sudo /usr/local/bin/scvu/install-python-wheels.sh --py py310`.

## Where to look for more context (key files)
- `bootc_ostree/image/Containerfile` — main image build logic and offline-first checks.
- `bootc_ostree/build-scripts/` — ISO build orchestration and helper scripts.
- `bootc_ostree/image/scripts/create-npm-tarballs.sh` and `bootc_ostree/image/offline-repo/npm-packages/package-versions.txt` — JS framework packing workflow.
- `bootc_ostree/README.md` and root `README.md` — overall README with the canonical build commands.

## When to ask the human maintainer
- If you need to change the offline artifact layout, ask before renaming directories under `image/offline-repo/`.
- If you plan to remove or change `scvu-post-install.sh` behavior (user creation, extension installation, enabling services), confirm intent with maintainers because it affects first-boot system configuration.

---
If any section is unclear or you want more examples (e.g., a small checklist for editing `Containerfile` safely), tell me which parts to expand.

## Containerfile safe-edit checklist (quick reference)
Follow this checklist when editing `bootc_ostree/image/Containerfile` to avoid large rebuilds, offline breaks, and runtime issues:

- **Prefer offline artifacts:** If you add or bump packages, ensure corresponding RPMs/archives exist under `bootc_ostree/image/offline-repo/<vendor>/` or document the network fallback. Example: adding `obs` packages requires updating `offline-repo/obs/`.
- **Keep DNF invocations atomic:** Use the existing pattern `dnf -y --setopt=install_weak_deps=False install <pkgs> && dnf -y clean all && rm -rf /var/cache/dnf` in the same `RUN` to reduce layers and cache leakage.
- **Avoid unnecessary `systemctl` changes:** `systemctl enable` is safe-to-leave (expected warnings during container build). Do not remove these lines unless you understand target runtime effects.
- **NVIDIA/kernel changes:** If adding kernel or NVIDIA packages, ensure the build environment contains matching `kernel-devel` packages or accept that `akmods` may fail. Document any kernel-version assumptions in your PR.
- **Offline npm workflow:** When adding JS frameworks, update `bootc_ostree/image/offline-repo/npm-packages/package-versions.txt` and run `./bootc_ostree/image/scripts/create-npm-tarballs.sh`; commit resulting `*.tgz` files so `COPY offline-repo/npm-packages/ /opt/npm-packages/` works offline.
- **Binary artifacts:** For binaries (e.g., `oc`, `kubectl`, `crc`, `triton`), copy files into `offline-repo/<vendor>/` and verify that the Containerfile copies them to `/usr/local/bin/scvu/` or `/usr/share/<name>` with correct modes (use `install -m 0755` to set perms).
- **Test locally with Podman:** Before pushing, build the image locally to validate: `podman build -t scvu-bootc -f bootc_ostree/image/Containerfile bootc_ostree/image` and inspect logs for skipped offline steps.
- **Keep helper scripts in sync:** If you change install locations or caches (e.g., `/opt/python-wheels`), update the post-install helpers: `/usr/local/bin/scvu/install-python-wheels.sh` and `scvu-post-install.sh` accordingly.

## Linter / CI checklist for Containerfile changes
Add these checks to PR reviewers' mental checklist or CI jobs that touch the image build path:

- **Build validation (fast):** Run a local build of the Containerfile (podman) and fail the PR if the build errors:
  - `podman build -t scvu-bootc -f bootc_ostree/image/Containerfile bootc_ostree/image`
- **Offline smoke test:** Verify offline branch by creating (or pointing to) `bootc_ostree/image/offline-repo/` with minimal artifacts and ensure Containerfile uses them instead of network downloads. CI can run a build with `--pull=false` and a prepared `offline-repo` tarball.
- **DNF cache hygiene:** Ensure every `dnf install` line is followed by `dnf -y clean all && rm -rf /var/cache/dnf` in the same RUN; CI lint should flag `dnf install` occurrences without subsequent cleanup.
- **Script syntax checks:** Run `shellcheck` on modified scripts in `bootc_ostree/image/scripts/` and helpers under `/usr/local/bin/scvu/`.
- **Permission checks:** Verify binaries copied into image are executable and owned appropriately; CI can run `podman run --rm scvu-bootc stat -c "%a %n" /usr/local/bin/scvu/*` after a build.
- **Small image size guardrail:** Fail if an image layer grows unexpectedly large (e.g., >5GB delta) — CI can record baseline image size and compare diffs for PRs touching `Containerfile`.
- **Documented offline artifacts:** PR that adds packages must update `bootc_ostree/INDEX.md` or `bootc_ostree/image/offline-repo/README` (if present) to list required offline artifacts and locations.

---
If you want, I can also add a lightweight GitHub Actions workflow that runs the fast `podman build` and `shellcheck` for PRs touching `bootc_ostree/image/**`. Shall I scaffold that? 
