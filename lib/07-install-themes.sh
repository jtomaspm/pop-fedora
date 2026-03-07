#!/usr/bin/env bash
set -euo pipefail

gsettings set org.gnome.shell favorite-apps "[
'app.zen_browser.zen.desktop',
'org.gnome.Nautilus.desktop',
'com.mitchellh.ghostty.desktop',
'code.desktop',
'org.gnome.Software.desktop'
]"