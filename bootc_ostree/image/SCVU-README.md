SCVU Bootc Workstation - Quick Notes

Full documentation: `/usr/local/share/doc/scvu/README.md` (inside the OS) or `bootc_ostree/README.md` (repo root).


Windows Network Discovery
- Samba server: enabled for Windows network visibility (smb.service, nmb.service)
- Avahi: mDNS/DNS-SD for modern Windows 10/11 and macOS discovery
- wsdd: WS-Discovery protocol for Windows 10+ network computers list
- Configuration: `/etc/samba/smb.conf` (workgroup: WORKGROUP, netbios: SCVU-BOOTC)
- Check status: `systemctl status smb nmb avahi-daemon wsdd`
- View in Windows: Open File Explorer → Network → Look for "SCVU-BOOTC"
- Note: Firewall must allow ports 137-139/udp, 445/tcp, 5353/udp (mDNS)


Post-install checks
- NVIDIA: `nvidia-smi` (after reboot into installed system) to confirm driver `580.95.05`. Kernel modules are pre-built at image creation time for bootc's read-only filesystem.
- VS Code: `code --version`; offline package was installed when present, otherwise from Microsoft repo.
- WineHQ + Lutris: `wine --version` and `lutris --version` to verify Windows emulation support.
- Docker Desktop: launch from the app menu or run `systemctl --user status docker-desktop` to confirm it starts; CLI tools are available via `docker` and `docker-compose`.
- Draw.io: `drawio --version` to confirm install.
- Python toolchains: `python3.9|3.10|3.11|3.12|3.13 -m pip list` to see preinstalled data-science packages; default `python3` is 3.14 from Fedora.

Notable packaged content (preinstalled)
- GPU: NVIDIA driver/cuda libs 580.95.05 (offline RPMs preferred), fallback to rpmfusion online.
- IDEs/tools: VS Code, Docker Desktop, draw.io.
- Windows Emulation: WineHQ stable 10.0, Lutris, Steam prerequisites (mesa-vulkan, gamemode, gamescope).
- Data science (per Python 3.9–3.13): `tritonclient`, `numpy`, `scipy`, `pandas`, `matplotlib`, `scikit-learn`, `jupyter`, `notebook`, `ipython`, `seaborn`, `opencv-python`.
- Misc: OBS Studio plugin dependencies, runtime fonts/codecs from offline repos, VS Code extensions staged in `/opt/vscode-extensions/` (install with `code --install-extension /opt/vscode-extensions/<name>.vsix`).

Support
- If a package looks missing, check `/tmp/rpms` content in the build logs; online fallbacks may have been used when offline RPMs were absent.
- For detailed build steps and flags, see `build_export_iso.sh` and `build-iso-helper.sh` docs in the repo.
