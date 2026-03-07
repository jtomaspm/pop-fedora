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

pf_log_info "Setting keyboard shortcuts"

run_user gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-file-manager/']"
run_user gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-file-manager/ name "FileManager"
run_user gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-file-manager/ command "nautilus --new-window"
run_user gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-file-manager/ binding "<Super>e"

run_user gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-terminal/']"
run_user gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-terminal/ name "Terminal"
run_user gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-terminal/ command "ghostty"
run_user gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-terminal/ binding "<Super>Return"

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

