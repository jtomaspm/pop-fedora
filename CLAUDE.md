# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of Bash scripts for setting up a fresh Fedora installation. Running `install.sh` either bootstraps from GitHub or runs locally, then executes each numbered step in `lib/` in order.

## Running

```bash
# Run locally
bash install.sh

# Run from GitHub (bootstraps into a temp dir, then cleans up)
bash <(wget -qO- https://raw.githubusercontent.com/jtomaspm/pop-fedora/main/install.sh)
```

There are no tests, build steps, or linters.

## Architecture

- `install.sh` — entry point. Detects whether it's running from a local checkout or needs to bootstrap from GitHub (downloads archive, extracts to temp dir, re-execs). Collects `lib/*.sh` sorted by name and runs each in order. Steps run under `sudo` (preserving the `POP_FEDORA_*` env vars) unless already root.
- `lib/NN-step-name.sh` — numbered steps executed in sort order. Each is a standalone Bash script. The installer exports these env vars for steps to use:
  - `POP_FEDORA_REPO_ROOT` — repo root path
  - `POP_FEDORA_LIB_DIR` — lib directory path
  - `POP_FEDORA_STEP_FILE`, `POP_FEDORA_STEP_NAME`, `POP_FEDORA_STEP_NUMBER`

## Current steps

| File | Purpose |
|------|---------|
| `01-setup-dnf.sh` | Configures libdnf5 (fastest mirror, parallel downloads), runs `dnf update/upgrade` |
| `02-install-basic-tools.sh` | Enables RPM Fusion free/nonfree, installs core CLI tools (git, curl, neovim, fzf, rg, gh, etc.) |
| `03-setup-timeshift.sh` | Installs Timeshift, configures rsync snapshots with 5 daily backups, and creates an initial snapshot when none exists |
| `04-install-drivers.sh` | Runs fwupd firmware updates, installs multimedia codecs (ffmpeg, GStreamer) |
| `05-setup-flatpak.sh` | Adds Flathub remotes (system + user), installs Gear Lever |
| `06-install-software.sh` | Installs dev runtimes (Rust, Go, Node, Python, .NET), removes Firefox, installs Zen Browser via Flatpak, installs Docker Desktop |
| `07-install-config.sh` | Placeholder |
| `08-install-themes.sh` | Placeholder |
| `09-setup-accounts.sh` | Placeholder |

## Conventions

- All scripts use `set -euo pipefail`.
- New steps: add a file named `NN-description-with-dashes.sh` in `lib/`. The number determines execution order. Empty/placeholder files are shown as `(placeholder)` in the installer output.
- Steps that may partially fail (like fwupd when no updates exist) use local `set +e` / `set -e` guards around those commands.
