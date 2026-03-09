#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"
# shellcheck source=../lib/packages.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/packages.sh"

cpu_vendor="unknown"
secure_boot_state="unknown"
has_intel_gpu=0
has_amd_gpu=0
has_nvidia_gpu=0
has_supported_nvidia_gpu=0

declare -a detected_gpu_descriptions=()
declare -a detected_nvidia_devices=()
declare -a unsupported_nvidia_devices=()

readonly POP_FEDORA_NVIDIA_MODULE_WAIT_TIMEOUT_SECONDS=300
readonly POP_FEDORA_NVIDIA_MODULE_WAIT_INTERVAL_SECONDS=5

refresh_firmware_commands() {
    pf_retry_command fwupdmgr refresh --force
    fwupdmgr get-devices
    pf_retry_command_allowing_exit_codes "0 2" fwupdmgr get-updates
    pf_retry_command fwupdmgr update
}

refresh_firmware() {
    pf_run_best_effort refresh_firmware_commands
}

install_multimedia_support() {
    pf_retry_command dnf4 group install multimedia -y
    pf_retry_command dnf swap 'ffmpeg-free' 'ffmpeg' --allowerasing -y
    pf_retry_command dnf upgrade @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y
    pf_retry_command dnf group install -y sound-and-video
}

ensure_hardware_detection_tools() {
    local -a packages

    packages=()

    if ! command -v lspci >/dev/null 2>&1; then
        packages+=(pciutils)
    fi

    if ! command -v mokutil >/dev/null 2>&1; then
        packages+=(mokutil)
    fi

    if (( ${#packages[@]} == 0 )); then
        return 0
    fi

    pf_retry_command dnf install -y "${packages[@]}"
}

trim_leading_whitespace() {
    local value

    value="$1"
    value="${value#"${value%%[![:space:]]*}"}"

    printf '%s\n' "$value"
}

detect_cpu_vendor() {
    local detected_vendor

    detected_vendor=""

    if ! command -v lscpu >/dev/null 2>&1; then
        return 0
    fi

    detected_vendor="$(
        lscpu | awk -F: '
            $1 == "Vendor ID" {
                gsub(/^[[:space:]]+/, "", $2)
                print $2
                exit
            }
        '
    )"

    if [[ -n "$detected_vendor" ]]; then
        cpu_vendor="$detected_vendor"
    fi
}

process_display_adapter_record() {
    local device
    local gpu_description
    local slot
    local vendor

    slot="$1"
    vendor="$2"
    device="$3"

    gpu_description="$slot $vendor $device"
    detected_gpu_descriptions+=("$gpu_description")

    case "$vendor" in
        *NVIDIA*)
            has_nvidia_gpu=1
            detected_nvidia_devices+=("$device")
            ;;
        *Intel*)
            has_intel_gpu=1
            ;;
        *AMD*|*ATI*)
            has_amd_gpu=1
            ;;
    esac
}

detect_graphics_hardware() {
    local current_class
    local current_device
    local current_slot
    local current_vendor
    local key
    local lspci_output
    local line
    local value

    current_class=""
    current_device=""
    current_slot=""
    current_vendor=""

    if ! command -v lspci >/dev/null 2>&1; then
        pf_log_warning "lspci is not available; skipping hardware-specific driver detection."
        return 0
    fi

    if ! lspci_output="$(lspci -vmm -nn 2>/dev/null)"; then
        pf_log_warning "Failed to query PCI hardware with lspci; skipping hardware-specific driver detection."
        return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "$line" ]]; then
            case "$current_class" in
                VGA\ compatible\ controller*|3D\ controller*|Display\ controller*)
                    process_display_adapter_record "$current_slot" "$current_vendor" "$current_device"
                    ;;
            esac

            current_class=""
            current_device=""
            current_slot=""
            current_vendor=""
            continue
        fi

        key="${line%%:*}"
        value="$(trim_leading_whitespace "${line#*:}")"

        case "$key" in
            Slot)
                current_slot="$value"
                ;;
            Class)
                current_class="$value"
                ;;
            Vendor)
                current_vendor="$value"
                ;;
            Device)
                current_device="$value"
                ;;
        esac
    done <<< "$lspci_output"

    case "$current_class" in
        VGA\ compatible\ controller*|3D\ controller*|Display\ controller*)
            process_display_adapter_record "$current_slot" "$current_vendor" "$current_device"
            ;;
    esac
}

nvidia_device_is_supported() {
    local device

    device="$1"

    [[ "$device" =~ (GeForce[[:space:]]+)?RTX[[:space:]]+(20|30|40|50)[0-9]{2} ]] && return 0
    [[ "$device" =~ (GeForce[[:space:]]+)?GTX[[:space:]]+(6|7|8|9)[0-9]{2} ]] && return 0
    [[ "$device" =~ (GeForce[[:space:]]+)?GTX[[:space:]]+10[0-9]{2} ]] && return 0
    [[ "$device" =~ (GeForce[[:space:]]+)?GTX[[:space:]]+16[0-9]{2} ]] && return 0
    [[ "$device" =~ (GeForce[[:space:]]+)?GT[[:space:]]+(6|7|8|9)[0-9]{2} ]] && return 0

    return 1
}

classify_nvidia_hardware() {
    local device

    if (( has_nvidia_gpu == 0 )); then
        return 0
    fi

    for device in "${detected_nvidia_devices[@]}"; do
        if nvidia_device_is_supported "$device"; then
            has_supported_nvidia_gpu=1
            continue
        fi

        unsupported_nvidia_devices+=("$device")
    done

    if (( ${#unsupported_nvidia_devices[@]} > 0 )); then
        has_supported_nvidia_gpu=0
    fi
}

detect_secure_boot_state() {
    local mokutil_output

    secure_boot_state="unknown"

    if ! command -v mokutil >/dev/null 2>&1; then
        pf_log_warning "mokutil is not available; NVIDIA Secure Boot checks will be skipped."
        return 0
    fi

    if ! mokutil_output="$(mokutil --sb-state 2>/dev/null)"; then
        pf_log_warning "Failed to read Secure Boot state with mokutil."
        return 0
    fi

    if [[ "$mokutil_output" =~ [Ss]ecure[Bb]oot[[:space:]]+enabled ]]; then
        secure_boot_state="enabled"
        return 0
    fi

    if [[ "$mokutil_output" =~ [Ss]ecure[Bb]oot[[:space:]]+disabled ]]; then
        secure_boot_state="disabled"
        return 0
    fi
}

log_detected_hardware() {
    local gpu_description

    pf_log_info "CPU vendor: $cpu_vendor"

    if (( ${#detected_gpu_descriptions[@]} == 0 )); then
        pf_log_warning "No display adapters were detected with lspci."
        return 0
    fi

    pf_log_info "Detected display adapters:"

    for gpu_description in "${detected_gpu_descriptions[@]}"; do
        pf_log_list_item "$gpu_description"
    done
}

install_nvidia_drivers() {
    pf_retry_command dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
}

nvidia_kernel_module_is_available() {
    local kernel_version
    local module_pattern

    kernel_version="$1"
    module_pattern="/usr/lib/modules/$kernel_version/extra/nvidia.ko*"

    if modinfo -k "$kernel_version" -F version nvidia >/dev/null 2>&1; then
        return 0
    fi

    if compgen -G "$module_pattern" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

prepare_nvidia_kernel_module() {
    pf_log_info "Rebuilding the NVIDIA kernel module with akmods."
    pf_retry_command akmods --force --rebuild

    pf_log_info "Regenerating initramfs with the rebuilt NVIDIA module."
    pf_retry_command dracut --force
}

handle_nvidia_drivers() {
    if (( has_nvidia_gpu == 0 )); then
        pf_log_info "No NVIDIA display adapters detected."
        return 0
    fi

    classify_nvidia_hardware

    if (( ${#unsupported_nvidia_devices[@]} > 0 )); then
        pf_log_warning "Detected NVIDIA hardware outside the supported allowlist. Leaving Nouveau in place."
        for gpu_description in "${unsupported_nvidia_devices[@]}"; do
            pf_log_list_item "$gpu_description"
        done
        return 0
    fi

    if (( has_supported_nvidia_gpu == 0 )); then
        pf_log_warning "Detected NVIDIA hardware, but no supported models matched the allowlist. Leaving Nouveau in place."
        return 0
    fi

    detect_secure_boot_state

    if [[ "$secure_boot_state" == "enabled" ]]; then
        pf_log_warning "Secure Boot is enabled. Skipping proprietary NVIDIA drivers until Secure Boot is disabled or MOK enrollment is completed."
        return 0
    fi

    if [[ "$secure_boot_state" == "unknown" ]]; then
        pf_log_warning "Secure Boot state could not be determined. Skipping proprietary NVIDIA drivers to avoid a broken setup."
        return 0
    fi

    install_nvidia_drivers
    prepare_nvidia_kernel_module
}

install_intel_media_drivers() {
    pf_retry_command dnf swap libva-intel-media-driver intel-media-driver --allowerasing -y
    pf_retry_command dnf install libva-intel-driver -y
}

handle_intel_drivers() {
    if (( has_intel_gpu == 0 )); then
        pf_log_info "No Intel display adapters detected."
        return 0
    fi

    install_intel_media_drivers
}

swap_multilib_driver_if_installed() {
    local installed_package
    local replacement_package

    installed_package="$1"
    replacement_package="$2"

    if ! rpm -q "$installed_package" >/dev/null 2>&1; then
        pf_log_info "$installed_package is not installed; skipping the multilib swap."
        return 0
    fi

    pf_retry_command dnf swap "$installed_package" "$replacement_package" -y
}

install_amd_media_drivers() {
    pf_retry_command dnf swap mesa-va-drivers mesa-va-drivers-freeworld -y
    pf_retry_command dnf swap mesa-vdpau-drivers mesa-vdpau-drivers-freeworld -y
    swap_multilib_driver_if_installed mesa-va-drivers.i686 mesa-va-drivers-freeworld.i686
    swap_multilib_driver_if_installed mesa-vdpau-drivers.i686 mesa-vdpau-drivers-freeworld.i686
}

handle_amd_drivers() {
    if (( has_amd_gpu == 0 )); then
        pf_log_info "No AMD display adapters detected."
        return 0
    fi

    install_amd_media_drivers
}

pf_log_section "Refresh Firmware"
refresh_firmware

pf_log_section "Install Multimedia Drivers and Codecs"
install_multimedia_support

pf_log_section "Detect Hardware"
ensure_hardware_detection_tools
detect_cpu_vendor
detect_graphics_hardware
log_detected_hardware

pf_log_section "Install NVIDIA Drivers"
handle_nvidia_drivers

pf_log_section "Install Intel Media Drivers"
handle_intel_drivers

pf_log_section "Install AMD Media Drivers"
handle_amd_drivers
