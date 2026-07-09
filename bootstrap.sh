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
log "Installing Homebrew (linuxbrew, referenced in dotfiles zshrc)"
if ! have brew && [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ---------------------------------------------------------------------------
log "Installing Homebrew formulae"
if ! have brew; then
  echo "brew not found on PATH, cannot install formulae. Aborting." >&2
  exit 1
fi
BREW_FORMULAE=(fzf k9s lazygit libuv lpeg luajit luv ncurses neovim tree-sitter unibilium utf8proc yamlfmt)
brew install "${BREW_FORMULAE[@]}"

log "Installing Homebrew casks"
brew install --cask copilot-cli

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
log "Installing Claude Code CLI"
if have npm; then
  npm install -g @anthropic-ai/claude-code
else
  warn "npm not found, skipping Claude Code CLI install"
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
log "Installing Docker Engine"
if ! have docker; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  log "Docker already installed, skipping"
fi

log "Adding $USER to docker group (run docker without sudo)"
if ! getent group docker >/dev/null; then
  sudo groupadd docker
fi
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  warn "Added $USER to docker group. Log out/in (or 'newgrp docker') for it to take effect."
fi

# ---------------------------------------------------------------------------
log "Installing Azure CLI"
if ! have az; then
  curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

log "Installing AKS CLI plugin (kubectl + kubelogin via az aks install-cli)"
if ! have kubectl; then
  sudo az aks install-cli
else
  log "kubectl already present, skipping az aks install-cli"
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
