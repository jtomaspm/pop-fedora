#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"
# shellcheck source=../lib/git.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/git.sh"
# shellcheck source=../lib/packages.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/packages.sh"

install_repository_releases_commands() {
    local fedora_version

    fedora_version="$(rpm -E %fedora)"

    dnf install \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm" \
        -y
    dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release -y
}

install_repository_releases() {
    pf_run_best_effort install_repository_releases_commands
}

update_core_packages() {
    pf_dnf_refresh_system
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

    git_user_name="${POP_FEDORA_GIT_USER_NAME:-}"
    git_user_email="${POP_FEDORA_GIT_USER_EMAIL:-}"

    if [[ -n "$git_user_name" ]]; then
        pf_git_config_set user.name "$git_user_name"
    fi

    if [[ -n "$git_user_email" ]]; then
        pf_git_config_set user.email "$git_user_email"
    fi

    pf_git_config_set pull.rebase false
}

pf_log_section "Enable Third-Party Repositories"
install_repository_releases

pf_log_section "Install Core System Packages"
update_core_packages
install_basic_tools
install_dnf_plugins

pf_log_section "Configure Git"
configure_git
