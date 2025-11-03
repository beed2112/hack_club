# hosts_tools.sh — my_add_host / my_del_host helpers for /etc/hosts

# my_add_host: append (or replace) an /etc/hosts entry
# Usage:
#   my_add_host <IP> <hostname> [domain=htb]
#   my_add_host -r <IP> <hostname> [domain=htb]   # replace existing then add
#
# Example:
#   my_add_host 10.76.21.12 web          # -> "10.76.21.12 web.htb web  # Added by my_add_host YYYY-MM-DD HH:MM:SS"
#   my_add_host -r 10.76.21.12 web lab

my_add_host() {
  local replace=0
  if [[ "${1:-}" == "-r" || "${1:-}" == "--replace" ]]; then
    replace=1; shift
  fi

  local ip="${1:-}" host="${2:-}" domain="${3:-htb}"
  if [[ -z "$ip" || -z "$host" ]]; then
    echo "Usage: my_add_host [-r|--replace] <IP> <hostname> [domain=htb]" >&2
    return 2
  fi

  local fqdn="${host}.${domain}"
  local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
  local line="${ip} ${fqdn} ${host}  # Added by my_add_host ${ts}"

  # If entry appears to exist, warn unless replacing
  if grep -Eq "^[[:space:]]*${ip}[[:space:]].*\b(${fqdn}|${host})\b" /etc/hosts \
     || grep -Eq "^[[:space:]]*[0-9a-fA-F:.]+[[:space:]].*\b${fqdn}\b" /etc/hosts 2>/dev/null; then
    if (( replace == 0 )); then
      echo "⚠ Entry for '${fqdn}' or IP '${ip}' already present in /etc/hosts."
      echo "   Use: my_add_host -r ${ip} ${host} ${domain}   to replace it."
      return 0
    fi
  fi

  if (( replace == 1 )); then
    local bak="/etc/hosts.bak.$(date +%Y%m%d-%H%M%S)"
    echo "🗂  Backing up /etc/hosts -> ${bak}"
    sudo cp /etc/hosts "${bak}"
    sudo sed -i \
      -e "/^[[:space:]]*${ip}[[:space:]]/d" \
      -e "/[[:space:]]${fqdn}\b/d" \
      -e "/[[:space:]]${host}\b/d" \
      /etc/hosts
  fi

  # Append with comment via echo | sudo tee -a
  printf '%s\n' "$line" | sudo tee -a /etc/hosts >/dev/null && \
    echo "✅ Added: $line"
}

# my_del_host: remove /etc/hosts entries by hostname (optional domain) or IP+hostname
# Usage:
#   my_del_host <hostname> [domain=htb]               # hostname-only
#   my_del_host <IP> <hostname> [domain=htb]          # IP + hostname
#
# Examples:
#   my_del_host web                      # removes lines containing web.htb or web
#   my_del_host web lab                  # removes lines containing web.lab or web
#   my_del_host 10.76.21.12 web          # removes lines for IP or web.htb/web
#   my_del_host 10.76.21.12 web lab      # removes lines for IP or web.lab/web

my_del_host() {
  local ip="" host="" domain="htb"

  # Argument parsing with IP detection
  case $# in
    1)
      host="$1"
      ;;
    2)
      if [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$|^[0-9a-fA-F:]+$ ]]; then
        ip="$1"; host="$2"
      else
        host="$1"; domain="$2"
      fi
      ;;
    3)
      ip="$1"; host="$2"; domain="$3"
      ;;
    *)
      echo "Usage: my_del_host <hostname> [domain=htb]  |  my_del_host <IP> <hostname> [domain=htb]" >&2
      return 2
      ;;
  esac

  if [[ -z "$host" ]]; then
    echo "Error: hostname required." >&2
    return 2
  fi

  local fqdn="${host}.${domain}"
  local ts bak tmp
  ts="$(date +%Y%m%d-%H%M%S)"
  bak="/etc/hosts.bak.${ts}"
  tmp="$(mktemp)"

  echo "🔎 Removing entries matching:"
  [[ -n "$ip"   ]] && echo "   - IP:   ${ip}"
  echo "   - FQDN: ${fqdn}"
  echo "   - Host: ${host}"

  # Show matches (if any)
  sudo grep -nE "^[[:space:]]*${ip}[[:space:]]|(^|[[:space:]])${fqdn}([[:space:]]|$)|(^|[[:space:]])${host}([[:space:]]|$)" /etc/hosts 2>/dev/null || true

  echo "🗂  Backing up /etc/hosts -> ${bak}"
  if ! sudo cp /etc/hosts "${bak}"; then
    echo "❌ Could not backup /etc/hosts" >&2
    rm -f "$tmp"
    return 1
  fi

  # Filter lines; if IP is empty, only match fqdn/host
  if sudo awk -v ip="$ip" -v fqdn="$fqdn" -v host="$host" '
      BEGIN { hasip = (ip != ""); }
      {
        ipmatch   = (hasip && $0 ~ "^[[:space:]]*" ip "[[:space:]]");
        fqdmatch  = ($0 ~ "(^|[[:space:]])" fqdn "([[:space:]]|$)");
        hostmatch = ($0 ~ "(^|[[:space:]])" host "([[:space:]]|$)");
        if (ipmatch || fqdmatch || hostmatch) next;
        print;
      }' /etc/hosts > "$tmp"; then
    if sudo tee /etc/hosts < "$tmp" >/dev/null; then
      echo "✅ Removed entries referencing ${fqdn}/${host}${ip:+ or ${ip}}"
      rm -f "$tmp"
      return 0
    fi
  fi

  echo "❌ Failed to update /etc/hosts (restored backup at ${bak})." >&2
  rm -f "$tmp"
  return 1
}
