# my_nmapscan.sh — source this file from your shell rc to load the function.
my_nmapscan() {
  # Usage: my_nmapscan <IP> [hostname] [mode]
  # mode: (optional)
  #   "brute"        -> TCP with brute NSE
  #   "udp"          -> UDP only
  #   "all"          -> TCP + UDP
  #   "all-brute"    -> TCP + UDP both with brute NSE
  #
  # Examples:
  #   my_nmapscan 10.76.21.12
  #   my_nmapscan 10.76.21.12 web01
  #   my_nmapscan 10.76.21.12 web01 all
  #   my_nmapscan 10.76.21.12 web01 all-brute
  #   DRY_RUN=1 my_nmapscan 10.76.21.12 web01 all

  local ip="${1:-}" host="${2:-}" mode="${3:-}"
  if [ -z "$ip" ]; then
    printf "Usage: %s <IP> [hostname] [mode: brute|udp|all|all-brute]\n" "${FUNCNAME[0]}" >&2
    return 2
  fi
  # normalize mode to lowercase (portable)
  mode="$(printf '%s' "$mode" | tr '[:upper:]' '[:lower:]')"

  # ---------- tuneable defaults ----------
  local SYN_MIN_RATE="${SYN_MIN_RATE:-1000}"    # pps for stage-1 SYN sweep
  local SYN_TIMING="${SYN_TIMING:--T4}"
  local SYN_RETRIES="${SYN_RETRIES:-2}"
  local TCP_TIMING="${TCP_TIMING:--T4}"
  local TCP_SCRIPTSET_DEFAULT="${TCP_SCRIPTSET_DEFAULT:-default,auth,vuln}"

  local UDP_TOP_PORTS="${UDP_TOP_PORTS:-500}"
  local UDP_TIMING="${UDP_TIMING:--T4}"
  local UDP_RETRIES="${UDP_RETRIES:-2}"
  local UDP_SCRIPTSET_DEFAULT="${UDP_SCRIPTSET_DEFAULT:-default,vuln}"
  local UDP_SCRIPTSET_BRUTE="${UDP_SCRIPTSET_BRUTE:-default,auth,brute,vuln}"

  local HOST_TIMEOUT="${HOST_TIMEOUT:-2m}"

  # Tag for filenames
  local tag="${host:-$ip}"
  tag="$(printf '%s' "$tag" | tr -c 'A-Za-z0-9._-' '_')"

  local datepart dry rc start_ts end_ts dur
  datepart=$(date +%Y%m%d-%H%M%S)
  dry="${DRY_RUN:-0}"

  # Filenames use: <proto>.<stage>-<tag>.<date>.<ext>
  # TCP artifacts:
  local tcp_discovery_gnmap="tcp.discovery-${tag}.${datepart}.gnmap"
  local tcp_open_txt="tcp.open_tcp_ports-${tag}.${datepart}.txt"
  local tcp_open_csv="tcp.open_tcp_ports-${tag}.${datepart}.csv"
  local tcp_heavy_base="tcp.heavy-${tag}.${datepart}"
  local tcp_heavy_xml="${tcp_heavy_base}.xml"

  # UDP artifacts:
  local udp_discovery_gnmap="udp.discovery-${tag}.${datepart}.gnmap"
  local udp_open_txt="udp.open_udp_ports-${tag}.${datepart}.txt"
  local udp_open_csv="udp.open_udp_ports-${tag}.${datepart}.csv"
  local udp_heavy_base="udp.heavy-${tag}.${datepart}"
  local udp_heavy_xml="${udp_heavy_base}.xml"

  # Decide script sets
  local tcp_scripts udp_scripts
  if [[ "$mode" == "brute" || "$mode" == "all-brute" || "$INCLUDE_BRUTE" == "1" ]]; then
    tcp_scripts="default,auth,brute,vuln"
  else
    tcp_scripts="$TCP_SCRIPTSET_DEFAULT"
  fi
  if [[ "$mode" == "all-brute" || "$INCLUDE_BRUTE_UDP" == "1" ]]; then
    udp_scripts="$UDP_SCRIPTSET_BRUTE"
  else
    udp_scripts="$UDP_SCRIPTSET_DEFAULT"
  fi

  # Decide flows explicitly (so "all" always runs both)
  local do_tcp=1 do_udp=0
  if [[ "$mode" == "udp" ]]; then
    do_tcp=0; do_udp=1
  elif [[ "$mode" == "all" || "$mode" == "all-brute" ]]; then
    do_tcp=1; do_udp=1
  fi

  # ---------- xsltproc + bootstrap XSL ----------
  local xsl_file="${HOME}/nmap-bootstrap.xsl"
  if ! command -v xsltproc >/dev/null 2>&1; then
    printf "⚠  xsltproc not found; XML→HTML conversion will be skipped.\n"
  elif [ ! -s "${xsl_file}" ]; then
    printf "ℹ  %s not found; attempting to download...\n" "${xsl_file}"
    if command -v wget >/dev/null 2>&1; then
      wget -q -O "${xsl_file}" "https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl" \
        && printf "✅ Downloaded bootstrap XSL.\n" || printf "⚠  Download failed; skipping HTML conversion.\n"
    elif command -v curl >/dev/null 2>&1; then
      curl -sSL -o "${xsl_file}" "https://raw.githubusercontent.com/honze-net/nmap-bootstrap-xsl/master/nmap-bootstrap.xsl" \
        && printf "✅ Downloaded bootstrap XSL.\n" || printf "⚠  Download failed; skipping HTML conversion.\n"
    else
      printf "⚠  Neither wget nor curl available to fetch XSL; skipping HTML conversion.\n"
    fi
  else
    printf "✅ Found bootstrap stylesheet: %s\n" "${xsl_file}"
  fi

  # ---------------- TCP flow ----------------
  if [ "$do_tcp" -eq 1 ]; then
    local PORTS
    local syn_cmd=( sudo nmap -n -sS -p- ${SYN_TIMING} --min-rate "${SYN_MIN_RATE}" --max-retries "${SYN_RETRIES}" -oG "${tcp_discovery_gnmap}" -Pn "${ip}" )
    printf "\n▶▶▶ TCP Stage-1: fast SYN discovery (all ports) on %s (%s)\n" "${ip}" "${tag}"
    printf "Command:\n  %s\n\n" "$(printf '%q ' "${syn_cmd[@]}")"

    if [ "$dry" = "1" ]; then
      printf "ℹ  DRY_RUN=1 — skipping TCP SYN discovery. Would write: %s\n" "${tcp_discovery_gnmap}"
    else
      start_ts=$(date +%s); "${syn_cmd[@]}"; rc=$?; end_ts=$(date +%s); dur=$((end_ts - start_ts))
      if [ $rc -ne 0 ]; then
        printf "✖ SYN discovery failed (exit: %d). Continuing.\n" "$rc"
      else
        printf "✔ SYN discovery complete (duration: %02d:%02d:%02d)\n" $((dur/3600)) $(((dur%3600)/60)) $((dur%60))
      fi

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
        printf "⚠  No open TCP ports discovered.\n"
      fi

      if [ -n "${PORTS}" ]; then
        local heavy_cmd=( sudo nmap -n -p "${PORTS}" ${TCP_TIMING} -sT -sV --version-all --script "${tcp_scripts}" -O --osscan-guess -oA "${tcp_heavy_base}" -Pn "${ip}" )
        printf "\n▶▶▶ TCP Stage-2: targeted heavy scan (service/os/scripts)\n"
        printf "Command:\n  %s\n\n" "$(printf '%q ' "${heavy_cmd[@]}")"
        start_ts=$(date +%s); "${heavy_cmd[@]}"; rc=$?; end_ts=$(date +%s); dur=$(( end_ts - start_ts ))
        if [ $rc -eq 0 ]; then
          printf "✅ Heavy TCP scan complete (duration: %02d:%02d:%02d). Base: %s\n\n" $((dur/3600)) $(((dur%3600)/60)) $((dur%60)) "${tcp_heavy_base}"
        else
          printf "✖ Heavy TCP scan failed (exit: %d). Base: %s\n\n" "$rc" "${tcp_heavy_base}"
        fi
        if command -v xsltproc >/dev/null 2>&1 && [ -s "${xsl_file}" ] && [ -s "${tcp_heavy_xml}" ]; then
          printf "▶ Converting %s -> %s\n" "${tcp_heavy_xml}" "${tcp_heavy_base}.html"
          xsltproc -o "${tcp_heavy_base}.html" "${xsl_file}" "${tcp_heavy_xml}" && printf "✅ Converted to HTML: %s\n" "${tcp_heavy_base}.html"
        fi
      else
        printf "ℹ  No TCP ports to run heavy scan against; skipping Stage-2.\n"
      fi
    fi
  fi

  # ---------------- UDP flow ----------------
  if [ "$do_udp" -eq 1 ]; then
    local UPORTS
    local udp_discovery_cmd=( sudo nmap -n -sU --top-ports "${UDP_TOP_PORTS}" ${UDP_TIMING} --max-retries "${UDP_RETRIES}" --host-timeout "${HOST_TIMEOUT}" -oG "${udp_discovery_gnmap}" -Pn "${ip}" )
    printf "\n▶▶▶ UDP Stage-1: top-ports discovery (top:%s)\n" "${UDP_TOP_PORTS}"
    printf "Command:\n  %s\n\n" "$(printf '%q ' "${udp_discovery_cmd[@]}")"

    if [ "$dry" = "1" ]; then
      printf "ℹ  DRY_RUN=1 — skipping UDP discovery. Would write: %s\n" "${udp_discovery_gnmap}"
    else
      start_ts=$(date +%s); "${udp_discovery_cmd[@]}"; rc=$?; end_ts=$(date +%s); dur=$((end_ts - start_ts))
      if [ $rc -ne 0 ]; then
        printf "✖ UDP discovery returned %d (parsing any output)\n" "$rc"
      else
        printf "✔ UDP discovery complete (duration: %02d:%02d:%02d)\n" $((dur/3600)) $(((dur%3600)/60)) $((dur%60))
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
        printf "⚠  No open UDP ports discovered.\n"
      fi

      if [ -n "${UPORTS}" ]; then
        local udp_heavy_cmd=( sudo nmap -n -sU -p "${UPORTS}" ${UDP_TIMING} -sV --script "${udp_scripts}" -oA "${udp_heavy_base}" -Pn "${ip}" )
        printf "\n▶▶▶ UDP Stage-2: targeted UDP checks (service/scripts)\n"
        printf "Command:\n  %s\n\n" "$(printf '%q ' "${udp_heavy_cmd[@]}")"
        start_ts=$(date +%s); "${udp_heavy_cmd[@]}"; rc=$?; end_ts=$(date +%s); dur=$(( end_ts - start_ts ))
        if [ $rc -eq 0 ]; then
          printf "✅ Targeted UDP checks complete (duration: %02d:%02d:%02d). Base: %s\n\n" $((dur/3600)) $(((dur%3600)/60)) $((dur%60)) "${udp_heavy_base}"
        else
          printf "✖ Targeted UDP checks failed (exit: %d). Base: %s\n\n" "$rc" "${udp_heavy_base}"
        fi
        if command -v xsltproc >/dev/null 2>&1 && [ -s "${xsl_file}" ] && [ -s "${udp_heavy_xml}" ]; then
          printf "▶ Converting %s -> %s\n" "${udp_heavy_xml}" "${udp_heavy_base}.html"
          xsltproc -o "${udp_heavy_base}.html" "${xsl_file}" "${udp_heavy_xml}" && printf "✅ Converted to HTML: %s\n" "${udp_heavy_base}.html"
        fi
      else
        printf "ℹ  No UDP ports to run targeted checks against; skipping UDP Stage-2.\n"
      fi
    fi
  fi

  # final heads-up
  [ -f "${tcp_discovery_gnmap}" ] && printf "ℹ  TCP discovery gnmap: %s\n" "${tcp_discovery_gnmap}"
  [ -f "${udp_discovery_gnmap}" ] && printf "ℹ  UDP discovery gnmap: %s\n" "${udp_discovery_gnmap}"
  return 0
}
