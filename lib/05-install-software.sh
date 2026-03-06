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