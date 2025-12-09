# SCVU Bootc Workstation — Tech Stack Breakdown

## 1. **Core OS & Desktop Stack**
- **Operating System**: Fedora 43 (KDE Spin)
- **Desktop Environment**: KDE Plasma (with SDDM display manager)
- **Display Protocol**: Wayland (KDE/SDDM native)
- **Remote Access**: XRDP (Remote Desktop Protocol)
- **Window Manager**: KWin (KDE's window manager)
- **Theme**: Adwaita (GTK/GNOME theme compatibility)

---

## 2. **Development Stack**
### Languages & Runtime
- **Python**: 3.9, 3.10, 3.11, 3.12, 3.13
- **C/C++**: GCC compiler suite
- **Build Systems**: CMake, Make
- **Version Control**: Git

### Development Tools
- **IDE/Editor**: VS Code
- **Package Managers**: 
  - pip (Python)
  - npm/pnpm (Node.js)
  - dnf (Fedora packages)

### Containerization
- **Container Runtimes**: Docker Desktop, Podman
- **Container Format**: OCI (Open Container Initiative)

---

## 3. **ML/Data Science Stack**
### Scientific Computing
- **NumPy**: Numerical computing
- **SciPy**: Scientific algorithms
- **pandas**: Data manipulation & analysis
- **scikit-learn**: Machine learning library

### Data Visualization
- **Matplotlib**: Plotting library
- **Jupyter**: Interactive notebooks
- **OpenCV**: Computer vision & image processing

---

## 4. **Graphics & Design Stack**
### GPU Computing
- **NVIDIA CUDA**: GPU acceleration framework
- **NVIDIA Drivers**: GPU support

### 3D Rendering & Modeling
- **Blender**: 3D modeling, rendering, animation
- **VLC**: Video playback

### 2D Graphics & Design
- **GIMP**: Raster image editor
- **Inkscape**: Vector graphics editor
- **draw.io**: Diagram & flowchart tool

---

## 5. **Multimedia Stack**
### Audio/Video Processing
- **FFmpeg**: Video/audio encoding, streaming
- **OBS Studio**: Screen recording, streaming

### Media Playback
- **VLC**: Universal media player

---

## 6. **Windows Emulation Stack**
### Wine Ecosystem
- **WineHQ**: Windows API compatibility layer
- **Lutris**: Game launcher (uses Wine backend)
- **Prism Launcher**: Minecraft launcher (Java-based)

---

## 7. **Office & Productivity Stack**
- **LibreOffice**: Office suite (Writer, Calc, Impress)
- **QGIS**: Geographic Information System (GIS)

---

## 8. **Networking & File Sharing Stack**
### Local Network
- **Samba**: SMB/CIFS file sharing (Windows shares)
- **Avahi**: mDNS/Zeroconf for network discovery

### Storage Support
- **NTFS Support**: NTFS read-write (ntfs-3g)
- **ExFAT Support**: ExFAT read-write

---

## 9. **Cloud & Container Orchestration Stack**
### Kubernetes & OpenShift
- **oc**: OpenShift CLI
- **kubectl**: Kubernetes CLI
- **CRC**: CodeReady Containers (local OpenShift)

### Triton
- **Triton Server**: Model inference server

---

## 10. **JavaScript/Frontend Stack** (via npm)
### Framework Generators
- **create-react-app**: React boilerplate
- **@vue/cli**: Vue.js CLI
- **@angular/cli**: Angular CLI
- **create-next-app**: Next.js boilerplate
- **Vite**: Modern build tool & dev server

### Build Tools
- **webpack**: Module bundler
- **webpack-cli**: Webpack CLI

### Development Tools
- **TypeScript**: Static typing for JavaScript
- **ts-node**: TypeScript Node.js executor
- **ESLint**: Code linter
- **Prettier**: Code formatter

### Testing
- **Jest**: Testing framework
- **Mocha**: Test runner

### Package Manager
- **pnpm**: Fast package manager (alternative to npm/yarn)

---

## Architecture Summary

```
┌─────────────────────────────────────────────────────────┐
│              SCVU Bootc Workstation                     │
├─────────────────────────────────────────────────────────┤
│ Core Layer: Fedora 43 + KDE + SDDM + XRDP              │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────┬──────────────┬─────────────┬──────────┐ │
│ │ Development │ ML/Data Sci  │  Graphics   │ Multimedia
│ │             │              │  & Design   │          │
│ │ Python 3.x  │ NumPy/SciPy  │ NVIDIA CUDA │ FFmpeg   │
│ │ Node.js     │ pandas       │ Blender     │ OBS      │
│ │ Git         │ scikit-learn │ GIMP        │ VLC      │
│ │ Docker/Pod  │ Jupyter      │ Inkscape    │          │
│ │ VS Code     │ OpenCV       │ draw.io     │          │
│ └─────────────┴──────────────┴─────────────┴──────────┘ │
├─────────────────────────────────────────────────────────┤
│ ┌──────────────────┬──────────────┬──────────────────┐  │
│ │ Windows Emul.    │ Office/GIS   │ Cloud/K8s        │  │
│ │ Wine/Lutris      │ LibreOffice  │ OpenShift (oc)   │  │
│ │ Prism Launcher   │ QGIS         │ kubectl          │  │
│ └──────────────────┴──────────────┴──────────────────┘  │
├─────────────────────────────────────────────────────────┤
│ Networking & Storage: Samba, Avahi, NTFS, ExFAT        │
└─────────────────────────────────────────────────────────┘
```

---

## Quick Reference by Use Case

### 🎓 **Data Scientists / ML Engineers**
Focus: ML/Data Science + Development + Graphics (CUDA)
- Python 3.x, NumPy, SciPy, pandas, scikit-learn, Jupyter
- NVIDIA CUDA, OpenCV, Blender (for 3D ML)

### 👨‍💻 **Web Developers**
Focus: Development + JavaScript/Frontend
- Node.js, VS Code, React/Vue/Angular
- Docker/Podman for containerization

### 🎮 **Game Developers / 3D Artists**
Focus: Graphics + Development
- Blender, NVIDIA CUDA, FFmpeg, OBS
- Python for scripting, C++ for engines

### 🏢 **System Administrators / DevOps**
Focus: Cloud + Containers + Networking
- Docker, Podman, OpenShift, Kubernetes (oc, kubectl)
- Samba, Avahi for network management

### 🖥️ **Windows App Users**
Focus: Windows Emulation
- WineHQ, Lutris, Prism Launcher

### 📊 **GIS / Geospatial Analysts**
Focus: Office/Productivity + Development
- QGIS, Python 3.x, LibreOffice

