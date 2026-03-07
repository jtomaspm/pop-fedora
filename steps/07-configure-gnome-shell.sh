#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"

target_user="${SUDO_USER:-}"

if [[ -z "$target_user" || "$target_user" == "root" ]]; then
    pf_log_warning "Skipping GNOME configuration: no non-root invoking user was detected."
    exit 0
fi

target_uid="$(id -u "$target_user")"
target_runtime_dir="/run/user/$target_uid"
target_bus="$target_runtime_dir/bus"

if [[ ! -S "$target_bus" ]]; then
    pf_log_warning "Skipping GNOME configuration: no active session bus was found for $target_user."
    exit 0
fi

run_user() {
    sudo -u "$target_user" env \
        XDG_RUNTIME_DIR="$target_runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$target_bus" \
        "$@"
}

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

if run_user gnome-extensions list | grep -q "$EXT"; then
    pf_log_info "Extension $EXT already installed."
else
    pf_log_info "Installing $EXT..."
    dnf install -y gnome-shell-extension-appindicator
fi

pf_log_info "Enabling $EXT..."
run_user gnome-extensions enable "$EXT"


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