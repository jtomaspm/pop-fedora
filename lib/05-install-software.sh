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

# Docker Desktop for Fedora
# Official docs:
# https://docs.docker.com/desktop/setup/install/linux/fedora/

# Docker Desktop is only supported on Fedora x86_64 and requires a desktop session.
DOCKER_DESKTOP_URL="https://desktop.docker.com/linux/main/amd64/docker-desktop-x86_64-rhel.rpm?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-linux-amd64"

# Docker repo is required by Docker Desktop on Fedora.
dnf -y install dnf-plugins-core
dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo


tmp_rpm="$(mktemp --suffix=.rpm)"
trap 'rm -f "$tmp_rpm"' EXIT

curl -fL "$DOCKER_DESKTOP_URL" -o "$tmp_rpm"
dnf -y install "$tmp_rpm"

echo
echo "Docker Desktop installed."
echo "Launch it from your desktop session, or run:"
echo "  systemctl --user start docker-desktop"