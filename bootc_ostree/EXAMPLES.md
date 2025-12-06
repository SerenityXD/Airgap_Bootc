# Interactive vs Non-Interactive: Examples

## The Simplest Comparison

### Non-Interactive (What You Had)
```bash
./build_export_iso.sh
```
- **Result:** Pre-configured ISO (system already set up in container)
- **Boot:** Anaconda runs automatically, minimal user interaction
- **Use:** Standardized deployments, CI/CD, quick rollout

### Interactive (What You Now Have)
```bash
./build_export_iso.sh --iso-type anaconda-iso --config config-interactive.toml
```
- **Result:** Anaconda installer ISO (user makes all decisions)
- **Boot:** Anaconda asks for disk, partitions, users, timezone, etc.
- **Use:** Custom hardware, flexible deployments, end-user machines

---

## Real-World Scenario

### Scenario: Deploy to 3 Servers

#### Option A: Non-Interactive Approach
```bash
# Build once
./build_export_iso.sh --iso-name SCVU-Server.iso

# Deploy to 3 identical servers
# Boot Server1, Server2, Server3 from SCVU-Server.iso
# Each auto-installs identically (exact same config)
# 30 minutes per server
```

**Pros:** Repeatable, consistent, minimal per-server time  
**Cons:** All servers get same partitioning/config (no customization)

#### Option B: Interactive Approach
```bash
# Build once
./build_export_iso.sh \
  --iso-type anaconda-iso \
  --config config-interactive.toml \
  --iso-name SCVU-Interactive-Server.iso

# Deploy to 3 servers with different hardware
# Boot Server1: User configures disk (500GB available) → creates large /var
# Boot Server2: User configures disk (2TB available) → creates smaller /var
# Boot Server3: User configures disk (4TB available) → creates custom partitions
# 45 minutes per server (includes user decisions)
```

**Pros:** Customizable per-hardware, flexible, optimal for each machine  
**Cons:** Requires manual input, slightly slower per machine

---

## Installation Screen Comparison

### Non-Interactive ISO Boot Sequence
```
1. GRUB Menu (1 sec)
   ↓
2. Anaconda Loads (5 sec)
   ↓
3. [AUTO] Disk Detection (10 sec)
   ↓
4. [AUTO] Partitioning (10 sec)
   ↓
5. [AUTO] Format & Install (varies)
   ↓
6. System Ready
```
**User action required:** None (just boot and wait)  
**Total time:** 20-30 minutes

### Interactive ISO Boot Sequence
```
1. GRUB Menu (1 sec)
   ↓
2. Anaconda Loads (5 sec)
   ↓
3. [USER] Welcome Screen
   ↓
4. [USER] Language Selection
   ↓
5. [USER] Disk Selection & Partitioning
   ↓
6. [USER] User Setup (root, accounts)
   ↓
7. [USER] Network Configuration
   ↓
8. [USER] Timezone & Keyboard
   ↓
9. [AUTO] Format & Install (varies)
   ↓
10. System Ready
```
**User action required:** Yes (answer screens 3-8)  
**Total time:** 25-40 minutes (includes user decision time)

---

## Command Examples by Use Case

### Development/Testing
```bash
# Quick build, default name
./build-iso-helper.sh interactive

# Or with options
./build_export_iso.sh \
  --iso-type anaconda-iso \
  --config config-interactive.toml

# Result: SCVU-Interactive-20251206-160000.iso
```

### Production Deployment
```bash
# Semantic naming
./build_export_iso.sh \
  --iso-type anaconda-iso \
  --config config-interactive.toml \
  --iso-name SCVU-Interactive-v1.0.iso
```

### Offline/Air-Gapped Deployment
```bash
# With offline packages
./build_export_iso.sh \
  --iso-type anaconda-iso \
  --config config-interactive.toml \
  --fetch-offline \
  --packages docker-desktop,vscode,nvidia \
  --iso-name SCVU-Interactive-Offline.iso
```

### Comparing Both Approaches
```bash
# Build both ISOs for testing
./build-iso-helper.sh compare

# Result: 
#   SCVU-Interactive-20251206-160000.iso (interactive)
#   SCVU-Standard-20251206-160000.iso (non-interactive)
```

---

## Configuration Examples

### Current (Minimal Interactive)
```toml
# config-interactive.toml
[customizations.installer]
contents = ""
```
**Effect:** User gets full Anaconda installer UI

### Possible Future (Custom Kernel Args)
```toml
[customizations.installer]
contents = ""

[customizations.kernel]
# Add boot parameters if needed
```

### Possible Future (Custom Timezone)
```toml
[customizations.installer]
contents = ""

[customizations.timezone]
# Could pre-set timezone (Anaconda still allows user change)
```

---

## File Size Comparison

Both ISO types should be approximately the same size (~14GB for SCVU Bootc):

```
Non-Interactive:   14G  SCVU-Standard.iso
Interactive:       14G  SCVU-Interactive.iso
```

**Why same size?** Both contain:
- Same container image (SCVU Bootc with KDE, tools, etc.)
- Same Anaconda installer software
- Different only in kickstart provisioning method

---

## When to Use Each

### Use Non-Interactive When:
- ✅ Deploying to identical hardware (data center)
- ✅ Need consistent, repeatable installations
- ✅ CI/CD pipeline or automated rollout
- ✅ Pre-configured system works for all users
- ✅ Minimal user interaction desired

### Use Interactive When:
- ✅ Deploying to varied hardware
- ✅ End users making their own servers
- ✅ Custom partitioning needed per machine
- ✅ Different configurations per site/user
- ✅ Flexibility more important than automation

---

## Migration from Non-Interactive to Interactive

### If you already deployed non-interactive ISOs:

```bash
# Your existing ISOs still work! No changes needed.
# You can now ALSO build interactive ISOs for new deployments:

./build_export_iso.sh \
  --iso-type anaconda-iso \
  --config config-interactive.toml \
  --iso-name SCVU-Interactive-v2.iso

# Old non-interactive ISOs continue to work
# New interactive ISOs available alongside
# Users can choose which to use
```

---

## Helper Script Examples

### Example 1: Quick Interactive Build
```bash
./build-iso-helper.sh interactive
# Outputs: SCVU-Interactive-20251206-160530.iso
```

### Example 2: Quick Non-Interactive Build
```bash
./build-iso-helper.sh non-interactive
# Outputs: SCVU-Standard-20251206-160530.iso
```

### Example 3: Build Both for Testing
```bash
./build-iso-helper.sh compare
# Outputs:
#   SCVU-Interactive-20251206-160530.iso
#   SCVU-Standard-20251206-160530.iso
# Now you can boot both and compare!
```

### Example 4: Custom Name
```bash
./build-iso-helper.sh interactive --iso-name SCVU-v1.0.iso
# Outputs: SCVU-v1.0.iso
```

### Example 5: With Offline Packages
```bash
./build-iso-helper.sh interactive --fetch-offline --iso-name SCVU-Offline.iso
# Builds with offline RPMs included
```

---

## Summary Table

| Aspect | Non-Interactive | Interactive |
|--------|-----------------|-------------|
| **Build Command** | `./build_export_iso.sh` | `./build_export_iso.sh --iso-type anaconda-iso --config config-interactive.toml` |
| **Boot Experience** | Automatic, no prompts | Anaconda GUI with menus |
| **Partitioning** | Pre-configured | User-chosen |
| **Root Password** | Pre-set in container | User-set during install |
| **User Accounts** | Pre-configured | User-created during install |
| **Use Case** | Standardized deployments | Custom/flexible deployments |
| **Time to Deploy** | 20-30 minutes | 25-40 minutes (includes user input) |
| **Learning Curve** | None (automatic) | Low (standard installer) |

---

## Ready to Try?

**Start here:**
```bash
cd /home/benson/Documents/Bootc_Test/bootc_ostree

# Build interactive ISO
./build-iso-helper.sh interactive

# Or build both for comparison
./build-iso-helper.sh compare

# Check results
ls -lh output/bootiso/*.iso
```

**Next:** Boot the ISOs and test both installation flows!
