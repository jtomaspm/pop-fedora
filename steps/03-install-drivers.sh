#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"
# shellcheck source=../lib/packages.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/packages.sh"

refresh_firmware_commands() {
    pf_retry_command fwupdmgr refresh --force
    fwupdmgr get-devices
    pf_retry_command fwupdmgr get-updates
    pf_retry_command fwupdmgr update
}

refresh_firmware() {
    pf_run_best_effort refresh_firmware_commands
}

install_multimedia_support() {
    pf_retry_command dnf4 group install multimedia -y
    pf_retry_command dnf swap 'ffmpeg-free' 'ffmpeg' --allowerasing -y
    pf_retry_command dnf upgrade @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y
    pf_retry_command dnf group install -y sound-and-video
}

pf_log_section "Refresh Firmware"
refresh_firmware

pf_log_section "Install Multimedia Drivers and Codecs"
install_multimedia_support
