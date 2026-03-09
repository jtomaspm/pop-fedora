#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ARCHIVE_URL="https://github.com/jtomaspm/pop-fedora/archive/refs/heads/main.tar.gz"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

bootstrap_log_section() {
    local title

    title="$1"

    printf '\n==> %s\n' "$title"
}

bootstrap_log_info() {
    local message

    message="$1"

    printf '[INFO] %s\n' "$message"
}

bootstrap_log_error() {
    local message

    message="$1"

    printf '[ERROR] %s\n' "$message" >&2
}

bootstrap_format_command() {
    local formatted_command

    printf -v formatted_command '%q ' "$@"
    printf '%s\n' "${formatted_command% }"
}

bootstrap_retry_command() {
    local attempt
    local attempts
    local command_display
    local delay_seconds
    local exit_code

    attempts=3
    delay_seconds=5
    attempt=1
    command_display="$(bootstrap_format_command "$@")"

    while true; do
        if "$@"; then
            if (( attempt > 1 )); then
                bootstrap_log_info "Command succeeded on attempt $attempt/$attempts: $command_display"
            fi

            return 0
        fi

        exit_code=$?

        if (( attempt >= attempts )); then
            bootstrap_log_error "Command failed after $attempts attempt(s): $command_display"
            return "$exit_code"
        fi

        bootstrap_log_info "Command failed on attempt $attempt/$attempts: $command_display"
        bootstrap_log_info "Retrying in ${delay_seconds}s..."
        sleep "$delay_seconds"
        attempt=$((attempt + 1))
    done
}

REPO_ROOT=""
LIB_DIR=""
STEPS_DIR=""
TEMP_DIR=""
FAILED_STEP=""
KEEPALIVE_PID=""
POP_FEDORA_HOSTNAME="${POP_FEDORA_HOSTNAME:-}"
POP_FEDORA_HOSTNAME_PROMPTED="${POP_FEDORA_HOSTNAME_PROMPTED:-}"
POP_FEDORA_GIT_USER_NAME="${POP_FEDORA_GIT_USER_NAME:-}"
POP_FEDORA_GIT_USER_EMAIL="${POP_FEDORA_GIT_USER_EMAIL:-}"

declare -a STEPS=()
declare -a REQUESTED_STEP_NUMBERS=()
declare -a COMPLETED_STEPS=()
declare -a APPLIED_CHANGES=()

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

    APPLIED_CHANGES+=("[hostname] Set system hostname to $POP_FEDORA_HOSTNAME")
}

git_config_get() {
    local key

    key="$1"
    pf_git_config_get "$key"
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

    if [[ -f "$script_dir/install.sh" && -f "$script_dir/lib/logging.sh" && -d "$script_dir/lib" && -d "$script_dir/steps" ]]; then
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

    bootstrap_log_section "Bootstrap"
    bootstrap_log_info "Bootstrapping jtomaspm/pop-fedora@main"
    bootstrap_retry_command wget -qO "$archive_path" "$REPO_ARCHIVE_URL"
    tar -xzf "$archive_path" -C "$TEMP_DIR"

    extracted_dir="$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

    if [[ -z "$extracted_dir" ]]; then
        bootstrap_log_error "Failed to extract the repository archive."
        return 1
    fi

    REPO_ROOT="$extracted_dir"
    LIB_DIR="$REPO_ROOT/lib"
    STEPS_DIR="$REPO_ROOT/steps"

    if [[ ! -f "$REPO_ROOT/install.sh" || ! -f "$LIB_DIR/logging.sh" || ! -d "$LIB_DIR" || ! -d "$STEPS_DIR" ]]; then
        bootstrap_log_error "Failed to prepare a temporary checkout of the repository."
        return 1
    fi
}

collect_steps() {
    mapfile -t STEPS < <(find "$STEPS_DIR" -maxdepth 1 -type f -name '*.sh' | sort)

    if [[ "${#STEPS[@]}" -eq 0 ]]; then
        pf_log_error "No installer steps were found in $STEPS_DIR"
        return 1
    fi
}

parse_args() {
    local step_flag
    local raw_step

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --steps|-s)
                step_flag="$1"
                shift

                if [[ "$#" -eq 0 ]]; then
                    pf_log_error "$step_flag requires at least one step number."
                    return 1
                fi

                while [[ "$#" -gt 0 ]]; do
                    raw_step="$1"

                    if [[ ! "$raw_step" =~ ^[0-9]+$ ]]; then
                        pf_log_error "Invalid step number: $raw_step"
                        return 1
                    fi

                    REQUESTED_STEP_NUMBERS+=("$(printf '%02d' "$((10#$raw_step))")")
                    shift
                done
                ;;
            *)
                pf_log_error "Unknown argument: $1"
                return 1
                ;;
        esac
    done
}

filter_requested_steps() {
    local step_file
    local step_number
    local missing_steps=()
    local filtered_steps=()
    local requested_step
    local missing_display
    local -A requested_lookup=()
    local -A found_lookup=()

    if [[ "${#REQUESTED_STEP_NUMBERS[@]}" -eq 0 ]]; then
        return 0
    fi

    for requested_step in "${REQUESTED_STEP_NUMBERS[@]}"; do
        requested_lookup["$requested_step"]=1
    done

    for step_file in "${STEPS[@]}"; do
        step_number="$(step_number_from_file "$step_file")"
        if [[ -n "${requested_lookup[$step_number]:-}" ]]; then
            filtered_steps+=("$step_file")
            found_lookup["$step_number"]=1
        fi
    done

    for requested_step in "${REQUESTED_STEP_NUMBERS[@]}"; do
        if [[ -z "${found_lookup[$requested_step]:-}" ]]; then
            missing_steps+=("$requested_step")
        fi
    done

    if [[ "${#missing_steps[@]}" -gt 0 ]]; then
        printf -v missing_display '%s ' "${missing_steps[@]}"
        pf_log_error "Unknown step number(s): ${missing_display% }"
        return 1
    fi

    STEPS=("${filtered_steps[@]}")
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
    export POP_FEDORA_STEPS_DIR="$STEPS_DIR"
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

    sudo --preserve-env=POP_FEDORA_REPO_ROOT,POP_FEDORA_LIB_DIR,POP_FEDORA_STEPS_DIR,POP_FEDORA_STEP_FILE,POP_FEDORA_STEP_NAME,POP_FEDORA_STEP_NUMBER,POP_FEDORA_GIT_USER_NAME,POP_FEDORA_GIT_USER_EMAIL \
        bash "$step_file"
}

print_summary() {
    local entry

    pf_log_section "Summary"

    if [[ -n "$FAILED_STEP" ]]; then
        pf_log_error "The installer stopped before finishing all requested steps."
    else
        pf_log_success "The installer has finished running."
    fi

    if [[ "${#APPLIED_CHANGES[@]}" -eq 0 ]]; then
        pf_log_info "Changes applied in this run: none"
    else
        pf_log_info "Changes applied in this run:"
        for entry in "${APPLIED_CHANGES[@]}"; do
            pf_log_list_item "$entry"
        done
    fi

    if [[ "${#COMPLETED_STEPS[@]}" -eq 0 ]]; then
        pf_log_info "Completed steps: none"
    else
        pf_log_info "Completed steps:"
        for entry in "${COMPLETED_STEPS[@]}"; do
            pf_log_list_item "$entry"
        done
    fi

    if [[ -n "$FAILED_STEP" ]]; then
        pf_log_error "Failed step: $FAILED_STEP"
        return 0
    fi

    pf_log_success "All requested steps completed successfully."
}

prompt_for_reboot() {
    local reply

    if [[ ! -t 0 ]]; then
        pf_log_info "Skipping reboot prompt because the installer is not running interactively."
        return 0
    fi

    pf_log_section "Reboot"
    pf_log_info "A reboot is recommended to apply all changes."

    while true; do
        read -r -p "Reboot now? [Y/n]: " reply

        case "$reply" in
            ""|[Yy]|[Yy][Ee][Ss])
                pf_log_info "Rebooting now."
                if [[ "$EUID" -eq 0 ]]; then
                    systemctl reboot
                    return $?
                fi

                sudo systemctl reboot
                return $?
                ;;
            [Nn]|[Nn][Oo])
                pf_log_info "Reboot skipped. Reboot later to apply all changes."
                return 0
                ;;
            *)
                pf_log_warning "Please answer yes or no."
                ;;
        esac
    done
}

main() {
    local step_file
    local step_number
    local step_description
    local exit_code
    local logging_file

    trap cleanup EXIT

    if REPO_ROOT="$(resolve_repo_root)"; then
        LIB_DIR="$REPO_ROOT/lib"
        STEPS_DIR="$REPO_ROOT/steps"
        logging_file="$LIB_DIR/logging.sh"
        # shellcheck source=lib/logging.sh
        source "$logging_file"
        # shellcheck source=lib/git.sh
        source "$LIB_DIR/git.sh"
        pf_log_section "Repository"
        pf_log_info "Using local checkout at $REPO_ROOT"
    else
        prepare_bootstrap_repo
        bash "$REPO_ROOT/install.sh" "$@"
        return $?
    fi

    parse_args "$@"
    collect_steps
    filter_requested_steps
    prompt_for_hostname
    prompt_for_git_config
    ensure_sudo_session
    set_new_hostname

    for step_file in "${STEPS[@]}"; do
        step_number="$(step_number_from_file "$step_file")"
        step_description="$(describe_step "$step_file")"
        if run_step "$step_file"; then
            COMPLETED_STEPS+=("[$step_number] $step_description")
            if [[ -s "$step_file" ]]; then
                APPLIED_CHANGES+=("[$step_number] $step_description")
            fi
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
    prompt_for_reboot
}

main "$@"
