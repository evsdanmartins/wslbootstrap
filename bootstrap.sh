#!/usr/bin/env bash
#
# Fresh-machine bootstrap: zsh + starship + chezmoi dotfiles (evsdanmartins/dotfiles)
# + neovim (evsdanmartins/kickstart.nvim) + supporting tooling.
#
# Target: Debian/Ubuntu (apt). Idempotent - safe to re-run.
#
# Usage: ./bootstrap.sh

set -euo pipefail

DOTFILES_REPO="https://github.com/evsdanmartins/dotfiles.git"
NVIM_CONFIG_REPO="https://github.com/evsdanmartins/kickstart.nvim.git"
NVIM_VERSION="v0.10.2"
NERD_FONT="JetBrainsMono"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> WARN:\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if ! have apt-get; then
  echo "This script targets Debian/Ubuntu (apt-get not found). Aborting." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
log "Updating apt and installing base packages"
sudo apt-get update -y
sudo apt-get install -y \
  build-essential curl file git unzip zip wget gpg ca-certificates \
  software-properties-common zsh tmux fontconfig xclip \
  ripgrep fd-find

# fd is packaged as fdfind on Debian/Ubuntu; expose it as `fd`
if have fdfind && ! have fd; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# ---------------------------------------------------------------------------
log "Installing Neovim ${NVIM_VERSION} to /opt/nvim (matches PATH in dotfiles zshrc)"
if [ ! -x /opt/nvim/bin/nvim ] || ! /opt/nvim/bin/nvim --version | head -1 | grep -q "${NVIM_VERSION#v}"; then
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  NVIM_TARBALL="nvim-linux-x86_64.tar.gz" ;;
    aarch64) NVIM_TARBALL="nvim-linux-arm64.tar.gz" ;;
    *) echo "Unsupported arch for nvim prebuilt binary: $ARCH" >&2; exit 1 ;;
  esac
  TMP_TGZ="$(mktemp)"
  curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${NVIM_TARBALL}" -o "$TMP_TGZ"
  sudo rm -rf /opt/nvim
  sudo mkdir -p /opt/nvim
  sudo tar -xzf "$TMP_TGZ" -C /opt/nvim --strip-components=1
  rm -f "$TMP_TGZ"
else
  log "Neovim already up to date, skipping"
fi
export PATH="$PATH:/opt/nvim/bin"

# ---------------------------------------------------------------------------
log "Installing chezmoi"
if ! have chezmoi; then
  sh -c "$(curl -fsSL get.chezmoi.io)" -- -b "$HOME/.local/bin"
fi
export PATH="$HOME/.local/bin:$PATH"

log "Applying dotfiles from ${DOTFILES_REPO} via chezmoi"
chezmoi init --apply "$DOTFILES_REPO"

# ---------------------------------------------------------------------------
log "Cloning kickstart.nvim config to ~/.config/nvim"
if [ -d "$HOME/.config/nvim" ] && [ ! -d "$HOME/.config/nvim/.git" ]; then
  mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%s 2>/dev/null || echo backup)"
fi
if [ ! -d "$HOME/.config/nvim/.git" ]; then
  git clone "$NVIM_CONFIG_REPO" "$HOME/.config/nvim"
else
  log "~/.config/nvim already a git repo, skipping clone"
fi

# ---------------------------------------------------------------------------
log "Installing Starship prompt"
if ! have starship; then
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
fi

# ---------------------------------------------------------------------------
log "Installing Homebrew (linuxbrew, referenced in dotfiles zshrc)"
if ! have brew && [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# ---------------------------------------------------------------------------
log "Installing nvm + latest LTS Node.js"
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
if have nvm; then
  nvm install --lts
  nvm alias default 'lts/*'
fi

# ---------------------------------------------------------------------------
log "Installing uv (provides ~/.local/bin/env sourced by dotfiles zshrc)"
if [ ! -f "$HOME/.local/bin/env" ]; then
  curl -fsSL https://astral.sh/uv/install.sh | sh
fi

# ---------------------------------------------------------------------------
log "Installing zoxide"
if ! have zoxide; then
  curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

# ---------------------------------------------------------------------------
log "Installing fzf"
if [ ! -d "$HOME/.fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
fi

# ---------------------------------------------------------------------------
log "Installing lazygit (handy with nvim/tmux workflow)"
if ! have lazygit; then
  LG_VERSION="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -Po '"tag_name": *"v\K[^"]*')"
  LG_ARCH="$(uname -m)"; [ "$LG_ARCH" = "aarch64" ] && LG_ARCH="arm64" || LG_ARCH="x86_64"
  TMP_TAR="$(mktemp -d)"
  curl -fsSL "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_VERSION}_Linux_${LG_ARCH}.tar.gz" -o "$TMP_TAR/lazygit.tar.gz"
  tar -xzf "$TMP_TAR/lazygit.tar.gz" -C "$TMP_TAR" lazygit
  sudo install "$TMP_TAR/lazygit" /usr/local/bin
  rm -rf "$TMP_TAR"
fi

# ---------------------------------------------------------------------------
log "Installing tmux plugin manager (TPM) + plugins"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
"$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "tmux plugin install returned non-zero, check manually with prefix+I"

# ---------------------------------------------------------------------------
log "Installing Nerd Font (${NERD_FONT}) for prompt/tmux glyphs"
FONT_DIR="$HOME/.local/share/fonts/${NERD_FONT}NerdFont"
if [ ! -d "$FONT_DIR" ]; then
  mkdir -p "$FONT_DIR"
  TMP_FONT="$(mktemp -d)"
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${NERD_FONT}.zip" -o "$TMP_FONT/font.zip"
  unzip -oq "$TMP_FONT/font.zip" -d "$FONT_DIR"
  rm -rf "$TMP_FONT"
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
log "Setting zsh as default shell"
ZSH_PATH="$(command -v zsh)"
if [ "$SHELL" != "$ZSH_PATH" ]; then
  if ! grep -q "$ZSH_PATH" /etc/shells; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  fi
  sudo chsh -s "$ZSH_PATH" "$USER"
fi

# ---------------------------------------------------------------------------
log "Done. Log out/in (or run 'exec zsh') to start zsh."
log "First zsh launch will auto-clone zinit and its plugins (see ~/.zshrc)."
log "Open nvim once to let lazy.nvim (kickstart) install plugins: nvim +Lazy"
