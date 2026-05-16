# Build and Release Workflow

## Standard Build
```bash
./bootc_ostree/fedora/build-scripts/build_export_iso.sh interactive
```

## Alternate Modes
```bash
./bootc_ostree/fedora/build-scripts/build_export_iso.sh non-interactive
./bootc_ostree/fedora/build-scripts/build_export_iso.sh compare
```

## Useful Flags
```bash
./bootc_ostree/fedora/build-scripts/build_export_iso.sh \
  --fetch-offline \
  --packages all \
  --iso-name BOOTC-Interactive.iso
```

## Artifacts
- ISO: `bootc_ostree/fedora/output/bootiso/`
- OCI archive: `bootc_ostree/fedora/oci-image/`
- Logs: `bootc_ostree/fedora/build-scripts/logs/`

## Validation
```bash
./bootc_ostree/fedora/tests/test_shell_syntax.sh
./bootc_ostree/fedora/tests/test_fetch_all_dry_run.sh
```
