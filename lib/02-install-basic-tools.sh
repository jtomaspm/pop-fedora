#!/usr/bin/env bash
set -euo pipefail

dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
dnf group upgrade core -y
dnf4 group install core -y

dnf install -y \
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
