#!/usr/bin/env bash
#
# Fresh-machine bootstrap: zsh + starship + neovim + supporting tooling.
#
# Target: Debian/Ubuntu (apt). Idempotent - safe to re-run.
#
# Usage: ./bootstrap-generic.sh

set -euo pipefail

NERD_FONT="JetBrainsMono"
NVIM_CONFIG_REPO="https://github.com/nvim-lua/kickstart.nvim.git"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> WARN:\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if ! have apt-get; then
  echo "This script targets Debian/Ubuntu (apt-get not found). Aborting." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
log "Configuring git globals"
if ! git config --global user.name >/dev/null 2>&1 || ! git config --global user.email >/dev/null 2>&1; then
  printf 'Enter your git user.name: '
  read -r GIT_NAME
  printf 'Enter your git user.email: '
  read -r GIT_EMAIL
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
else
  log "git user.name/user.email already set, skipping"
fi

# ---------------------------------------------------------------------------
log "Setting up SSH key for GitHub"
SSH_KEY="$HOME/.ssh/id_rsa"
if [ ! -f "$SSH_KEY" ]; then
  printf 'Enter your email address for the SSH key: '
  read -r GIT_EMAIL
  if [ -z "$GIT_EMAIL" ]; then
    echo "Email cannot be empty. Aborting." >&2
    exit 1
  fi
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -t rsa -b 4096 -C "$GIT_EMAIL" -f "$SSH_KEY" -N ""
  chmod 600 "$SSH_KEY"
  chmod 644 "$SSH_KEY.pub"
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add "$SSH_KEY" >/dev/null 2>&1 || true
  echo
  log "Your new SSH public key:"
  echo
  cat "$SSH_KEY.pub"
  echo
  log "Add the key above to https://github.com/settings/keys before continuing."
  printf 'Press ENTER once the key has been added to GitHub... '
  read -r _
  log "Verifying GitHub SSH connection..."
  if ssh -o StrictHostKeyChecking=no -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    log "GitHub SSH authentication confirmed."
  else
    warn "Could not verify GitHub SSH connection. Proceeding anyway — check manually if clone steps fail."
  fi
else
  log "SSH key already exists at $SSH_KEY, skipping generation"
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
log "Adding deadsnakes PPA and installing Python 3.14"
if ! grep -rq deadsnakes /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
  sudo add-apt-repository -y ppa:deadsnakes/ppa
  sudo apt-get update -y
fi
sudo apt-get install -y python3.14 python3.14-venv python3.14-dev python3-pip python3-venv

log "Installing uv"
if [ ! -f "$HOME/.local/bin/env" ]; then
  curl -fsSL https://astral.sh/uv/install.sh | sh
fi

log "Installing pynvim (Python neovim client)"
sudo apt-get install -y python3-pynvim

# ---------------------------------------------------------------------------
log "Installing Homebrew (linuxbrew)"
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
BREW_FORMULAE=(fzf k9s lazydocker lazygit libuv lpeg luajit luv ncurses neovim tree-sitter unibilium utf8proc yamlfmt)
brew install "${BREW_FORMULAE[@]}"

log "Installing Homebrew casks"
brew install --cask copilot-cli

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
  npm install -g @anthropic-ai/claude-code neovim
else
  warn "npm not found, skipping Claude Code CLI install"
fi

# ---------------------------------------------------------------------------
log "Installing tree-sitter-cli (kickstart.nvim dependency)"
if have npm; then
  npm install -g tree-sitter-cli
else
  warn "npm not found, skipping tree-sitter-cli install"
fi

# ---------------------------------------------------------------------------
log "Installing kickstart.nvim as neovim config"
NVIM_DIR="$HOME/.config/nvim"
if [ -d "$NVIM_DIR" ] && [ -n "$(ls -A "$NVIM_DIR" 2>/dev/null)" ]; then
  log "$NVIM_DIR already exists and is non-empty, skipping kickstart.nvim clone"
else
  git clone --depth 1 "$NVIM_CONFIG_REPO" "$NVIM_DIR"
  rm -rf "$NVIM_DIR/.git"
fi

log "Installing neovim plugins via lazy.nvim (headless)"
nvim --headless "+Lazy! sync" +qa 2>/dev/null || warn "lazy.nvim sync returned non-zero, open nvim manually to check"

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
log "Open nvim once to let lazy.nvim (kickstart) install plugins: nvim +Lazy"
log "Run 'az login' to authenticate the Azure CLI."
