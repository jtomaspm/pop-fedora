#!/usr/bin/env bash
set -euo pipefail

readonly TIMESHIFT_CONFIG="/etc/timeshift.json"
readonly SNAPSHOT_ROOT="/timeshift/snapshots"

require_mount() {
    local mountpoint

    mountpoint="$1"

    if ! findmnt -M "$mountpoint" > /dev/null; then
        echo "Required mount point not found: $mountpoint" >&2
        exit 1
    fi
}

mount_uuid() {
    local mountpoint
    local uuid
    local source

    mountpoint="$1"
    uuid="$(findmnt -no UUID -M "$mountpoint" 2>/dev/null || true)"

    if [[ -n "$uuid" ]]; then
        printf '%s\n' "$uuid"
        return 0
    fi

    source="$(findmnt -no SOURCE -M "$mountpoint" 2>/dev/null || true)"
    if [[ -n "$source" ]]; then
        uuid="$(blkid -s UUID -o value "$source" 2>/dev/null || true)"
    fi

    if [[ -z "$uuid" ]]; then
        echo "Could not determine UUID for mount point: $mountpoint" >&2
        exit 1
    fi

    printf '%s\n' "$uuid"
}

write_config() {
    local backup_device_uuid
    local temp_config

    backup_device_uuid="$1"
    temp_config="$(mktemp)"

    cat > "$temp_config" <<EOF
{
  "backup_device_uuid" : "$backup_device_uuid",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "false",
  "include_btrfs_home" : "false",
  "stop_cron_emails" : "true",
  "schedule_monthly" : "false",
  "schedule_weekly" : "false",
  "schedule_daily" : "true",
  "schedule_hourly" : "false",
  "schedule_boot" : "false",
  "count_monthly" : "2",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_hourly" : "6",
  "count_boot" : "5",
  "snapshot_size" : "0",
  "snapshot_count" : "0",
  "exclude" : [
  ],
  "exclude-apps" : [
  ]
}
EOF

    install -Dm0644 "$temp_config" "$TIMESHIFT_CONFIG"
    rm -f "$temp_config"
}

snapshot_exists() {
    if [[ ! -d "$SNAPSHOT_ROOT" ]]; then
        return 1
    fi

    find "$SNAPSHOT_ROOT" -mindepth 1 -maxdepth 1 -type d | read -r _
}

require_mount /
require_mount /home

root_uuid="$(mount_uuid /)"

dnf install -y timeshift

write_config "$root_uuid"

echo "Configured Timeshift at $TIMESHIFT_CONFIG"

if snapshot_exists; then
    echo "Timeshift snapshot already present. Skipping initial snapshot."
    exit 0
fi

timeshift --create --scripted --yes --rsync --comments "Initial snapshot" --tags D

echo "Created initial Timeshift snapshot."
