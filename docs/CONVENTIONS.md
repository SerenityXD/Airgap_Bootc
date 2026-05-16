# Project Conventions

## Path Conventions
- All build and image workflow paths are rooted at `bootc_ostree/fedora/`.
- Avoid machine-specific absolute paths in docs.
- Generated outputs remain under `bootc_ostree/fedora/output/` and `bootc_ostree/fedora/oci-image/`.

## Naming Conventions
- Shell scripts: kebab-case (`build_export_iso.sh`, `fetch_all_offline.sh`).
- Markdown files: kebab-case where practical.
- Modes and options: use `interactive` and `non-interactive` consistently.

## Documentation Conventions
- `README.md` (root): short, high-level entrypoint and links.
- `bootc_ostree/fedora/README.md`: canonical build/install workflow.
- Keep one canonical source per topic to avoid drift.
- Prefer sections with clear ownership:
  - Purpose
  - Inputs
  - Outputs
  - Verification steps

## Script Conventions
- Use `set -euo pipefail` for shell scripts.
- Keep orchestration scripts declarative when possible.
- Isolate reusable shell helpers under `lib/` directories.
- Keep output messaging concise and consistently formatted.

## Testing Conventions
- Maintain syntax checks for all shell scripts.
- Keep dry-run tests for fetch orchestration behavior.
- Add regression checks when introducing new script modes or flags.
