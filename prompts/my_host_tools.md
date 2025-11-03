Build a small Bash helper file called `hosts_tools.sh` with two functions — `my_add_host()` and `my_del_host()` — plus a short README delivered as a ZIP. Keep things simple, safe, and user-friendly.

## What I want (big picture) Often will get you very close. 💣
- Two Bash functions that help me *add* and *remove* entries in `/etc/hosts`.
- Both functions should be sourceable (this file is meant to be `source`d, not executed).
- All writes to `/etc/hosts` should be done safely (use `sudo tee` or write to a temp file then `sudo tee` it back). No risky redirections.
- Use clear, friendly output with small icons (✅ ⚠ ❌ 🗂 🔎) so it’s obvious what happened.

## Deliverables
1) In chat: a single Bash code block containing only the two function definitions.
2) As an attachment: a ZIP named `hosts_tools_readme.zip` that contains one file: `README.md` explaining how to install and use these functions. Don’t print the README inline.

## Function 1: `my_add_host`
A tiny helper to append (or replace) an entry.

- **Usage**
  - `my_add_host <IP> <hostname> [domain=htb]`
  - `my_add_host -r <IP> <hostname> [domain=htb]` (or `--replace`) to remove any existing lines for that IP/host before adding the fresh one.
- **Behavior**
  - Default domain is `htb`. The line added should look like:
    ```
    <IP> <host>.<domain> <host>  # Added by my_add_host YYYY-MM-DD HH:MM:SS
    ```
  - If a matching entry already exists and `-r` wasn’t used, print a gentle warning and exit without changing the file, suggesting the `-r` form.
  - If `-r` is used, first make a timestamped backup of `/etc/hosts` (e.g., `/etc/hosts.bak.YYYYMMDD-HHMMSS`), then remove lines that match the same IP, the FQDN, or the short host before appending the new line.
- **Errors & returns**
  - If required args are missing, print a short usage line and return `2`.
  - Otherwise return `0` on success.

## Function 2: `my_del_host`
A small remover that works with hostname (optionally domain) or IP+hostname.

- **Usage**
  - Hostname only: `my_del_host <hostname> [domain=htb]`
  - With IP: `my_del_host <IP> <hostname> [domain=htb]`
- **Argument handling**
  - 1 arg → treat it as `<hostname>` (domain defaults to `htb`).
  - 2 args → if the first looks like an IP (IPv4 or IPv6), treat as `<IP> <hostname>`; otherwise treat as `<hostname> <domain>`.
  - 3 args → `<IP> <hostname> <domain>`.
  - Anything else → print a short usage message and return `2`.
- **Behavior**
  - Show what you’re about to remove (IP if given, FQDN, short host).
  - Preview matches with a `grep -nE` so the user can see what lines will be touched.
  - Make a timestamped backup of `/etc/hosts`.
  - Filter the file to drop any line that starts with the given IP **or** contains the FQDN as a whole word **or** the short host as a whole word.
  - Write the filtered content back safely (temp file → `sudo tee`).
  - On success, print a short success line and return `0`. On write failure, explain that the backup remains and return `1`.

## Safety notes
- Always write via `sudo tee` (append or overwrite from a temp file). Avoid `sudo echo >>` patterns.
- Keep everything portable Bash (LF line endings, no zsh-only tricks).

## Messages & style
- Use clear, compact messages with icons like:
  - `🗂 Backing up /etc/hosts -> /etc/hosts.bak.20251102-174300`
  - `🔎 Removing entries matching: ...`
  - `✅ Added: <the exact line>`
  - `✅ Removed entries referencing ...`
  - `⚠ Entry already exists... try: my_add_host -r ...`
  - `❌ Failed to update /etc/hosts ...`
- Don’t be verbose; just enough to confirm what happened.

## README (put this in `hosts_tools_readme.zip` as `README.md`)
Write a short, friendly README that covers:
- What the two functions do and that the default domain is `htb`.
- How to install: save `hosts_tools.sh` somewhere (e.g., `~/bin/hosts_tools.sh`) and source it from `~/.bashrc` or `~/.zshrc` (include tiny snippets for both shells), then reload the shell.
- Usage examples for both functions (add, replace, and delete paths).
- Safety notes (backups, `sudo tee`, preview via `grep`).
- A couple of copy-paste one-liners (source file, add entry, delete entry).

## Light acceptance checks
- `bash -n` passes on the function file.
- All writes use safe patterns (no sudo+redirection).
- `my_add_host`:
  - Adds the line with the exact timestamped comment.
  - With `-r`, backs up and removes old matching lines before adding the new one.
  - Without `-r`, warns and exits if an entry already exists.
- `my_del_host`:
  - Parses args as described; backs up, previews, filters, and writes back safely.
  - Returns `0` on success, `1` on write failure, `2` on usage error.
