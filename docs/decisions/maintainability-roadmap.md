# Maintainability Improvement TODO

This file tracks the repository-wide maintainability and structure cleanup.

## Status Legend
- [ ] Not started
- [~] In progress
- [x] Completed

## 1) Documentation Consolidation
- [x] Rewrite root README as concise project entrypoint.
- [x] Rewrite Fedora README as canonical detailed guide with clear sections.
- [x] Replace stale Fedora INDEX with a lightweight pointer index.
- [x] Add docs index and conventions pages.
- [x] Add targeted docs for architecture and operations.

## 2) Folder and File Organization
- [x] Create top-level docs hierarchy (`docs/architecture`, `docs/operations`, `docs/decisions`).
- [x] Preserve runtime/build folders while reducing documentation sprawl.
- [x] Add project organization conventions (`docs/CONVENTIONS.md`).

## 3) Redundant/Outdated Content Cleanup
- [x] Remove stale and non-existent references from primary docs.
- [x] Mark historical stack breakdown file as moved to docs.
- [x] Eliminate path drift in examples (canonical path is `bootc_ostree/fedora/...`).

## 4) Script Readability Improvements
- [x] Refactor `fetch_all_offline.sh` to reduce duplicated orchestration logic.
- [x] Split `build_export_iso.sh` into sourced helper files under `build-scripts/lib/`.
- [x] Add focused smoke validation for script entrypoint (`--help`) and syntax checks.

## 5) Repository Hygiene and Standards
- [x] Fix `.gitignore` for Fedora subtree outputs and offline artifacts.
- [x] Define naming and ownership conventions for files and docs.
- [x] Add safe rollout and migration checklist.

## 6) Validation
- [x] Run syntax tests (`bootc_ostree/fedora/tests/test_shell_syntax.sh`).
- [x] Run dry-run fetch workflow test (`bootc_ostree/fedora/tests/test_fetch_all_dry_run.sh`).
- [~] Optional local build smoke test (`build_export_iso.sh --help` and one mode command).

## Safe Rollout Sequence
1. Apply docs and path corrections.
2. Update ignore rules and conventions.
3. Refactor low-risk script internals (no behavior changes).
4. Validate with existing shell tests.
5. Follow with deeper build-script modularization in a dedicated PR.

## Validation Notes
- `test_shell_syntax.sh`: passed
- `test_fetch_all_dry_run.sh`: passed
- `build_export_iso.sh --help`: prompted for sudo in this environment, so full smoke run was not completed unattended

---

# Future Improvements (Medium & Lower Priority)

This section tracks suggested improvements identified through code review and maintainability analysis.

## 7) Build Script Modularization
- [ ] Extract distinct functions from `build_export_iso.sh` (currently 500+ lines):
  - `build_image()` — container image creation
  - `export_oci()` — OCI archive export
  - `create_iso()` — ISO creation from OCI
  - Dedicated trap/cleanup handler
- **Benefit**: Easier to test, extend, and debug individual phases
- **Effort**: 2-3 hours
- **Notes**: Maintain backward compatibility with mode-based API

## 8) Consolidate Offline Artifacts Documentation
- [ ] Remove duplicate content (currently in `bootc_ostree/fedora/README.md` and `docs/operations/offline-artifacts.md`)
- [ ] Create single canonical source for offline artifact workflow
- [ ] Update cross-references in both locations
- **Benefit**: Easier to maintain, reduces drift
- **Effort**: 1 hour

## 9) Comprehensive Build Customization Guide
- [ ] Document build argument patterns in `docs/operations/`
- [ ] Explain how to create custom ISO configs without editing `Containerfile`
- [ ] Add examples for common scenarios:
  - Minimal image (core tools only)
  - Full entertainment workstation
  - Data science focused build
  - Game development focused build
- **Benefit**: Users use proper mechanisms instead of hacking Containerfile
- **Effort**: 2-3 hours

## 10) Enhanced Build Logging & Diagnostics
- [ ] Create log analysis helpers (grep/parse for common failures)
- [ ] Document log file locations prominently in README
- [ ] Add log rotation policy
- [ ] Log captured environment variables at build start (for debugging)
- **Benefit**: Faster troubleshooting, better diagnostics
- **Effort**: 2 hours

## 11) Expand Test Coverage
- [ ] Add integration tests for actual build workflow (non-critical)
- [ ] Add offline-mode validation tests
- [ ] Add ISO image structure validation
- [ ] Add post-install script smoke tests
- **Benefit**: Catch regressions early, document expected behavior
- **Effort**: 4-6 hours
- **CI Integration**: Ideal for GitHub Actions workflow

## 12) Standardize Script Naming
- [~] Rename `pull-vscode-extensions.sh` → `fetch_vscode_extensions.sh` (consistency)
- [ ] Consider renaming `create-npm-tarballs.sh` → `fetch_npm_tarballs.sh` or `prepare_npm_tarballs.sh`
- **Benefit**: Uniform naming convention
- **Effort**: 1 hour (script renaming + updates to fetch_all_offline.sh)
- **Note**: Include in next breaking-change release

## 13) Enhance Containerfile Documentation
- [ ] Add clear section markers (e.g., `# ===== GNOME Desktop =====`)
- [ ] Document offline check patterns with comments
- [ ] Add notes explaining why certain packages are grouped
- [ ] Document which build arguments affect which sections
- **Benefit**: Easier code navigation and future modifications
- **Effort**: 3-4 hours

## 14) Tool-Specific Troubleshooting Guides
- [ ] NVIDIA driver build failures in container
- [ ] Docker Desktop startup and permission issues
- [ ] WineHQ package conflicts and compatibility
- [ ] Blender library and GPU compatibility
- [ ] k3s networking and image load failures
- **Benefit**: Faster user issue resolution
- **Effort**: 3 hours

## 15) Granular Makefile Targets
- [ ] `make build-image-only` — skip ISO generation
- [ ] `make quick-test` — syntax + dry-run (fast validation)
- [ ] `make rebuild-image` — clean + rebuild without offline refetch
- [ ] `make offline-validate` — verify all offline artifacts are present
- **Benefit**: Faster iteration loops for developers
- **Effort**: 1-2 hours

## 16) Generic Build Script Helpers
- [ ] Enhance `build-scripts/lib/common.sh` with:
  - Structured logging (same as image scripts)
  - Path resolution helpers
  - File download utilities
- [ ] Mirror utilities available in `fetch-scripts/lib/common.sh`
- **Benefit**: Reduced code duplication, consistent patterns
- **Effort**: 1.5 hours

## 17) Output Backup Directory Policy
- [ ] Document cleanup policy for old `output.prev-*` directories
- [ ] Add them to meaningful `.gitignore` patterns or document retention
- [ ] Consider automated cleanup (keep last N builds, delete older ones)
- **Benefit**: Reduces confusion about current outputs
- **Effort**: 30 minutes

## 18) Changelog / Release Notes
- [ ] Maintain CHANGELOG.md documenting:
  - Breaking changes in build process
  - New offline artifacts added
  - Containerfile modifications
  - Script API changes
- **Benefit**: Track evolution, helps users understand version differences
- **Effort**: Ongoing (20 minutes per release)

## 19) GitHub Actions CI Workflow
- [ ] Shell syntax validation (all scripts)
- [ ] Containerfile build validation (fast smoke test)
- [ ] Offline artifact presence check
- [ ] DNF cache hygiene lint
- [ ] Optional: image size guardrail (fail if >15GB)
- **Benefit**: Catch issues before merge, enforce standards
- **Effort**: 2-3 hours
- **Reference**: See `.github/copilot-instructions.md` for detailed checks

## 20) Architecture Decision Record (ADR) Expansion
- [ ] ADR for offline-first strategy and trade-offs
- [ ] ADR for bootc vs traditional package managers
- [ ] ADR for Anaconda installer choice
- [ ] ADR for image size optimization trade-offs
- **Benefit**: Document design rationale for future maintainers
- **Effort**: 3-4 hours

---

## Implementation Priority Tiers

### Tier 1 (High Value, Low Effort)
- #8 Consolidate offline documentation (1 hour)
- #17 Output backup policy (30 min)
- #12 Script naming standardization (1 hour)

### Tier 2 (Medium Value, Medium Effort)
- #7 Build script modularization (2-3 hours, high impact)
- #10 Enhanced logging & diagnostics (2 hours)
- #15 Granular Makefile targets (1-2 hours)
- #16 Generic build script helpers (1.5 hours)

### Tier 3 (Larger Initiatives)
- #11 Expand test coverage (4-6 hours, ideal for CI)
- #9 Build customization guide (2-3 hours)
- #13 Containerfile documentation (3-4 hours)
- #14 Tool-specific troubleshooting (3 hours)
- #19 GitHub Actions CI (2-3 hours, reusable infrastructure)
- #20 ADR expansion (3-4 hours, documentation)

## Dependencies & Ordering

- #8 should probably complete before #9 (consolidate before expanding)
- #7 (build script modularization) should precede #11 (testing)
- #19 (CI workflow) benefits from #11 (having tests to run)
- #13 (Containerfile documentation) is independent

---
