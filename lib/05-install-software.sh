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

remove_package_if_installed() {
    local package_name

    package_name="$1"

    if rpm -q "$package_name" >/dev/null 2>&1; then
        dnf remove -y "$package_name"
    fi
}

preflight_docker_desktop_qemu_conflict() {
    local qemu_path
    local qemu_owner

    qemu_path="/usr/bin/qemu-system-x86_64"

    if [[ ! -e "$qemu_path" ]]; then
        return 0
    fi

    qemu_owner="$(rpm -qf "$qemu_path" 2>/dev/null || true)"

    case "$qemu_owner" in
        qemu-system-x86-core-*)
            echo "Docker Desktop preflight: removing Fedora QEMU packages that own $qemu_path"
            echo "This avoids the known Docker Desktop install conflict on Fedora."
            remove_package_if_installed qemu-system-x86
            remove_package_if_installed qemu-system-x86-core
            ;;
        qemu-system-x86-*)
            echo "Docker Desktop preflight: removing Fedora QEMU package that owns $qemu_path"
            echo "This avoids the known Docker Desktop install conflict on Fedora."
            remove_package_if_installed qemu-system-x86
            ;;
    esac
}

# Docker repo is required by Docker Desktop on Fedora.
dnf -y install dnf-plugins-core
dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

preflight_docker_desktop_qemu_conflict

tmp_rpm="$(mktemp --suffix=.rpm)"
trap 'rm -f "$tmp_rpm"' EXIT

curl -fL "$DOCKER_DESKTOP_URL" -o "$tmp_rpm"
dnf -y install "$tmp_rpm"

echo
echo "Docker Desktop installed."
echo "Launch it from your desktop session, or run:"
echo "  systemctl --user start docker-desktop"
