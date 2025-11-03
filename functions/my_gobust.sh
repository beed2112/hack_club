# gobust.sh — source this file to load the function
# Usage:
#   mygobust <target> [tag] [mode: dir|vhost|dns] [extra gobuster args...]
# Modes:
#   dir   - directory/content discovery (URL required, e.g. http://10.10.10.10/)
#   vhost - virtual host fuzzing (base URL to IP or site, e.g. http://10.10.10.10)
#   dns   - subdomain brute force (domain required, e.g. example.htb)
#
# Examples:
#   mygobust http://10.10.10.10 web01 dir
#   mygobust http://10.10.10.10 vhost
#   mygobust example.htb dns
#   DRY_RUN=1 mygobust http://10.10.10.10 web01 dir -x php,txt

mygobust() {
  # Usage: mygobust <target> [tag] [mode: dir|vhost|dns] [extra gobuster args...]
  local target="${1:-}" a2="${2:-}" a3="${3:-}"; shift $(( $#>=3 ? 3 : ($#>=2 ? 2 : ($#>=1 ? 1 : 0)) ))

  if [ -z "$target" ]; then
    echo "Usage: mygobust <url|domain|ip> [tag] [mode: dir|vhost|dns] [extra gobuster args]" >&2
    return 2
  fi

  # ---------- sensible defaults (override via env) ----------
  local GB_THREADS="${GB_THREADS:-50}"
  local GB_AGENT="${GB_AGENT:-Gobuster/Autopilot}"  # HTTP modes only
  # Leave GB_STATUS unset unless you *want* allowlist; if set we’ll clear blacklist.
  # export GB_STATUS="200,204,301,302,307,401,403"
  local GB_EXT="${GB_EXT:-}"
  local GB_FOLLOW_REDIRECTS="${GB_FOLLOW_REDIRECTS:-0}"
  local GB_INSECURE_TLS="${GB_INSECURE_TLS:-1}"
  local GB_DNS_RESOLVERS="${GB_DNS_RESOLVERS:-}"
  local GB_DNS_WILDCARD_OK="${GB_DNS_WILDCARD_OK:-0}"

  # ---------- derive tag & mode (auto-detect mode in arg2) ----------
  local mode tag
  case "$a2" in
    dir|vhost|dns) mode="$a2"; tag="";;
    *)             tag="$a2"; mode="${a3:-dir}";;
  esac

  # derive tag from host if not provided
  if [ -z "$tag" ]; then
    local host="${target#*://}"; host="${host%%/*}"; tag="$host"
  fi
  tag="$(printf '%s' "$tag" | tr -c 'A-Za-z0-9._-' '_')"

  # ---------- wordlist pickers ----------
  _gb_pick_web_wordlist() {
    local c=()
    [ -n "${GOBUSTER_WORDLIST:-}" ] && c+=("$GOBUSTER_WORDLIST")
    c+=("$HOME/.wordlists/web-quick.txt"
        "$HOME/.wordlists/dir-medium.txt"
        "/usr/share/seclists/Discovery/Web-Content/common.txt"
        "/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt"
        "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt")
    local wl; for wl in "${c[@]}"; do [ -s "$wl" ] && { printf '%s\n' "$wl"; return; }; done; return 1
  }
  _gb_pick_dns_wordlist() {
    local c=()
    [ -n "${GOBUSTER_DNS_WORDLIST:-}" ] && c+=("$GOBUSTER_DNS_WORDLIST")
    c+=("$HOME/.wordlists/subdomains-top1k.txt"
        "/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
        "/usr/share/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt"
        "/usr/share/seclists/Discovery/DNS/combined_subdomains.txt")
    local wl; for wl in "${c[@]}"; do [ -s "$wl" ] && { printf '%s\n' "$wl"; return; }; done; return 1
  }

  local wordlist dns_wordlist
  case "$mode" in
    dir)
      if ! wordlist="$(_gb_pick_web_wordlist)"; then echo "✖ No suitable web wordlist. Set GOBUSTER_WORDLIST or install seclists." >&2; return 3; fi
      echo "ℹ Using wordlist: $wordlist"
      ;;
    vhost|dns)
      if ! dns_wordlist="$(_gb_pick_dns_wordlist)"; then echo "✖ No DNS/vhost wordlist. Set GOBUSTER_DNS_WORDLIST or install seclists." >&2; return 3; fi
      echo "ℹ Using DNS/vhost wordlist: $dns_wordlist"
      ;;
    *) echo "✖ Unknown mode: $mode (use dir|vhost|dns)" >&2; return 2;;
  esac

  # ---------- outputs ----------
  local datepart="$(date +%Y%m%d-%H%M%S)"
  local base="gobuster.${mode}-${tag}.${datepart}"
  local OUT_TXT="${base}.txt"
  local OUT_JSON="${base}.json"

  # detect user-provided status/blacklist flags
  local user_set_s=0 user_set_b=0
  for a in "$@"; do case "$a" in -s|--status-codes) user_set_s=1;; -b|--status-codes-blacklist) user_set_b=1;; esac; done

  # ---------- build command ----------
  local -a cmd
  case "$mode" in
    dir)
      case "$target" in http://*|https://*) : ;; *) target="http://${target}";; esac
      [[ "$target" != */ ]] && target="${target}/"
      cmd=( gobuster dir -u "$target" -w "$wordlist" -t "$GB_THREADS" -a "$GB_AGENT" -o "$OUT_TXT" -z )
      [ -n "$GB_EXT" ] && cmd+=( -x "$GB_EXT" )
      [ "$GB_FOLLOW_REDIRECTS" = "1" ] && cmd+=( -r )
      [ "$GB_INSECURE_TLS" = "1" ] && cmd+=( -k )
      if [ -n "${GB_STATUS:-}" ] && [ $user_set_s -eq 0 ] && [ $user_set_b -eq 0 ]; then
        cmd+=( --status-codes "$GB_STATUS" --status-codes-blacklist "" )
      fi
      ;;
    vhost)
      case "$target" in http://*|https://*) : ;; *) target="http://${target}";; esac
      target="${target%/}"
      cmd=( gobuster vhost -u "$target" -w "$dns_wordlist" -t "$GB_THREADS" -a "$GB_AGENT" -o "$OUT_TXT" -z )
      [ "$GB_INSECURE_TLS" = "1" ] && cmd+=( -k )
      ;;
    dns)
      # IMPORTANT: no -a (User-Agent) here; dns mode doesn't support it
      cmd=( gobuster dns -d "$target" -w "$dns_wordlist" -t "$GB_THREADS" -o "$OUT_TXT" -z )
      [ -n "$GB_DNS_RESOLVERS" ] && cmd+=( --resolver "$GB_DNS_RESOLVERS" )
      [ "$GB_DNS_WILDCARD_OK" = "1" ] && cmd+=( --wildcard )
      ;;
  esac

  # extra args last (allow override)
  [ "$#" -gt 0 ] && cmd+=( "$@" )

  echo
  echo "▶▶▶ Gobuster ${mode} on ${target} (tag:${tag})"
  echo "Command:"; printf '  %q ' "${cmd[@]}"; echo

  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "ℹ DRY_RUN=1 — skipping execution. Would write: ${OUT_TXT}"
    return 0
  fi

  "${cmd[@]}"; local rc=$?
  if [ $rc -ne 0 ]; then echo "✖ gobuster returned $rc" >&2; return $rc; fi

  if gobuster "${mode}" -h 2>&1 | grep -q -- '--json'; then
    local -a json_cmd=( "${cmd[@]}" --json )
    for i in "${!json_cmd[@]}"; do [[ "${json_cmd[$i]}" = "-o" ]] && json_cmd[$((i+1))]="${OUT_JSON}"; done
    echo "ℹ Capturing JSON: ${OUT_JSON}"
    "${json_cmd[@]}" >/dev/null 2>&1 || true
  fi

  echo "✅ Output: ${OUT_TXT}"
  [ -f "${OUT_JSON}" ] && echo "✅ JSON:   ${OUT_JSON}"
}
