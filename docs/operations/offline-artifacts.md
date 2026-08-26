# Offline Artifacts Workflow

## Purpose
Prepare third-party packages and binaries for air-gapped image builds.

## Canonical Commands
```bash
./bootc_ostree/fedora/fetch_all_offline.sh
./bootc_ostree/fedora/fetch-scripts/fetch_gimp.sh
./bootc_ostree/fedora/fetch-scripts/fetch_krita.sh
DAVINCI_RESOLVE_URL=https://official-vendor-url ./bootc_ostree/fedora/fetch-scripts/fetch_davinci_resolve.sh
UNREAL_ENGINE_URL=https://signed-vendor-url ./bootc_ostree/fedora/fetch-scripts/fetch_unreal_engine.sh
./bootc_ostree/fedora/fetch-scripts/create-npm-tarballs.sh
```

## Artifact Locations
- RPMs and binaries: `bootc_ostree/fedora/image/offline-repo/<vendor>/`
- Claude Code CLI: `bootc_ostree/fedora/image/offline-repo/claude/` (place the binary as `claude` or `claude-code`)
- VS Code extensions: `bootc_ostree/fedora/image/offline-repo/vscode-extensions/`
- npm tarballs: `bootc_ostree/fedora/image/offline-repo/npm-packages/`
- Wallpapers: `bootc_ostree/fedora/image/offline-repo/wallpapers/`

## Verification
- Confirm files are present under the expected vendor directories.
- Run dry-run test:
```bash
./bootc_ostree/fedora/tests/test_fetch_all_dry_run.sh
```

## Notes
If offline artifacts are missing, build scripts may fall back to online downloads when supported.

GIMP and Krita can be fetched directly from Fedora repos with their dedicated scripts.

DaVinci Resolve and Unreal Engine are vendor-gated artifacts. Their fetch scripts stage an official vendor-supplied installer or archive when `DAVINCI_RESOLVE_URL` or `DAVINCI_RESOLVE_FILE`, and `UNREAL_ENGINE_URL` or `UNREAL_ENGINE_FILE`, are provided.
