#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"
# shellcheck source=../lib/packages.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/packages.sh"
# shellcheck source=../lib/users.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/users.sh"

configure_vscode_repository_commands() {
    local vscode_key_url
    local vscode_repo_file
    local vscode_repo_config

    vscode_key_url="https://packages.microsoft.com/keys/microsoft.asc"
    vscode_repo_file="/etc/yum.repos.d/vscode.repo"
    vscode_repo_config="[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc"

    pf_retry_command rpm --import "$vscode_key_url"
    echo -e "$vscode_repo_config" | sudo tee "$vscode_repo_file" > /dev/null
    pf_retry_command_allowing_exit_codes "0 100" dnf check-update -y
}

disable_wait_online_service() {
    systemctl disable NetworkManager-wait-online.service
}

install_openh264_support() {
    pf_retry_command dnf install -y openh264 gstreamer1-plugin-openh264 mozilla-openh264
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
    pf_dnf_refresh_system
}

install_flatpak_software() {
    pf_flatpak_install_system flathub \
        app.zen_browser.zen \
        com.stremio.Stremio \
        com.mattjakeman.ExtensionManager \
        com.vysp3r.ProtonPlus \
        org.onlyoffice.desktopeditors \
        io.ente.auth
}

install_github_cli() {
    pf_retry_command dnf config-manager addrepo --overwrite --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo -y
    pf_retry_command dnf install gh --repo gh-cli -y
}

install_development_tooling() {
    pf_retry_command dnf install -y \
        zsh \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        rust \
        cargo \
        dotnet-sdk-10.0 \
        nodejs \
        npm \
        python3 \
        pip3 \
        golang
}

configure_default_shell() {
    local target_user
    local zsh_path
    local current_shell

    if ! target_user="$(pf_user_require_for_action_or_warn "Skipping default shell configuration: no target user was detected.")"; then
        return 0
    fi

    if ! zsh_path="$(command -v zsh)"; then
        pf_log_error "Unable to configure the default shell: zsh was not found after installation."
        return 1
    fi

    if ! current_shell="$(pf_user_get_passwd_field "$target_user" shell)"; then
        pf_log_error "Unable to configure the default shell: user $target_user was not found."
        return 1
    fi

    if [[ "$current_shell" == "$zsh_path" ]]; then
        pf_log_info "$target_user already uses $zsh_path as the default shell."
        return 0
    fi

    usermod -s "$zsh_path" "$target_user"
    pf_log_success "Default shell for $target_user set to $zsh_path."
}

configure_vscode_repository() {
    pf_run_best_effort configure_vscode_repository_commands
}

install_vscode() {
    pf_retry_command dnf install code -y
}

install_docker() {
    local docker_desktop_url
    local docker_target_user
    local target_user_message
    local tmp_rpm
    local tmp_rpm_trap_command

    # Docker Desktop for Fedora
    # Official docs:
    # https://docs.docker.com/desktop/setup/install/linux/fedora/

    # Docker Desktop is only supported on Fedora x86_64 and requires a desktop session.
    docker_desktop_url="https://desktop.docker.com/linux/main/amd64/docker-desktop-x86_64-rhel.rpm?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-linux-amd64"
    target_user_message="Docker group exists. No non-root user was detected to add to it automatically."

    if docker_target_user="$(pf_user_resolve_for_action)"; then
        :
    else
        docker_target_user=""
    fi

    # Docker repo is required by Docker Desktop on Fedora.
    pf_retry_command dnf config-manager addrepo --overwrite --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

    pf_retry_command dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker

    if ! getent group docker >/dev/null; then
        groupadd docker
    fi

    pf_user_add_to_group_if_non_root "$docker_target_user" docker

    systemctl enable docker.service
    systemctl enable containerd.service

    pf_log_info "Docker service and group configuration complete."
    if [[ -n "$docker_target_user" ]]; then
        pf_log_info "$docker_target_user is now in the docker group. You may need to log out and log back in for this to take effect..."
    else
        pf_log_info "$target_user_message"
    fi

    tmp_rpm="$(mktemp --suffix=.rpm)"
    printf -v tmp_rpm_trap_command 'rm -f -- %q' "$tmp_rpm"
    trap "$tmp_rpm_trap_command" EXIT

    pf_retry_command curl -fL "$docker_desktop_url" -o "$tmp_rpm"
    pf_run_best_effort pf_retry_command dnf -y install "$tmp_rpm"

    pf_log_success "Docker Desktop installed."
    pf_log_info "May fail on VMs without nested virtualization support or if running under WSL. Please check the output above for any errors."
}

install_desktop_apps() {
    pf_retry_command dnf install -y \
        steam \
        lutris \
        nautilus-python \
        gnome-tweaks \
        ghostty
}

install_claude_code() {
    local target_user
    local target_home

    if ! target_user="$(pf_user_require_for_action_or_warn "Skipping Claude Code installation: no non-root target user was detected.")"; then
        return 0
    fi

    if ! target_home="$(pf_user_get_passwd_field "$target_user" home)"; then
        pf_log_error "Unable to install Claude Code: home directory for $target_user could not be resolved."
        return 1
    fi

    pf_log_info "Installing Claude Code for $target_user."

    if [[ "$EUID" -eq 0 ]]; then
        pf_retry_command sudo -u "$target_user" env \
            HOME="$target_home" \
            USER="$target_user" \
            LOGNAME="$target_user" \
            bash -lc 'set -euo pipefail; curl -fsSL https://claude.ai/install.sh | bash'
    else
        pf_retry_command env \
            HOME="$target_home" \
            USER="$target_user" \
            LOGNAME="$target_user" \
            bash -lc 'set -euo pipefail; curl -fsSL https://claude.ai/install.sh | bash'
    fi

    pf_log_success "Claude Code installed for $target_user."
    pf_log_info "Claude Code will be available in a new shell after ~/.local/bin is added to PATH."
}

install_global_tools() {
    npm i -g opencode-ai
    npm i -g @openai/codex
    install_claude_code
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
configure_default_shell

pf_log_section "Install Visual Studio Code"
configure_vscode_repository
install_vscode

pf_log_section "Install Docker Desktop"
install_docker

pf_log_section "Install Desktop Applications"
install_desktop_apps

pf_log_section "Install Global CLI Tools"
install_global_tools
