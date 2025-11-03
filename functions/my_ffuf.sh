# ffuf.sh — source this file to load the function
# Usage:
#   myffuf <target> [tag] [mode: dir|vhost|dns] [extra ffuf args...]
#
# Modes:
#   dir   - directory/content discovery. If target doesn't contain FUZZ, we append /FUZZ
#   vhost - virtual host fuzzing against a base URL/IP using Host header: "Host: FUZZ.<domain>"
#   dns   - subdomain HTTP check (HTTP-based, not raw DNS): http://FUZZ.<domain>/
#
# Examples:
#   myffuf http://10.10.10.10/ web01 dir
#   myffuf http://10.10.10.10 vhost                # will prompt for domain via env FF_VHOST_DOMAIN or infer from tag
#   myffuf example.htb dns
#   DRY_RUN=1 myffuf http://target/ dir -e php,txt
#
# Notes:
# - myffuf focuses on HTTP fuzzing. For raw DNS brute-force (no HTTP), use gobuster dns, puredns, or massdns.
# - myffuf defaults to filtering 404 via -fc 404. If you set -mc (allowlist) yourself or via FF_MATCH_CODES,
#   we do NOT add the default -fc to avoid conflicting filters.

myffuf() {
  local target="${1:-}" a2="${2:-}" a3="${3:-}"; shift $(( $#>=3 ? 3 : ($#>=2 ? 2 : ($#>=1 ? 1 : 0)) ))
  if [ -z "$target" ]; then
    echo "Usage: myffuf <url|domain|ip> [tag] [mode: dir|vhost|dns] [extra ffuf args]" >&2
    return 2
  fi

  # ---------- sensible defaults (override via env) ----------
  local FF_THREADS="${FF_THREADS:-50}"             # -t
  local FF_AGENT="${FF_AGENT:-FFUF/Autopilot}"     # -H "User-Agent: ..."
  local FF_EXT="${FF_EXT:-}"                        # -e , e.g. "php,txt,html"
  local FF_FOLLOW_REDIRECTS="${FF_FOLLOW_REDIRECTS:-0}"  # -r
  local FF_INSECURE_TLS="${FF_INSECURE_TLS:-1}"          # -k
  local FF_TIMEOUT="${FF_TIMEOUT:-10}"              # -timeout (seconds)
  local FF_RATE="${FF_RATE:-}"                      # -rate requests per second (optional)
  local FF_MATCH_CODES="${FF_MATCH_CODES:-}"        # -mc (allowlist)
  local FF_FILTER_CODES="${FF_FILTER_CODES:-404}"   # -fc (blacklist) used only if -mc not set
  local FF_SILENT="${FF_SILENT:-1}"                 # -s for clean logs
  local FF_VHOST_DOMAIN="${FF_VHOST_DOMAIN:-}"      # domain for vhost mode, e.g. example.htb

  # ---------- derive tag & mode (auto-detect mode in arg2) ----------
  local mode tag
  case "$a2" in
    dir|vhost|dns) mode="$a2"; tag="";;
    *)             tag="$a2"; mode="${a3:-dir}";;
  esac

  # Derive tag from host if not provided
  if [ -z "$tag" ]; then
    local host="${target#*://}"; host="${host%%/*}"; tag="$host"
  fi
  tag="$(printf '%s' "$tag" | tr -c 'A-Za-z0-9._-' '_')"

  # ---------- wordlist pickers ----------
  _ff_pick_web_wordlist() {
    local c=()
    [ -n "${FF_WORDLIST:-}" ] && c+=("$FF_WORDLIST")
    c+=("$HOME/.wordlists/web-quick.txt"
        "$HOME/.wordlists/dir-medium.txt"
        "/usr/share/seclists/Discovery/Web-Content/common.txt"
        "/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt"
        "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt")
    local wl; for wl in "${c[@]}"; do [ -s "$wl" ] && { printf '%s\n' "$wl"; return; }; done; return 1
  }
  _ff_pick_dns_wordlist() {
    local c=()
    [ -n "${FF_DNS_WORDLIST:-}" ] && c+=("$FF_DNS_WORDLIST")
    c+=("$HOME/.wordlists/subdomains-top1k.txt"
        "/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
        "/usr/share/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt"
        "/usr/share/seclists/Discovery/DNS/combined_subdomains.txt")
    local wl; for wl in "${c[@]}"; do [ -s "$wl" ] && { printf '%s\n' "$wl"; return; }; done; return 1
  }

  local wordlist dns_wordlist
  case "$mode" in
    dir)
      if ! wordlist="$(_ff_pick_web_wordlist)"; then echo "✖ No suitable web wordlist. Set FF_WORDLIST or install seclists." >&2; return 3; fi
      echo "ℹ Using wordlist: $wordlist"
      ;;
    vhost|dns)
      if ! dns_wordlist="$(_ff_pick_dns_wordlist)"; then echo "✖ No DNS/vhost wordlist. Set FF_DNS_WORDLIST or install seclists." >&2; return 3; fi
      echo "ℹ Using DNS/vhost wordlist: $dns_wordlist"
      ;;
    *)
      echo "✖ Unknown mode: $mode (use dir|vhost|dns)" >&2; return 2;;
  esac

  # ---------- outputs ----------
  local datepart="$(date +%Y%m%d-%H%M%S)"
  local base="ffuf.${mode}-${tag}.${datepart}"
  local OUT_TXT="${base}.txt"
  local OUT_JSON="${base}.json"

  # Detect if user already supplied -mc or -fc to avoid double-setting
  local user_set_mc=0 user_set_fc=0
  for a in "$@"; do
    case "$a" in
      -mc|--match-code|--match-codes) user_set_mc=1 ;;
      -fc|--filter-code|--filter-codes) user_set_fc=1 ;;
    esac
  done

  # ---------- build command ----------
  local -a cmd http_headers
  http_headers=( -H "User-Agent: ${FF_AGENT}" )

  case "$mode" in
    dir)
      # Ensure URL has FUZZ. If not present, append /FUZZ for convenience.
      case "$target" in
        http://*|https://*) : ;;
        *) target="http://${target}";;
      esac
      if [[ "$target" != *FUZZ* ]]; then
        target="${target%/}/FUZZ"
      fi
      cmd=( ffuf -u "$target" -w "$wordlist" -t "$FF_THREADS" -timeout "$FF_TIMEOUT" -o "$OUT_JSON" -of json )
      [ -n "$FF_RATE" ] && cmd+=( -rate "$FF_RATE" )
      [ -n "$FF_EXT" ] && cmd+=( -e "$FF_EXT" )
      [ "$FF_FOLLOW_REDIRECTS" = "1" ] && cmd+=( -r )
      [ "$FF_INSECURE_TLS" = "1" ] && cmd+=( -k )
      [ "$FF_SILENT" = "1" ] && cmd+=( -s )
      cmd+=( "${http_headers[@]}" )

      # Status logic: prefer allowlist if provided; else default blacklist 404 (unless user overrides)
      if [ $user_set_mc -eq 0 ] && [ -n "${FF_MATCH_CODES:-}" ]; then
        cmd+=( -mc "$FF_MATCH_CODES" )
      elif [ $user_set_mc -eq 0 ] && [ $user_set_fc -eq 0 ]; then
        cmd+=( -fc "${FF_FILTER_CODES}" )
      fi
      ;;
    vhost)
      # Base URL should hit the target IP/host. We'll fuzz Host header with FUZZ.<domain>
      case "$target" in
        http://*|https://*) : ;;
        *) target="http://${target}";;
      esac
      target="${target%/}"
      local domain="${FF_VHOST_DOMAIN:-${tag}}"
      # Strip port/IP-like tag when inferring
      # If tag looks like an IP, require FF_VHOST_DOMAIN from user
      if [[ "$domain" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(:[0-9]+)?$ ]]; then
        if [ -z "${FF_VHOST_DOMAIN:-}" ]; then
          echo "✖ vhost mode needs a domain. Set FF_VHOST_DOMAIN (e.g., export FF_VHOST_DOMAIN='example.htb')." >&2
          return 3
        fi
        domain="${FF_VHOST_DOMAIN}"
      fi
      cmd=( ffuf -u "$target" -w "$dns_wordlist" -t "$FF_THREADS" -timeout "$FF_TIMEOUT" -o "$OUT_JSON" -of json )
      [ -n "$FF_RATE" ] && cmd+=( -rate "$FF_RATE" )
      [ "$FF_FOLLOW_REDIRECTS" = "1" ] && cmd+=( -r )
      [ "$FF_INSECURE_TLS" = "1" ] && cmd+=( -k )
      [ "$FF_SILENT" = "1" ] && cmd+=( -s )
      # Host header fuzzing
      cmd+=( -H "Host: FUZZ.${domain}" )
      cmd+=( "${http_headers[@]}" )
      # Filtering: keep defaults consistent with dir
      if [ $user_set_mc -eq 0 ] && [ -n "${FF_MATCH_CODES:-}" ]; then
        cmd+=( -mc "$FF_MATCH_CODES" )
      elif [ $user_set_mc -eq 0 ] && [ $user_set_fc -eq 0 ]; then
        cmd+=( -fc "${FF_FILTER_CODES}" )
      fi
      ;;
    dns)
      # HTTP-based subdomain check: http://FUZZ.domain/
      local domain="$target"
      # If full URL was provided, extract host as domain
      if [[ "$domain" == http://* || "$domain" == https://* ]]; then
        domain="${domain#*://}"; domain="${domain%%/*}"
      fi
      cmd=( ffuf -u "http://FUZZ.${domain}/" -w "$dns_wordlist" -t "$FF_THREADS" -timeout "$FF_TIMEOUT" -o "$OUT_JSON" -of json )
      [ -n "$FF_RATE" ] && cmd+=( -rate "$FF_RATE" )
      [ "$FF_FOLLOW_REDIRECTS" = "1" ] && cmd+=( -r )
      [ "$FF_INSECURE_TLS" = "1" ] && cmd+=( -k )
      [ "$FF_SILENT" = "1" ] && cmd+=( -s )
      cmd+=( "${http_headers[@]}" )
      # Filtering
      if [ $user_set_mc -eq 0 ] && [ -n "${FF_MATCH_CODES:-}" ]; then
        cmd+=( -mc "$FF_MATCH_CODES" )
      elif [ $user_set_mc -eq 0 ] && [ $user_set_fc -eq 0 ]; then
        cmd+=( -fc "${FF_FILTER_CODES}" )
      fi
      ;;
  esac

  # Append user's extra args last (override ours if desired)
  [ "$#" -gt 0 ] && cmd+=( "$@" )

  echo
  echo "▶▶▶ ffuf ${mode} on ${target} (tag:${tag})"
  echo "Command:"; printf '  %q ' "${cmd[@]}"; echo

  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "ℹ DRY_RUN=1 — skipping execution. Would write: ${OUT_JSON} and ${OUT_TXT}"
    return 0
  fi

  # Run once: send normal console output to TXT via tee; JSON is written by -o/-of
  "${cmd[@]}" | tee "${OUT_TXT}"
  local rc=${PIPESTATUS[0]}
  if [ $rc -ne 0 ]; then echo "✖ ffuf returned $rc" >&2; return $rc; fi

  echo "✅ Output (txt): ${OUT_TXT}"
  echo "✅ Output (json): ${OUT_JSON}"
}
