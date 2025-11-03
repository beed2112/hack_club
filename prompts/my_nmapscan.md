Build a small Bash tool called `nmapscan()` plus a short README that ships in a ZIP. Keep the prose clear and human, but cover the essentials so someone can drop this into their shell and get nice, predictable results.

## What to deliver
1) In chat: one Bash code block defining **only** the `nmapscan()` function (no shebang, no wrapper).
2) As an attachment: a ZIP named `nmapscan_readme.zip` with a single file `README.md` explaining how to install and use it. Don’t print the README inline.

## What `nmapscan()` should do (big picture)  Often will get you very close. 💣
- Be sourced into a shell (e.g., `~/.functions/nmapscan.sh`) and run as:
  - `nmapscan <IP> [mode]`
- Modes:
  - `brute` → normal TCP flow but include brute NSE scripts
  - `udp`   → only do the UDP flow
  - `all`   → run both TCP and UDP (no brute unless explicitly asked or forced)
- Flow overview:
  - **TCP, stage 1**: fast SYN sweep over all ports to discover what’s open.
  - **TCP, stage 2**: if any TCP ports were found, run a detailed scan against just those ports (service/version/NSE, OS guess), then produce a nice HTML report from XML via `xsltproc` + `nmap-bootstrap.xsl`.
  - **UDP**: when requested (mode `udp` or `all`), do a top-ports discovery, then a targeted follow-up on any open UDP ports; also convert XML → HTML if possible.
- Show friendly, compact status lines with icons (`▶▶▶`, `✅`, `⚠`, `✖`, `ℹ`) and print the exact command before each run (use `printf '%q '` style quoting). Show elapsed time as `HH:MM:SS`.

## Inputs, help, and return codes
- If `<IP>` is missing, print: `Usage: nmapscan <IP> [mode: brute|udp|all]` to **stderr** and return `2`.
- If `xsltproc` is not installed, stop **before scanning**, print a short install hint (Debian/Ubuntu, Fedora/RHEL, macOS/Homebrew), and return `127`.
- Otherwise, normal success returns `0`. If any single `nmap` step fails, report it but don’t crash the entire flow—continue when it makes sense.

## Tunable environment variables (simple, sensible defaults)
Let these be overridden by the user’s env, but default to:
- `SYN_MIN_RATE=1000`         # fast SYN sweep rate
- `SYN_TIMING='-T4'`
- `SYN_RETRIES=2`
- `TCP_TIMING='-T4'`
- `TCP_SCRIPTSET_DEFAULT='default,auth,vuln'`
- `UDP_TOP_PORTS=500`
- `UDP_TIMING='-T4'`
- `UDP_RETRIES=2`
- `HOST_TIMEOUT='2m'`
- `INCLUDE_BRUTE` (unset/0 by default; if `1`, force brute scripts on the TCP heavy stage even if mode isn’t `brute`)
- `DRY_RUN=0` (if `1`, print what would run and which files would be written, but don’t execute anything)

## Files and naming
- Timestamp like `YYYYMMDD-HHMMSS` via `date +%Y%m%d-%H%M%S`.
- Base names:
  - `outbase="${ip}.${datepart}"`
  - `tcp_base="${outbase}.tcp"`
  - `udp_base="${outbase}.udp"`
- Write artifacts to the **current directory**:
  - TCP stage 1: `${tcp_base}.discovery.gnmap`
  - Parsed open ports: `${tcp_base}.open_tcp_ports.txt` and `.csv`
  - TCP heavy outputs: `${tcp_base}.heavy.{nmap,gnmap,xml}` and, if possible, `${tcp_base}.heavy.html`
  - UDP counterparts: `${udp_base}.discovery.gnmap`, `${udp_base}.open_udp_ports.{txt,csv}`, `${udp_base}.heavy.{nmap,gnmap,xml,html}`

## Exact command shapes (keep them recognizable)
- TCP stage 1 (fast discovery):
  ```
  sudo nmap -n -sS -p- ${SYN_TIMING} --min-rate "${SYN_MIN_RATE}" --max-retries "${SYN_RETRIES}"     -oG "${tcp_base}.discovery.gnmap" -Pn "${ip}"
  ```
- TCP stage 2 (targeted heavy, only if ports found):
  - Script set:
    - `mode=brute` or `INCLUDE_BRUTE=1` → `default,auth,brute,vuln`
    - otherwise use `TCP_SCRIPTSET_DEFAULT`
  ```
  sudo nmap -n -p "${PORTS}" ${TCP_TIMING} -sT -sV --version-all     --script "${scripts}" -O --osscan-guess -oA "${tcp_base}.heavy" -Pn "${ip}"
  ```
- UDP stage 1 (top ports):
  ```
  sudo nmap -n -sU --top-ports "${UDP_TOP_PORTS}" ${UDP_TIMING} --max-retries "${UDP_RETRIES}"     --host-timeout "${HOST_TIMEOUT}" -oG "${udp_base}.discovery.gnmap" -Pn "${ip}"
  ```
- UDP stage 2 (targeted follow-up, only if ports found):
  ```
  sudo nmap -n -sU -p "${UPORTS}" ${UDP_TIMING} -sV --script "default,vuln"     -oA "${udp_base}.heavy" -Pn "${ip}"
  ```

## Quality-of-life details
- On first run, if `~/nmap-bootstrap.xsl` is missing, try to download it from:
  `https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl`
  using `wget` (preferred) or `curl`. If neither tool exists, warn and continue (you’ll just skip XML→HTML conversion).
- Always show the command you’re about to run.
- If `DRY_RUN=1`, don’t execute anything—just show the commands and the paths that would be written.

## Parsing ports (simple and robust)
- From each `*.discovery.gnmap`, extract the `Ports:` section, split by commas, keep entries where the second field is `open`, pull the port number (first field), trim whitespace, and write a **unique, numeric-sorted** list. Also write a CSV on one line for the heavy scan.

## Examples people will try
- `nmapscan 10.76.21.12`
- `nmapscan 10.76.21.12 brute`
- `nmapscan 10.76.21.12 udp`
- `DRY_RUN=1 nmapscan 10.76.21.12 all`

## README (put in `nmapscan_readme.zip` as `README.md`)
Make a short, friendly doc with:
- **Overview** of the two-stage scan and the HTML conversion using `xsltproc` + `nmap-bootstrap.xsl`.
- **Installation (Bash/Zsh)**: save as `~/.functions/nmapscan.sh` and auto-source from `~/.bashrc`/`~/.zshrc` (include tiny code snippets).
- **Usage**: `nmapscan <IP> [mode]`, bullet what each mode does, and include the four example commands above.
- **Output files**: describe the timestamped naming and what files get produced for TCP/UDP, including the HTML reports when possible.
- **Dependencies**: `nmap`, `xsltproc`, and `wget` or `curl` (for first-time stylesheet download). Note that `sudo` may be required. Include quick install lines for Debian/Ubuntu, Fedora/RHEL, and macOS (Homebrew).
- **Tunable env vars**: list the env keys and default values from the section above, with one-line explanations.
- **Notes**: brute is opt-in (`mode=brute` or `INCLUDE_BRUTE=1`), UDP heavy only runs if discovery found ports, `DRY_RUN` prints without touching anything, and outputs land in the current working directory.

## Light acceptance checks
- `bash -n` passes for the function file.
- `DRY_RUN=1` shows commands and paths, writes nothing.
- Missing `xsltproc` exits early with a clear multi-OS install hint and status `127`.
- Missing stylesheet triggers a one-time download attempt (otherwise carry on and skip HTML conversion).
- The README matches the implemented behavior and naming.

## Return format
- In chat: one Bash code block with **only** the `nmapscan()` definition.
- As a file: `nmapscan_readme.zip` containing `README.md` as described above.
