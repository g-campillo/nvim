#!/usr/bin/env bash
# Fresh-Mac bootstrap for this Neovim config. Idempotent — safe to re-run.
#
# Installs every SYSTEM dependency the config needs. The Neovim plugins and LSP
# servers install themselves on first `nvim` launch (lazy.nvim + Mason); this
# script only lays down the toolchain those need to actually run.
#
# NOTE: not `set -e` on purpose — this is best-effort so one already-installed
# tool never aborts the rest. Run `make doctor` afterwards to see the result.
set -o pipefail

ZSHRC="$HOME/.zshrc"
log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# `make doctor` — report what's installed and what nvim will see. Read-only.
doctor() {
  [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
  [ -x /usr/local/bin/brew ]    && eval "$(/usr/local/bin/brew shellenv)"
  export NVM_DIR="$HOME/.nvm"
  [ -s "$(brew --prefix nvm 2>/dev/null)/nvm.sh" ] && . "$(brew --prefix nvm)/nvm.sh"
  export PYENV_ROOT="$HOME/.pyenv"; export PATH="$PYENV_ROOT/bin:$PATH"
  command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init - bash)"
  [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ] && . "$HOME/.sdkman/bin/sdkman-init.sh" 2>/dev/null
  echo "Dependencies:"
  for t in nvim brew git rg node npm python3 go java; do
    if command -v "$t" >/dev/null 2>&1; then
      if [ "$t" = go ]; then v=$(go version 2>&1); else v=$("$t" --version 2>&1 | head -1); fi
      printf '  \342\234\205 %-8s %s\n' "$t" "$v"
    else
      printf '  \342\235\214 %-8s missing\n' "$t"
    fi
  done
  echo "JDKs under ~/.sdkman (jdtls needs one 21+ and one 17):"
  ls -1 "$HOME/.sdkman/candidates/java" 2>/dev/null | grep -v '^current$' | sed 's/^/  - /' || echo "  (none)"
  if brew list --cask 2>/dev/null | grep -q font-fira-code-nerd-font; then
    echo "  FiraCode Nerd Font installed (set it as your terminal font)"
  else
    echo "  ! FiraCode Nerd Font not installed"
  fi
}

if [ "${1:-install}" = "doctor" ]; then doctor; exit 0; fi

# --- 1. Homebrew -----------------------------------------------------------
log "Homebrew"
if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ] && [ ! -x /usr/local/bin/brew ]; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
BREW_BIN=$([ -x /opt/homebrew/bin/brew ] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew)
eval "$("$BREW_BIN" shellenv)"

# --- 2. Xcode Command Line Tools ------------------------------------------
# Homebrew already pulls these in; explicit per request. The dialog is async —
# it can't be waited on from a script, so we just kick it off.
log "Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install 2>/dev/null || true
  echo "   A GUI dialog may have appeared — click Install and let it finish."
fi

# --- Neovim itself (a fresh Mac won't have it) -----------------------------
log "Neovim"
brew install neovim || true

# --- 3. FiraCode Nerd Font -------------------------------------------------
log "FiraCode Nerd Font"
brew install --cask font-fira-code-nerd-font || true
echo "   Set your terminal font to 'FiraCode Nerd Font' — this draws nvim's icons."

# --- 4. ripgrep (powers Telescope live-grep — searches file contents) ------
log "ripgrep"
brew install ripgrep || true

# --- 5. Node via nvm -------------------------------------------------------
# Needed so Mason can install the JS/TS-based LSPs (ts_ls, html, cssls, ...).
log "nvm + Node LTS"
brew install nvm || true
export NVM_DIR="$HOME/.nvm"; mkdir -p "$NVM_DIR"
# shellcheck disable=SC1091
. "$(brew --prefix nvm)/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'

# --- 6. Python via pyenv ---------------------------------------------------
# Needed for the Python LSPs (pylsp, ruff). The extra brew libs are pyenv's
# build deps — without them `pyenv install` fails to compile CPython.
log "pyenv + latest Python"
brew install pyenv openssl readline sqlite3 xz zlib tcl-tk || true
export PYENV_ROOT="$HOME/.pyenv"; export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
PY_LATEST=$(pyenv install --list | grep -E '^[[:space:]]*3\.[0-9]+\.[0-9]+$' | tail -1 | tr -d '[:space:]')
if [ -n "$PY_LATEST" ]; then
  pyenv install -s "$PY_LATEST"
  pyenv global "$PY_LATEST"
fi

# --- 7. Go -----------------------------------------------------------------
# ponytail: no goenv/gvm — Go 1.21+ self-manages toolchains (GOTOOLCHAIN=auto
# downloads whatever version a project's go.mod asks for). brew keeps Go current.
log "Go (gopls needs it)"
brew install go || true

# --- 8. SDKMAN + JDKs ------------------------------------------------------
# The config's jdtls hardcodes ~/.sdkman JDK paths: newest 21+ runs jdtls,
# 17 is the compile target. Both must physically exist under ~/.sdkman.
log "SDKMAN + JDK 21 & 17"
if [ ! -d "$HOME/.sdkman" ]; then
  curl -s "https://get.sdkman.io?rcupdate=false" | bash
fi
# auto-answer the "set as default?" prompt so installs don't hang on no TTY
sed -i '' 's/sdkman_auto_answer=false/sdkman_auto_answer=true/' "$HOME/.sdkman/etc/config" 2>/dev/null || true
# shellcheck disable=SC1091
. "$HOME/.sdkman/bin/sdkman-init.sh" 2>/dev/null   # 2>/dev/null: hush a benign bash-3.2 warning
# newest Temurin patch for a major (sdk lists newest-first, so head -1)
tem_latest() { sdk list java 2>/dev/null | grep -oE "$1\.[0-9]+\.[0-9]+(\.[0-9]+)?-tem" | head -1; }
# ponytail: pinned fallbacks if the list parse misses; bump via `sdk list java`
J17=$(tem_latest 17); [ -z "$J17" ] && J17="17.0.13-tem"
J21=$(tem_latest 21); [ -z "$J21" ] && J21="21.0.5-tem"
sdk install java "$J17" || true   # compile target for jdtls
sdk install java "$J21" || true   # runs jdtls (21+); installed last => default `java`

# --- Wire everything into ~/.zshrc (idempotent) ---------------------------
log "Configuring ~/.zshrc"
if grep -q 'nvim-bootstrap (managed)' "$ZSHRC" 2>/dev/null; then
  echo "   Managed block already present — skipped."
else
  cat >> "$ZSHRC" <<EOF

# >>> nvim-bootstrap (managed) >>>
eval "\$($BREW_BIN shellenv)"
export NVM_DIR="\$HOME/.nvm"
[ -s "\$(brew --prefix nvm)/nvm.sh" ] && . "\$(brew --prefix nvm)/nvm.sh"
export PYENV_ROOT="\$HOME/.pyenv"
export PATH="\$PYENV_ROOT/bin:\$PATH"
command -v pyenv >/dev/null && eval "\$(pyenv init - zsh)"
export SDKMAN_DIR="\$HOME/.sdkman"
[ -s "\$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "\$SDKMAN_DIR/bin/sdkman-init.sh"
# <<< nvim-bootstrap (managed) <<<
EOF
  echo "   Added managed block to ~/.zshrc"
fi

log "Done."
echo "   1. Open a NEW terminal (or: source ~/.zshrc)"
echo "   2. Run: nvim   — let lazy.nvim & Mason finish installing, then restart nvim"
echo "   3. Check anytime with: make doctor"
