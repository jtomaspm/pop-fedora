#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"

disable_wait_online_service() {
    systemctl disable NetworkManager-wait-online.service
}

install_openh264_support() {
    dnf install -y openh264 gstreamer1-plugin-openh264 mozilla-openh264
    dnf config-manager setopt fedora-cisco-openh264.enabled=1
}

remove_preinstalled_software() {
    dnf remove -y \
        firefox \
        ptyxis \
        libreoffice-writer \
        libreoffice-calc \
        libreoffice-impress \
        libreoffice-core
}

refresh_system_packages() {
    dnf autoremove -y
    dnf clean all
    dnf update -y
    dnf upgrade -y
}

install_flatpak_software() {
    flatpak install --system -y flathub app.zen_browser.zen
    flatpak install --system -y flathub com.stremio.Stremio
    flatpak install --system -y flathub com.mattjakeman.ExtensionManager
    flatpak install --system -y flathub com.vysp3r.ProtonPlus
    flatpak install --system -y flathub org.onlyoffice.desktopeditors
    flatpak install --system -y flathub io.ente.auth
}

install_github_cli() {
    dnf config-manager addrepo --overwrite --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo -y
    dnf install gh --repo gh-cli -y
}

install_development_tooling() {
    dnf install -y \
        zsh \
        rust \
        cargo \
        dotnet-sdk-10.0 \
        nodejs \
        npm \
        python3 \
        pip3 \
        golang
}

configure_vscode_repository() {
    local vscode_key_url
    local vscode_repo_file
    local vscode_repo_config

    vscode_key_url="https://packages.microsoft.com/keys/microsoft.asc"
    vscode_repo_file="/etc/yum.repos.d/vscode.repo"
    vscode_repo_config="[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc"

    set +e
    rpm --import "$vscode_key_url"
    echo -e "$vscode_repo_config" | sudo tee "$vscode_repo_file" > /dev/null
    dnf check-update -y
    set -e
}

install_vscode() {
    dnf install code -y
}

install_docker() {
    local docker_desktop_url
    local docker_target_user

    # Docker Desktop for Fedora
    # Official docs:
    # https://docs.docker.com/desktop/setup/install/linux/fedora/

    # Docker Desktop is only supported on Fedora x86_64 and requires a desktop session.
    docker_desktop_url="https://desktop.docker.com/linux/main/amd64/docker-desktop-x86_64-rhel.rpm?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-linux-amd64"
    docker_target_user="${SUDO_USER:-${USER:-}}"

    # Docker repo is required by Docker Desktop on Fedora.
    dnf config-manager addrepo --overwrite --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker

    if ! getent group docker >/dev/null; then
        groupadd docker
    fi

    if [[ -n "$docker_target_user" && "$docker_target_user" != "root" ]]; then
        usermod -aG docker "$docker_target_user"
    fi

    systemctl enable docker.service
    systemctl enable containerd.service

    pf_log_info "Docker service and group configuration complete."
    if [[ -n "$docker_target_user" && "$docker_target_user" != "root" ]]; then
        pf_log_info "$docker_target_user is now in the docker group. You may need to log out and log back in for this to take effect..."
    else
        pf_log_info "Docker group exists. No non-root user was detected to add to it automatically."
    fi

    tmp_rpm="$(mktemp --suffix=.rpm)"
    trap 'rm -f "$tmp_rpm"' EXIT

    curl -fL "$docker_desktop_url" -o "$tmp_rpm"
    set +e
    dnf -y install "$tmp_rpm"
    set -e

    pf_log_success "Docker Desktop installed."
    pf_log_info "May fail on VMs without nested virtualization support or if running under WSL. Please check the output above for any errors."
}

install_desktop_apps() {
    dnf install -y \
        steam \
        nautilus-python \
        gnome-tweaks \
        ghostty
}

install_global_tools() {
    npm i -g opencode-ai
    npm i -g @openai/codex
    curl -fsSL https://claude.ai/install.sh | bash
}

pf_log_section "Configure System Services"
disable_wait_online_service

pf_log_section "Install Codec Support"
install_openh264_support

pf_log_section "Remove Preinstalled Software"
remove_preinstalled_software
refresh_system_packages

pf_log_section "Install Flatpak Applications"
install_flatpak_software

pf_log_section "Install Developer Tooling"
install_github_cli
install_development_tooling

pf_log_section "Install Visual Studio Code"
configure_vscode_repository
install_vscode

pf_log_section "Install Docker Desktop"
install_docker

pf_log_section "Install Desktop Applications"
install_desktop_apps

pf_log_section "Install Global CLI Tools"
install_global_tools
