#!/usr/bin/env bash
set -euo pipefail

sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
sudo dnf group upgrade core -y
sudo dnf4 group install core -y

sudo dnf install -y \
    git \
    curl \
    wget \
    tree \
    gh \
    fzf \
    rg \
    neovim \
    fastfetch \
    unzip \
    tar \
    xz 

