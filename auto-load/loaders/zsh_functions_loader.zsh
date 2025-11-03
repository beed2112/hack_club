# ~/.config/shell/zsh_functions_loader.zsh
# Autoload all user functions from ~/.functions/*.sh (zsh)


# Guard
if [[ -n "${__USER_FUNCTIONS_LOADED_ZSH:-}" ]]; then
  return 0
fi
__USER_FUNCTIONS_LOADED_ZSH=1

local FUNCDIR="$HOME/.functions"
[[ -d "$FUNCDIR" ]] || return 0

# Use a local option scope
setopt local_options null_glob NO_nomatch

# Source all readable *.sh in sorted order
for f in $FUNCDIR/*.sh; do
  [[ -r "$f" ]] || continue
  source "$f"
done
