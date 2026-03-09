# pop-fedora

> [!IMPORTANT]
> **Quick install**
>
> Run directly from GitHub:
>
> ```
> bash <(wget -qO- https://raw.githubusercontent.com/jtomaspm/pop-fedora/main/install.sh)
> ```
>
> Run from a local checkout:
>
> ```
> bash install.sh
> ```
>
> Run only selected phases:
>
> ```
> bash install.sh --steps 01 05 07
> ```

Fedora is a strong base system, but a fresh install still leaves a lot of work if your goal is to turn it into a serious machine for coding, containers, media playback, local AI, and PC gaming. `pop-fedora` is an opinionated Fedora bootstrapper that takes that clean base and pushes it toward a more complete daily-driver setup for developers and gamers without pretending to be a brand new distro.

If you like Fedora itself, but you do not want to spend your first evening re-enabling codecs, hunting down the right repositories, fixing GPU media support, installing a terminal and editor stack, setting up Docker, layering gaming tools, and then rebuilding your GNOME workflow from scratch, this repo is meant to do that work for you.

## Why use this instead of hopping to another distro? 🎯

The pitch here is simple: keep Fedora, remove setup drag.

- You stay on top of Fedora instead of moving to a different base with its own packaging decisions and maintenance tradeoffs.
- You get a curated developer-and-gaming setup in one pass instead of rebuilding the same environment by hand after every reinstall.
- You keep the flexibility of a normal Fedora workstation instead of locking yourself into an immutable image or a highly customized spin.
- You still know exactly what changed, because every change lives in plain Bash and local config files.

This project is not a magical "better Fedora" image. It is a reproducible set of installer phases that reshape a stock Fedora workstation into something closer to the machine many people actually want to use every day.

## What this changes on a default Fedora install

The installer runs numbered scripts in order, so the resulting system is not just "Fedora plus apps". It changes package management behavior, adds repositories, refreshes firmware, installs multimedia support, configures developer tooling, replaces parts of the default desktop workflow, and drops opinionated user config into your home directory.

### 1. Package management is made more aggressive and less manual

The first phase writes a custom `libdnf5` config under `/etc/dnf/libdnf5.conf.d/420-pop.conf`. That changes three defaults:

- package installs assume "yes" by default
- the fastest mirror is preferred
- DNF is allowed to parallelize downloads up to 10 at a time

After that, the installer performs a full metadata refresh and updates the system. The point is to start from a current Fedora state before the rest of the software stack is layered on top.

### 2. Fedora gets the extra repositories a gaming/dev machine usually needs

The bootstrapper enables more than the standard Fedora repositories.

- RPM Fusion Free and Nonfree are added so the system can pull in codecs, gaming packages, and proprietary driver components that are outside the stock Fedora defaults.
- Terra is added as an extra package source.
- Later phases add dedicated repositories for GitHub CLI, Visual Studio Code, and Docker.
- Flathub is registered as a system Flatpak remote.

This matters because a stock Fedora install is intentionally conservative. A machine aimed at games, media, container workflows, and mainstream desktop apps often needs broader software sources.

### 3. Firmware, codecs, and graphics/media support are handled early

The driver phase starts by refreshing firmware metadata with `fwupdmgr`, listing devices, checking for updates, and applying firmware updates when available. That is an unusually practical choice for a workstation bootstrapper because it treats hardware readiness as part of setup, not as a separate cleanup task after the fact.

The same phase also installs multimedia support in a more complete way than the default workstation image:

- the `multimedia` group is installed
- Fedora's `ffmpeg-free` package is swapped for the full `ffmpeg`
- the multimedia group is upgraded without weak dependencies
- the `sound-and-video` group is installed

That means the system is explicitly moved toward full playback and media support instead of relying on Fedora's more limited defaults.

### 4. GPU behavior is adjusted based on detected hardware

The installer actively detects CPU vendor, display adapters, and Secure Boot state before it decides what to do.

For NVIDIA systems:

- it looks for supported GeForce models in an explicit allowlist
- if Secure Boot is enabled, it skips proprietary NVIDIA installation instead of risking a broken graphics stack
- if supported NVIDIA hardware is found and Secure Boot is not blocking the install, it installs `akmod-nvidia` and CUDA-related NVIDIA driver packages
- it rebuilds kernel modules with `akmods` and regenerates the initramfs with `dracut`
- if the NVIDIA card is outside the allowlist, it leaves Nouveau in place on purpose

For Intel systems:

- Fedora's `libva-intel-media-driver` package is swapped for `intel-media-driver`
- `libva-intel-driver` is installed alongside it

For AMD systems:

- `mesa-va-drivers` is swapped to `mesa-va-drivers-freeworld`
- `mesa-vdpau-drivers` is swapped to `mesa-vdpau-drivers-freeworld`
- the same replacement is attempted for installed multilib variants when they exist

This is one of the biggest reasons the project is useful for gaming and media users: it does more than install generic packages. It tries to move the machine toward better real-world playback, acceleration, and GPU support depending on what hardware Fedora is running on.

## Software that gets installed

The software footprint is intentionally broad. This is not a tiny dotfiles repo. It installs a full workstation stack.

### Core command-line and system tools

The installer brings in:

- `git`
- `curl`
- `wget`
- `tree`
- `fzf`
- `rg`
- `neovim`
- `fastfetch`
- `unzip`
- `tar`
- `xz`
- `dnf5-plugins`
- `dnf-plugins-core`

This establishes a sane baseline for shell work, package management, file search, and editor bootstrapping.

### Development tooling

For development, the repo installs:

- `zsh`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- `rust`
- `cargo`
- `dotnet-sdk-10.0`
- `nodejs`
- `npm`
- `python3`
- `pip3`
- `golang`
- `gh`
- `code` (Visual Studio Code)

This gives you a cross-language workstation out of the box instead of a machine that only feels complete after several manual setup passes.

### Container and local AI tooling

The bootstrapper installs and configures:

- Docker Engine packages
- Docker Buildx
- Docker Compose plugin
- Docker Desktop for Fedora/RHEL-compatible systems
- Ollama
- `@openai/codex` as a global npm package
- `opencode-ai` as a global npm package
- Claude Code via Anthropic's install script

Docker is not just installed. The Docker service is enabled, `containerd` is enabled, a `docker` group is ensured, and the non-root target user is added to that group when possible.

Ollama is installed system-wide, and if the `ollama` group exists the target user is added to it so local model usage does not stay trapped behind root-only access.

### Gaming and desktop software

The desktop and gaming phase installs:

- Steam
- Lutris
- Fragments
- `remote-viewer`
- `nautilus-python`
- `gnome-tweaks`
- Ghostty

Through Flatpak, it also installs:

- Zen Browser
- Stremio
- GNOME Extension Manager
- ProtonPlus
- ONLYOFFICE Desktop Editors
- Ente Auth
- Gear Lever

That makes the machine more usable both as a gaming desktop and as a general personal workstation. You are not left on a sparse workstation image with only the default Fedora app selection.

### Media and compatibility packages

The installer adds:

- `openh264`
- `gstreamer1-plugin-openh264`
- `mozilla-openh264`
- `fuse-libs`
- Flatseal

It also explicitly enables the Fedora Cisco OpenH264 repository option. This is another example of the project pushing Fedora toward a more practical desktop setup for normal users who expect media playback and app compatibility to work without post-install archaeology.

### Fonts

Two Nerd Font families are installed system-wide:

- Cascadia Mono Nerd Font
- Cascadia Code Nerd Font

The installer removes old files from those target font directories before reinstalling the archives, then refreshes the font cache. That gives the terminal and editor stack a consistent icon-capable font foundation.

## Software that gets removed or replaced

`pop-fedora` does not only add packages. It also strips out a few default choices.

It removes:

- Firefox
- Ptyxis
- LibreOffice Writer
- LibreOffice Calc
- LibreOffice Impress
- LibreOffice Core

The intent is clear from the rest of the install:

- Zen Browser replaces Firefox as the browser choice
- Ghostty replaces Fedora's default terminal choice
- ONLYOFFICE replaces the default LibreOffice office stack

After removals, the installer runs `dnf autoremove`, clears caches, and refreshes packages again so the system does not keep unnecessary leftovers around.

## Configuration that gets applied

This repo is not only an app installer. It also makes a lot of opinionated configuration changes.

### Git configuration

At startup, the installer prompts for `user.name` and `user.email` if they are not already present in global Git config. It then writes those values and also sets `pull.rebase` to `false`.

That means the machine is not only ready to clone repositories. It is immediately ready to make commits with a usable global identity.

### Shell and session behavior

The target user's default shell is changed to Zsh if it is not already Zsh.

The config install phase then creates:

- `~/.config/shell`
- `~/.config/ghostty`
- `~/.config/scripts`
- `~/.config/nvim`

It installs the following files from the repo:

- `config/zsh/.zshrc` to `~/.zshrc`
- `config/shell/profile` to `~/.config/shell/profile`
- `config/ghostty/config` to `~/.config/ghostty/config`
- the full `config/nvim` tree to `~/.config/nvim`

It also ensures that `~/.bashrc` sources `~/.config/shell/profile`, so the shared shell environment is not exclusive to Zsh.

The shared shell profile does four important things:

- sets `EDITOR` to Neovim
- sets `TERM` and `TERMINAL` to Ghostty
- moves config, data, and cache handling onto XDG-style paths
- prepends `~/.config/scripts` and `~/.local/bin` to `PATH`

That gives both Bash and Zsh a consistent environment and makes the installed tools feel like part of one stack instead of disconnected packages.

### Zsh configuration

The shipped `.zshrc` is not minimal. It turns Zsh into a more interactive daily shell.

It enables:

- completion menus with selection support
- colored completion output
- case-insensitive completion and glob matching
- automatic directory jumping with `autocd`
- automatic slash insertion on completed directories
- shared, append-only shell history across sessions
- comment support in interactive shell input
- fzf's Zsh integration
- a custom multi-line prompt
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

It also explicitly undefines terminal flow control on `Ctrl+S`, which avoids the classic "terminal froze" behavior that still catches people when using shells heavily.

### Ghostty configuration

Ghostty is configured to use `CaskaydiaMono Nerd Font`, and the terminal type is set to `xterm-256color`.

The bundled config also adds terminal workflow shortcuts:

- `Ctrl+T` opens a new tab
- `Ctrl+S` splits to the right
- `Ctrl+A` splits downward
- `Ctrl+H`, `Ctrl+J`, `Ctrl+K`, and `Ctrl+L` move between splits
- `Ctrl+W` closes the active surface

So Ghostty is not merely installed as an alternative terminal. It becomes a keyboard-first terminal workspace.

### Neovim configuration

The Neovim tree under `config/nvim` sets up a modern Lua-based configuration bootstrapped by `lazy.nvim`. It is opinionated, but still readable enough that you can extend it yourself.

At the editor level it enables:

- spaces instead of tabs
- four-space indentation defaults
- line numbers
- mouse support
- system clipboard integration
- undo persistence
- smart case-sensitive searching
- always-on sign column
- split-right and split-below behavior
- cursorline
- generous scroll offset
- yank highlighting

Keybindings are defined for:

- leader key on space
- opening Netrw with `<leader>e`
- clearing search highlight with `Esc`
- opening diagnostics list with `<leader>q`
- leaving terminal mode with double `Esc`
- moving between windows with `Ctrl+H/J/K/L`

The active plugin set focuses on editor usability rather than sheer plugin count.

It installs and configures:

- OneDark as the color theme, with italic comments disabled
- `nvim-highlight-colors` for inline color previews
- `guess-indent` for indentation detection
- `gitsigns` for Git gutter signs
- Telescope for fuzzy finding, project search, buffer switching, and config file search
- `lazydev` to improve Lua development for Neovim config itself
- `nvim-lspconfig` with Mason tooling and Lua language server setup
- `conform.nvim` for formatting, with format-on-save behavior and Lua formatting through `stylua`
- `blink.cmp` plus LuaSnip for completion and snippets
- `todo-comments` for visible TODO and note markers
- `mini.nvim` modules for text objects, surround editing, and a simple statusline
- Treesitter for syntax-aware highlighting and indentation
- `nvim-dap` and `nvim-dap-ui` for debugging

The LSP layer is currently geared toward Lua out of the box, not every language listed in the system package install. That is important to say clearly: the machine is ready for many ecosystems, but the shipped Neovim LSP defaults are still focused and relatively small.

Treesitter is set to ensure parsers for:

- Bash
- C
- Diff
- HTML
- Lua
- Luadoc
- Markdown
- Markdown inline
- Query
- Vim
- Vimdoc

This editor setup is a strong example of the repo's philosophy. It does not try to ship every possible plugin. It creates a practical, clean coding environment that is immediately comfortable for terminal-based development.

### GNOME configuration

The GNOME phase only runs when the target user has an active session bus, which means it is intentionally aimed at a real desktop session rather than blindly writing settings in the dark.

It changes favorites on the dock to:

- Zen Browser
- Nautilus
- Ghostty
- Visual Studio Code
- GNOME Software
- GNOME Settings

It installs the Papirus icon theme using the upstream install script, then sets:

- icon theme to Papirus
- color scheme preference to dark
- accent color to slate

It installs and enables:

- AppIndicator support
- Dash to Dock

Dash to Dock is then customized in detail:

- maximum icon size is set to 42
- trash is hidden
- mounted drives are hidden
- multi-monitor support is enabled
- custom theme shrinking is enabled
- the Show Apps button is kept visible
- the Show Apps button is moved to the top
- apps are kept at the edge
- show delay is reduced
- dock hotkeys and related shortcut arrays are cleared out

The script then attempts to reload GNOME Shell or, if that is not supported in the current session, live-reapply the extension so the settings take effect as cleanly as possible.

Outside the dock, GNOME gets more behavioral changes:

- right mouse button resizing is enabled for windows
- idle dimming is disabled
- low battery can trigger power saver mode
- session idle delay is disabled
- screen lock is disabled
- battery sleep remains a timed suspend after 15 minutes
- AC sleep is disabled

Keyboard shortcuts are also rebuilt around a more keyboard-driven workflow:

- `Super+E` opens Nautilus
- `Super+Return` opens Ghostty
- `Super+Q` is added as a close-window shortcut alongside `Alt+F4`
- `Super+B` is assigned to the web/browser action
- `Super+1` through `Super+0` switch workspaces
- `Super+Shift+1` through `Super+Shift+0` move windows to workspaces
- `Super+A` and `Super+S` are added as workspace navigation shortcuts alongside the default left/right workspace bindings
- `Super+W` toggles GNOME overview

This means the desktop result is not "Fedora with a few extra packages". It becomes a more customized GNOME workstation with a dock-first workflow, keyboard shortcuts for common actions, and fewer stock friction points.

## Flatpak setup

Flatpak is treated as part of the normal software story, not as an optional afterthought.

The installer:

- adds Flathub as a system remote
- installs `fuse-libs` and Flatseal
- installs Gear Lever as an initial Flatpak-oriented utility
- later installs the broader desktop app set from Flathub

That split is useful because it establishes Flatpak support early and then uses it for apps that make sense to keep decoupled from the RPM layer.

## Service and system behavior changes

Several less flashy but meaningful system-level changes also happen:

- `NetworkManager-wait-online.service` is disabled
- Docker is enabled to start automatically
- `containerd` is enabled
- the installer keeps a sudo session alive once authenticated
- the installer can prompt for hostname and change it with `hostnamectl`
- a reboot prompt appears at the end of a successful run

These are the sorts of changes that make the machine feel "finished" after setup instead of technically installed but still awkward in everyday use.

## What lives in `config/`

The `config/` directory is the repo's user-environment payload.

- `config/shell/profile` defines shared shell environment defaults
- `config/zsh/.zshrc` turns Zsh into the main interactive shell
- `config/ghostty/config` shapes the default terminal experience
- `config/nvim/` provides the full Neovim setup

If you want to understand the exact user-facing environment this repo creates, `config/` matters just as much as the package-install steps.

## What this does not try to be

`pop-fedora` is not:

- a Fedora spin
- an immutable image
- a universal hardware abstraction layer
- a no-op dotfiles repo

It is an opinionated workstation bootstrapper. It assumes you want Fedora, but you want it to land much closer to "ready to build things and play games" on day one.

It also does not hide the fact that some areas are still unfinished. The `08-setup-accounts` phase is currently a placeholder, and account-level setup beyond the current user-focused flow is intentionally limited.

## What to expect when you run it

When you launch the installer, it may:

- ask for a new hostname
- ask for Git name and email if they are missing
- request sudo authentication
- run step scripts in numeric order
- skip user-session desktop actions if no active desktop session exists
- recommend a reboot after completion

That makes it friendly to interactive use on a real Fedora workstation, but it is still best treated as a machine-shaping installer. Read it before you run it.

## Best fit

This repo makes the most sense if you want:

- Fedora as your base
- a stronger out-of-the-box developer terminal/editor setup
- better gaming and multimedia readiness
- Docker, modern CLI tooling, and local AI tooling installed early
- a more customized GNOME desktop without hand-tuning every setting yourself

If that sounds like the machine you wanted Fedora to be after the first several hours of setup, that is exactly the gap `pop-fedora` is trying to close. 🚀
