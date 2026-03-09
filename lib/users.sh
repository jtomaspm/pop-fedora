if [[ -z "${POP_FEDORA_USERS_SH:-}" ]]; then
    POP_FEDORA_USERS_SH=1
    readonly POP_FEDORA_USERS_SH

    pf_user_resolve_default() {
        local target_user

        if [[ "$EUID" -eq 0 ]]; then
            target_user="${SUDO_USER:-}"
        else
            target_user="${USER:-}"
        fi

        if [[ -z "$target_user" || "$target_user" == "root" ]]; then
            return 1
        fi

        printf '%s\n' "$target_user"
    }

    pf_user_resolve_for_action() {
        local target_user

        target_user="${SUDO_USER:-${USER:-}}"

        if [[ -z "$target_user" || "$target_user" == "root" ]]; then
            return 1
        fi

        printf '%s\n' "$target_user"
    }

    pf_user_require_default_or_warn() {
        local warning_message
        local target_user

        warning_message="$1"

        if ! target_user="$(pf_user_resolve_default)"; then
            pf_log_warning "$warning_message"
            return 1
        fi

        printf '%s\n' "$target_user"
    }

    pf_user_require_default_or_error() {
        local error_message
        local target_user

        error_message="$1"

        if ! target_user="$(pf_user_resolve_default)"; then
            pf_log_error "$error_message"
            return 1
        fi

        printf '%s\n' "$target_user"
    }

    pf_user_require_for_action_or_warn() {
        local warning_message
        local target_user

        warning_message="$1"

        if ! target_user="$(pf_user_resolve_for_action)"; then
            pf_log_warning "$warning_message"
            return 1
        fi

        printf '%s\n' "$target_user"
    }

    pf_user_get_passwd_field() {
        local username
        local field_name
        local passwd_entry
        local _account_name
        local _password
        local uid
        local gid
        local _gecos
        local home
        local shell_path

        username="$1"
        field_name="$2"

        if ! passwd_entry="$(getent passwd "$username")"; then
            return 1
        fi

        IFS=':' read -r _account_name _password uid gid _gecos home shell_path <<<"$passwd_entry"

        case "$field_name" in
            uid)
                printf '%s\n' "$uid"
                ;;
            gid)
                printf '%s\n' "$gid"
                ;;
            home)
                printf '%s\n' "$home"
                ;;
            shell)
                printf '%s\n' "$shell_path"
                ;;
            *)
                return 1
                ;;
        esac
    }

    pf_user_get_primary_group() {
        local username
        local gid
        local group_entry
        local group_name
        local _rest

        username="$1"

        if ! gid="$(pf_user_get_passwd_field "$username" gid)"; then
            return 1
        fi

        if ! group_entry="$(getent group "$gid")"; then
            return 1
        fi

        IFS=':' read -r group_name _rest <<<"$group_entry"
        printf '%s\n' "$group_name"
    }

    pf_maybe_chown() {
        local username
        local group_name
        local path

        username="$1"
        group_name="$2"
        path="$3"

        if [[ "$EUID" -eq 0 ]]; then
            chown "$username:$group_name" "$path"
        fi
    }

    pf_maybe_chown_recursive() {
        local username
        local group_name
        local path

        username="$1"
        group_name="$2"
        path="$3"

        if [[ "$EUID" -eq 0 ]]; then
            chown -R "$username:$group_name" "$path"
        fi
    }

    pf_user_add_to_group_if_non_root() {
        local username
        local group_name

        username="$1"
        group_name="$2"

        if [[ -n "$username" && "$username" != "root" ]]; then
            usermod -aG "$group_name" "$username"
        fi
    }
fi
