#!/usr/bin/env bash
set -euo pipefail

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

sudo dnf in fuse-libs -y
flatpak install it.mijorus.gearlever