# ~/.config/shell/bash_functions_loader.sh
# Autoload all user functions from ~/.functions/*.sh (bash)
# Idempotent per-session via guard variable.

# Guard against re-sourcing
if [ -n "${__USER_FUNCTIONS_LOADED_BASH:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
__USER_FUNCTIONS_LOADED_BASH=1

# Ensure folder exists
FUNCDIR="${HOME}/.functions"
[ -d "$FUNCDIR" ] || return 0

# Enable nullglob in a local scope so *.sh expands to nothing if no files
shopt -q nullglob || __NF_set=1
shopt -s nullglob

# Source all readable *.sh in sorted order
for f in "$FUNCDIR"/*.sh; do
  [ -r "$f" ] || continue
  # shellcheck source=/dev/null
  . "$f"
done

# Restore nullglob if we enabled it
[ -n "${__NF_set:-}" ] && shopt -u nullglob && unset __NF_set
