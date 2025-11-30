# Base Fedora image for bootc
FROM registry.fedoraproject.org/fedora:43

# bootc labels
LABEL bootc="true"
LABEL bootc.os="fedora"
LABEL bootc.version="43"

# Essentials and KDE
RUN dnf -y install \
    @base-x @kde-desktop-environment sddm \
    git curl wget vim \
    python3 python3-pip \
    nodejs npm yarn \
    && dnf -y clean all && rm -rf /var/cache/dnf

# VS Code (placeholder: assumes offline RPM added later)
# COPY vscode.rpm /tmp/
# RUN dnf -y install /tmp/vscode.rpm && rm -f /tmp/vscode.rpm

# Docker Desktop (placeholder)
# COPY docker-desktop.rpm /tmp/
# RUN dnf -y install /tmp/docker-desktop.rpm && rm -f /tmp/docker-desktop.rpm

# NVIDIA/CUDA (placeholder: add RPMs or use rpmfusion + nvidia repo offline)
# COPY nvidia/*.rpm /tmp/nvidia/
# RUN dnf -y install /tmp/nvidia/*.rpm && rm -rf /tmp/nvidia

# ML wheels embed
COPY ml-wheels/ /opt/ml-wheels/

# Post-boot setup script
COPY post-install/ /opt/post-install/

# Enable services as needed
RUN systemctl enable sddm || true

# Default user creation (example)
RUN useradd -m AIBUser && echo 'AIBUser:changeme' | chpasswd && usermod -aG wheel,docker AIBUser || true

# Entrypoint handled by bootc system provisioning
