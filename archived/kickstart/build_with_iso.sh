#!/usr/bin/env bash
set -euo pipefail

## Helper script to download a Fedora installation ISO and run livemedia-creator
## Adapt the ISO URL for the Fedora release you target.

ISO_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/39/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-39-1.6.iso"
ISO_PATH="/tmp/fedora-install.iso"

echo "Downloading ISO to ${ISO_PATH} (change ISO_URL in this script if needed)"
curl -fSL -o "${ISO_PATH}" "${ISO_URL}"

echo "Running livemedia-creator with ${ISO_PATH}"
sudo livemedia-creator --make-iso --iso "${ISO_PATH}" --ks kickstart/bootc.ks --project bootc --resultdir out --tmp /var/tmp

echo "Done. Check out/ for the generated ISO files."
