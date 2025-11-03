# myffuf — thin wrapper for ffuf

`myffuf` streamlines ffuf usage for three common cases: **dir**, **vhost**, and **dns** (HTTP-based).
It auto-picks wordlists, sets sane defaults, tags output files, and captures both JSON and a readable TXT log.

## Install
```bash
cp ffuf.sh ~/bin/
source ~/bin/ffuf.sh
# Add to ~/.bashrc or ~/.zshrc for persistence
```

## Defaults (override via env)
- Threads: `FF_THREADS=50`
- Agent header: `FF_AGENT="FFUF/Autopilot"`
- Follow redirects: `FF_FOLLOW_REDIRECTS=0` (use `1` to enable `-r`)
- Ignore TLS issues: `FF_INSECURE_TLS=1` (adds `-k`)
- Timeout: `FF_TIMEOUT=10`
- Rate limit (req/s): `FF_RATE` unset by default
- Status filtering:
  - **Default**: blacklist 404 via `-fc 404`
  - If you set `FF_MATCH_CODES`, the wrapper adds `-mc` and skips the default `-fc`
- Wordlists: tries `$FF_WORDLIST` / `$FF_DNS_WORDLIST`, then common SecLists paths

Outputs:
```
ffuf.<mode>-<tag>.<YYYYMMDD-HHMMSS>.txt   # console output via tee
ffuf.<mode>-<tag>.<YYYYMMDD-HHMMSS>.json  # ffuf -of json -o ...
```

## Modes & Examples

### dir — content discovery
If `FUZZ` is missing in the URL, the wrapper auto-appends `/FUZZ`.

```bash
myffuf http://target/                 # -> http://target/FUZZ
myffuf http://target/path/ web dir
FF_EXT=php,txt myffuf https://target/ dir
FF_MATCH_CODES=200,302 myffuf http://target/ dir
DRY_RUN=1 myffuf http://target/ dir -e js,php -v
```

### vhost — virtual hosts via Host header
Point `-u` at the base URL/IP and fuzz `Host: FUZZ.<domain>`.
Set `FF_VHOST_DOMAIN` if the tag/target isn't a domain.

```bash
# Base is an IP, domain is provided
FF_VHOST_DOMAIN=example.htb myffuf http://10.10.10.10 vhost

# Base already a URL; tag becomes the domain automatically if it looks like one
myffuf http://10.10.10.10 example.htb vhost
```

### dns — HTTP subdomain probing
HTTP-based check using `http://FUZZ.<domain>/` (not raw DNS).

```bash
myffuf example.htb dns
FF_MATCH_CODES=200,301 myffuf corp.local dns -s
```

> For raw DNS brute force (no HTTP), use `gobuster dns`, `puredns`, or `massdns`.

## Passing extra ffuf flags
Everything after the first 1–3 args is forwarded verbatim:
```bash
# Filter sizes and words
myffuf http://target/ dir -fs 0 -fw 0

# Verbose, color
myffuf http://target/ dir -v -c
```

## Tips
- You can override any automatically added option by passing your own (`-mc`, `-fc`, `-H`, etc.).
- For vhost, lowercase wordlists reduce noise. Consider validating with `curl -H "Host: …"` on a few hits.
- Combine with Nmap findings to prioritize services/paths per host.
