# Dotfile Function Autoload (bash & zsh)

Load every `*.sh` function file from `~/.functions` automatically in **bash** and **zsh**.

## Quick Install (recommended)

```bash
bash ~/functions-autoload/install.sh
```

What it does:
- Creates `~/.functions/` if missing.
- Installs lightweight loader snippets:
  - `~/.config/shell/bash_functions_loader.sh`
  - `~/.config/shell/zsh_functions_loader.zsh`
- Appends a **single** `source` line (idempotent, with markers) to your `~/.bashrc` and `~/.zshrc`.

> Safe: the installer backs up your rc files once (e.g., `~/.bashrc.bak.autoload-YYYYmmdd-HHMMSS`).

## Manual Install

### 1) Place loader files

```bash
mkdir -p ~/.config/shell
cp loaders/bash_functions_loader.sh ~/.config/shell/
cp loaders/zsh_functions_loader.zsh ~/.config/shell/
```

### 2) Ensure your functions folder exists

```bash
mkdir -p ~/.functions
```

### 3) Add **one** of the following lines to your shell rc files

**bash – `~/.bashrc`**

```bash
# >>> functions-autoload (bash) >>>
[ -f "$HOME/.config/shell/bash_functions_loader.sh" ] && . "$HOME/.config/shell/bash_functions_loader.sh"
# <<< functions-autoload (bash) <<<
```

**zsh – `~/.zshrc`**

```zsh
# >>> functions-autoload (zsh) >>>
[ -f "$HOME/.config/shell/zsh_functions_loader.zsh" ] && source "$HOME/.config/shell/zsh_functions_loader.zsh"
# <<< functions-autoload (zsh) <<<
```

## How it works

- At each shell startup, the loader walks `~/.functions` and `source`s every readable `*.sh` file.
- Filenames are sorted to give you predictable load order (e.g., prefix with numbers: `00-lib.sh`, `10-add_host.sh`).

### Loader guarantees
- **Idempotent**: avoids double-sourcing in the same shell session.
- **Fast**: uses `nullglob`/`NOMATCH` handling to skip when empty.
- **Safe**: ignores non-readable files; won’t error if directory is empty.

## Usage

1. Drop your functions into `~/.functions/*.sh`. Example provided at `examples/add_host_del_host.sh`.
2. Open a new shell, or run in your current shell:  
   **bash** → `source ~/.config/shell/bash_functions_loader.sh`  
   **zsh**  → `source ~/.config/shell/zsh_functions_loader.zsh`
3. List loaded functions:
   - bash: `declare -F | awk '{print $3}' | sort`
   - zsh: `print -l ${(ok)functions} | sort`



## Uninstall

- Remove the three lines between the `functions-autoload` markers from `~/.bashrc` and/or `~/.zshrc`.
- Optionally delete: `~/.config/shell/{bash_functions_loader.sh,zsh_functions_loader.zsh}` and `~/.functions`.

## Troubleshooting

- **Nothing loads**: ensure the loader line exists in your rc and points to the right path; create a new shell.
- **Permission prompt**: some example functions use `sudo` (e.g., editing `/etc/hosts`).
- **Zsh errors about globbing**: the loader sets `null_glob`/`nonomatch` locally to avoid errors on empty directories.

