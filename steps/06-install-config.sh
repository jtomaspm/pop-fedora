#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"

readonly REPO_ROOT="${POP_FEDORA_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
readonly BASHRC_PROFILE_LINE='[ -f "$XDG_CONFIG_HOME/shell/profile" ] && source "$XDG_CONFIG_HOME/shell/profile"'

target_user=""
target_group=""
target_home=""

resolve_target_user() {
    local passwd_entry
    local group_entry
    local _username
    local _password
    local _uid
    local gid
    local gecos
    local group_name
    local shell_path

    if [[ "$EUID" -eq 0 ]]; then
        target_user="${SUDO_USER:-}"

        if [[ -z "$target_user" || "$target_user" == "root" ]]; then
            pf_log_warning "Skipping config installation: no non-root invoking user was detected."
            exit 0
        fi
    else
        target_user="${USER:-}"

        if [[ -z "$target_user" || "$target_user" == "root" ]]; then
            pf_log_error "Unable to determine which user should receive the shell configuration."
            return 1
        fi
    fi

    if ! passwd_entry="$(getent passwd "$target_user")"; then
        pf_log_error "Unable to resolve home directory for $target_user."
        return 1
    fi

    IFS=':' read -r _username _password _uid gid gecos target_home shell_path <<<"$passwd_entry"

    if ! group_entry="$(getent group "$gid")"; then
        pf_log_error "Unable to resolve primary group for $target_user."
        return 1
    fi

    IFS=':' read -r group_name _ <<<"$group_entry"
    target_group="$group_name"

    if [[ -z "$target_home" || -z "$target_group" ]]; then
        pf_log_error "Unable to resolve account details for $target_user."
        return 1
    fi
}

set_target_ownership() {
    local path

    path="$1"

    if [[ "$EUID" -eq 0 ]]; then
        chown "$target_user:$target_group" "$path"
    fi
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

pf_log_section "Install Shell Configuration"
resolve_target_user

ensure_directory "$target_home/.config/shell"
ensure_directory "$target_home/.config/ghostty"
ensure_directory "$target_home/.config/scripts"

install_config_file "config/zsh/.zshrc" "$target_home/.zshrc"
install_config_file "config/shell/profile" "$target_home/.config/shell/profile"

ensure_bashrc_profile_line
