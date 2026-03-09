#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"
# shellcheck source=../lib/packages.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/packages.sh"
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

readonly GNOME_SHELL_SCHEMA="org.gnome.shell"
readonly GNOME_SHELL_BUS_NAME="org.gnome.Shell"
readonly GNOME_SHELL_OBJECT_PATH="/org/gnome/Shell"
readonly GNOME_SHELL_EXTENSIONS_BUS_NAME="org.gnome.Shell.Extensions"
readonly GNOME_SHELL_EXTENSIONS_OBJECT_PATH="/org/gnome/Shell/Extensions"
readonly DASH_TO_DOCK_SCHEMA="org.gnome.shell.extensions.dash-to-dock"
readonly DASH_TO_DOCK_EXTENSION_UUID="dash-to-dock@micxgx.gmail.com"

gnome_shell_call() {
    local method="$1"
    shift

    run_user gdbus call \
        --session \
        --dest "$GNOME_SHELL_BUS_NAME" \
        --object-path "$GNOME_SHELL_OBJECT_PATH" \
        --method "org.gnome.Shell.$method" \
        "$@"
}

gnome_shell_extensions_call() {
    local method="$1"
    shift

    # Probe failures are handled by the caller so the installer can continue.
    run_user gdbus call \
        --session \
        --dest "$GNOME_SHELL_EXTENSIONS_BUS_NAME" \
        --object-path "$GNOME_SHELL_EXTENSIONS_OBJECT_PATH" \
        --method "org.gnome.Shell.Extensions.$method" \
        "$@"
}

shell_service_is_available() {
    run_user gdbus introspect \
        --session \
        --dest "$GNOME_SHELL_BUS_NAME" \
        --object-path "$GNOME_SHELL_OBJECT_PATH" >/dev/null 2>&1
}

shell_extensions_service_is_available() {
    gnome_shell_extensions_call ListExtensions >/dev/null 2>&1
}

extension_is_registered() {
    local extension_uuid="$1"

    gnome_shell_extensions_call GetExtensionInfo "$extension_uuid" >/dev/null 2>&1
}

gsettings_get_string_array_entries() {
    local schema="$1"
    local key="$2"

    run_user gsettings get "$schema" "$key" \
        | sed -E 's/^@as +//' \
        | tr -d '[]' \
        | tr ',' '\n' \
        | sed -E "s/^ *'//; s/' *$//; s/^ *//; s/ *$//" \
        | sed '/^$/d'
}

set_gsettings_string_array() {
    local schema="$1"
    local key="$2"
    local values=("${@:3}")
    local serialized="["
    local value

    for value in "${values[@]}"; do
        if [[ "$serialized" != "[" ]]; then
            serialized+=", "
        fi

        serialized+="'$value'"
    done

    serialized+="]"
    run_user gsettings set "$schema" "$key" "$serialized"
}

string_array_contains_entry() {
    local target_value="$1"
    shift
    local value

    for value in "$@"; do
        if [[ "$value" == "$target_value" ]]; then
            return 0
        fi
    done

    return 1
}

gsettings_string_array_add_unique() {
    local schema="$1"
    local key="$2"
    local target_value="$3"
    local values=()

    mapfile -t values < <(gsettings_get_string_array_entries "$schema" "$key")

    if string_array_contains_entry "$target_value" "${values[@]}"; then
        return 0
    fi

    values+=("$target_value")
    set_gsettings_string_array "$schema" "$key" "${values[@]}"
}

gsettings_string_array_remove() {
    local schema="$1"
    local key="$2"
    local target_value="$3"
    local values=()
    local filtered_values=()
    local value

    mapfile -t values < <(gsettings_get_string_array_entries "$schema" "$key")

    for value in "${values[@]}"; do
        if [[ "$value" != "$target_value" ]]; then
            filtered_values+=("$value")
        fi
    done

    if [[ "${#filtered_values[@]}" -eq "${#values[@]}" ]]; then
        return 0
    fi

    set_gsettings_string_array "$schema" "$key" "${filtered_values[@]}"
}

mark_extension_enabled_in_gsettings() {
    local extension_uuid="$1"

    gsettings_string_array_add_unique "$GNOME_SHELL_SCHEMA" enabled-extensions "$extension_uuid"
    gsettings_string_array_remove "$GNOME_SHELL_SCHEMA" disabled-extensions "$extension_uuid"
}

mark_extension_disabled_in_gsettings() {
    local extension_uuid="$1"

    gsettings_string_array_remove "$GNOME_SHELL_SCHEMA" enabled-extensions "$extension_uuid"
    gsettings_string_array_add_unique "$GNOME_SHELL_SCHEMA" disabled-extensions "$extension_uuid"
}

enable_extension_live() {
    local extension_uuid="$1"
    local service_unavailable_warning="Skipping live enable for $extension_uuid: the GNOME Shell extensions service is not available in the current user session."
    local not_registered_warning="Installed $extension_uuid but GNOME Shell has not registered it in the current session."
    local enable_failed_warning="Installed $extension_uuid but GNOME Shell rejected the live enable request."

    pf_log_info "Enabling $extension_uuid..."

    if ! shell_extensions_service_is_available; then
        pf_log_warning "$service_unavailable_warning"
        return 0
    fi

    if ! extension_is_registered "$extension_uuid"; then
        pf_log_warning "$not_registered_warning"
        return 0
    fi

    if ! gnome_shell_extensions_call EnableExtension "$extension_uuid" >/dev/null 2>&1; then
        pf_log_warning "$enable_failed_warning"
        return 0
    fi

    mark_extension_enabled_in_gsettings "$extension_uuid"

    pf_log_success "Enabled $extension_uuid in the current GNOME session."
    return 0
}

install_and_enable_extension() {
    local section_title="$1"
    local package_name="$2"
    local extension_uuid="$3"

    pf_log_section "$section_title"
    pf_retry_command dnf install -y "$package_name"
    enable_extension_live "$extension_uuid"
}

configure_dash_to_dock() {
    pf_log_section "Configure Dash To Dock"
    run_user gsettings set "$DASH_TO_DOCK_SCHEMA" dash-max-icon-size 42
    run_user gsettings set "$DASH_TO_DOCK_SCHEMA" show-trash false
    run_user gsettings set "$DASH_TO_DOCK_SCHEMA" show-mounts false
    run_user gsettings set "$DASH_TO_DOCK_SCHEMA" multi-monitor true
    run_user gsettings set "$DASH_TO_DOCK_SCHEMA" custom-theme-shrink true
    run_user gsettings set "$DASH_TO_DOCK_SCHEMA" show-show-apps-button true
    run_user gsettings set "$DASH_TO_DOCK_SCHEMA" show-apps-at-top true
    run_user gsettings set "$DASH_TO_DOCK_SCHEMA" show-apps-always-in-the-edge true
    run_user gsettings set "$DASH_TO_DOCK_SCHEMA" show-delay 0.25
}

reapply_extension_live() {
    local extension_uuid="$1"
    local service_unavailable_warning="Skipping live reapply for $extension_uuid: the GNOME Shell extensions service is not available in the current user session."
    local not_registered_warning="Skipping live reapply for $extension_uuid: GNOME Shell has not registered it in the current session."
    local disable_failed_warning="Skipping live reapply for $extension_uuid: GNOME Shell rejected the disable request."
    local enable_failed_warning="Skipping live reapply for $extension_uuid: GNOME Shell rejected the enable request."

    if ! shell_extensions_service_is_available; then
        pf_log_warning "$service_unavailable_warning"
        return 1
    fi

    if ! extension_is_registered "$extension_uuid"; then
        pf_log_warning "$not_registered_warning"
        return 1
    fi

    pf_log_info "Reapplying $extension_uuid in the current GNOME session..."

    if ! gnome_shell_extensions_call DisableExtension "$extension_uuid" >/dev/null 2>&1; then
        pf_log_warning "$disable_failed_warning"
        return 1
    fi

    mark_extension_disabled_in_gsettings "$extension_uuid"

    if ! gnome_shell_extensions_call EnableExtension "$extension_uuid" >/dev/null 2>&1; then
        pf_log_warning "$enable_failed_warning"
        return 1
    fi

    mark_extension_enabled_in_gsettings "$extension_uuid"

    pf_log_success "Reapplied $extension_uuid in the current GNOME session."
    return 0
}

reload_gnome_shell() {
    local reload_output
    local restart_command='Meta.restart("pop-fedora applied GNOME extensions")'
    local service_unavailable_warning="Skipping GNOME Shell reload: the GNOME Shell DBus service is not available in the current user session."
    local restart_failed_warning="GNOME Shell reload was rejected or is unsupported in the current session."
    local restart_fallback_warning="GNOME Shell reload did not complete; falling back to a live Dash to Dock reapply."
    local restart_output_warning="GNOME Shell reload returned an unexpected response; falling back to a live Dash to Dock reapply."
    local reapply_failed_warning="Dash to Dock settings were written, but the extension could not be reapplied live. A logout or manual shell restart may still be required."

    pf_log_section "Reload GNOME Shell"

    if ! shell_service_is_available; then
        pf_log_warning "$service_unavailable_warning"
    else
        if reload_output="$(gnome_shell_call Eval "$restart_command" 2>/dev/null)"; then
            if [[ "$reload_output" == "(true,"* ]]; then
                pf_log_success "Requested GNOME Shell reload."
                return 0
            fi

            pf_log_warning "$restart_output_warning"
        else
            pf_log_warning "$restart_failed_warning"
        fi
    fi

    pf_log_warning "$restart_fallback_warning"

    if reapply_extension_live "$DASH_TO_DOCK_EXTENSION_UUID"; then
        pf_log_success "Dash to Dock settings were reapplied without a full GNOME Shell restart."
        return 0
    fi

    pf_log_warning "$reapply_failed_warning"
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
pf_retry_command bash -lc 'set -euo pipefail; wget -qO- https://git.io/papirus-icon-theme-install | sh'

run_user gsettings set org.gnome.desktop.interface icon-theme 'Papirus'
run_user gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
run_user gsettings set org.gnome.desktop.interface accent-color 'slate'

install_and_enable_extension \
    "Configure AppIndicator Extension" \
    "gnome-shell-extension-appindicator" \
    "appindicatorsupport@rgcjonas.gmail.com"
install_and_enable_extension \
    "Configure Dash to Dock Extension" \
    "gnome-shell-extension-dash-to-dock" \
    "$DASH_TO_DOCK_EXTENSION_UUID"
configure_dash_to_dock
reload_gnome_shell
configure_dash_to_dock

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
