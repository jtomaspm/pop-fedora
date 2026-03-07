# pop-fedora

Interactive Fedora setup scripts.

## Run from GitHub

This command downloads `install.sh` from GitHub, fetches the full repo into a temporary directory, runs the numbered scripts in `steps/` in order, and then removes the temporary checkout:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/jtomaspm/pop-fedora/main/install.sh)
```

## Run locally

```bash
bash install.sh
```

Numbered installer steps live in `steps/`. Shared helpers such as `logging.sh` live in `lib/`.
