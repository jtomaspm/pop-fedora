#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"
# shellcheck source=../lib/packages.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/packages.sh"

flathub_remote_name="flathub"
flathub_remote_url="https://dl.flathub.org/repo/flathub.flatpakrepo"
gearlever_app_id="it.mijorus.gearlever"

add_flathub_remote() {
    flatpak remote-add --system --if-not-exists "$flathub_remote_name" "$flathub_remote_url"
}

install_flatpak_dependencies() {
    dnf install -y fuse-libs flatseal
}

install_flatpak_apps() {
    pf_flatpak_install_system "$flathub_remote_name" "$gearlever_app_id"
}

pf_log_section "Configure Flatpak Remotes"
add_flathub_remote

pf_log_section "Install Flatpak Support Packages"
install_flatpak_dependencies

pf_log_section "Install Flatpak Applications"
install_flatpak_apps
