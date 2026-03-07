#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ARCHIVE_URL="https://github.com/jtomaspm/pop-fedora/archive/refs/heads/main.tar.gz"

REPO_ROOT=""
LIB_DIR=""
TEMP_DIR=""
FAILED_STEP=""
KEEPALIVE_PID=""
POP_FEDORA_HOSTNAME="${POP_FEDORA_HOSTNAME:-}"
POP_FEDORA_HOSTNAME_PROMPTED="${POP_FEDORA_HOSTNAME_PROMPTED:-}"
POP_FEDORA_GIT_USER_NAME="${POP_FEDORA_GIT_USER_NAME:-}"
POP_FEDORA_GIT_USER_EMAIL="${POP_FEDORA_GIT_USER_EMAIL:-}"

declare -a STEPS=()
declare -a RUN_STEPS=()

prompt_for_hostname() {
    local current_hostname

    if [[ -n "$POP_FEDORA_HOSTNAME_PROMPTED" ]]; then
        return 0
    fi

    current_hostname="$(hostnamectl --static)"

    echo ""
    echo "Current hostname: $current_hostname"
    read -rp "Enter new hostname (leave empty to ignore): " POP_FEDORA_HOSTNAME

    POP_FEDORA_HOSTNAME_PROMPTED="1"
    export POP_FEDORA_HOSTNAME
    export POP_FEDORA_HOSTNAME_PROMPTED
}

set_new_hostname() {
    if [[ -z "$POP_FEDORA_HOSTNAME" ]]; then
        return 0
    fi

    echo "Setting hostname to $POP_FEDORA_HOSTNAME"
    if [[ "$EUID" -eq 0 ]]; then
        hostnamectl set-hostname "$POP_FEDORA_HOSTNAME"
    else
        sudo hostnamectl set-hostname "$POP_FEDORA_HOSTNAME"
    fi
}

git_config_get() {
    local key

    key="$1"

    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        sudo -u "$SUDO_USER" git config --global --get "$key" 2>/dev/null || true
        return 0
    fi

    git config --global --get "$key" 2>/dev/null || true
}

prompt_for_git_config() {
    local existing_git_user_name
    local existing_git_user_email
    local prompted_git_user_name
    local prompted_git_user_email

    existing_git_user_name="$(git_config_get user.name)"
    existing_git_user_email="$(git_config_get user.email)"

    prompted_git_user_name=""
    prompted_git_user_email=""

    if [[ -z "$existing_git_user_name" ]]; then
        prompted_git_user_name="${POP_FEDORA_GIT_USER_NAME:-}"
    fi

    if [[ -z "$existing_git_user_email" ]]; then
        prompted_git_user_email="${POP_FEDORA_GIT_USER_EMAIL:-}"
    fi

    if [[ ( -z "$existing_git_user_name" && -z "$prompted_git_user_name" ) || ( -z "$existing_git_user_email" && -z "$prompted_git_user_email" ) ]] && [[ ! -t 0 ]]; then
        echo "Git user.name and user.email must be provided in an interactive shell when they are not already set." >&2
        return 1
    fi

    while [[ -z "$existing_git_user_name" && -z "$prompted_git_user_name" ]]; do
        read -r -p "Git user.name: " prompted_git_user_name
    done

    while [[ -z "$existing_git_user_email" && -z "$prompted_git_user_email" ]]; do
        read -r -p "Git user.email: " prompted_git_user_email
    done

    POP_FEDORA_GIT_USER_NAME="$prompted_git_user_name"
    POP_FEDORA_GIT_USER_EMAIL="$prompted_git_user_email"
    export POP_FEDORA_GIT_USER_NAME
    export POP_FEDORA_GIT_USER_EMAIL
}

cleanup() {
    if [[ -n "${KEEPALIVE_PID:-}" ]]; then
        kill "$KEEPALIVE_PID" 2>/dev/null || true
        wait "$KEEPALIVE_PID" 2>/dev/null || true
    fi

    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR:-}" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

resolve_repo_root() {
    local script_dir

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

    if [[ -f "$script_dir/install.sh" && -d "$script_dir/lib" ]]; then
        printf '%s\n' "$script_dir"
        return 0
    fi

    return 1
}

prepare_bootstrap_repo() {
    local archive_path
    local extracted_dir

    TEMP_DIR="$(mktemp -d)"
    archive_path="$TEMP_DIR/repo.tar.gz"

    echo "Bootstrapping jtomaspm/pop-fedora@main"
    wget -qO "$archive_path" "$REPO_ARCHIVE_URL"
    tar -xzf "$archive_path" -C "$TEMP_DIR"

    extracted_dir="$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

    if [[ -z "$extracted_dir" ]]; then
        echo "Failed to extract the repository archive." >&2
        return 1
    fi

    REPO_ROOT="$extracted_dir"
    LIB_DIR="$REPO_ROOT/lib"

    if [[ ! -f "$REPO_ROOT/install.sh" || ! -d "$LIB_DIR" ]]; then
        echo "Failed to prepare a temporary checkout of the repository." >&2
        return 1
    fi
}

collect_steps() {
    mapfile -t STEPS < <(find "$LIB_DIR" -maxdepth 1 -type f -name '*.sh' | sort)

    if [[ "${#STEPS[@]}" -eq 0 ]]; then
        echo "No installer steps were found in $LIB_DIR" >&2
        return 1
    fi
}

step_number_from_file() {
    local step_file
    local step_base

    step_file="$1"
    step_base="$(basename "$step_file")"

    printf '%s\n' "${step_base%%-*}"
}

step_name_from_file() {
    local step_file
    local step_base
    local step_name

    step_file="$1"
    step_base="$(basename "$step_file")"
    step_name="${step_base#*-}"
    step_name="${step_name%.sh}"

    printf '%s\n' "${step_name//-/ }"
}

describe_step() {
    local step_file
    local step_name

    step_file="$1"
    step_name="$(step_name_from_file "$step_file")"

    if [[ ! -s "$step_file" ]]; then
        printf '%s (placeholder)\n' "$step_name"
        return 0
    fi

    printf '%s\n' "$step_name"
}

ensure_sudo_session() {
    if [[ "$EUID" -eq 0 ]]; then
        return 0
    fi

    echo "Authenticating sudo access"
    sudo -v

    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
    done >/dev/null 2>&1 &
    KEEPALIVE_PID=$!
}

run_step() {
    local step_file
    local step_number
    local step_name

    step_file="$1"
    step_number="$(step_number_from_file "$step_file")"
    step_name="$(step_name_from_file "$step_file")"

    export POP_FEDORA_REPO_ROOT="$REPO_ROOT"
    export POP_FEDORA_LIB_DIR="$LIB_DIR"
    export POP_FEDORA_STEP_FILE="$step_file"
    export POP_FEDORA_STEP_NAME="$step_name"
    export POP_FEDORA_STEP_NUMBER="$step_number"
    export POP_FEDORA_GIT_USER_NAME
    export POP_FEDORA_GIT_USER_EMAIL

    echo
    echo "Running [$step_number] $step_name"
    if [[ "$EUID" -eq 0 ]]; then
        bash "$step_file"
        return 0
    fi

    sudo --preserve-env=POP_FEDORA_REPO_ROOT,POP_FEDORA_LIB_DIR,POP_FEDORA_STEP_FILE,POP_FEDORA_STEP_NAME,POP_FEDORA_STEP_NUMBER,POP_FEDORA_GIT_USER_NAME,POP_FEDORA_GIT_USER_EMAIL \
        bash "$step_file"
}

print_summary() {
    local entry

    echo
    echo "Summary"

    if [[ "${#RUN_STEPS[@]}" -eq 0 ]]; then
        echo "Ran: none"
    else
        echo "Ran:"
        for entry in "${RUN_STEPS[@]}"; do
            echo "  $entry"
        done
    fi

    if [[ -n "$FAILED_STEP" ]]; then
        echo "Failed: $FAILED_STEP"
    fi
}

main() {
    local step_file
    local step_number
    local step_description
    local exit_code

    trap cleanup EXIT
    prompt_for_hostname
    prompt_for_git_config

    if REPO_ROOT="$(resolve_repo_root)"; then
        LIB_DIR="$REPO_ROOT/lib"
    else
        prepare_bootstrap_repo
        bash "$REPO_ROOT/install.sh" "$@"
        return $?
    fi

    collect_steps
    ensure_sudo_session
    set_new_hostname

    for step_file in "${STEPS[@]}"; do
        step_number="$(step_number_from_file "$step_file")"
        step_description="$(describe_step "$step_file")"
        if run_step "$step_file"; then
            RUN_STEPS+=("[$step_number] $step_description")
        else
            exit_code=$?
            FAILED_STEP="[$step_number] $step_description"
            echo "Step failed: $FAILED_STEP" >&2
            print_summary
            return "$exit_code"
        fi
    done

    print_summary
}

main "$@"
