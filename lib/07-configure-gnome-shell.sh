#!/usr/bin/env bash
set -euo pipefail

target_user="${SUDO_USER:-}"

if [[ -z "$target_user" || "$target_user" == "root" ]]; then
    echo "Skipping GNOME configuration: no non-root invoking user was detected." >&2
    exit 0
fi

target_uid="$(id -u "$target_user")"
target_runtime_dir="/run/user/$target_uid"
target_bus="$target_runtime_dir/bus"

if [[ ! -S "$target_bus" ]]; then
    echo "Skipping GNOME configuration: no active session bus was found for $target_user." >&2
    exit 0
fi

run_user() {
    sudo -u "$target_user" env \
        XDG_RUNTIME_DIR="$target_runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$target_bus" \
        "$@"
}

# ---------- Dash favorites ----------
run_user gsettings set org.gnome.shell favorite-apps "[
'app.zen_browser.zen.desktop',
'org.gnome.Nautilus.desktop',
'com.mitchellh.ghostty.desktop',
'code.desktop',
'org.gnome.Software.desktop',
'org.gnome.Settings.desktop'
]"

# ---------- Papirus ----------
wget -qO- https://git.io/papirus-icon-theme-install | sh

run_user gsettings set org.gnome.desktop.interface icon-theme 'Papirus'
run_user gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# ---------- AppIndicator extension ----------
EXT="appindicatorsupport@rgcjonas.gmail.com"

if run_user gnome-extensions list | grep -q "$EXT"; then
    echo "Extension $EXT already installed."
else
    echo "Installing $EXT..."
    dnf install -y gnome-shell-extension-appindicator
fi

echo "Enabling $EXT..."
run_user gnome-extensions enable "$EXT"