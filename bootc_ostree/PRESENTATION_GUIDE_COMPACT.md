# SCVU Bootc Workstation: Compact Presentation Guide

## 🎯 The Pitch (30 seconds)

**Problem:** Traditional workstation deployment = 2 hours per machine + manual config = inconsistency  
**Solution:** SCVU Bootc = Pre-built container image in ISO = 25-minute deploy + identical config  
**Result:** 74% faster, zero network needed, fully reproducible

---

## 📊 Key Numbers

| Metric | Value |
|--------|-------|
| **Deploy Time** | 20–30 min/machine (vs 2+ hours traditional) |
| **ISO Size** | 14 GB (all-inclusive, offline-ready) |
| **Pre-installed Packages** | 150+ (Python, ML, dev tools, NVIDIA, multimedia) |
| **Network Required** | None (fully air-gapped) |
| **Disk Space (Installed)** | ~25 GB minimum |
| **Time Savings (100 machines)** | $7,400 / 74% reduction |

---

## 🏗️ What's Inside (The Stack)

✅ **Desktop:** Fedora 43 KDE + SDDM + XRDP  
✅ **Development:** Python 3.9–3.13, VS Code, Git, GCC/CMake, Docker, Podman  
✅ **ML/Data Science:** NumPy, SciPy, pandas, Matplotlib, scikit-learn, Jupyter, OpenCV  
✅ **Graphics:** NVIDIA CUDA + Blender, GIMP, Inkscape  
✅ **Multimedia:** FFmpeg, VLC, OBS Studio  
✅ **Windows Emulation:** WineHQ, Lutris, Prism Launcher  
✅ **Extras:** LibreOffice, QGIS, OpenShift tools (oc, kubectl, CRC), Samba, Avahi  
✅ **Windows Integration:** NTFS/ExFAT read-write, network shares (SMB), Windows discovery

---

## 🪟 Windows Filesystem & Network Support

**Out-of-the-box compatibility:**
- **External drives:** NTFS/ExFAT USB drives, external SSDs auto-mount and fully read-writable
- **Network shares:** Connect to Windows SMB/CIFS shares seamlessly
- **Windows discovery:** System advertised on Windows network for easy discovery
- **Dual-boot:** Direct access to Windows partitions if multi-booting
- **File transfer:** Full Windows interop via network and USB

**Pre-installed tools:**
- ntfs-3g, ntfsprogs, exfatprogs (filesystem support)
- samba-client, cifs-utils (network shares)
- wsdd (Windows Service Discovery)
- avahi (mDNS/network browsing)

---

## 🔧 How It Works (Build → Deploy)

### Analogy: Like a Smartphone OS Update
**Traditional:** Individual packages patched mid-system = risky conflicts, inconsistent updates  
**Bootc:** Complete OS downloaded, tested, then swapped atomically = safe, identical, auto-rollback on failure

### Build Phase (Once, Online)
```
1. Fetch offline packages (10–20 min)
2. Build container image (12 sec cached / 5 min first time)
3. Export OCI archive (40 sec)
4. Compose ISO (8 min)
→ Result: 14 GB ISO, ready to ship
```

### Deploy Phase (Per-Machine, Offline)
```
1. Boot ISO → 2. Anaconda installer → 3. User picks disk
4. System deploys → 5. First boot → 6. Done
→ Result: 25 min, no network, identical system
```

---

## 📋 Installation Modes

| Mode | User Interaction | Time | Best For |
|------|------------------|------|----------|
| **Interactive** | High (GUI) | 20–30 min | Desktops, varied hardware |
| **Non-Interactive** | None (auto) | 15–20 min | Servers, identical hardware |

---

## ⚡ Smart Features

1. **Auto AIBUser Creation** – Post-install script creates user account, sets up Docker group
2. **Offline Python Wheels** – Pre-built wheels for all Python versions (30–60 sec install vs 5–10 min compile)
3. **Multi-Disk Safety** – System detects disks, user selects target, confirmation before install
4. **Modular Post-Install** – Optional flags: `--skip-nvidia`, `--wheels-only`, `--py py311`, etc.

---

## 💼 Use Cases

### 1. Enterprise Workstation Deployment
- **Before:** 50 machines × 2 hours = 100 hours IT time
- **After:** Build (1 hour) + Deploy (3 hours) = 4 hours total
- **Savings:** 96 hours + consistency + zero config drift

### 2. Air-Gapped ML Research Lab
- Build online → Transfer ISO to lab → Deploy with zero network
- All ML libraries pre-installed (NumPy, scipy, sklearn, torch)
- Reproducible environment for all researchers

### 3. Edge Computing / Inference Nodes
- Customize Containerfile for edge hardware
- Create minimal ISO (8 GB) with pre-cached ML models
- Deploy and start inference immediately

### 4. Disaster Recovery
- Spare machine breaks down → 25 min deploy + restore home backup
- Back to work in 30 min (vs 2+ hours traditional)

---

## 🎬 Presentation Structure (40 minutes)

| Section | Time |
|---------|------|
| Opening + Problem | 4 min |
| Solution Overview | 3 min |
| What's Inside | 3 min |
| Build & Deploy Process | 4 min |
| Installation Modes | 2 min |
| Smart Features | 3 min |
| Use Cases | 4 min |
| **Live Demo** (or screenshots) | 8 min |
| ROI / Business Value | 3 min |
| Q&A + Closing | 3 min |

---

## 💡 Key Talking Points

### Problem Statement
> *"How do you deploy identical, fully-configured workstations—offline—in under 30 minutes each?"*

### Unique Value Proposition
- ✅ **Reproducible:** Same system, same packages, every time
- ✅ **Offline:** Works completely air-gapped, no network dependency
- ✅ **Fast:** 25 minutes vs 2+ hours per machine
- ✅ **Flexible:** Interactive or automated modes
- ✅ **Customizable:** Edit Containerfile, rebuild, redeploy

### Business Impact
- **Time Savings:** 74% reduction in IT deployment time
- **Consistency:** Zero configuration drift, identical environments
- **Support:** Reduced help desk tickets (everyone has same setup)
- **Compliance:** Reproducible, auditable deployments
- **Speed to Productivity:** Teams start working immediately

---

## 🎯 Demo Walkthrough (If Showing Live)

1. **Show Containerfile** – "Everything defined in one place"
2. **Show offline packages** – "Pre-downloaded, air-gap ready"
3. **Trigger build** – `./build-iso-helper.sh interactive`
4. **Show ISO** – "14 GB, ready to deploy"
5. **Show post-install script** – "Modular, selective installation"

---

## ❓ Q&A Soundbites

**Q: Why not just use containers?**  
A: Containers are great for apps, but Bootc gives you entire OS + desktop + all dev tools in one reproducible image—perfect when you need graphics.

**Q: Can we customize for different teams?**  
A: Yes! Edit Containerfile, rebuild (25–35 min), new ISO ready. Can create minimal/standard/enterprise variants.

**Q: What about updates?**  
A: Rebuild ISO with updated packages and redeploy. Future: OTA updates via container image push.

**Q: Works only for Fedora?**  
A: Current: Fedora 43 bootc. Adaptable to RHEL, CentOS Stream, Ubuntu bootc (same process).

**Q: What about user data?**  
A: Home directories are writable (separate from immutable rootfs). Backup/restore between machines, or NFS mount for centralized storage.

---

## 🚀 Next Steps

1. **Pilot Program** – Deploy 10 machines, gather feedback
2. **Create Variants** – Minimal/standard/full customizations
3. **Mass Deployment** – Roll out to entire organization
4. **CI/CD Integration** – Automate builds and testing

---

## 📄 Quick Reference

- **ISO Location:** `/bootc_ostree/output/bootiso/SCVU.iso` (14 GB)
- **Build Config:** `config-interactive.toml` (interactive Anaconda mode)
- **Post-Install:** `sudo /usr/local/bin/scvu/scvu-post-install.sh`
- **AIBUser:** Default password `AIBUser@A!BUser` (changeable)
- **Build Logs:** `bootc_ostree/build-scripts/logs/build-TIMESTAMP.log`

---

## 🎓 Audience-Specific Variants

### For Executives (15 min)
- Focus: ROI, time savings, consistency
- Show: Problem/solution, cost calculator, success metrics

### For Developers (30 min)
- Focus: Architecture, customization, automation
- Show: Containerfile, build process, modular design

### For IT/Operations (30 min)
- Focus: Deployment, scalability, support
- Show: Installation walkthrough, post-install, troubleshooting

### For Security/Compliance (30 min)
- Focus: Reproducibility, auditability, secure deployment
- Show: Build verification, immutable rootfs benefits, update strategy

---

**This compact guide captures all essentials while cutting content in half. Adapt depth based on audience.**
