# mygobust — thin wrapper for Gobuster

This function standardizes **dir**, **vhost**, and **dns** modes, auto-picks sensible wordlists, tags outputs, and writes timestamped results.

## Install

```bash
# copy files
cp gobust.sh ~/bin/  # or any path you source in your shell

# source it in your shell (bash/zsh)
source ~/bin/gobust.sh
# or add to ~/.bashrc / ~/.zshrc:
#   [ -f ~/bin/gobust.sh ] && source ~/bin/gobust.sh
```

## Defaults
- Threads: `GB_THREADS=50`
- HTTP User-Agent (dir/vhost only): `GB_AGENT="Gobuster/Autopilot"`
- TLS: `GB_INSECURE_TLS=1` (adds `-k` for HTTPS)
- Status allowlist (dir/vhost): **unset by default**. If you set `GB_STATUS`, the wrapper auto-clears the blacklist with `-b ""` to avoid conflicts.
- Wordlists:
  - dir: tries `$GOBUSTER_WORDLIST`, `~/.wordlists/*`, then common SecLists paths
  - dns/vhost: tries `$GOBUSTER_DNS_WORDLIST`, then SecLists DNS lists

Outputs are written as:
```
gobuster.<mode>-<tag>.<YYYYMMDD-HHMMSS>.txt
gobuster.<mode>-<tag>.<YYYYMMDD-HHMMSS>.json   # when supported
```

---

## Quick Start Examples

### Directory / Content discovery
```bash
mygobust http://artificial.htb/            # default mode=dir, tag=artificial.htb
mygobust http://10.10.10.10 web01 dir
GB_EXT=php,txt mygobust https://target.local/ dir -q
```

**With an allowlist of status codes (auto-disables blacklist):**
```bash
GB_STATUS="200,204,301,302,307,401,403" mygobust http://artificial.htb/ dir
```

**Follow redirects / ignore TLS:**
```bash
GB_FOLLOW_REDIRECTS=1 GB_INSECURE_TLS=1 mygobust https://internal/ dir
```

**Dry run (print command only):**
```bash
DRY_RUN=1 mygobust http://artificial.htb/ dir -x php,html,txt
```

### Virtual host fuzzing
```bash
# Usually point -u at an IP or base URL; the wordlist is treated as Host: candidates
mygobust http://10.10.10.10 vhost
mygobust http://10.10.10.10 corp vhost -q
# Custom vhost list
GOBUSTER_DNS_WORDLIST=~/lists/my-vhosts.txt mygobust http://10.10.10.10 vhost
```

### DNS subdomain brute force
```bash
mygobust artificial.htb dns
GB_DNS_RESOLVERS="1.1.1.1,8.8.8.8" mygobust artificial.htb dns
GB_DNS_WILDCARD_OK=1 mygobust artificial.htb dns
```

### Tagging
```bash
mygobust http://target/ redteam dir          # tag=redteam
mygobust http://10.10.10.10 vhost            # tag derived from host
```

### Passing extra Gobuster flags
Anything after the first 1–3 args is forwarded verbatim:
```bash
# add extensions + quiet
mygobust http://target/ dir -x php,js,txt -q

# change HTTP method
mygobust http://target/ dir -m HEAD
```

---

## Tips & Notes

- If you set `GB_STATUS`, the wrapper appends `--status-codes-blacklist ""` to prevent the classic Gobuster clash (`-s` with default blacklist).
- `dns` mode **does not** pass `-a` (User-Agent), because Gobuster’s DNS module doesn’t support it.
- For vhost scans, low-noise, lowercase wordlists work best.
- You can override any automatically-added flag by passing your own version in the “extra args” position.

---

## Example session

```bash
$ mygobust http://artificial.htb/ dir
ℹ Using wordlist: /usr/share/seclists/Discovery/Web-Content/common.txt
▶▶▶ Gobuster dir on http://artificial.htb/ (tag:artificial.htb)
Command:
  gobuster dir -u http://artificial.htb/ -w /usr/share/seclists/Discovery/Web-Content/common.txt -t 50 -a Gobuster/Autopilot -o gobuster.dir-artificial.htb.20251102-120000.txt -z -k
...
✅ Output: gobuster.dir-artificial.htb.20251102-120000.txt
```

---

## Uninstall
Remove the `source` line from your shell rc and delete `gobust.sh`.
