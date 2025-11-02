# nmapscan.sh — source this file from your shell rc to load the function.
nmapscan() {
  # Usage: nmapscan <IP> [hostname] [mode]
  # mode: (optional) "brute" (add brute NSE), "udp" (UDP only), "all" (TCP+UDP), "all-brute" (TCP+UDP with brute)
  # Examples:
  #   nmapscan 10.76.21.12
  #   nmapscan 10.76.21.12 web01
  #   nmapscan 10.76.21.12 web01 all
  #   nmapscan 10.76.21.12 web01 all-brute
  #   DRY_RUN=1 nmapscan 10.76.21.12 web01 all   # dry-run

  local ip="${1:-}" host="${2:-}" mode="${3:-}"
  if [ -z "$ip" ]; then
    printf "Usage: %s <IP> [hostname] [mode: brute|udp|all|all-brute]\n" "${FUNCNAME[0]}" >&2
    return 2
  fi

  # ---------- tuneable defaults ----------
  local SYN_MIN_RATE="${SYN_MIN_RATE:-1000}"    # pps for stage-1 SYN sweep
  local SYN_TIMING="${SYN_TIMING:--T4}"
  local SYN_RETRIES="${SYN_RETRIES:-2}"
  local TCP_TIMING="${TCP_TIMING:--T4}"
  local TCP_SCRIPTSET_DEFAULT="${TCP_SCRIPTSET_DEFAULT:-default,auth,vuln}"
  local UDP_TOP_PORTS="${UDP_TOP_PORTS:-500}"
  local UDP_TIMING="${UDP_TIMING:--T4}"
  local UDP_RETRIES="${UDP_RETRIES:-2}"
  local HOST_TIMEOUT="${HOST_TIMEOUT:-2m}"

  # Tag for filenames: prefer hostname if given, else IP; sanitize to [A-Za-z0-9._-]
  local tag="${host:-$ip}"
  tag="$(printf '%s' "$tag" | tr -c 'A-Za-z0-9._-' '_')"

  local datepart dry rc start_ts end_ts dur
  datepart=$(date +%Y%m%d-%H%M%S)

  # Filenames use: <proto>.<stage>-<tag>.<date>.<ext>
  # TCP artifacts:
  local tcp_discovery_gnmap="tcp.discovery-${tag}.${datepart}.gnmap"
  local tcp_open_txt="tcp.open_tcp_ports-${tag}.${datepart}.txt"
  local tcp_open_csv="tcp.open_tcp_ports-${tag}.${datepart}.csv"
  local tcp_heavy_base="tcp.heavy-${tag}.${datepart}"   # -> .nmap/.xml/.gnmap/.html
  local tcp_heavy_xml="${tcp_heavy_base}.xml"

  # UDP artifacts:
  local udp_discovery_gnmap="udp.discovery-${tag}.${datepart}.gnmap"
  local udp_open_txt="udp.open_udp_ports-${tag}.${datepart}.txt"
  local udp_open_csv="udp.open_udp_ports-${tag}.${datepart}.csv"
  local udp_heavy_base="udp.heavy-${tag}.${datepart}"
  local udp_heavy_xml="${udp_heavy_base}.xml"

  # decide script set (enable brute only when explicitly requested)
  # Supported:
  #   mode = brute        -> TCP with brute
  #   mode = all-brute    -> TCP+UDP with brute
  #   env INCLUDE_BRUTE=1 -> force brute regardless of mode
  local scripts
  if [[ "$mode" == "brute" || "$mode" == "all-brute" || "$INCLUDE_BRUTE" == "1" ]]; then
    scripts="default,auth,brute,vuln"
  else
    scripts="${TCP_SCRIPTSET_DEFAULT}"
  fi

  # DRY_RUN handling
  dry="${DRY_RUN:-0}"

  # ---------- check xsltproc + bootstrap XSL ----------
  if ! command -v xsltproc >/dev/null 2>&1; then
    cat >&2 <<'ERR'
❌ Required tool "xsltproc" is not installed.
Install it with one of the commands below for your platform:

  Debian / Ubuntu:
    sudo apt update && sudo apt install xsltproc

  Fedora / CentOS / RHEL:
    sudo dnf install libxslt

  macOS (Homebrew):
    brew install libxslt

After installing, re-run this function.
ERR
    return 127
  fi

  local xsl_file dl_cmd
  xsl_file="${HOME}/nmap-bootstrap.xsl"
  if [ ! -f "${xsl_file}" ] || [ -s "${xsl_file}" ] && [ ! -s "${xsl_file}" ]; then
    # The condition above ensures we fetch if missing OR empty
    :
  fi
  if [ ! -f "${xsl_file}" ] || [ ! -s "${xsl_file}" ]; then
    printf "ℹ  %s not found; attempting to download...\n" "${xsl_file}"
    if command -v wget >/dev/null 2>&1; then
      dl_cmd=( wget -q -O "${xsl_file}" "https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl" )
    elif command -v curl >/dev/null 2>&1; then
      dl_cmd=( curl -sSL -o "${xsl_file}" "https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl" )
    else
      cat >&2 <<'ERR'
⚠  Neither wget nor curl is available to download nmap-bootstrap.xsl.
Please download it manually and save to: ~/nmap-bootstrap.xsl
URL:
  https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl
ERR
      dl_cmd=()
    fi
    if [ "${#dl_cmd[@]}" -gt 0 ]; then
      printf "▶ Download command:\n  %s\n" "$(printf '%q ' "${dl_cmd[@]}")"
      if "${dl_cmd[@]}"; then
        printf "✅ Downloaded nmap-bootstrap.xsl -> %s\n" "${xsl_file}"
      else
        printf "⚠  Failed to download bootstrap XSL; XML->HTML conversion will be skipped if XSL missing.\n"
      fi
    fi
  else
    printf "✅ Found bootstrap stylesheet: %s\n" "${xsl_file}"
  fi

  # ---------------- TCP: stage 1 (fast SYN discovery) ----------------
  if [ "$mode" != "udp" ]; then
    local syn_cmd PORTS
    syn_cmd=( sudo nmap -n -sS -p- ${SYN_TIMING} --min-rate "${SYN_MIN_RATE}" --max-retries "${SYN_RETRIES}" -oG "${tcp_discovery_gnmap}" -Pn "${ip}" )

    printf "\n▶▶▶ TCP Stage-1: fast SYN discovery (all ports) on %s (%s)\n" "${ip}" "${tag}"
    printf "Command:\n  %s\n\n" "$(printf '%q ' "${syn_cmd[@]}")"

    if [ "$dry" = "1" ]; then
      printf "ℹ  DRY_RUN=1 — skipping SYN discovery. Would write: %s\n" "${tcp_discovery_gnmap}"
    else
      start_ts=$(date +%s)
      "${syn_cmd[@]}"; rc=$?
      end_ts=$(date +%s); dur=$((end_ts - start_ts))
      if [ $rc -ne 0 ]; then
        printf "✖ SYN discovery failed (exit: %d). Continuing but heavy scan may be skipped if no ports found.\n" "$rc"
      else
        printf "✔ SYN discovery complete (duration: %02d:%02d:%02d)\n" $((dur/3600)) $(((dur%3600)/60)) $((dur%60))
      fi
    fi

    # parse discovery to ports list
    if [ "$dry" = "1" ]; then
      printf "ℹ  DRY_RUN=1 — no parsing of %s\n" "${tcp_discovery_gnmap}"
      PORTS=""
    else
      if [ -f "${tcp_discovery_gnmap}" ]; then
        awk -F'Ports: ' '/Ports:/{print $2}' "${tcp_discovery_gnmap}" \
          | tr ',' '\n' \
          | awk -F'/' '$2 ~ /^open/ {print $1}' \
          | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
          | sort -n -u > "${tcp_open_txt}" || true
      fi

      if [ -s "${tcp_open_txt}" ]; then
        paste -sd, "${tcp_open_txt}" > "${tcp_open_csv}"
        PORTS="$(cat "${tcp_open_csv}")"
        printf "✅ Discovered open TCP ports: %s\n" "${PORTS}"
      else
        PORTS=""
        printf "⚠  No open TCP ports discovered from stage-1.\n"
      fi
    fi

    # ---------------- TCP: stage 2 (heavy targeted scan) ----------------
    if [ -n "${PORTS}" ]; then
      local heavy_cmd
      heavy_cmd=( sudo nmap -n -p "${PORTS}" ${TCP_TIMING} -sT -sV --version-all --script "${scripts}" -O --osscan-guess -oA "${tcp_heavy_base}" -Pn "${ip}" )

      printf "\n▶▶▶ TCP Stage-2: targeted heavy scan (service/os/scripts)\n"
      printf "Command:\n  %s\n\n" "$(printf '%q ' "${heavy_cmd[@]}")"

      if [ "$dry" = "1" ]; then
        printf "ℹ  DRY_RUN=1 — skipping heavy TCP scan. Would write base: %s\n\n" "${tcp_heavy_base}"
      else
        start_ts=$(date +%s)
        "${heavy_cmd[@]}"; rc=$?
        end_ts=$(date +%s); dur=$(( end_ts - start_ts ))
        if [ $rc -eq 0 ]; then
          printf "✅ Heavy TCP scan complete (duration: %02d:%02d:%02d). Base: %s\n\n" $((dur/3600)) $(((dur%3600)/60)) $((dur%60)) "${tcp_heavy_base}"
        else
          printf "✖ Heavy TCP scan failed (exit: %d). Base: %s\n\n" "$rc" "${tcp_heavy_base}"
        fi

        # convert XML -> HTML for heavy TCP xml if possible
        if [ -f "${tcp_heavy_xml}" ] && [ -s "${tcp_heavy_xml}" ] && [ -f "${xsl_file}" ] && [ -s "${xsl_file}" ]; then
          printf "▶ Converting %s -> %s using %s\n" "${tcp_heavy_xml}" "${tcp_heavy_base}.html" "${xsl_file}"
          xsltproc -o "${tcp_heavy_base}.html" "${xsl_file}" "${tcp_heavy_xml}" && printf "✅ Converted to HTML: %s\n" "${tcp_heavy_base}.html"
        elif [ -f "${tcp_heavy_xml}" ] && [ -s "${tcp_heavy_xml}" ]; then
          printf "⚠  XML present (%s) but bootstrap XSL missing; skipping HTML conversion.\n" "${tcp_heavy_xml}"
        fi
      fi
    else
      printf "ℹ  No TCP ports to run heavy scan against; skipping Stage-2.\n"
    fi
  fi # end tcp flow

  # ---------------- UDP flow ----------------
  if [ "$mode" = "udp" ] || [ "$mode" = "all" ] || [ "$mode" = "all-brute" ]; then
    local UPORTS rc
    local udp_discovery_cmd=( sudo nmap -n -sU --top-ports "${UDP_TOP_PORTS}" ${UDP_TIMING} --max-retries "${UDP_RETRIES}" --host-timeout "${HOST_TIMEOUT}" -oG "${udp_discovery_gnmap}" -Pn "${ip}" )

    printf "\n▶▶▶ UDP Stage-1: top-ports discovery (top:%s)\n" "${UDP_TOP_PORTS}"
    printf "Command:\n  %s\n\n" "$(printf '%q ' "${udp_discovery_cmd[@]}")"

    if [ "$dry" = "1" ]; then
      printf "ℹ  DRY_RUN=1 — skipping UDP top-ports discovery. Would write: %s\n" "${udp_discovery_gnmap}"
      UPORTS=""
    else
      start_ts=$(date +%s)
      "${udp_discovery_cmd[@]}"; rc=$?
      end_ts=$(date +%s); dur=$((end_ts - start_ts))
      if [ $rc -ne 0 ]; then
        printf "✖ UDP discovery returned %d (continuing to parse any output)\n" "$rc"
      else
        printf "✅ UDP top-ports discovery complete (duration: %02d:%02d:%02d)\n" $((dur/3600)) $(((dur%3600)/60)) $((dur%60))
      fi

      if [ -f "${udp_discovery_gnmap}" ]; then
        awk -F'Ports: ' '/Ports:/{print $2}' "${udp_discovery_gnmap}" \
          | tr ',' '\n' \
          | awk -F'/' '$2=="open"{print $1}' \
          | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
          | sort -n -u > "${udp_open_txt}" || true
      fi

      if [ -s "${udp_open_txt}" ]; then
        paste -sd, "${udp_open_txt}" > "${udp_open_csv}"
        UPORTS="$(cat "${udp_open_csv}")"
        printf "✅ Discovered open UDP ports: %s\n" "${UPORTS}"
      else
        UPORTS=""
        printf "⚠  No open UDP ports discovered in top-ports scan.\n"
      fi
    fi

    # targeted UDP checks (sV + scripts) if open UDP ports found
    if [ -n "${UPORTS}" ]; then
      local udp_heavy_cmd=( sudo nmap -n -sU -p "${UPORTS}" ${UDP_TIMING} -sV --script "default,vuln" -oA "${udp_heavy_base}" -Pn "${ip}" )

      printf "\n▶▶▶ UDP Stage-2: targeted UDP checks (service/scripts)\n"
      printf "Command:\n  %s\n\n" "$(printf '%q ' "${udp_heavy_cmd[@]}")"

      if [ "$dry" = "1" ]; then
        printf "ℹ  DRY_RUN=1 — skipping targeted UDP checks. Would write base: %s\n\n" "${udp_heavy_base}"
      else
        start_ts=$(date +%s)
        "${udp_heavy_cmd[@]}"; rc=$?
        end_ts=$(date +%s); dur=$(( end_ts - start_ts ))
        if [ $rc -eq 0 ]; then
          printf "✅ Targeted UDP checks complete (duration: %02d:%02d:%02d). Base: %s\n\n" $((dur/3600)) $(((dur%3600)/60)) $((dur%60)) "${udp_heavy_base}"
        else
          printf "✖ Targeted UDP checks failed (exit: %d). Base: %s\n\n" "$rc" "${udp_heavy_base}"
        fi

        # convert UDP xml -> html if possible
        if [ -f "${udp_heavy_xml}" ] && [ -s "${udp_heavy_xml}" ] && [ -f "${xsl_file}" ] && [ -s "${xsl_file}" ]; then
          printf "▶ Converting %s -> %s using %s\n" "${udp_heavy_xml}" "${udp_heavy_base}.html" "${xsl_file}"
          xsltproc -o "${udp_heavy_base}.html" "${xsl_file}" "${udp_heavy_xml}" && printf "✅ Converted to HTML: %s\n" "${udp_heavy_base}.html"
        elif [ -f "${udp_heavy_xml}" ] && [ -s "${udp_heavy_xml}" ]; then
          printf "⚠  UDP XML present (%s) but bootstrap XSL missing; skipping HTML conversion.\n" "${udp_heavy_xml}"
        fi
      fi
    else
      printf "ℹ  No UDP ports to run targeted checks against; skipping UDP Stage-2.\n"
    fi
  fi # end udp flow

  # final heads-up
  [ -f "${tcp_discovery_gnmap}" ] && printf "ℹ  TCP discovery gnmap: %s\n" "${tcp_discovery_gnmap}"

  return 0
}
