#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"
# shellcheck source=../lib/users.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/users.sh"
# shellcheck source=../lib/session.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/session.sh"

if ! target_user="$(pf_user_require_default_or_warn "Skipping GNOME configuration: no non-root invoking user was detected.")"; then
    exit 0
fi

target_bus="$(pf_user_session_bus_path "$target_user")"

if [[ ! -S "$target_bus" ]]; then
    pf_log_warning "Skipping GNOME configuration: no active session bus was found for $target_user."
    exit 0
fi

run_user() {
    pf_run_in_user_session "$target_user" "$@"
}

gnome_shell_extensions_call() {
    local method="$1"
    shift

    # Probe failures are handled by the caller so the installer can continue.
    run_user gdbus call \
        --session \
        --dest org.gnome.Shell \
        --object-path /org/gnome/Shell \
        --method "org.gnome.Shell.Extensions.$method" \
        "$@"
}

extension_is_registered() {
    local extension_uuid="$1"
    local output

    if ! output="$(gnome_shell_extensions_call ListExtensions 2>/dev/null)"; then
        return 1
    fi

    grep -Fq "$extension_uuid" <<<"$output"
}

extension_is_enabled() {
    local extension_uuid="$1"
    local output

    if ! output="$(gnome_shell_extensions_call GetExtensionInfo "$extension_uuid" 2>/dev/null)"; then
        return 1
    fi

    grep -Eq "'state': <1(\\.0+)?>" <<<"$output"
}

wait_for_extension_registration() {
    local extension_uuid="$1"
    local attempt

    # RPM installation can finish before the live GNOME Shell session notices the extension.
    pf_log_info "Waiting for GNOME to detect $extension_uuid..."

    for ((attempt = 1; attempt <= 30; attempt++)); do
        if extension_is_registered "$extension_uuid"; then
            return 0
        fi

        sleep 1
    done

    return 1
}

enable_extension_live() {
    local extension_uuid="$1"
    local output
    local not_registered_warning="Installed $extension_uuid but GNOME Shell did not register it in the current session. It should be available after the next login."
    local enable_failed_warning="Installed $extension_uuid but could not enable it in the current session. It should be available after the next login."

    if extension_is_enabled "$extension_uuid"; then
        pf_log_info "$extension_uuid already enabled"
        return 0
    fi

    if ! wait_for_extension_registration "$extension_uuid"; then
        pf_log_warning "$not_registered_warning"
        return 0
    fi

    if extension_is_enabled "$extension_uuid"; then
        pf_log_info "$extension_uuid already enabled"
        return 0
    fi

    pf_log_info "Enabling $extension_uuid..."

    if ! output="$(gnome_shell_extensions_call EnableExtension "$extension_uuid" 2>/dev/null)"; then
        pf_log_warning "$enable_failed_warning"
        return 0
    fi

    if grep -Fq "true" <<<"$output" || extension_is_enabled "$extension_uuid"; then
        return 0
    fi

    pf_log_warning "$enable_failed_warning"
    return 0
}

configure_custom_keybinding() {
    local keybinding_id="$1"
    local name="$2"
    local command="$3"
    local binding="$4"
    local keybinding_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${keybinding_id}/"
    local keybinding_schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${keybinding_path}"

    run_user gsettings set "$keybinding_schema" name "$name"
    run_user gsettings set "$keybinding_schema" command "$command"
    run_user gsettings set "$keybinding_schema" binding "$binding"
}

readonly CUSTOM_FILE_MANAGER_KEYBINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-file-manager/"
readonly CUSTOM_TERMINAL_KEYBINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-terminal/"

pf_log_section "Configure Dash Favorites"
run_user gsettings set org.gnome.shell favorite-apps "[
'app.zen_browser.zen.desktop',
'org.gnome.Nautilus.desktop',
'com.mitchellh.ghostty.desktop',
'code.desktop',
'org.gnome.Software.desktop',
'org.gnome.Settings.desktop'
]"

pf_log_section "Install Papirus Icon Theme"
wget -qO- https://git.io/papirus-icon-theme-install | sh

run_user gsettings set org.gnome.desktop.interface icon-theme 'Papirus'
run_user gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

pf_log_section "Configure AppIndicator Extension"
EXT="appindicatorsupport@rgcjonas.gmail.com"
dnf install -y gnome-shell-extension-appindicator
enable_extension_live "$EXT"

pf_log_section "Configure Gnome Settings"
run_user gsettings set org.gnome.desktop.wm.preferences resize-with-right-button true

pf_log_info "Applying GNOME power profile"
run_user gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
run_user gsettings set org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery true
run_user gsettings set org.gnome.desktop.session idle-delay 0
run_user gsettings set org.gnome.desktop.screensaver lock-enabled false
run_user gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend'
run_user gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 900
run_user gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
run_user gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0

pf_log_info "Setting keyboard shortcuts"

run_user gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "['${CUSTOM_FILE_MANAGER_KEYBINDING_PATH}', '${CUSTOM_TERMINAL_KEYBINDING_PATH}']"
configure_custom_keybinding "custom-file-manager" "FileManager" "nautilus --new-window" "<Super>e"
configure_custom_keybinding "custom-terminal" "Terminal" "ghostty" "<Super>Return"

run_user gsettings set org.gnome.desktop.wm.keybindings close "['<Super>q', '<Alt>F4']"
run_user gsettings set org.gnome.settings-daemon.plugins.media-keys www "['<Super>b']"

run_user gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-1 "['<Super><Shift>1']"
run_user gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-2 "['<Super><Shift>2']"
run_user gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-3 "['<Super><Shift>3']"
run_user gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-4 "['<Super><Shift>4']"
run_user gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-5 "['<Super><Shift>5']"
run_user gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-6 "['<Super><Shift>6']"
run_user gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-7 "['<Super><Shift>7']"
run_user gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-8 "['<Super><Shift>8']"
run_user gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-9 "['<Super><Shift>9']"
run_user gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-10 "['<Super><Shift>0']"

run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>1']"
run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>2']"
run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>3']"
run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-4 "['<Super>4']"
run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-5 "['<Super>5']"
run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-6 "['<Super>6']"
run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-7 "['<Super>7']"
run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-8 "['<Super>8']"
run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-9 "['<Super>9']"
run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-10 "['<Super>0']"

run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super>Page_Up', '<Super>KP_Prior', '<Super><Alt>Left', '<Control><Alt>Left', '<Super>a']"
run_user gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super>Page_Down', '<Super>KP_Next', '<Super><Alt>Right', '<Control><Alt>Right', '<Super>s']"

run_user gsettings set org.gnome.shell.keybindings toggle-overview "['<Super>w']"
