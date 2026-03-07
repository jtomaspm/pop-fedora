#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ARCHIVE_URL="https://github.com/jtomaspm/pop-fedora/archive/refs/heads/main.tar.gz"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly LOGGING_FILE="$SCRIPT_DIR/lib/logging.sh"

if [[ -f "$LOGGING_FILE" ]]; then
    # shellcheck source=lib/logging.sh
    source "$LOGGING_FILE"
else
    pf_supports_color_on_fd() {
        local fd

        fd="$1"

        if [[ "${TERM:-}" == "dumb" ]]; then
            return 1
        fi

        if [[ "$fd" -eq 1 ]]; then
            [[ -t 1 ]]
            return $?
        fi

        [[ -t 2 ]]
    }

    pf_stdout_color() {
        local code

        code="$1"

        if pf_supports_color_on_fd 1; then
            printf '\033[%sm' "$code"
        fi
    }

    pf_stderr_color() {
        local code

        code="$1"

        if pf_supports_color_on_fd 2; then
            printf '\033[%sm' "$code"
        fi
    }

    pf_log_section() {
        local title
        local color_reset
        local color_title

        title="$1"
        color_title="$(pf_stdout_color '1;34')"
        color_reset="$(pf_stdout_color '0')"

        printf '\n%s==>%s %s\n' "$color_title" "$color_reset" "$title"
    }

    pf_log_info() {
        local message
        local color_reset
        local color_label

        message="$1"
        color_label="$(pf_stdout_color '1;36')"
        color_reset="$(pf_stdout_color '0')"

        printf '%s[INFO]%s %s\n' "$color_label" "$color_reset" "$message"
    }

    pf_log_success() {
        local message
        local color_reset
        local color_label

        message="$1"
        color_label="$(pf_stdout_color '1;32')"
        color_reset="$(pf_stdout_color '0')"

        printf '%s[OK]%s %s\n' "$color_label" "$color_reset" "$message"
    }

    pf_log_warning() {
        local message
        local color_reset
        local color_label

        message="$1"
        color_label="$(pf_stderr_color '1;33')"
        color_reset="$(pf_stderr_color '0')"

        printf '%s[WARN]%s %s\n' "$color_label" "$color_reset" "$message" >&2
    }

    pf_log_error() {
        local message
        local color_reset
        local color_label

        message="$1"
        color_label="$(pf_stderr_color '1;31')"
        color_reset="$(pf_stderr_color '0')"

        printf '%s[ERR ]%s %s\n' "$color_label" "$color_reset" "$message" >&2
    }

    pf_log_list_item() {
        local message

        message="$1"

        printf '  - %s\n' "$message"
    }
fi

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

    pf_log_section "Hostname"
    pf_log_info "Current hostname: $current_hostname"
    read -rp "Enter new hostname (leave empty to ignore): " POP_FEDORA_HOSTNAME

    POP_FEDORA_HOSTNAME_PROMPTED="1"
    export POP_FEDORA_HOSTNAME
    export POP_FEDORA_HOSTNAME_PROMPTED
}

set_new_hostname() {
    if [[ -z "$POP_FEDORA_HOSTNAME" ]]; then
        return 0
    fi

    pf_log_section "Hostname"
    pf_log_info "Setting hostname to $POP_FEDORA_HOSTNAME"
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
        pf_log_error "Git user.name and user.email must be provided in an interactive shell when they are not already set."
        return 1
    fi

    if [[ -z "$existing_git_user_name" || -z "$existing_git_user_email" ]]; then
        pf_log_section "Git Configuration"
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

    pf_log_section "Bootstrap"
    pf_log_info "Bootstrapping jtomaspm/pop-fedora@main"
    wget -qO "$archive_path" "$REPO_ARCHIVE_URL"
    tar -xzf "$archive_path" -C "$TEMP_DIR"

    extracted_dir="$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

    if [[ -z "$extracted_dir" ]]; then
        pf_log_error "Failed to extract the repository archive."
        return 1
    fi

    REPO_ROOT="$extracted_dir"
    LIB_DIR="$REPO_ROOT/lib"

    if [[ ! -f "$REPO_ROOT/install.sh" || ! -d "$LIB_DIR" ]]; then
        pf_log_error "Failed to prepare a temporary checkout of the repository."
        return 1
    fi
}

collect_steps() {
    mapfile -t STEPS < <(find "$LIB_DIR" -maxdepth 1 -type f -name '*.sh' | sort)

    if [[ "${#STEPS[@]}" -eq 0 ]]; then
        pf_log_error "No installer steps were found in $LIB_DIR"
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

    pf_log_section "Privileges"
    pf_log_info "Authenticating sudo access"
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

    pf_log_section "Step [$step_number]"
    pf_log_info "$step_name"
    if [[ "$EUID" -eq 0 ]]; then
        bash "$step_file"
        return 0
    fi

    sudo --preserve-env=POP_FEDORA_REPO_ROOT,POP_FEDORA_LIB_DIR,POP_FEDORA_STEP_FILE,POP_FEDORA_STEP_NAME,POP_FEDORA_STEP_NUMBER,POP_FEDORA_GIT_USER_NAME,POP_FEDORA_GIT_USER_EMAIL \
        bash "$step_file"
}

print_summary() {
    local entry

    pf_log_section "Summary"

    if [[ "${#RUN_STEPS[@]}" -eq 0 ]]; then
        pf_log_info "Ran: none"
    else
        pf_log_info "Completed steps:"
        for entry in "${RUN_STEPS[@]}"; do
            pf_log_list_item "$entry"
        done
    fi

    if [[ -n "$FAILED_STEP" ]]; then
        pf_log_error "Failed: $FAILED_STEP"
        return 0
    fi

    pf_log_success "All requested steps completed."
}

main() {
    local step_file
    local step_number
    local step_description
    local exit_code

    trap cleanup EXIT
    prompt_for_hostname
    prompt_for_git_config

    pf_log_section "Repository"
    if REPO_ROOT="$(resolve_repo_root)"; then
        LIB_DIR="$REPO_ROOT/lib"
        pf_log_info "Using local checkout at $REPO_ROOT"
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
            pf_log_success "Completed [$step_number] $step_description"
        else
            exit_code=$?
            FAILED_STEP="[$step_number] $step_description"
            pf_log_error "Step failed: $FAILED_STEP"
            print_summary
            return "$exit_code"
        fi
    done

    print_summary
}

main "$@"
