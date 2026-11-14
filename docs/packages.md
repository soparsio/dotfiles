# Packages

Package declarations are maintained in the tracked
`home/.chezmoidata/packages.yaml` inventory. Platform setup scripts read that
data to install system packages, desktop applications, and mise-managed tools.
The inventory is shared configuration, not machine-local secret data.

Applying changes can install software, configure package repositories, and
require administrator privileges. Review `chezmoi diff` and package-script
output before applying.

## Shared tools

The common mise inventory includes:

| Tool                                                   | Version                                             |
| ------------------------------------------------------ | --------------------------------------------------- |
| Node.js                                                | `24.21.0`                                           |
| Bun                                                    | `latest`                                            |
| Go                                                     | `latest`                                            |
| Python                                                 | `3.15.2`                                            |
| ripgrep, shfmt, Atuin, Starship                        | `latest`                                            |
| Codex CLI, Claude Code, Gemini CLI, GitHub Copilot CLI | Latest npm packages, installed through Bun and mise |

Mise is installed with its official installer on macOS and Linux and with
WinGet on Windows. The after-install script installs Bun first, then invokes
`mise install` for the configured tools. Ollama uses Homebrew on macOS, its
official installer on Linux/WSL, and WinGet on native Windows.

## Editors and application configuration

### Editor preference

The shared `editor` default is `code --wait`. Override it in
`~/.config/chezmoi/chezmoi.yaml`; Zsh exports the selected value as `EDITOR`,
`VISUAL`, and `GIT_EDITOR`.

### Vim and Neovim

Vim configuration is installed as `~/.vimrc` on Unix-like systems and
`~/_vimrc` on Windows. Neovim uses `~/.config/nvim/init.vim`. The Vim settings
share a template fragment so the platform-specific destinations stay aligned.

### Visual Studio Code

VS Code settings are managed at platform-specific user settings paths. In WSL,
the setup mirrors settings to Windows when `code` resolves to the Windows CLI.
Settings and extensions remain profile-specific; keyboard shortcuts, tasks,
MCP servers, snippets, prompts, and language models inherit from the Default
profile.

The profile setup updates VS Code's internal profile storage. Quit all VS Code
windows before applying profile changes; it requires Python 3 and a matching
`code`, `code-insiders`, or `code-oss` CLI.

### Codex, Atuin, and Starship

Codex defaults are shared under `~/.config/codex/config.toml`, while profile
state uses separate `CODEX_HOME` directories. Setup preserves conflicting
profile config files rather than replacing them. Some sign-in flows may still
use shared operating-system or application credential storage.

Atuin and Starship settings are managed under `~/.config/`. The Zsh integration
sets `ATUIN_CONFIG_DIR` to `~/.config/atuin/` and does not replace an existing
`~/.atuin/config.toml`.

## Platform inventory

| Platform                | System packages and applications                                                                                                            |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| macOS                   | Homebrew formulas: GitHub CLI, Git, Neovim, Ollama, and Zsh. Casks: Ghostty, Chrome, OrbStack, Cursor, Obsidian, and Visual Studio Code.    |
| Linux / apt             | Base certificates, curl, Git, GnuPG, Neovim, and Zsh; GitHub CLI; Visual Studio Code, Chrome, Cursor, Obsidian, and Ghostty when available. |
| Linux / dnf             | Base certificates, curl, Git, Neovim, and Zsh; GitHub CLI; Visual Studio Code, Chrome, Cursor, and Ghostty when available.                  |
| Linux / pacman          | Base certificates, curl, Git, GitHub CLI, Neovim, and Zsh; Ghostty when available.                                                          |
| Linux / zypper          | Base certificates, curl, Git, Neovim, and Zsh; GitHub CLI; Ghostty when available.                                                          |
| Native Windows / WinGet | mise, Git, GitHub CLI, Neovim, Ollama, Visual Studio Code, Chrome, Cursor, and Obsidian.                                                    |
| Native Windows / Cygwin | Zsh, Git, and curl; Oh My Zsh is installed after applying the managed Zsh configuration.                                                    |

Linux desktop application availability varies by distribution and repository.
For Debian-based systems, setup downloads vendor packages for applications
that are not available in the configured repositories. WSL skips Linux desktop
applications; use Windows GUI applications there. OrbStack is macOS-only and
Ghostty has no official Windows application.

## Installation behavior

- Package scripts are `run_onchange` scripts. Changes to package inventory
  data update their rendered contents and trigger them on apply.
- macOS setup uses Homebrew. Linux setup supports apt, dnf, pacman, and zypper;
  root permissions are required for system package operations.
- Native Windows package setup requires WinGet. The Cygwin and Oh My Zsh setup
  steps prepare Zsh after system packages are available.
- Existing installations are generally detected before install. Version
  handling follows each platform script's package-manager options; WinGet uses
  `--no-upgrade`, while mise uses the versions in the shared tool inventory.

To change the shared package set, edit `home/.chezmoidata/packages.yaml`.
Runtime versions and global tool settings are rendered into
`home/dot_config/mise/config.toml.tmpl`. Run `make check` after changing the
inventory or templates, then review the rendered `chezmoi diff`.
