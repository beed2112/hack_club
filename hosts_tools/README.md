# `hosts-tools` — quick helpers to add/remove /etc/hosts entries

Two Bash functions in one file:
- **add_host** — append (or replace) an /etc/hosts entry, default domain `htb`
- **del_host** — remove entries by hostname (and optional domain) or by IP + hostname

All writes use the `echo | sudo tee` pattern and make timestamped backups when replacing/removing.

---

## Install

1) Save `hosts_tools.sh` somewhere, e.g. `~/bin/hosts_tools.sh`
2) Source it from your shell rc:

**Bash (`~/.bashrc`):**
```bash
[ -f "$HOME/bin/hosts_tools.sh" ] && source "$HOME/bin/hosts_tools.sh"
```

**Zsh (`~/.zshrc`):**
```zsh
[[ -f $HOME/bin/hosts_tools.sh ]] && source $HOME/bin/hosts_tools.sh
```

Reload your shell:
```bash
source ~/.bashrc   # or: source ~/.zshrc
```

---

## add_host

**Usage**
```bash
add_host <IP> <hostname> [domain=htb]
add_host -r <IP> <hostname> [domain=htb]   # replace existing entry, then add
```

**Examples**
```bash
add_host 10.76.21.12 web                # -> 10.76.21.12 web.htb web  # Added by add_host <timestamp>
add_host 10.76.21.12 web lab            # -> 10.76.21.12 web.lab web  # Added by add_host <timestamp>
add_host -r 10.76.21.12 web             # replace then add
```

- Appends a timestamped comment: `# Added by add_host YYYY-MM-DD HH:MM:SS`
- When `-r/--replace` is used, a backup is created: `/etc/hosts.bak.YYYYMMDD-HHMMSS`

---

## del_host

**Usage**
```bash
# hostname-only (domain defaults to htb)
del_host <hostname> [domain=htb]

# explicit IP + host
del_host <IP> <hostname> [domain=htb]
```

**Examples**
```bash
del_host web                 # removes lines containing web.htb or web
del_host web lab             # removes lines containing web.lab or web
del_host 10.76.21.12 web     # removes lines referencing the IP or web.htb/web
```

- Creates a backup: `/etc/hosts.bak.YYYYMMDD-HHMMSS`
- Matches any line with the given IP **or** FQDN **or** short host

---

## Safety & Notes

- Both functions **only append or rewrite via `sudo tee`**, never `sudo echo >>`.
- `del_host` filters into a temp file and then writes back to `/etc/hosts`.
- You can preview current matching lines with:
  ```bash
  sudo grep -nE 'yourhost|your.ip' /etc/hosts
  ```

---

## One-liners (copy/paste)

```bash
# load now
source ~/bin/hosts_tools.sh

# add
add_host 10.76.21.12 web
add_host -r 10.76.21.12 web lab

# delete
del_host web
del_host 10.76.21.12 web
```
