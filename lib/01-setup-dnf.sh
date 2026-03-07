#!/usr/bin/env bash
set -euo pipefail

config_dir="/etc/dnf/libdnf5.conf.d"
config_file="$config_dir/420-pop.conf"

write_dnf_config() {
    mkdir -p "$config_dir"

    tee "$config_file" > /dev/null <<'EOF'
[main]
defaultyes=True
fastestmirror=True
max_parallel_downloads=10
EOF
}

show_dnf_config() {
    echo "Created $config_file"
    echo
    echo "Contents:"
    cat "$config_file"
}

# ---------- libdnf5 configuration ----------
write_dnf_config
show_dnf_config

# ---------- System updates ----------
dnf update -y
dnf upgrade -y
