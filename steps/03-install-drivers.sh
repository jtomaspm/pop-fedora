#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"

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

pf_log_section "Refresh Firmware"
refresh_firmware

pf_log_section "Install Multimedia Drivers and Codecs"
install_multimedia_support
