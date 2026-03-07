#!/usr/bin/env bash
set -euo pipefail

systemctl disable NetworkManager-wait-online.service

dnf install -y openh264 gstreamer1-plugin-openh264 mozilla-openh264
dnf config-manager setopt fedora-cisco-openh264.enabled=1

dnf remove -y \
    firefox

flatpak install --system -y flathub app.zen_browser.zen

dnf autoremove -y

dnf clean all

dnf update -y
dnf upgrade -y

dnf install -y \
    rust \
    cargo \
    dotnet-sdk-10.0 \
    nodejs \
    npm \
    python3 \
    pip3 \
    golang

rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
dnf check-update -y
dnf install code -y

# Docker Desktop for Fedora
# Official docs:
# https://docs.docker.com/desktop/setup/install/linux/fedora/

# Docker Desktop is only supported on Fedora x86_64 and requires a desktop session.
DOCKER_DESKTOP_URL="https://desktop.docker.com/linux/main/amd64/docker-desktop-x86_64-rhel.rpm?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-linux-amd64"
DOCKER_TARGET_USER="${SUDO_USER:-${USER:-}}"

# Docker repo is required by Docker Desktop on Fedora.
dnf -y install dnf-plugins-core
dnf config-manager addrepo --overwrite --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

if ! getent group docker >/dev/null; then
    groupadd docker
fi

if [[ -n "$DOCKER_TARGET_USER" && "$DOCKER_TARGET_USER" != "root" ]]; then
    usermod -aG docker "$DOCKER_TARGET_USER"
fi

systemctl enable docker.service
systemctl enable containerd.service

echo
echo "### DOCKER ###"
echo
if [[ -n "$DOCKER_TARGET_USER" && "$DOCKER_TARGET_USER" != "root" ]]; then
    echo "$DOCKER_TARGET_USER is now in the docker group. You may need to log out and log back in for this to take effect..."
else
    echo "Docker group exists. No non-root user was detected to add to it automatically."
fi
echo
echo

tmp_rpm="$(mktemp --suffix=.rpm)"
trap 'rm -f "$tmp_rpm"' EXIT

curl -fL "$DOCKER_DESKTOP_URL" -o "$tmp_rpm"
set +e
dnf -y install "$tmp_rpm"
set -e

echo
echo "Docker Desktop installed."
echo "May fail on VMs without nested virtualization support or if running under WSL. Please check the output above for any errors."
echo
