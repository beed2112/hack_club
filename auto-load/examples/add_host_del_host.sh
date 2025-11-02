# ~/.functions/add_host_del_host.sh
# Sample helpers that edit /etc/hosts via sudo tee
# - add_host <IP> <hostname> [domain]
# - del_host <hostname>

add_host() {
  local ip="${1:-}" host="${2:-}" domain="${3:-htb}"
  if [ -z "$ip" ] || [ -z "$host" ]; then
    printf "Usage: add_host <IP> <hostname> [domain]\n" >&2
    return 2
  fi
  local fqdn="${host}.${domain}"
  local ts
  ts="$(date +%Y-%m-%dT%H:%M:%S%z)"
  # Remove any existing line for this hostname or FQDN
  sudo sed -i.bak "/[[:space:]]${host}\$/d;/[[:space:]]${fqdn}\$/d" /etc/hosts
  # Add new line with comment
  printf "%s\t%s %s\t# Added by add_host %s\n" "$ip" "$fqdn" "$host" "$ts" | sudo tee -a /etc/hosts >/dev/null
  printf "Added: %s -> %s (%s)\n" "$ip" "$fqdn" "$ts"
}

del_host() {
  local host="${1:-}"
  if [ -z "$host" ]; then
    printf "Usage: del_host <hostname>\n" >&2
    return 2
  fi
  # Delete both short and any FQDN with this host at end of field
  sudo sed -i.bak "/[[:space:]]${host}\$/d" /etc/hosts
  printf "Removed entries ending with: %s\n" "$host"
}
