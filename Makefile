# Makefile for Bootc Image
# All paths are relative to the repo root.

FEDORA_DIR        := bootc_ostree/fedora
IMAGE_DIR         := $(FEDORA_DIR)/image
BUILD_SCRIPTS_DIR := $(FEDORA_DIR)/build-scripts
FETCH_SCRIPTS_DIR := $(FEDORA_DIR)/fetch-scripts
TESTS_DIR         := $(FEDORA_DIR)/tests

FULL_IMAGE_TAG ?= localhost/bootc-full
BARE_IMAGE_TAG ?= localhost/bootc-bare
IMAGE_TAG      ?= $(FULL_IMAGE_TAG)
OCI_IMAGE_VERSION ?=
OCI_TAG_SUFFIX    := $(if $(strip $(OCI_IMAGE_VERSION)),:$(OCI_IMAGE_VERSION),)
OCI_FILE_SUFFIX   := $(if $(strip $(OCI_IMAGE_VERSION)),-$(OCI_IMAGE_VERSION),)
FULL_OCI_PATH  ?= $(FEDORA_DIR)/output/oci-image/bootc-full$(OCI_FILE_SUFFIX).oci
ISO_NAME   ?=
ISO_TYPE   ?= anaconda-iso

# Pass extra args to build_export_iso.sh (e.g. EXTRA_BUILD_ARGS="--no-image-prune")
EXTRA_BUILD_ARGS ?=
EXTRA_VERIFY_ARGS ?=

# Timer Function
TIMER_START  := $(shell date "+%s")
TIMER_END     = $(shell date "+%s")
TIMER_SECONDS = $(shell expr $(TIMER_END) - $(TIMER_START))
TIMER_FORMAT  = $(shell date --utc --date="@$(TIMER_SECONDS)" "+%H:%M:%S")


.PHONY: help
help:
	@echo ""
	@echo "Bootc Image — Simple Help"
	@echo "================================"
	@echo ""
	@echo "  First time setup: make fetch-bare-full-verify"
	@echo "  What it does: fetches all offline artifacts, builds the bare ISO, builds the full OCI, and verifies contents in one step"
	@echo ""
	@echo "  Common targets:"
	@echo "    build-iso-bare     Build ISO with just GUI + podman baseline (no optional packages)"
	@echo "    verify-iso       Verify contents of existing ISO (expects all optional packages)"
	@echo "    clean-iso       Remove ISO output directories only (keep offline-repo and podman images)"
	@echo "    prune-podman     Aggressive Podman cleanup (unused images/layers/build cache/volumes)"
	@echo ""
	@echo "  For more targets, run: make help-advanced"
	@echo ""

.PHONY: help-advanced
help-advanced:
	@echo ""
	@echo "Bootc Image — Advanced Help"
	@echo "=================================="
	@echo ""
	@echo "  Offline artifacts (advanced):"
	@echo "    fetch-full         Fetch + VS Code extensions + npm tarballs"
	@echo "    refetch-offline-full   Remove all offline-repo and refetch from scratch"
	@echo "    npm-tarballs           Generate npm tarballs for offline JS frameworks"
	@echo "    vscode-extensions      Download VS Code extensions (.vsix)"
	@echo ""
	@echo "  Optimization:"
	@echo ""
	@echo "  Testing (advanced):"
	@echo "    test-syntax            Run shell syntax checks on all scripts"
	@echo "    test-dry-run           Dry-run fetch test (no network calls)"
	@echo "    verify-iso      		  Verify Image (all optional packages expected)"
	@echo ""
	@echo "  Maintenance (advanced):"
	@echo "    clean-iso              Remove ISO output directories only"
	@echo "    prune-podman           Aggressive cleanup: unused images/layers/build cache/volumes"
	@echo ""
	@echo "  All-in-one commands:"
	@echo "    fetch-bare-full-verify All-in-one: refetch-offline + build + verify"
	@echo "    bare-full-verify 	  All-in-one: build + verify"
	@echo ""
	@echo "  Variables (all targets):"
	@echo "    FULL_IMAGE_TAG         Full-build Podman image tag (default: $(FULL_IMAGE_TAG))"
	@echo "    BARE_IMAGE_TAG         Bare-build Podman image tag (default: $(BARE_IMAGE_TAG))"
	@echo "    IMAGE_TAG              Podman image tag override for build-image (default: $(IMAGE_TAG))"
	@echo "    OCI_IMAGE_VERSION      Optional OCI image version/tag suffix (example: v1.0)"
	@echo "    ISO_NAME               Custom ISO filename"
	@echo "    ISO_TYPE               anaconda-iso | iso (default: $(ISO_TYPE))"
	@echo "    EXTRA_BUILD_ARGS       Extra flags to build_export_iso.sh"
	@echo "    EXTRA_VERIFY_ARGS      Extra flags to verify_iso_contents.sh"
	@echo ""
	@echo "  Verify ISO exclusion flags:"
	@echo "    --no-expect-docker-desktop"
	@echo "    --no-expect-gimp-krita"
	@echo "    --no-expect-blender"
	@echo "    --no-expect-rations"
	@echo "    --no-expect-cuda-toolkit"
	@echo "    --desktop-env ENV      Force desktop environment check (auto-detected if omitted)"
	@echo ""
	@echo "  Advanced example:"
	@echo "    make refetch-offline-full build-iso verify-iso"
	@echo "    make build-iso EXTRA_BUILD_ARGS='--no-image-prune --build-arg EXCLUDE_CUDA_TOOLKIT=yes'"
	@echo ""

# ---------------------------------------------------------------------------
# Fetching
# ---------------------------------------------------------------------------

.PHONY: fetch-full
fetch-full:
	INCLUDE_OPTIONAL_FETCH=true $(FEDORA_DIR)/fetch_all_offline.sh

.PHONY: refetch-offline-full
refetch-offline-full:
	@mkdir -p $(IMAGE_DIR)/offline-repo/rations $(IMAGE_DIR)/offline-repo/wallpapers
	@echo "Removing offline-repo packages except manually managed rations and wallpapers..."
	find $(IMAGE_DIR)/offline-repo -mindepth 1 -maxdepth 1 \
		! -name rations \
		! -name wallpapers \
		-exec sudo rm -rf -- {} +
	@echo "Refetching all offline artifacts..."
	INCLUDE_OPTIONAL_FETCH=true $(FEDORA_DIR)/fetch_all_offline.sh
	@echo "Refetch complete."



.PHONY: npm-tarballs
npm-tarballs:
	$(FETCH_SCRIPTS_DIR)/create-npm-tarballs.sh

.PHONY: vscode-extensions
vscode-extensions:
	$(FETCH_SCRIPTS_DIR)/pull-vscode-extensions.sh

# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

.PHONY: build-image
build-image: IMAGE_TAG = $(FULL_IMAGE_TAG)
build-image:
	podman build --format docker -t $(IMAGE_TAG) -f $(IMAGE_DIR)/Containerfile $(IMAGE_DIR)

.PHONY: build-image-bare
build-image-bare: IMAGE_TAG = $(BARE_IMAGE_TAG)
build-image-bare:
	podman build --format docker -t $(IMAGE_TAG) -f $(IMAGE_DIR)/Containerfile.bare $(IMAGE_DIR)

# Helper: Build ISO with buildargs
define build_iso
	$(BUILD_SCRIPTS_DIR)/build_export_iso.sh $(1) \
	    --tag $(6) \
	    --profile $(4) \
	    --artifact $(5) \
	    $(if $(7),--oci-path $(7)) \
	    $(if $(2),--iso-name $(2)) \
	    $(if $(filter-out anaconda-iso,$(ISO_TYPE)),--iso-type $(ISO_TYPE)) \
	    $(foreach arg,$(3),--build-arg $(arg)) \
	    $(EXTRA_BUILD_ARGS)
endef

.PHONY: build-iso
build-iso: IMAGE_TAG = $(FULL_IMAGE_TAG)
build-iso:
	@echo "Building full ISO with all optional packages (~13GB, includes CUDA)..."
	$(call build_iso,interactive,$(ISO_NAME),,full,iso,$(IMAGE_TAG))

.PHONY: build-iso-bare
build-iso-bare: IMAGE_TAG = $(BARE_IMAGE_TAG)
build-iso-bare:
	@echo "Building bare ISO (GUI + podman baseline for two-step deployment)..."
	$(call build_iso,interactive,bootc-bare.iso,,bare,iso,$(IMAGE_TAG))

.PHONY: build-oci-full
build-oci-full: OCI_PATH = $(FEDORA_DIR)/output/oci-image/bootc-full$(OCI_FILE_SUFFIX).oci
build-oci-full: IMAGE_TAG = $(FULL_IMAGE_TAG)$(OCI_TAG_SUFFIX)
build-oci-full:
	@echo "Building full OCI archive (includes full desktop environment)..."
	$(call build_iso,interactive,,,full,oci,$(IMAGE_TAG),$(OCI_PATH))



# ---------------------------------------------------------------------------
# Testing
# ---------------------------------------------------------------------------

.PHONY: test
test: test-syntax test-dry-run

.PHONY: test-syntax
test-syntax:
	$(TESTS_DIR)/test_shell_syntax.sh

.PHONY: test-dry-run
test-dry-run:
	$(TESTS_DIR)/test_fetch_all_dry_run.sh

.PHONY: verify-iso
verify-iso:
	@echo "Verifying Image build (expecting all optional packages)..."
	@OCI_FILE=$$(ls -t $(FEDORA_DIR)/output/oci-image/*.oci 2>/dev/null | head -n1); \
	ISO_FILE=$$(ls -t $(FEDORA_DIR)/output/bootiso/*.iso 2>/dev/null | head -n1); \
	if [ -n "$$OCI_FILE" ]; then echo "Found OCI: $$OCI_FILE"; fi; \
	if [ -n "$$ISO_FILE" ]; then echo "Found ISO: $$ISO_FILE"; fi; \
	ARGS=""; \
	if [ -n "$$OCI_FILE" ]; then ARGS="$$ARGS --oci-path $$OCI_FILE"; fi; \
	if [ -n "$$ISO_FILE" ]; then ARGS="$$ARGS --iso-path $$ISO_FILE"; fi; \
	$(BUILD_SCRIPTS_DIR)/verify_iso_contents.sh $$ARGS $(EXTRA_VERIFY_ARGS)




# ---------------------------------------------------------------------------
# Maintenance
# ---------------------------------------------------------------------------


.PHONY: clean-iso
clean-iso:
	@echo "Removing ISO output directories under $(FEDORA_DIR)/output/ ..."
	sudo rm -rf $(FEDORA_DIR)/output/
	@echo "Done."

.PHONY: prune-podman
prune-podman:
	@echo "Aggressively pruning podman (unused images, containers, networks, volumes, build cache, and untagged images) ..."
	@echo "Before cleanup:"
	@podman system df || true
	podman system prune -a -f --volumes
	podman image prune -a -f
	podman builder prune -a -f
	@echo "Removing untagged intermediate images (<none>:<none>) ..."
	@UNTAGGED_IDS="$$(podman images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | awk '$$1=="<none>:<none>"{print $$2}' | sort -u)"; \
	if [ -n "$$UNTAGGED_IDS" ]; then \
		echo "Found $$(printf '%s\n' "$$UNTAGGED_IDS" | wc -l) untagged images"; \
		printf '%s\n' "$$UNTAGGED_IDS" | xargs -r podman rmi -f; \
	else \
		echo "No untagged images found"; \
	fi
	@podman system prune --external -f || true
	podman volume prune -f
	@echo "After cleanup:"
	@podman system df || true
	@echo "Podman aggressive prune complete."

.PHONY: prune-podman-sudo
prune-podman-sudo:
	@echo "Running podman prune with sudo (may be needed if some images/volumes are owned by root)..."
	sudo podman system df || true
	sudo podman system prune -a -f --volumes
	sudo podman image prune -a -f
	sudo podman builder prune -a -f
	@echo "Removing untagged intermediate images (<none>:<none>) with sudo..."
	@UNTAGGED_IDS="$$(sudo podman images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | awk '$$1=="<none>:<none>"{print $$2}' | sort -u)"; \
	if [ -n "$$UNTAGGED_IDS" ]; then \
		echo "Found $$(printf '%s\n' "$$UNTAGGED_IDS" | wc -l) untagged images"; \
		printf '%s\n' "$$UNTAGGED_IDS" | xargs -r sudo podman rmi -f; \
	else \
		echo "No untagged images found"; \
	fi
	sudo podman system prune --external -f || true
	sudo podman volume prune -f
	@echo "After cleanup:"
	@sudo podman system df || true
	@echo "Podman prune with sudo complete."

.PHONY: clean-all
clean-all: prune-podman-sudo prune-podman clean-iso
	@echo "Full cleanup complete."

# ---------------------------------------------------------------------------
# All-in-one targets
# ---------------------------------------------------------------------------

.PHONY: fetch-bare-full-verify
fetch-bare-full-verify:
	@echo "Validating sudo access for fetch phase..."
	@sudo -v
	@echo "Sudo credentials cached. Starting fetch-bare-full-verify chain with sudo keepalive..."
	@{ \
		while true; do sudo -n true >/dev/null 2>&1 || exit; sleep 60; done & \
		SUDO_KEEPALIVE_PID=$$!; \
		trap 'kill $$SUDO_KEEPALIVE_PID' EXIT; \
		$(MAKE) refetch-offline-full build-iso-bare build-oci-full verify-iso \
			EXTRA_VERIFY_ARGS="--oci-path $(FULL_OCI_PATH)" timer; \
		STATUS=$$?; \
		kill $$SUDO_KEEPALIVE_PID; \
		exit $$STATUS; \
	}
	@echo "All-in-one fetch, build, and verify complete. (Bare ISO + Full OCI)"

.PHONY: bare-full-verify
bare-full-verify:
	@echo "Validating sudo access for build phase..."
	@sudo -v
	@echo "Sudo credentials cached. Starting bare-full-verify chain with sudo keepalive..."
	@{ \
		while true; do sudo -n true >/dev/null 2>&1 || exit; sleep 60; done & \
		SUDO_KEEPALIVE_PID=$$!; \
		trap 'kill $$SUDO_KEEPALIVE_PID' EXIT; \
		$(MAKE) build-iso-bare build-oci-full verify-iso \
			EXTRA_VERIFY_ARGS="--oci-path $(FULL_OCI_PATH)" timer; \
		STATUS=$$?; \
		kill $$SUDO_KEEPALIVE_PID; \
		exit $$STATUS; \
	}
	@echo "All-in-one build, and verify complete. (Bare ISO + Full OCI)"

# ---------------------------------------------------------------------------
# Timer target 
# ---------------------------------------------------------------------------

.PHONY: timer
timer:
	@echo "Timer: Total Time taken: $(TIMER_FORMAT)"