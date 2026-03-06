#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ARCHIVE_URL="https://github.com/jtomaspm/pop-fedora/archive/refs/heads/main.tar.gz"

REPO_ROOT=""
LIB_DIR=""
TEMP_DIR=""
FAILED_STEP=""

declare -a STEPS=()
declare -a RUN_STEPS=()
declare -a SKIPPED_STEPS=()

cleanup() {
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

prompt_step_action() {
    local step_number
    local step_description
    local answer

    step_number="$1"
    step_description="$2"

    while true; do
        read -r -p "[$step_number] $step_description: run or skip? [r/s] " answer

        case "${answer,,}" in
            r|run)
                return 0
                ;;
            s|skip)
                return 1
                ;;
            *)
                echo "Enter 'r' to run or 's' to skip."
                ;;
        esac
    done
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

    echo
    echo "Running [$step_number] $step_name"
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

    if [[ "${#SKIPPED_STEPS[@]}" -eq 0 ]]; then
        echo "Skipped: none"
    else
        echo "Skipped:"
        for entry in "${SKIPPED_STEPS[@]}"; do
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

    if REPO_ROOT="$(resolve_repo_root)"; then
        LIB_DIR="$REPO_ROOT/lib"
    else
        prepare_bootstrap_repo
        bash "$REPO_ROOT/install.sh" "$@"
        return $?
    fi

    collect_steps

    for step_file in "${STEPS[@]}"; do
        step_number="$(step_number_from_file "$step_file")"
        step_description="$(describe_step "$step_file")"

        if prompt_step_action "$step_number" "$step_description"; then
            if run_step "$step_file"; then
                RUN_STEPS+=("[$step_number] $step_description")
            else
                exit_code=$?
                FAILED_STEP="[$step_number] $step_description"
                echo "Step failed: $FAILED_STEP" >&2
                print_summary
                return "$exit_code"
            fi
        else
            SKIPPED_STEPS+=("[$step_number] $step_description")
        fi
    done

    print_summary
}

main "$@"
