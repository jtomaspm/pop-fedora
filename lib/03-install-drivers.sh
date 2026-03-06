#!/usr/bin/env bash
set -euo pipefail

set +e
sudo fwupdmgr refresh --force
sudo fwupdmgr get-devices
sudo fwupdmgr get-updates
sudo fwupdmgr update
set -e

sudo dnf4 group install multimedia -y
sudo dnf swap 'ffmpeg-free' 'ffmpeg' --allowerasing  -y
sudo dnf upgrade @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y
sudo dnf group install -y sound-and-video
