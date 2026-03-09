#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"
# shellcheck source=../lib/users.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/users.sh"

readonly REPO_ROOT="${POP_FEDORA_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
readonly BASHRC_PROFILE_LINE='[ -f "$XDG_CONFIG_HOME/shell/profile" ] && source "$XDG_CONFIG_HOME/shell/profile"'

target_user=""
target_group=""
target_home=""

resolve_target_user() {
    if [[ "$EUID" -eq 0 ]]; then
        if ! target_user="$(pf_user_require_default_or_warn "Skipping config installation: no non-root invoking user was detected.")"; then
            exit 0
        fi
    else
        if ! target_user="$(pf_user_require_default_or_error "Unable to determine which user should receive the shell configuration.")"; then
            return 1
        fi
    fi

    if ! target_home="$(pf_user_get_passwd_field "$target_user" home)"; then
        pf_log_error "Unable to resolve home directory for $target_user."
        return 1
    fi

    if ! target_group="$(pf_user_get_primary_group "$target_user")"; then
        pf_log_error "Unable to resolve primary group for $target_user."
        return 1
    fi

    if [[ -z "$target_home" || -z "$target_group" ]]; then
        pf_log_error "Unable to resolve account details for $target_user."
        return 1
    fi
}

set_target_ownership() {
    local path

    path="$1"
    pf_maybe_chown "$target_user" "$target_group" "$path"
}

set_target_ownership_recursive() {
    local path

    path="$1"
    pf_maybe_chown_recursive "$target_user" "$target_group" "$path"
}

ensure_directory() {
    local directory

    directory="$1"

    mkdir -p "$directory"
    set_target_ownership "$directory"
    pf_log_info "Ensured directory $directory"
}

install_config_file() {
    local source_relative_path
    local source_path
    local target_path

    source_relative_path="$1"
    target_path="$2"
    source_path="$REPO_ROOT/$source_relative_path"

    if [[ ! -f "$source_path" ]]; then
        pf_log_error "Missing config source file: $source_relative_path"
        return 1
    fi

    install -m 0644 "$source_path" "$target_path"
    set_target_ownership "$target_path"
    pf_log_success "Installed $source_relative_path to $target_path"
}

install_config_directory() {
    local source_relative_path
    local source_path
    local target_path

    source_relative_path="$1"
    target_path="$2"
    source_path="$REPO_ROOT/$source_relative_path"

    if [[ ! -d "$source_path" ]]; then
        pf_log_error "Missing config source directory: $source_relative_path"
        return 1
    fi

    rm -rf "$target_path"
    mkdir -p "$target_path"
    cp -a "$source_path/." "$target_path"
    set_target_ownership_recursive "$target_path"
    pf_log_success "Installed $source_relative_path to $target_path"
}

ensure_bashrc_profile_line() {
    local bashrc_path

    bashrc_path="$target_home/.bashrc"

    if [[ ! -f "$bashrc_path" ]]; then
        : > "$bashrc_path"
        set_target_ownership "$bashrc_path"
        pf_log_info "Created $bashrc_path"
    fi

    if grep -Fqx "$BASHRC_PROFILE_LINE" "$bashrc_path"; then
        pf_log_info "$bashrc_path already sources the shared shell profile."
        return 0
    fi

    if [[ -s "$bashrc_path" ]]; then
        printf '\n%s\n' "$BASHRC_PROFILE_LINE" >> "$bashrc_path"
    else
        printf '%s\n' "$BASHRC_PROFILE_LINE" >> "$bashrc_path"
    fi

    set_target_ownership "$bashrc_path"
    pf_log_success "Added shared shell profile sourcing to $bashrc_path"
}

pf_log_section "Install User Configuration"
resolve_target_user

ensure_directory "$target_home/.config/shell"
ensure_directory "$target_home/.config/ghostty"
ensure_directory "$target_home/.config/scripts"

install_config_file "config/zsh/.zshrc" "$target_home/.zshrc"
install_config_file "config/shell/profile" "$target_home/.config/shell/profile"
install_config_file "config/ghostty/config" "$target_home/.config/ghostty/config"
install_config_directory "config/nvim" "$target_home/.config/nvim"

ensure_bashrc_profile_line
