if [[ -z "${POP_FEDORA_SESSION_SH:-}" ]]; then
    POP_FEDORA_SESSION_SH=1
    readonly POP_FEDORA_SESSION_SH

    pf_user_runtime_dir() {
        local username
        local user_uid

        username="$1"

        user_uid="$(id -u "$username")"
        printf '/run/user/%s\n' "$user_uid"
    }

    pf_user_session_bus_path() {
        local username
        local runtime_dir

        username="$1"
        runtime_dir="$(pf_user_runtime_dir "$username")"

        printf '%s/bus\n' "$runtime_dir"
    }

    pf_run_in_user_session() {
        local username
        local runtime_dir
        local session_bus

        username="$1"
        shift

        runtime_dir="$(pf_user_runtime_dir "$username")"
        session_bus="$(pf_user_session_bus_path "$username")"

        sudo -u "$username" env \
            XDG_RUNTIME_DIR="$runtime_dir" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=$session_bus" \
            "$@"
    }
fi
