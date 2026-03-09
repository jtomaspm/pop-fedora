if [[ -z "${POP_FEDORA_PACKAGES_SH:-}" ]]; then
    POP_FEDORA_PACKAGES_SH=1
    readonly POP_FEDORA_PACKAGES_SH
    readonly POP_FEDORA_RETRY_ATTEMPTS_DEFAULT=3
    readonly POP_FEDORA_RETRY_DELAY_SECONDS_DEFAULT=5

    pf_format_command() {
        local formatted_command

        printf -v formatted_command '%q ' "$@"
        printf '%s\n' "${formatted_command% }"
    }

    pf_retry_command() {
        local attempt
        local attempts
        local command_display
        local delay_seconds
        local exit_code

        attempts="${POP_FEDORA_RETRY_ATTEMPTS:-$POP_FEDORA_RETRY_ATTEMPTS_DEFAULT}"
        delay_seconds="${POP_FEDORA_RETRY_DELAY_SECONDS:-$POP_FEDORA_RETRY_DELAY_SECONDS_DEFAULT}"
        attempt=1
        command_display="$(pf_format_command "$@")"

        while true; do
            if "$@"; then
                if (( attempt > 1 )); then
                    pf_log_success "Command succeeded on attempt $attempt/$attempts: $command_display"
                fi

                return 0
            fi

            exit_code=$?

            if (( attempt >= attempts )); then
                pf_log_error "Command failed after $attempts attempt(s): $command_display"
                return "$exit_code"
            fi

            pf_log_warning "Command failed on attempt $attempt/$attempts: $command_display"
            pf_log_info "Retrying in ${delay_seconds}s..."
            sleep "$delay_seconds"
            attempt=$((attempt + 1))
        done
    }

    pf_dnf_refresh_system() {
        pf_retry_command dnf update -y
        pf_retry_command dnf upgrade -y
    }

    pf_run_best_effort() {
        local callback

        callback="$1"
        shift

        set +e
        "$callback" "$@"
        set -e
    }

    pf_flatpak_install_system() {
        local remote_name

        remote_name="$1"
        shift

        pf_retry_command flatpak install --system -y "$remote_name" "$@"
    }

    pf_flatpak_remote_add_system() {
        local remote_name
        local remote_url

        remote_name="$1"
        remote_url="$2"

        pf_retry_command flatpak remote-add --system --if-not-exists "$remote_name" "$remote_url"
    }
fi
