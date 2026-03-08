# AGENTS.md

Agent guide for working in `pop-fedora`.

## Repo Purpose
This repo is a Bash-based Fedora workstation bootstrapper.
`install.sh` runs locally or bootstraps a temporary checkout from GitHub, then executes `steps/*.sh` in numeric order.
Most scripts mutate a real Fedora system.

## Layout
- `install.sh` - main entry point, bootstrap logic, argument parsing, sudo handling, summary output.
- `lib/logging.sh` - shared logging helpers.
- `steps/NN-name.sh` - numbered installer phases executed in lexical order.
- `README.md` - short user-facing instructions.
- `CLAUDE.md` - older agent guidance; use this file as the current source of truth.
- Current steps: `01-setup-dnf`, `02-install-basic-tools`, `03-install-drivers`, `04-setup-flatpak`, `05-install-software`, `06-install-config` (placeholder), `07-configure-gnome-shell`, `08-setup-accounts` (placeholder).

## External Rule Files
- No `.cursorrules` file was found.
- No files were found under `.cursor/rules/`.
- No `.github/copilot-instructions.md` file was found.
- Do not assume any additional Cursor or Copilot policy beyond this file and the repository contents.

## Build, Lint, And Test Commands
There is no build system, no formal test suite, and no repo-configured linter.

Main execution:

```bash
# Run locally
bash install.sh

# Run from GitHub bootstrap
bash <(wget -qO- https://raw.githubusercontent.com/jtomaspm/pop-fedora/main/install.sh)

# Run selected steps
bash install.sh --steps 01 05 07

# Closest thing to a single test: run one step
bash install.sh --steps 07
```

Fast validation:

```bash
# Syntax-check one script
bash -n install.sh
bash -n steps/05-install-software.sh

# Syntax-check everything
for file in install.sh lib/*.sh steps/*.sh; do
  bash -n "$file"
done

# Optional linting if shellcheck is installed
shellcheck install.sh lib/*.sh steps/*.sh
shellcheck steps/07-configure-gnome-shell.sh
```

Testing guidance:
- No unit or integration tests are checked in.
- `bash -n` on changed files is the safest automated validation.
- The most realistic behavioral check is running only the affected step with `--steps` on a disposable Fedora VM or machine.
- Avoid full installer runs on a developer workstation unless the user explicitly wants to modify that machine.

## Safety Expectations
Assume commands may install or remove packages, change GNOME settings, alter shells or groups, enable services, and change system configuration.
- Prefer syntax validation first.
- Prefer targeted step execution over full runs.
- Use a Fedora VM for behavior checks when possible.
- Avoid introducing new interactive flows unless the installer already depends on them.

## Architecture Notes
- `install.sh` exports `POP_FEDORA_REPO_ROOT`, `POP_FEDORA_LIB_DIR`, `POP_FEDORA_STEPS_DIR`, `POP_FEDORA_STEP_FILE`, `POP_FEDORA_STEP_NAME`, and `POP_FEDORA_STEP_NUMBER`.
- Git prompts feed `POP_FEDORA_GIT_USER_NAME` and `POP_FEDORA_GIT_USER_EMAIL` into later steps.
- Step ordering comes entirely from the numeric filename prefix.
- Empty step files are treated as placeholders in the summary output.
- Reuse `lib/logging.sh` instead of inventing new output styles.

## Bash Style Guide

### Preamble And Imports
- Executable scripts should start with `#!/usr/bin/env bash`.
- Use `set -euo pipefail` at the top of installer and step scripts.
- Source shared helpers near the top of the file.
- Keep the existing fallback pattern when sourcing `logging.sh`.
- Add a `shellcheck source=...` comment when it helps static analysis.

Example:

```bash
# shellcheck source=../lib/logging.sh
source "${POP_FEDORA_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd -P)}/logging.sh"
```

### Formatting
- Match the existing style: 4-space indentation inside functions and control blocks.
- Put opening braces on the same line as function declarations.
- Use blank lines to separate logical sections.
- Prefer readable multi-line commands over dense one-liners.
- Align long argument lists vertically when readability improves.

### Variables, Types, And Naming
- Use lowercase `snake_case` for local variables and function names.
- Use uppercase only for exported environment variables and true global constants.
- Declare function-scoped variables with `local`.
- Use `readonly` for constants such as URLs and guard flags.
- Use arrays for path lists, command fragments, and step collections.
- Use associative arrays only when lookup semantics materially help.
- Preserve the `pf_` prefix for shared logging helpers.
- Preserve the `POP_FEDORA_` prefix for exported installer variables.
- Step filenames should follow `NN-description-with-dashes.sh`.
- Function names should be action-oriented, such as `configure_git` or `install_docker`.

### Quoting And Expansion
- Quote expansions by default: `"$var"`.
- Use `"${array[@]}"` when passing array items as separate arguments.
- Prefer `$(...)` over backticks.
- Avoid unquoted word splitting unless it is deliberate and clearly safe.
- Use braces for clarity in mixed parameter expansion.

### Functions And Flow
- Prefer small, named functions over long linear scripts.
- Let the top-level flow read like a checklist of high-level actions.
- Keep reusable helpers above the execution section.
- Return early for no-op or skip cases.
- Keep each step focused on one setup concern.

### Error Handling
- Default to fail-fast behavior via `set -euo pipefail`.
- For best-effort probing, use a narrow `set +e` / `set -e` block or an explicit guarded command.
- When failure is expected and non-fatal, log a clear warning or info message describing the fallback.
- Use `if ! command; then` when custom handling is needed.
- Do not swallow errors silently.

### Logging And User Output
- Use `pf_log_section` for major phases.
- Use `pf_log_info` for progress and state.
- Use `pf_log_success` for completed actions.
- Use `pf_log_warning` for recoverable issues.
- Use `pf_log_error` before returning non-zero on hard failures.
- Keep messages specific to the system change being made.

### Idempotency And Privilege Boundaries
- Prefer idempotent commands such as `mkdir -p`, `flatpak ... --if-not-exists`, and state checks before mutating the system.
- Assume scripts may be re-run on partially configured machines.
- `install.sh` manages sudo escalation; do not duplicate broad privilege handling in every step.
- When a step must act as the original desktop user, follow the existing `SUDO_USER` patterns.
- Preserve environment carefully when crossing into a DBus session.
- Be explicit about whether a command must run as root or as the invoking non-root user.

### Comments And Documentation
- Keep comments sparse and useful.
- Comment non-obvious constraints, external quirks, or safety notes.
- Do not restate what straightforward commands already make obvious.
- Update `README.md` only when user-facing behavior changes.

## Change Guidance
- Prefer minimal, targeted changes over broad refactors.
- Do not add a new step unless the change is truly a new installer phase.
- If you add a new step, choose the numeric prefix intentionally because it controls execution order.
- Move logic into `lib/` only when it is clearly shared or inherently reusable.
- Keep placeholder steps empty when they are only future slots.

## Recommended Agent Workflow
1. Read `install.sh` and any affected step scripts first.
2. Make the smallest change that fits the current architecture.
3. Run `bash -n` on every changed script.
4. If behavior must be exercised, run only the affected step on a disposable Fedora environment.
5. Summarize the system-level impact of the change in the final response.
6. Create a commit explaining what was changed in the message
