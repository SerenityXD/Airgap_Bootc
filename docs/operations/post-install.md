# Post-Install Operations

Run once after first boot:
```bash
sudo /usr/local/bin/bootc/bootc-post-install.sh
```

## VS Code Extensions

The following extensions are installed automatically per-user during `bootc-post-install.sh`:

### Development & Kubernetes Tools
- **ms-kubernetes-tools.vscode-kubernetes-tools** — Kubernetes management and debugging
- **ms-azuretools.vscode-docker** — Docker container tools and image management
- **redhat.vscode-yaml** — YAML language support for Kubernetes manifests
- **ms-vscode.makefile-tools** — Makefile debugging and execution

### General Development
- **ms-python.python** — Python language support and debugging
- **ms-toolsai.jupyter** — Jupyter notebook support
- **eamodio.gitlens** — Git history/blame visualization and advanced features

To skip extension installation, use:
```bash
sudo /usr/local/bin/bootc/bootc-post-install.sh --skip-extensions
```

To install extensions for specific users only:
```bash
sudo /usr/local/bin/bootc/bootc-post-install.sh alice bob
```

## Common Options
- `--wheels-only`
- `--no-wheels`
- `--skip-extensions`
- `--skip-services`
- `--skip-nvidia`
- `--only-steps extensions,services`

## Verification
```bash
sudo /usr/local/bin/bootc/install-js-frameworks.sh
nvidia-smi
code --version
```

## Samba Credential Sync

User accounts created by `bootc-post-install.sh` are automatically registered in
the Samba database so network drive access works with the same credentials as the
Linux login password.

When you browse the BOOTC machine from another system, connect to the username
share directly rather than a literal `homes` share name:
```bash
# Windows Explorer
\\hostname\\username

# GNOME Files / macOS Finder smb URL
smb://hostname/username
```

For users created by other means, register them manually:
```bash
sudo smbpasswd -a <username>   # registers user; prompts for Samba password
```

When a user changes their Linux password (`passwd`), also update Samba:
```bash
sudo smbpasswd <username>
```

Verify a user is registered:
```bash
sudo pdbedit -L | grep <username>
```
