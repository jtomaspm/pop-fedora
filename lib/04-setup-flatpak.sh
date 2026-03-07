#!/usr/bin/env bash
set -euo pipefail

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
    flatpak install --system -y "$flathub_remote_name" "$gearlever_app_id"
}

# ---------- Flatpak remotes ----------
add_flathub_remote

# ---------- Flatpak support packages ----------
install_flatpak_dependencies

# ---------- Flatpak applications ----------
install_flatpak_apps
