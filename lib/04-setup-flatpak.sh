#!/usr/bin/env bash
set -euo pipefail

flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

dnf install -y fuse-libs flatseal
flatpak install --system -y flathub it.mijorus.gearlever
