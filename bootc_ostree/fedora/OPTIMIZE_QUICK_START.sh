#!/bash
# Quick Reference: ISO Size Optimization Commands

# 1. DEDUPLICATION (First, remove duplicate RPMs)
cd bootc_ostree/fedora/fetch-scripts
echo "=== Preview deduplication ==="
DRY_RUN=true VERBOSE=true ./deduplicate-offline-repo.sh

echo "=== Apply deduplication (saves 200-400MB) ==="
./deduplicate-offline-repo.sh

# 2. BUILD MINIMAL ISO (No optional packages - fastest, smallest)
cd ../build-scripts
echo "=== Building minimal ISO (~8-9GB) ==="
./build_export_iso.sh --iso-name bootc-minimal.iso

# 3. BUILD WITH SPECIFIC PACKAGES
echo "=== Building with Docker Desktop ==="
./build_export_iso.sh --iso-name bootc-with-docker.iso \
  --build-arg INCLUDE_DOCKER_DESKTOP=yes

echo "=== Building with all optional packages ==="
./build_export_iso.sh --iso-name bootc-full.iso \
  --build-arg INCLUDE_OPTIONAL_PACKAGES=yes

# 4. BUILD WITH CUSTOM SELECTION
echo "=== Custom: Docker + GIMP/Krita ==="
./build_export_iso.sh --iso-name bootc-dev-art.iso \
  --build-arg INCLUDE_DOCKER_DESKTOP=yes \
  --build-arg INCLUDE_GIMP_KRITA=yes

# 5. CHECK SIZE RESULTS
echo -e "\n=== ISO File Sizes ==="
ls -lh ../output/bootiso/*.iso | awk '{print $9, "\t", $5}'
