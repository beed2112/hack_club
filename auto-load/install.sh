#!/usr/bin/env bash
set -euo pipefail

echo "== functions-autoload installer =="

CONFIG_DIR="${HOME}/.config/shell"
FUNCDIR="${HOME}/.functions"
BASHRC="${HOME}/.bashrc"
ZSHRC="${HOME}/.zshrc"
BASH_LOADER="${CONFIG_DIR}/bash_functions_loader.sh"
ZSH_LOADER="${CONFIG_DIR}/zsh_functions_loader.zsh"

mkdir -p "${CONFIG_DIR}" "${FUNCDIR}"

# Copy loaders
cp -f "loaders/bash_functions_loader.sh" "${BASH_LOADER}"
cp -f "loaders/zsh_functions_loader.zsh" "${ZSH_LOADER}"

stamp="$(date +%Y%m%d-%H%M%S)"

# Append to .bashrc if not present
if [ -f "${BASHRC}" ]; then
  if ! grep -q "functions-autoload (bash)" "${BASHRC}"; then
    cp -n "${BASHRC}" "${BASHRC}.bak.autoload-${stamp}" || true
    cat >> "${BASHRC}" <<'EOF'

# >>> functions-autoload (bash) >>>
[ -f "$HOME/.config/shell/bash_functions_loader.sh" ] && . "$HOME/.config/shell/bash_functions_loader.sh"
# <<< functions-autoload (bash) <<<
EOF
    echo "Updated ${BASHRC}"
  else
    echo "Already present in ${BASHRC}"
  fi
else
  echo "No ${BASHRC} found; skipping."
fi

# Append to .zshrc if present and not already added
if [ -f "${ZSHRC}" ]; then
  if ! grep -q "functions-autoload (zsh)" "${ZSHRC}"; then
    cp -n "${ZSHRC}" "${ZSHRC}.bak.autoload-${stamp}" || true
    cat >> "${ZSHRC}" <<'EOF'

# >>> functions-autoload (zsh) >>>
[ -f "$HOME/.config/shell/zsh_functions_loader.zsh" ] && source "$HOME/.config/shell/zsh_functions_loader.zsh"
# <<< functions-autoload (zsh) <<<
EOF
    echo "Updated ${ZSHRC}"
  else
    echo "Already present in ${ZSHRC}"
  fi
else
  echo "No ${ZSHRC} found; skipping."
fi

echo "Done. Open a new shell or run:"
echo "  source \"$BASH_LOADER\"   # bash"
echo "  source \"$ZSH_LOADER\"    # zsh"
