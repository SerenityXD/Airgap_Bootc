# ADR-0001: Fedora Path Conventions

## Status
Accepted

## Context
The repository previously contained mixed path references (`bootc_ostree/...` and `bootc_ostree/fedora/...`), causing drift and confusion.

## Decision
Use `bootc_ostree/fedora/` as the canonical root for build, image, output, and offline workflow references.

## Consequences
- Documentation and scripts remain consistent.
- Fewer broken examples and support issues.
- Path migration updates are required when old references are encountered.
