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
