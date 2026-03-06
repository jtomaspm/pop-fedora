# pop-fedora

Interactive Fedora setup scripts.

## Run from GitHub

This command downloads `install.sh` from GitHub, fetches the full repo into a temporary directory, runs the numbered scripts in `lib/` with per-step `run` or `skip` prompts, and then removes the temporary checkout:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/jtomaspm/pop-fedora/main/install.sh)
```

## Run locally

```bash
bash install.sh
```

## Bootstrap overrides

If you want to bootstrap from a fork or a different branch, override the defaults before running the command:

```bash
POP_FEDORA_GITHUB_OWNER=your-user POP_FEDORA_GITHUB_REPO=pop-fedora POP_FEDORA_GITHUB_REF=your-branch bash <(wget -qO- https://raw.githubusercontent.com/jtomaspm/pop-fedora/main/install.sh)
```
