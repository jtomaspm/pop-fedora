#!/usr/bin/env bash
set -euo pipefail

refresh_firmware() {
    set +e
    fwupdmgr refresh --force
    fwupdmgr get-devices
    fwupdmgr get-updates
    fwupdmgr update
    set -e
}

install_multimedia_support() {
    dnf4 group install multimedia -y
    dnf swap 'ffmpeg-free' 'ffmpeg' --allowerasing -y
    dnf upgrade @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y
    dnf group install -y sound-and-video
}

# ---------- Firmware updates ----------
refresh_firmware

# ---------- Multimedia drivers and codecs ----------
install_multimedia_support
