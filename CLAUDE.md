# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of interactive Bash scripts for setting up a fresh Fedora installation. Running `install.sh` either bootstraps from GitHub or runs locally, then walks through each numbered step in `lib/` with a run/skip prompt.

## Running

```bash
# Run locally
bash install.sh

# Run from GitHub (bootstraps into a temp dir, then cleans up)
bash <(wget -qO- https://raw.githubusercontent.com/jtomaspm/pop-fedora/main/install.sh)
```

There are no tests, build steps, or linters.

## Architecture

- `install.sh` — entry point. Detects whether it's running from a local checkout or needs to bootstrap. Collects `lib/*.sh` files sorted by name, prompts run/skip for each, executes them in order, prints a summary.
- `lib/NN-step-name.sh` — numbered steps executed in sort order. Each is a standalone Bash script. The installer exports these env vars for steps to use:
  - `POP_FEDORA_REPO_ROOT` — repo root path
  - `POP_FEDORA_LIB_DIR` — lib directory path
  - `POP_FEDORA_STEP_FILE`, `POP_FEDORA_STEP_NAME`, `POP_FEDORA_STEP_NUMBER`

## Current steps

| File | Purpose |
|------|---------|
| `01-setup-dnf.sh` | Configures libdnf5 (fastest mirror, parallel downloads), runs `dnf update/upgrade` |
| `02-install-basic-tools.sh` | Enables RPM Fusion free/nonfree, installs core CLI tools (git, curl, neovim, fzf, rg, gh, etc.) |
| `03-install-drivers.sh` | Runs fwupd firmware updates, installs multimedia codecs (ffmpeg, GStreamer) |
| `04-setup-flatpak.sh` | Adds Flathub remotes (system + user), installs Gear Lever |
| `05-install-software.sh` | Placeholder |
| `06-install-config.sh` | Placeholder |
| `07-install-themes.sh` | Placeholder |

## Conventions

- All scripts use `set -euo pipefail`.
- New steps: add a file named `NN-description-with-dashes.sh` in `lib/`. The number determines execution order. Empty/placeholder files are shown as `(placeholder)` in the prompt.
- Steps that may partially fail (like fwupd when no updates exist) use local `set +e` / `set -e` guards around those commands.
