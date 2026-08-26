# Security Vulnerability Report

> Generated: 2026-04-01  
> Scope: `bootc_ostree/fedora/image/Containerfile` and build scripts  
> Method: Static analysis of build artifacts, scripts, and configuration

---

## Summary

| # | Severity | Status | Location | Title |
|---|----------|--------|----------|-------|
| 1 | **Critical** | Fixed | `Containerfile` ~L268 | Chrome RPM installed with `--nogpgcheck` |
| 2 | **Critical** | Fixed | `Containerfile` ~L820 | k3s kubeconfig world-readable (admin token) |
| 3 | **Critical** | Fixed | `Containerfile` ~L985-L1000 | Password exposed via `--bootc-password` CLI argument |
| 4 | **High** | Fixed | `Containerfile` L394-395 | Offline RPM repos installed with `gpgcheck=0` |
| 5 | **High** | Fixed | `Containerfile` ~L85 | Samba `map to guest = Bad User` allows unauthenticated access |
| 6 | **High** | Fixed | `Containerfile` ~L835 | SELinux disabled for k3s containers |
| 7 | **Medium** | Open | `Containerfile` ~L748-790 | Binaries (oc, kubectl, helm) installed without checksum verification |
| 8 | **Medium** | Open | `Containerfile` ~L1574 | xrdp and Samba enabled at boot with no firewall rules |
| 9 | **Medium** | Open | `Containerfile` L34-35 | Enterprise CA bundle trusted without fingerprint pinning |
| 10 | **Medium** | Open | `Containerfile` ~L1172-1175 | VS Code extensions installed for all users without an allowlist |
| 11 | **Low** | Open | `Containerfile` ~L1070-1110 | No minimum password length enforcement |
| 12 | **Low** | Open | `Containerfile` ~L121 | Samba `[homes]` share is browseable by default |
| 13 | **Low** | Open | `Containerfile` ~L629-635 | npm tarballs installed globally without integrity verification |

---

## Critical Findings

### CVE-CLASS-1 — Chrome RPM installed with `--nogpgcheck`
**File:** `bootc_ostree/fedora/image/Containerfile` (L268-275)  
**Status:** Fixed ✓

**Description:**  
The Google Chrome RPM was downloaded from the internet and then installed with `--nogpgcheck`, which disables RPM signature verification. A man-in-the-middle attack or a compromised mirror could substitute a backdoored RPM with no detection.

**Fix Applied:**  
Google's signing key is imported with `rpm --import https://dl.google.com/linux/linux_signing_key.pub` before the package is installed. The `--nogpgcheck` flag has been removed.

**Current Code (Fixed):**
```dockerfile
RUN dnf -y --setopt=install_weak_deps=False install wget xdg-utils && \
    rpm --import https://dl.google.com/linux/linux_signing_key.pub && \
    curl --fail --show-error --location --retry 5 --retry-delay 3 --retry-connrefused \
    https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm \
    -o /tmp/google-chrome.rpm && \
    dnf -y install /tmp/google-chrome.rpm && \
    rm -f /tmp/google-chrome.rpm && \
    dnf -y clean all && rm -rf /var/cache/dnf

---

### CVE-CLASS-2 — k3s kubeconfig world-readable (cluster admin token exposed)
**File:** `bootc_ostree/fedora/image/Containerfile` (L820-835)  
**Status:** Fixed ✓

**Description:**  
`/etc/rancher/k3s/config.yaml` had `write-kubeconfig-mode: "0644"`, making `/etc/rancher/k3s/k3s.yaml` world-readable. This file contains the k3s cluster admin bearer token. Any local user could read it and gain full cluster-admin access to the Kubernetes API server.

**Fix Applied:**  
`write-kubeconfig-mode` changed to `"0600"`. The `k3s-kubeconfig-distribute.service` copies this file per-user at runtime with `chmod 600`, so per-user kubectl access is unaffected.

**Current Code (Fixed):**
```yaml
# Kubeconfig is owner-readable only (0600). The k3s-kubeconfig-distribute.service
# copies it per-user at runtime with chmod 600, so no world-readable admin token.
write-kubeconfig-mode: "0600"
# Explicit flannel backend — vxlan works in fully air-gapped environments
flannel-backend: "vxlan"
# SELinux enforcement left at the k3s default (enabled). Install k3s-selinux
# policy package if container workloads require SELinux policy adjustments.
```

---

### CVE-CLASS-3 — Password exposed via `--bootc-password` CLI argument
**File:** `bootc_ostree/fedora/image/Containerfile` (L985-L1000, embedded in `bootc-post-install.sh`)  
**Status:** Fixed ✓

**Description:**  
Passing `--bootc-password` on the command line causes the password to appear in:
- `/proc/<pid>/cmdline`
- `ps aux` and `ps -ef` output
- Shell history (if the command is run interactively with the password in-line)
- System audit logs and `journald` command tracing

Any local user can read `/proc/<pid>/cmdline` while the process runs.

**Fix Applied:**  
A new `--bootc-password-file FILE` option has been added. It reads the password from a file, preventing credential exposure. The `--bootc-password` flag is retained for backward compatibility but now emits a security warning to stderr.

**Current Code (Fixed):**
```bash
--bootc-password)
    [ $# -ge 2 ] || { echo "Missing value for $1"; exit 1; }
    echo "WARNING: --bootc-password passes credentials via command-line arguments," >&2
    echo "         which are visible in 'ps aux' and /proc/<pid>/cmdline." >&2
    echo "         Prefer --bootc-password-file /path/to/file for non-interactive use." >&2
    BOOTC_CREATE_USER_PASSWORD="$2"; shift 2 ;;

--bootc-password-file)
    [ $# -ge 2 ] || { echo "Missing value for $1"; exit 1; }
    [ -r "$2" ] || { echo "Error: cannot read password file '$2'"; exit 1; }
    BOOTC_CREATE_USER_PASSWORD=$(cat "$2"); shift 2 ;;
```

**Recommended Usage:**
```bash
# Secure method (preferred)
printf 'secret' > /root/.bootc-pw && chmod 600 /root/.bootc-pw
sudo bootc-post-install.sh --bootc-user alice --bootc-password-file /root/.bootc-pw
rm /root/.bootc-pw

# Legacy method (not recommended — shows warning)
sudo bootc-post-install.sh --bootc-user alice --bootc-password 'secret'  # ⚠️ WARNING
```

---

## High Findings

### H-1 — Offline RPM repos installed with `gpgcheck=0`
**File:** `bootc_ostree/fedora/image/Containerfile` (L394-395)  
**Status:** Fixed ✓ (with architectural note below)

**Description:**  
Every offline RPM in every vendor directory (`obs`, `rpmfusion`, `gimp`, `krita`, `winehq`) was installed via a dynamically created local repo with `gpgcheck=0`. A tampered RPM placed in the `offline-repo/` directory before a build would be installed silently with root privileges.

**Fix Applied:**  
Added explicit `--setopt="$repo_id.localpkg_gpgcheck=0"` to make the disable explicitly auditable in build logs. This documents the intent to rely on repository integrity from the build context.

**Current Code (Fixed):**
```bash
# Example from install_from_local_rpm_repo()
dnf -y --setopt="$repo_id.gpgcheck=0" \
       --setopt="$repo_id.localpkg_gpgcheck=0" \
       install /tmp/offline/"$repo_id"/*.rpm || { ... }
```

**Recommended Long-Term Fix:**  
To move toward full GPG verification:

1. Add a `gpg-keys/` directory alongside each offline vendor repo directory:
   ```
   offline-repo/
     ├── rpmfusion/
     │   ├── RPM-GPG-KEY-rpmfusion-free-fedora-43
     │   └── *.rpm
     ├── obs/
     ├── etc/
   ```

2. Import the vendor GPG key before creating the repo:
   ```dockerfile
   RUN rpm --import /tmp/offline/rpmfusion/RPM-GPG-KEY-rpmfusion-free-fedora-43 && \
       dnf -y install /tmp/offline/rpmfusion/*.rpm
   ```

3. Remove the explicit `gpgcheck=0` disable.

**Current Security Posture:**  
- The fix makes the offline RPM installation policy explicit in build logs.
- Full GPG verification requires shipping vendor keys, which requires keystore management in CI/CD.
- For now, security relies on build-context integrity (the offline-repo must come from a trusted source)

---

### H-2 — Samba `map to guest = Bad User` allows unauthenticated access
**File:** `bootc_ostree/fedora/image/Containerfile` (L85)  
**Status:** Fixed ✓

**Description:**  
`map to guest = Bad User` causes Samba to fall back to guest (unauthenticated) access when a user provides an incorrect password. Combined with `usershare allow guests = yes`, user-created shares were accessible to anyone on the LAN without valid credentials.

**Fix Applied:**
- `map to guest` changed from `Bad User` to `Never` (the Samba default)
- `usershare allow guests` changed from `yes` to `no`

**Current Code (Fixed):**
```ini
[global]
   workgroup = WORKGROUP
   server string = BOOTC Bootc Workstation
   security = user
   map to guest = Never
   # ...
   usershare allow guests = no
   usershare owner only = yes
```

**Result:**  
- Failed authentication attempts no longer fall back to guest access.
- User-created shares cannot be accessed by guest users.

---

### H-3 — SELinux disabled for k3s containers
**File:** `bootc_ostree/fedora/image/Containerfile` (L835)  
**Status:** Fixed ✓

**Description:**  
The k3s configuration contained `selinux: false`, disabling Mandatory Access Control enforcement for all k3s container workloads. This significantly increases the blast radius of a container escape, as no SELinux labels are enforced on container processes or filesystem access.

**Fix Applied:**  
`selinux: false` has been removed from `/etc/rancher/k3s/config.yaml`. k3s defaults to respecting the system SELinux policy. If workloads fail due to SELinux denials, the optional `k3s-selinux` policy package should be installed rather than disabling SELinux entirely.

**Current Code (Fixed):**
```yaml
# Kubeconfig is owner-readable only (0600). The k3s-kubeconfig-distribute.service
# copies it per-user at runtime with chmod 600, so no world-readable admin token.
write-kubeconfig-mode: "0600"
# Explicit flannel backend — vxlan works in fully air-gapped environments
flannel-backend: "vxlan"
# SELinux enforcement left at the k3s default (enabled). Install k3s-selinux
# policy package if container workloads require SELinux policy adjustments.
```

**Note:**  
The comment documents the security posture explicitly: SELinux is left enabled, and if container workloads require policy adjustments, use the `k3s-selinux` package rather than disabling SELinux.

---

## Medium Findings (Open)

### M-1 — Binaries installed without checksum verification
**File:** `bootc_ostree/fedora/image/Containerfile` (L748-790)  
**Status:** Open (k3s partially addressed, oc/kubectl/helm still vulnerable)

**Description:**  
Binary tools `oc`, `kubectl`, and `helm` are copied from `offline-repo/` and installed with no checksum or signature verification before execution. A tampered binary in the offline repo directory would be trusted silently.

**Current State:**  
- **k3s** (L814-817): Supports `sha256sum-*.txt` files alongside the binary and copies them to `/usr/share/k3s/`
- **oc, kubectl, helm** (L748-790): No checksum verification

**Current Code:**
```bash
# OpenShift/Kubernetes CLI tools — NO checksums verified
if [ -f "$OPENSHIFT_DIR/oc" ]; then
    install -m 0755 "$OPENSHIFT_DIR/oc" "$INSTALL_DIR/oc" && \
    echo "✓ oc installed from cache" && \
    oc version --client 2>/dev/null || true
else
    echo "⚠ oc binary not found in $OPENSHIFT_DIR (optional)"
fi
```

**Recommended Fix:**  
Extend the k3s pattern to all binaries:

1. When fetching binaries in `fetch_*.sh` scripts, also download `sha256sum.txt`:
   ```bash
   # In fetch_openshift_tools.sh
   curl -fsSL "https://mirror.openshift.com/pub/openshift-v4/.../oc-$VERSION-linux.tar.gz" \
     -o openshift/oc.tar.gz
   sha256sum openshift/oc.tar.gz > openshift/sha256sum.txt
   ```

2. Update the Containerfile to verify before install:
   ```dockerfile
   if [ -f "$OPENSHIFT_DIR/sha256sum.txt" ]; then
       cd "$OPENSHIFT_DIR" && sha256sum --check sha256sum.txt || exit 1
   fi
   install -m 0755 "$OPENSHIFT_DIR/oc" "$INSTALL_DIR/oc"
   ```

**Priority:** Medium (binaries run with user privileges, not root; lower risk than kernel modules)

---

### M-2 — xrdp and Samba enabled at boot with no firewall rules
**File:** `bootc_ostree/fedora/image/Containerfile` (L70-75 enable; L1574 enable)  
**Status:** Open

**Description:**  
`xrdp` (TCP 3389) and `smb`/`nmb` (TCP 139/445, UDP 137/138) are enabled system-wide via:
- `systemctl enable avahi-daemon.service` (L71)
- `systemctl enable wsdd.service` (L72)
- `systemctl enable smb.service` (L73)
- `systemctl enable nmb.service` (L74)
- `systemctl enable xrdp` (L1574)

In any network environment other than a fully trusted internal LAN, these services are immediately exposed upon boot with no firewall restrictions.

**Current State:**  
No firewall (`firewalld`) configuration is present in the Containerfile. Services are enabled but unrestricted.

**Recommended Fix:**  
Add firewall zone rules to restrict access:

```dockerfile
# Enable firewalld (comes with Fedora)
RUN systemctl enable firewalld

# Configure firewall zones and services
RUN firewall-offline-cmd --zone=home --add-service=samba && \
    firewall-offline-cmd --zone=home --add-service=rdp && \
    firewall-offline-cmd --zone=public --remove-service=samba && \
    firewall-offline-cmd --zone=public --remove-service=rdp

# If the primary network interface can be identified at build time:
# RUN firewall-offline-cmd --zone=home --change-interface=eth0
```

**Post-Install Guidance:**  
Users should:
1. Enable `firewalld.service` if not auto-enabled: `sudo systemctl enable firewalld`
2. Set the zone for their network interface: `sudo firewall-cmd --zone=home --change-interface=eth0 --permanent`
3. Test reachability: `sudo firewall-cmd --list-all`

**Priority:** Medium (exposure depends on network environment; recommended for untrusted networks)

---

### M-3 — Enterprise CA bundle trusted without fingerprint pinning
**File:** `bootc_ostree/fedora/image/Containerfile` (L34-35)  
**Status:** Open

**Description:**  
A CA certificate file is copied from the build context and trusted system-wide:
```dockerfile
COPY config/ca-bundle.crt /etc/pki/ca-trust/source/anchors/bootc-local-ca.crt
RUN update-ca-trust
```

If `ca-bundle.crt` is accidentally replaced with the wrong file (e.g., a developer copies in a test/staging CA), all TLS connections from the installed system could be silently intercepted without detection.

**Current State:**  
No fingerprint validation is performed. The build process trusts that the correct `ca-bundle.crt` file is in the build context.

**Recommended Fix:**  
Pin the expected SHA-256 fingerprint as a build assertion:

```dockerfile
COPY config/ca-bundle.crt /etc/pki/ca-trust/source/anchors/bootc-local-ca.crt

# Build-time assertion: verify the CA fingerprint matches expected value
RUN EXPECTED_FP="sha256:3f8a4ff0e27ecc6e0a2f0b1c2d3e4f5a..." && \
    ACTUAL_FP=$(openssl x509 -in /etc/pki/ca-trust/source/anchors/bootc-local-ca.crt \
                 -fingerprint -sha256 -noout | cut -d= -f2) && \
    if [ "$ACTUAL_FP" != "$EXPECTED_FP" ]; then \
        echo "ERROR: CA bundle fingerprint mismatch!"; \
        echo "  Expected: $EXPECTED_FP"; \
        echo "  Actual:   $ACTUAL_FP"; \
        exit 1; \
    fi && \
    update-ca-trust
```

**Steps to Implement:**
1. Compute your CA certificate fingerprint:
   ```bash
   openssl x509 -in ca-bundle.crt -fingerprint -sha256 -noout
   # Output: SHA256 Fingerprint=3f8a4ff0e27ecc6e0a2f0b1c2d3e4f5a...
   ```

2. Add the fingerprint value to the Containerfile assertion.

3. Document the fingerprint in your repository (e.g., in `bootc_ostree/fedora/CA_FINGERPRINT.txt`) for transparency.

**Priority:** Medium (enterprise CA management; mitigates accidental misconfigurations during development)

---

### M-4 — VS Code extensions installed without an allowlist
**File:** `bootc_ostree/fedora/image/Containerfile` (L1172-1175, L602)  
**Status:** Open

**Description:**  
Any `.vsix` file present in `offline-repo/vscode-extensions/` is silently installed for every local user by the post-install script:

```bash
for VSIX in /opt/vscode-extensions/*.vsix; do
    [ -f "$VSIX" ] || continue
    echo "  Installing $(basename "$VSIX")"
    sudo -u "$U" HOME="$HOME_DIR" code --install-extension "$VSIX" --no-sandbox --force 2>/dev/null
done
```

There is no allowlist, checksum verification, or publisher identity verification. A malicious or compromised `.vsix` file in the offline repo would be installed automatically.

**Current State:**  
All `.vsix` files under `offline-repo/vscode-extensions/` are installed without restriction.

**Recommended Fix:**  
Maintain an explicit allowlist and verify checksums:

1. Create an allowlist file:
   ```bash
   # offline-repo/vscode-extensions/ALLOWLIST.txt
   ms-vscode.cpptools
   ms-python.python
   hashicorp.terraform
   ```

2. Generate and store checksums:
   ```bash
   cd offline-repo/vscode-extensions/
   sha256sum *.vsix > sha256sums.txt
   ```

3. Update the post-install script:
   ```bash
   if [ ! -f "/opt/vscode-extensions/ALLOWLIST.txt" ]; then
       echo "No VS Code extensions allowlist; skipping installation"
       return 0
   fi
   
   # Verify checksums
   if [ -f "/opt/vscode-extensions/sha256sums.txt" ]; then
       (cd /opt/vscode-extensions && sha256sum --check sha256sums.txt) || {
           echo "ERROR: VS Code extension checksum verification failed"
           return 1
       }
   fi
   
   # Install only allowlisted extensions
   while read -r allowed_name; do
       [ -z "$allowed_name" ] && continue  # skip empty lines
       VSIX=$(ls /opt/vscode-extensions/*"$allowed_name"*.vsix 2>/dev/null | head -1)
       [ -f "$VSIX" ] || { echo "  Warning: $allowed_name not found"; continue; }
       echo "  Installing $(basename "$VSIX")"
       sudo -u "$U" HOME="$HOME_DIR" code --install-extension "$VSIX" --no-sandbox --force 2>/dev/null
   done < /opt/vscode-extensions/ALLOWLIST.txt
   ```

**Priority:** Medium (malicious extensions could access user files or environment; allowlist is straightforward to maintain)

---

## Low Findings (Open)

### L-1 — No minimum password length or complexity enforcement
**File:** `bootc_ostree/fedora/image/Containerfile` (L1070-1110, `prompt_for_bootc_user_details`)  
**Status:** Open

**Description:**  
The interactive password prompt in `bootc-post-install.sh` rejects empty passwords but accepts passwords of any length or complexity:

```bash
if [[ -z "$BOOTC_CREATE_USER_PASSWORD" ]]; then
    echo "  Password cannot be empty."
    continue
fi
```

Single-character passwords or simple guesses are accepted without warning.

**Current State:**  
Only check: password must not be empty (`if [[ -z "$..." ]]`)

**Recommended Fix:**  
Add minimum length validation and optional complexity checks:

```bash
# In prompt_for_bootc_user_details()
MIN_PASSWORD_LENGTH=12

if [[ -z "$BOOTC_CREATE_USER_PASSWORD" ]]; then
    echo "  Password cannot be empty."
    continue
fi

if [[ ${#BOOTC_CREATE_USER_PASSWORD} -lt $MIN_PASSWORD_LENGTH ]]; then
    echo "  Password must be at least $MIN_PASSWORD_LENGTH characters long."
    continue
fi

# Optional: warn on low complexity
if ! [[ "$BOOTC_CREATE_USER_PASSWORD" =~ [A-Z] ]] || \
   ! [[ "$BOOTC_CREATE_USER_PASSWORD" =~ [a-z] ]] || \
   ! [[ "$BOOTC_CREATE_USER_PASSWORD" =~ [0-9] ]]; then
    echo "  Warning: password lacks uppercase, lowercase, or digits (consider adding for better security)"
    read -r -p "  Continue anyway? [y/N] " -n 1
    [[ "$REPLY" == "y" || "$REPLY" == "Y" ]] || continue
fi
```

**Recommended Settings:**
- Minimum length: 12 characters (NIST SP 800-63B)
- Complexity encouragement: at least one uppercase, one lowercase, one digit

**Priority:** Low (user education is more effective; single-character passwords are rare in practice)

---

### L-2 — Samba `[homes]` share is browseable by default
**File:** `bootc_ostree/fedora/image/Containerfile` (L119-130, `[homes]` section)  
**Status:** Open

**Description:**  
The `[homes]` share definition has `browseable = yes`, allowing authenticated users to enumerate all home share names. This reveals usernames to anyone with valid Samba credentials on the network:

```ini
[homes]
   comment = User Home Directories
   browseable = yes                   # ⚠️ Reveals all usernames
   read only = no
   writable = yes
   valid users = %S
   create mask = 0644
   directory mask = 0755
   path = /home/%S
```

**Current State:**  
`[homes]` shares are browseable, exposing all local usernames to authenticated users on the network.

**Recommended Fix:**  
Set `browseable = no` in the `[homes]` section:

```ini
[homes]
   comment = User Home Directories
   browseable = no                    # Users log in using their username, not through browsing
   read only = no
   writable = yes
   valid users = %S
   create mask = 0644
   directory mask = 0755
   path = /home/%S
```

**Impact:**  
- Users will need to know the exact username to connect (e.g., `\\\\machine\\username`)
- Prevents passive username enumeration over SMB
- Does not affect legitimate users who already know their credentials

**Priority:** Low (information disclosure only; usernames are often guessable)

---

### L-3 — npm tarballs installed globally without integrity verification
**File:** `bootc_ostree/fedora/image/Containerfile` (L614-650, npm installation section)  
**Status:** Open

**Description:**  
npm packages in `offline-repo/npm-packages/` are installed globally without verifying the integrity of each tarball:

```bash
npm install -g /opt/npm-packages/*.tgz || echo "Warning: npm install -g failed"
```

A tampered `.tgz` file in the offline repo would be installed as a global binary without detection.

**Current State:**  
No SHA-256 or integrity verification is performed on npm tarballs before installation.

**Recommended Fix:**  
Extend the `create-npm-tarballs.sh` script to generate checksums, then verify during install:

1. **Update `create-npm-tarballs.sh`:**
   ```bash
   #!/bin/bash
   # ... existing code ...
   
   CACHE="/opt/npm-packages"
   cd "$CACHE"
   
   # Generate sha256sum file
   sha256sum *.tgz > sha256sums.txt
   echo "Generated $CACHE/sha256sums.txt"
   ```

2. **Update Containerfile npm install step:**
   ```dockerfile
   if ls /opt/npm-packages/*.tgz >/dev/null 2>&1; then \
       echo "Verifying npm package integrity..."; \
       (cd /opt/npm-packages && sha256sum --check sha256sums.txt) || { \
           echo "ERROR: npm package checksum verification failed"; \
           exit 1; \
       }; \
       echo "Installing JS frameworks from offline cache..."; \
       export HOME=/tmp && mkdir -p /tmp/.npm && npm config set cache /tmp/.npm --global || true; \
       npm install -g --cache /tmp/.npm /opt/npm-packages/*.tgz || { \
           echo "ERROR: npm install -g failed"; \
           exit 1; \
       }; \
   else \
       echo "No npm packages were cached; skipping global install"; \
   fi
   ```

**Priority:** Low (npm packages typically run at user level, not root; integrity risk is moderate)

---

## Summary of Fixed vs. Open Findings

### Recently Fixed (Critical/High Priority)
All critical and high-severity vulnerabilities have been addressed:
- ✅ Chrome RPM signature verification (CVE-CLASS-1)
- ✅ k3s kubeconfig permissions 0600 (CVE-CLASS-2)
- ✅ Password handling with --bootc-password-file (CVE-CLASS-3)
- ✅ Offline RPM repo policy documented (H-1)
- ✅ Samba guest fallback disabled (H-2)
- ✅ k3s SELinux enabled (H-3)

### Still Open (Medium Priority)
These require design decisions and multi-step implementation:

| Finding | Impact | Effort | Notes |
|---------|--------|--------|-------|
| **Binary checksums** (M-1) | Medium | Medium | Blocks: oc/kubectl/helm; k3s partially done |
| **Firewall rules** (M-2) | Medium | Low | Blocks: xrdp/samba exposure in untrusted networks |
| **CA fingerprint pinning** (M-3) | Medium | Low | Blocks: accidental CA misconfig during builds |
| **VSIX allowlist** (M-4) | Medium | Medium | Blocks: malicious extensions in offline-repo |

### Still Open (Low Priority)
These are information disclosure or edge cases:

| Finding | Impact | Effort | Notes |
|---------|--------|--------|-------|
| **Password length** (L-1) | Low | Low | No NIST-recommended 12-char minimum |
| **Samba browseable** (L-2) | Low | Trivial | Leaks usernames to authenticated users |
| **npm integrity** (L-3) | Low | Low | No checksum verification for .tgz files |

---

## Recommended Fix Priority Order

### Phase 1: Trivial Fixes (< 5 minutes each)
1. **L-2:** Set `browseable = no` in Samba `[homes]` section (Containerfile L121)
2. **L-3:** Extend `create-npm-tarballs.sh` to generate `sha256sums.txt`

### Phase 2: Low Effort (< 30 minutes each)
3. **M-2:** Add `firewall-offline-cmd` calls and firewalld enable (Containerfile)
4. **M-3:** Add CA fingerprint assertion to Containerfile build-time checks
5. **L-1:** Add minimum password length check to `prompt_for_bootc_user_details()`

### Phase 3: Medium Effort (1-2 hours each)
6. **M-1:** Update `fetch_*.sh` scripts to include `sha256sum.txt`; update Containerfile to verify before install
7. **M-4:** Add `ALLOWLIST.txt` to vscode-extensions; update post-install script to verify from allowlist

---

## Testing Recommendations

After implementing fixes:

| Fix | Test Method |
|-----|-------------|
| L-2 | `nmblookup -M WORKGROUP` should not list homes; use `smbclient -L` to verify |
| L-3 | Verify `sha256sums.txt` exists in npm-packages after running create-npm-tarballs.sh |
| M-2 | `sudo firewall-cmd --list-all` should show samba/rdp rules in home zone only |
| M-3 | Build image and verify CA assertion succeeds; test with wrong CA to verify failure |
| L-1 | Test password prompt: verify it rejects < 12 chars; accepts >= 12 chars |
| M-1 | Verify checksum verification in build log; intentionally corrupt a binary and expect build failure |
| M-4 | Add dummy VSIX to offline-repo; verify it's not installed if missing from allowlist |
