# System Overview

## Repository Intent
This repository builds an air-gapped Fedora bootc system image and installer ISO.

## High-Level Build Flow
1. Download optional offline payloads into `image/offline-repo/`.
2. Build the workstation image from `image/Containerfile`.
3. Export the image to an OCI archive.
4. Use `bootc-image-builder` to produce an installable ISO.

## Core Areas
- `bootc_ostree/fedora/build-scripts/`: build orchestration and ISO generation.
- `bootc_ostree/fedora/image/`: image definition and offline payload ingestion.
- `bootc_ostree/fedora/tests/`: shell validation checks.
- `bootc_ostree/fedora/output/`: build artifacts.

## Scalability Principles
- Keep orchestration scripts thin and modular.
- Keep docs layered: quick-start at root, details in scoped docs.
- Preserve offline-first behavior for all third-party dependencies.
