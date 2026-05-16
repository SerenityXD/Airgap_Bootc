# Documentation

## Central Guides
- **[Root README](../README.md)** — Quick start with Make commands and basic setup
- **[bootc_ostree/fedora/README.md](../bootc_ostree/fedora/README.md)** — Complete build workflows, offline payloads, options, and troubleshooting

## Additional Documentation
- `architecture/` — System and repository structure
- `operations/` — Day-to-day build, offline payload, post-install, and troubleshooting workflows
- `decisions/` — Architecture decision records (ADRs)
- `CONVENTIONS.md` — Naming, organization, and documentation standards

## Operations References
- `operations/build-and-release.md`
- `operations/offline-artifacts.md`
- `operations/post-install.md`
- `operations/security-vulnerabilities.md` — Security findings and fixes
- `operations/iso-size-optimization.md` — ISO size reduction guide
- `operations/troubleshooting.md`
- `operations/nvidia-hybrid-checklist.md` — Hybrid mode dGPU and nvidia-smi validation checklist

## Decisions & Roadmap
- `decisions/adr-0001-path-conventions.md`
- `decisions/maintainability-roadmap.md` — Repository-wide improvement checklist

## Conventions
- Keep documentation DRY — avoid duplicating content across multiple guides
- Link from root README to the fedora/README for detailed workflows
- Use relative paths rooted at `bootc_ostree/fedora/` in commands
