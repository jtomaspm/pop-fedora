#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"
# shellcheck source=../lib/packages.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/packages.sh"

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
    pf_log_success "Created $config_file"
    pf_log_info "Contents:"
    cat "$config_file"
}

pf_log_section "Configure libdnf5"
write_dnf_config
show_dnf_config

pf_log_section "Update System Packages"
pf_dnf_refresh_system
