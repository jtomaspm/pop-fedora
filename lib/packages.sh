if [[ -z "${POP_FEDORA_PACKAGES_SH:-}" ]]; then
    POP_FEDORA_PACKAGES_SH=1
    readonly POP_FEDORA_PACKAGES_SH

    pf_dnf_refresh_system() {
        dnf update -y
        dnf upgrade -y
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

        flatpak install --system -y "$remote_name" "$@"
    }
fi
