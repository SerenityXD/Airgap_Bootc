SCVU Bootc Workstation - Quick Notes

Full documentation: `/usr/local/share/doc/scvu/README.md` (inside the OS) or `bootc_ostree/README.md` (repo root).


Windows Network Discovery
- **Bidirectional discovery**: Linux ↔ Windows network visibility
- **From Windows to Linux**: Samba server (smb/nmb services) makes Linux visible in Windows Network
- **From Linux to Windows**: KDE Dolphin with kio-extras can browse Windows shares (smb:// protocol)
- Avahi: mDNS/DNS-SD for modern Windows 10/11 and macOS discovery (both directions)
- wsdd: WS-Discovery protocol makes Linux visible to Windows 10+ network computers list
- Samba client: nmblookup and smbclient tools for discovering and browsing Windows shares from Linux
- Configuration: `/etc/samba/smb.conf` (workgroup: WORKGROUP, netbios: SCVU-BOOTC)
- Check status: `systemctl status smb nmb avahi-daemon wsdd`
- **Browse Windows from Linux**: 
  - Dolphin: Navigate to Network → Samba Shares → Add Network Folder (smb://hostname)
  - Command line: `smbclient -L //windows-pc -N` (list shares)
  - Mount: `sudo mount -t cifs //windows-pc/share /mnt/point -o user=username`
- **View Linux from Windows**: File Explorer → Network → Look for "SCVU-BOOTC"
- Note: Firewall must allow ports 137-139/udp, 445/tcp, 5353/udp (mDNS)


Post-install checks
- NVIDIA: `nvidia-smi` (after reboot into installed system) to confirm driver `580.95.05`. Kernel modules are pre-built at image creation time for bootc's read-only filesystem.
- VS Code: `code --version`; offline package was installed when present, otherwise from Microsoft repo.
- WineHQ + Lutris: `wine --version` and `lutris --version` to verify Windows emulation support.
- Docker Desktop: launch from the app menu or run `systemctl --user status docker-desktop` to confirm it starts; CLI tools are available via `docker` and `docker-compose`.
- Draw.io: `drawio --version` to confirm install.
- Python toolchains: `python3.9|3.10|3.11|3.12|3.13 -m pip list` to see preinstalled data-science packages; default `python3` is 3.14 from Fedora.

Notable packaged content (preinstalled)

Offline npm packages (JS frameworks)
----------------------------------

For air-gapped or reproducible builds the image supports pre-caching npm packages
as tarballs and including them in the build. This repo contains a helper to
generate those tarballs and a manifest with pinned versions.

Files of interest:
- `image/offline-repo/npm-packages/package-versions.txt` — list of packages (one per line,
  optional `@version` suffix) that will be packed into `.tgz` files.
- `image/scripts/create-npm-tarballs.sh` — helper script that runs `npm pack` for
  each entry in the manifest and places the resulting `.tgz` files in
  `image/offline-repo/npm-packages/`.

Usage (on an internet-enabled machine):
```bash
chmod +x image/scripts/create-npm-tarballs.sh
./image/scripts/create-npm-tarballs.sh
# The script reads package-versions.txt and writes *.tgz into image/offline-repo/npm-packages/
```

After tarballs are created:
- Commit the `*.tgz` files into the repo (or otherwise copy them to the build host).
- The `Containerfile` will `COPY offline-repo/npm-packages/ /opt/npm-packages/` and
  will prefer installing from those tarballs during image build. If tarballs are
  absent the Containerfile falls back to `npm pack` (requires network access).

To verify in the built system run the verifier included in the image:
```bash
sudo /usr/local/bin/scvu/install-js-frameworks.sh
```
It reports which binaries are present and instructs how to install from the
offline cache if anything is missing.

Notes:
- Pin versions in `package-versions.txt` for reproducible builds.
- Tarballs are versioned and deterministic for a given registry state and
  package version; committing them makes builds reproducible and air-gap friendly.
Support
- If a package looks missing, check `/tmp/rpms` content in the build logs; online fallbacks may have been used when offline RPMs were absent.
