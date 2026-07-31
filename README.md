# systemsetup

Bootstrap scripts for a fresh Debian/Ubuntu box: zsh + [Starship](https://starship.rs/) prompt,
Neovim, and the supporting tooling both depend on. Two variants are provided:

- **`bootstrap.sh`** — the personal version. Applies dotfiles from
  [evsdanmartins/dotfiles](https://github.com/evsdanmartins/dotfiles) (via
  [chezmoi](https://www.chezmoi.io/)) and a Neovim config from
  [evsdanmartins/kickstart.nvim](https://github.com/evsdanmartins/kickstart.nvim), and hardcodes
  git identity.
- **`bootstrap-generic.sh`** — a repo-agnostic version anyone can run as-is. No dotfiles/chezmoi
  step, prompts for git `user.name`/`user.email` instead of hardcoding them, and uses the
  upstream [nvim-lua/kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) as the Neovim
  config (cloned, then its `.git` is removed since it's just a starting point, not a repo to
  track).

## What it installs

| Tool | Why | Script |
|---|---|---|
| build-essential, git, curl, unzip, wget | base toolchain | both |
| zsh, tmux | shell + terminal multiplexer | both |
| ripgrep, fd | used by Neovim (Telescope) | both |
| deadsnakes PPA + Python 3.14 (`python3.14`, `-venv`, `-dev`) | latest Python, side-by-side with system Python | both |
| Homebrew (linuxbrew) | referenced via `brew shellenv` in `.zshrc`; also used to install formulae below | both |
| Homebrew formulae: fzf, k9s, lazydocker, lazygit, libuv, lpeg, luajit, luv, ncurses, neovim, tree-sitter, unibilium, utf8proc, yamlfmt | editor + CLI tooling | both |
| Homebrew cask: copilot-cli | GitHub Copilot CLI | both |
| chezmoi + evsdanmartins/dotfiles | applies personal dotfiles | `bootstrap.sh` only |
| evsdanmartins/kickstart.nvim | personal Neovim config, cloned to `~/.config/nvim` | `bootstrap.sh` only |
| nvim-lua/kickstart.nvim | upstream Neovim config, cloned to `~/.config/nvim` (`.git` stripped after clone) | `bootstrap-generic.sh` only |
| tree-sitter-cli (npm) | kickstart.nvim dependency | `bootstrap-generic.sh` only (bundled with dotfiles in `bootstrap.sh`) |
| Starship | shell prompt | both |
| nvm + Node LTS | JS tooling | both |
| Claude Code CLI (`npm i -g @anthropic-ai/claude-code`) | `claude` command | both |
| uv | provides `~/.local/bin/env` sourced by `.zshrc` | both |
| zoxide | smarter `cd`, used by dotfiles zsh functions | both |
| TPM + tmux plugins | plugins listed in `.tmux.conf` (dracula, tilish, resurrect, ...) | both |
| JetBrainsMono Nerd Font | glyphs for Starship / tmux dracula theme | both |
| Docker Engine (official apt repo) | container runtime; `$USER` added to `docker` group so `docker` runs without `sudo` | both |
| Azure CLI (`az`) + AKS plugin (`az aks install-cli`) | Azure/AKS management; installs `kubectl` + `kubelogin` | both |

zinit (the zsh plugin manager) is **not** installed by this script — your `.zshrc` bootstraps it
itself on first zsh launch (personal dotfiles only; not applicable to `bootstrap-generic.sh`).

## Requirements

- Debian/Ubuntu (or WSL2 Ubuntu) with `apt-get` and `sudo` access
- Internet access
- `bash`

## Usage

```bash
git clone <this-repo-url> systemsetup   # or copy the script over
cd systemsetup
./bootstrap.sh            # personal version (dotfiles + personal nvim config)
# or
./bootstrap-generic.sh    # generic version (prompts for git identity, upstream kickstart.nvim)
```

Then:

```bash
exec zsh                 # switch into zsh now (or just log out/in)
nvim                      # first launch: lazy.nvim installs kickstart plugins
tmux                      # if plugins didn't pull automatically:
                          #   press prefix (C-s) then I to force-install TPM plugins
```

`bootstrap-generic.sh` prompts for your git `user.name`/`user.email` on first run (skipped if
already set globally). `bootstrap.sh` hardcodes them instead.

At the end, if no SSH key exists yet, the script generates one and prints the
**public** key to the terminal — copy it into
[github.com/settings/keys](https://github.com/settings/keys). The private key never leaves the
machine or gets printed. If you already have a key you want to keep, transfer it to
`~/.ssh/id_rsa` *before* running the script (e.g. via a password manager or `scp` from your
old machine) and generation is skipped.

Both scripts are idempotent — re-run either any time, it skips anything already installed.

## Notes / not included

Left out because they're either optional, commented out in the dotfiles, or a no-op without
extra config: Rust/cargo, `asdf`, opencode. Adding any of these is a small addition to either
script if you need them later.

## Troubleshooting

- **Shell didn't switch to zsh**: log out/in fully, or run `chsh -s $(which zsh)` manually and
  check `$SHELL` in a new terminal.
- **Nerd Font glyphs missing in prompt**: set your terminal emulator's font to
  `JetBrainsMono Nerd Font`.
- **tmux plugins missing**: run `~/.tmux/plugins/tpm/bin/install_plugins` manually.
- **`nvm`/`brew` not found in a new shell**: make sure you're in zsh (`echo $SHELL`) — those are
  wired up in the dotfiles `.zshrc`, not in bash.
- **`docker: permission denied`**: group membership needs a fresh login session. Run
  `newgrp docker` or log out/in, then retry.
