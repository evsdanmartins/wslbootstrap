# systemsetup

Bootstrap script for a fresh Debian/Ubuntu box: zsh + [Starship](https://starship.rs/) prompt,
dotfiles from [evsdanmartins/dotfiles](https://github.com/evsdanmartins/dotfiles) (applied via
[chezmoi](https://www.chezmoi.io/)), Neovim config from
[evsdanmartins/kickstart.nvim](https://github.com/evsdanmartins/kickstart.nvim), and the
supporting tooling both depend on.

## What it installs

| Tool | Why |
|---|---|
| build-essential, git, curl, unzip, wget | base toolchain |
| zsh, tmux | shell + terminal multiplexer |
| ripgrep, fd | used by Neovim (Telescope) |
| Homebrew (linuxbrew) | referenced via `brew shellenv` in `.zshrc`; also used to install formulae below |
| Homebrew formulae: fzf, k9s, lazygit, libuv, lpeg, luajit, luv, ncurses, neovim, tree-sitter, unibilium, utf8proc, yamlfmt | editor + CLI tooling |
| Homebrew cask: copilot-cli | GitHub Copilot CLI |
| chezmoi | applies the dotfiles repo |
| kickstart.nvim | cloned to `~/.config/nvim` |
| Starship | shell prompt |
| nvm + Node LTS | JS tooling |
| Claude Code CLI (`npm i -g @anthropic-ai/claude-code`) | `claude` command |
| uv | provides `~/.local/bin/env` sourced by `.zshrc` |
| zoxide | smarter `cd`, used by dotfiles zsh functions |
| TPM + tmux plugins | plugins listed in `.tmux.conf` (dracula, tilish, resurrect, ...) |
| JetBrainsMono Nerd Font | glyphs for Starship / tmux dracula theme |
| Docker Engine (official apt repo) | container runtime; `$USER` added to `docker` group so `docker` runs without `sudo` |
| Azure CLI (`az`) + AKS plugin (`az aks install-cli`) | Azure/AKS management; installs `kubectl` + `kubelogin` |

zinit (the zsh plugin manager) is **not** installed by this script — your `.zshrc` bootstraps it
itself on first zsh launch.

## Requirements

- Debian/Ubuntu (or WSL2 Ubuntu) with `apt-get` and `sudo` access
- Internet access
- `bash`

## Usage

```bash
git clone <this-repo-url> systemsetup   # or copy bootstrap.sh over
cd systemsetup
./bootstrap.sh
```

Then:

```bash
exec zsh                 # switch into zsh now (or just log out/in)
nvim                      # first launch: lazy.nvim installs kickstart plugins
tmux                      # if plugins didn't pull automatically:
                          #   press prefix (C-s) then I to force-install TPM plugins
```

At the end, if no `~/.ssh/id_ed25519` key exists yet, the script generates one and prints the
**public** key to the terminal — copy it into
[github.com/settings/keys](https://github.com/settings/keys). The private key never leaves the
machine or gets printed. If you already have a key you want to keep, transfer it to
`~/.ssh/id_ed25519` *before* running the script (e.g. via a password manager or `scp` from your
old machine) and generation is skipped.

The script is idempotent — re-run it any time, it skips anything already installed.

## Notes / not included

Left out because they're either optional, commented out in the dotfiles, or a no-op without
extra config: `kubectl`, Rust/cargo, `asdf`, opencode. Adding any of these is a small addition
to `bootstrap.sh` if you need them later.

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
