if [[ -z "${POP_FEDORA_GIT_SH:-}" ]]; then
    POP_FEDORA_GIT_SH=1
    readonly POP_FEDORA_GIT_SH

    pf_git_config_get() {
        local key

        key="$1"

        if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            sudo -u "$SUDO_USER" git config --global --get "$key" 2>/dev/null || true
            return 0
        fi

        git config --global --get "$key" 2>/dev/null || true
    }

    pf_git_config_set() {
        local key
        local value

        key="$1"
        value="$2"

        if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            sudo -u "$SUDO_USER" git config --global "$key" "$value"
            return 0
        fi

        git config --global "$key" "$value"
    }
fi
