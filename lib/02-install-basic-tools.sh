#!/usr/bin/env bash
set -euo pipefail

sudo dnf install -y \
    git \
    curl \
    wget \
    tree \
    unzip \
    tar \
    xz 

set +e
sudo fwupdmgr refresh --force
sudo fwupdmgr get-devices
sudo fwupdmgr get-updates
sudo fwupdmgr update
set -e

sudo dnf4 group install multimedia -y
sudo dnf swap 'ffmpeg-free' 'ffmpeg' --allowerasing  -y # Switch to full FFMPEG.
sudo dnf upgrade @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y # Installs gstreamer components. Required if you use Gnome Videos and other dependent applications.
sudo dnf group install -y sound-and-video # Installs useful Sound and Video complementary packages.

