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

    pf_retry_exit_code_is_allowed() {
        local exit_code
        local allowed_exit_code

        exit_code="$1"
        shift

        for allowed_exit_code in "$@"; do
            if [[ "$exit_code" == "$allowed_exit_code" ]]; then
                return 0
            fi
        done

        return 1
    }

    pf_retry_command_allowing_exit_codes() {
        local -a allowed_exit_codes
        local attempt
        local attempts
        local command_display
        local delay_seconds
        local errexit_was_set
        local exit_code

        read -r -a allowed_exit_codes <<< "$1"
        shift

        attempts="${POP_FEDORA_RETRY_ATTEMPTS:-$POP_FEDORA_RETRY_ATTEMPTS_DEFAULT}"
        delay_seconds="${POP_FEDORA_RETRY_DELAY_SECONDS:-$POP_FEDORA_RETRY_DELAY_SECONDS_DEFAULT}"
        attempt=1
        command_display="$(pf_format_command "$@")"

        while true; do
            errexit_was_set=0
            if [[ $- == *e* ]]; then
                errexit_was_set=1
            fi

            set +e
            "$@"
            exit_code=$?
            if (( errexit_was_set )); then
                set -e
            fi

            if pf_retry_exit_code_is_allowed "$exit_code" "${allowed_exit_codes[@]}"; then
                if (( attempt > 1 )); then
                    pf_log_success "Command succeeded on attempt $attempt/$attempts: $command_display"
                fi

                return 0
            fi

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

    pf_retry_command() {
        pf_retry_command_allowing_exit_codes "0" "$@"
    }

    pf_dnf_refresh_system() {
        local attempt
        local attempts
        local delay_seconds
        local -a dnf_command
        local errexit_was_set
        local exit_code

        attempts="${POP_FEDORA_RETRY_ATTEMPTS:-$POP_FEDORA_RETRY_ATTEMPTS_DEFAULT}"
        delay_seconds="${POP_FEDORA_RETRY_DELAY_SECONDS:-$POP_FEDORA_RETRY_DELAY_SECONDS_DEFAULT}"
        attempt=1
        dnf_command=(dnf -y)

        while true; do
            pf_log_info "Refreshing DNF metadata and applying system updates (attempt $attempt/$attempts)"

            errexit_was_set=0
            if [[ $- == *e* ]]; then
                errexit_was_set=1
            fi

            set +e
            "${dnf_command[@]}" clean metadata &&
                "${dnf_command[@]}" makecache --refresh &&
                "${dnf_command[@]}" update &&
                "${dnf_command[@]}" upgrade
            exit_code=$?
            if (( errexit_was_set )); then
                set -e
            fi

            if (( exit_code == 0 )); then
                if (( attempt > 1 )); then
                    pf_log_success "DNF refresh recovered on attempt $attempt/$attempts"
                fi

                return 0
            fi

            if (( attempt >= attempts )); then
                pf_log_error "DNF refresh failed after $attempts attempt(s), even after metadata and cache recovery."
                return 1
            fi

            pf_log_warning "DNF refresh failed on attempt $attempt/$attempts. Cleaning metadata and rebuilding the libdnf5 cache before retrying."

            # Corrupted or stale libdnf5 metadata can survive a normal retry, so clear the cache before trying again.
            "${dnf_command[@]}" clean all || true
            rm -rf /var/cache/libdnf5/* || true

            pf_log_info "Retrying in ${delay_seconds}s..."
            sleep "$delay_seconds"
            attempt=$((attempt + 1))
        done
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
