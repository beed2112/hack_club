# nmapscan — two‑stage TCP/UDP scanner with pretty HTML output

`nmapscan` is a Bash function that runs a fast SYN discovery, then a targeted "heavy" scan, and (optionally) a UDP flow.  
Outputs are tagged with a **hostname** (or the IP if hostname isn't provided) and the **timestamp**. The function also **auto‑downloads** the `nmap-bootstrap.xsl` stylesheet if it’s missing and uses `xsltproc` to generate a nice HTML report from XML.

## Installation (Bash or Zsh)

1) Save the function file somewhere, e.g. `~/.functions/nmapscan.sh`  
2) **Bash** – add this to your `~/.bashrc` (or `~/.bash_profile`):

```bash
# Autoload all functions from ~/.functions (create dir if needed)
[ -d "$HOME/.functions" ] || mkdir -p "$HOME/.functions"
for f in "$HOME"/.functions/*.sh; do [ -r "$f" ] && . "$f"; done
```

**Zsh** users can add the same loop to `~/.zshrc`.

3) Open a new shell (or `source ~/.bashrc`) and run `type -t nmapscan` to verify it’s loaded.

## Usage

```bash
nmapscan <IP> [hostname] [mode]
```

- **IP** (required): target host, e.g. `10.76.21.12`
- **hostname** (optional): tag for filenames; defaults to the IP if not provided (sanitized to `[A-Za-z0-9._-]`)
- **mode** (optional):
  - `brute`       : TCP flow with brute scripts
  - `udp`         : UDP flow only
  - `all`         : TCP + UDP
  - `all-brute`   : TCP + UDP with brute scripts

### Examples (using the canonical IP `10.76.21.12`)

```bash
# TCP only, no brute
nmapscan 10.76.21.12

# TCP only, tagged with hostname "web01"
nmapscan 10.76.21.12 web01

# TCP+UDP (no brute)
nmapscan 10.76.21.12 web01 all

# TCP with brute
nmapscan 10.76.21.12 web01 brute

# TCP+UDP with brute
nmapscan 10.76.21.12 web01 all-brute

# Force brute with an env var (regardless of mode)
INCLUDE_BRUTE=1 nmapscan 10.76.21.12 web01 all
```

## Output files

Filenames are normalized as:

```
<proto>.<stage>-<tag>.<YYYYMMDD-HHMMSS>.<ext>
```

**TCP artifacts**
- `tcp.discovery-<tag>.<ts>.gnmap`
- `tcp.open_tcp_ports-<tag>.<ts>.{txt,csv}`
- `tcp.heavy-<tag>.<ts>.{nmap,xml,gnmap,html}`

**UDP artifacts**
- `udp.discovery-<tag>.<ts>.gnmap`
- `udp.open_udp_ports-<tag>.<ts>.{txt,csv}`
- `udp.heavy-<tag>.<ts>.{nmap,xml,gnmap,html}`

> Note: The HTML files are generated from XML via `xsltproc` using `~/nmap-bootstrap.xsl`. If the stylesheet is missing, the function will **auto‑download** it (using `wget` or `curl`).

## Dependencies

- `nmap`
- `xsltproc` (for HTML conversion)
- `wget` or `curl` (to auto‑download the XSL if needed)
- `sudo` (if your setup requires root for SYN scans)

### Install xsltproc quickly

- Debian/Ubuntu: `sudo apt update && sudo apt install xsltproc`
- Fedora/RHEL: `sudo dnf install libxslt`
- macOS (Homebrew): `brew install libxslt`

## Tunable env vars

You can tweak behavior without editing the function:

```bash
SYN_MIN_RATE=1000   # pps for stage-1 SYN sweep
SYN_TIMING='-T4'
SYN_RETRIES=2
TCP_TIMING='-T4'
TCP_SCRIPTSET_DEFAULT='default,auth,vuln'  # used unless brute is explicitly enabled
UDP_TOP_PORTS=500
UDP_TIMING='-T4'
UDP_RETRIES=2
HOST_TIMEOUT='2m'
INCLUDE_BRUTE=0     # set to 1 to force brute regardless of mode
DRY_RUN=0           # set to 1 to print commands but not execute
```

## Notes

- `brute` scripts run **only** when explicitly requested (or when `INCLUDE_BRUTE=1`).
- UDP heavy phase runs only if open UDP ports are found in the discovery phase.
- Output directories are the current working directory.
