#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)}/logging.sh"

install_repository_releases() {
    local fedora_version

    fedora_version="$(rpm -E %fedora)"

    set +e
    dnf install \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm" \
        -y
    dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release -y
    set -e
}

update_core_packages() {
    dnf update -y
    dnf upgrade -y
    dnf group upgrade core -y
    dnf4 group install core -y
}

install_basic_tools() {
    dnf install -y \
        git \
        curl \
        wget \
        tree \
        fzf \
        rg \
        neovim \
        fastfetch \
        unzip \
        tar \
        xz
}

install_dnf_plugins() {
    dnf install dnf5-plugins dnf-plugins-core -y
}

configure_git() {
    local git_user_name
    local git_user_email
    local git_config_cmd

    git_user_name="${POP_FEDORA_GIT_USER_NAME:-}"
    git_user_email="${POP_FEDORA_GIT_USER_EMAIL:-}"

    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        git_config_cmd=(sudo -u "$SUDO_USER" git config --global)
    else
        git_config_cmd=(git config --global)
    fi

    if [[ -n "$git_user_name" ]]; then
        "${git_config_cmd[@]}" user.name "$git_user_name"
    fi

    if [[ -n "$git_user_email" ]]; then
        "${git_config_cmd[@]}" user.email "$git_user_email"
    fi

    "${git_config_cmd[@]}" pull.rebase false
}

pf_log_section "Enable Third-Party Repositories"
install_repository_releases

pf_log_section "Install Core System Packages"
update_core_packages
install_basic_tools
install_dnf_plugins

pf_log_section "Configure Git"
configure_git
