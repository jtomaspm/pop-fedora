#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/etc/dnf/libdnf5.conf.d"
CONFIG_FILE="$CONFIG_DIR/420-pop.conf"

mkdir -p "$CONFIG_DIR"

tee "$CONFIG_FILE" > /dev/null <<'EOF'
[main]
defaultyes=True
fastestmirror=True
max_parallel_downloads=10
EOF

echo "Created $CONFIG_FILE"
echo
echo "Contents:"
cat "$CONFIG_FILE"

dnf update -y
dnf upgrade -y
