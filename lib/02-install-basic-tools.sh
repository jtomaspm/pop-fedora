#!/usr/bin/env bash
set -euo pipefail

configure_git() {
    local git_user_name
    local git_user_email
    local git_config_cmd

    git_user_name="${POP_FEDORA_GIT_USER_NAME:-}"
    git_user_email="${POP_FEDORA_GIT_USER_EMAIL:-}"

    if [[ -z "$git_user_name" || -z "$git_user_email" ]]; then
        echo "Skipping git configuration because POP_FEDORA_GIT_USER_NAME or POP_FEDORA_GIT_USER_EMAIL is unset." >&2
        return 0
    fi

    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        git_config_cmd=(sudo -u "$SUDO_USER" git config --global)
    else
        git_config_cmd=(git config --global)
    fi

    "${git_config_cmd[@]}" user.name "$git_user_name"
    "${git_config_cmd[@]}" user.email "$git_user_email"
    "${git_config_cmd[@]}" pull.rebase false
}

dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
dnf update -y
dnf upgrade -y
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

configure_git
