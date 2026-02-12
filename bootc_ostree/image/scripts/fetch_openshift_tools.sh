#!/bin/bash
# Download OpenShift and Kubernetes CLI tools for offline inclusion in bootc image
# Run this on an internet-connected machine before building the ISO

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)"
OFFLINE_DIR="${SCRIPT_DIR}/image/offline-repo/openshift"
OC_VERSION="${OC_VERSION:-stable}"  # Can set to specific version like "4.14.0"
KUBECTL_VERSION="${KUBECTL_VERSION:-stable}"

echo "========================================"
echo "Fetch OpenShift/Kubernetes CLI Tools"
echo "========================================"
echo ""
echo "Target directory: ${OFFLINE_DIR}"
echo ""

mkdir -p "${OFFLINE_DIR}"
cd "${OFFLINE_DIR}"

# Download oc (includes kubectl)
echo "[1/2] Downloading oc (OpenShift CLI)..."
if [ "${OC_VERSION}" = "stable" ]; then
    OC_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz"
else
    OC_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux.tar.gz"
fi

if curl -fL "${OC_URL}" -o oc.tar.gz; then
    echo "  Extracting..."
    tar -xzf oc.tar.gz
    rm -f oc.tar.gz README.md
    chmod +x oc kubectl 2>/dev/null || true
    
    if [ -f oc ]; then
        echo "  ✓ oc downloaded: $(./oc version --client 2>/dev/null | head -1 || echo 'version check skipped')"
    fi
    if [ -f kubectl ]; then
        echo "  ✓ kubectl included in oc bundle"
    fi
else
    echo "  ✗ Failed to download oc"
    echo "  Manual download: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
    exit 1
fi

# Verify kubectl or download standalone
if [ ! -f kubectl ]; then
    echo "[2/2] Downloading kubectl (standalone)..."
    if [ "${KUBECTL_VERSION}" = "stable" ]; then
        KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    fi
    
    if curl -fLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; then
        chmod +x kubectl
        echo "  ✓ kubectl downloaded: ${KUBECTL_VERSION}"
    else
        echo "  ✗ Failed to download kubectl (not critical, oc bundle may include it)"
    fi
else
    echo "[2/2] kubectl already present from oc bundle"
fi

echo ""
echo "========================================"
echo "Download Complete!"
echo "========================================"
echo ""
echo "Files in ${OFFLINE_DIR}:"
ls -lh "${OFFLINE_DIR}"
echo ""
echo "These binaries will be automatically included in the next ISO build."
echo "To rebuild with offline OpenShift tools:"
echo "  cd ${SCRIPT_DIR}"
echo "  ./build_export_iso.sh --iso-name SCVU.iso"
echo ""
