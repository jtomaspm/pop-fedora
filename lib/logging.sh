if [[ -z "${POP_FEDORA_LOGGING_SH:-}" ]]; then
    POP_FEDORA_LOGGING_SH=1
    readonly POP_FEDORA_LOGGING_SH

    pf_color() {
        local code

        code="$1"

        printf '\033[%sm' "$code"
    }

    pf_stdout_color() {
        local code

        code="$1"

        pf_color "$code"
    }

    pf_stderr_color() {
        local code

        code="$1"

        pf_color "$code"
    }

    pf_log_section() {
        local title
        local color_reset
        local color_title

        title="$1"
        color_title="$(pf_stdout_color '1;34')"
        color_reset="$(pf_stdout_color '0')"

        printf '\n%s📍 SECTION%s %s\n' "$color_title" "$color_reset" "$title"
    }

    pf_log_info() {
        local message
        local color_reset
        local color_label

        message="$1"
        color_label="$(pf_stdout_color '1;36')"
        color_reset="$(pf_stdout_color '0')"

        printf '%sℹ️  INFO%s %s\n' "$color_label" "$color_reset" "$message"
    }

    pf_log_success() {
        local message
        local color_reset
        local color_label

        message="$1"
        color_label="$(pf_stdout_color '1;32')"
        color_reset="$(pf_stdout_color '0')"

        printf '%s✅ OK%s %s\n' "$color_label" "$color_reset" "$message"
    }

    pf_log_warning() {
        local message
        local color_reset
        local color_label

        message="$1"
        color_label="$(pf_stderr_color '1;33')"
        color_reset="$(pf_stderr_color '0')"

        printf '%s⚠️  WARN%s %s\n' "$color_label" "$color_reset" "$message" >&2
    }

    pf_log_error() {
        local message
        local color_reset
        local color_label

        message="$1"
        color_label="$(pf_stderr_color '1;31')"
        color_reset="$(pf_stderr_color '0')"

        printf '%s❌ ERROR%s %s\n' "$color_label" "$color_reset" "$message" >&2
    }

    pf_log_list_item() {
        local message
        local color_bullet
        local color_reset

        message="$1"
        color_bullet="$(pf_stdout_color '1;35')"
        color_reset="$(pf_stdout_color '0')"

        printf '  %s🔹%s %s\n' "$color_bullet" "$color_reset" "$message"
    }
fi
