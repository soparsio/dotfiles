# /DOTFILES

Personal shell, command-line, editor, and AI assistant configuration managed
with [chezmoi](https://www.chezmoi.io/). The shell configuration uses Zsh and
supports macOS, Linux, WSL, and native Windows.

## Table of Contents

- [Overview & Stack](#overview--stack)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Core Keybindings](#core-keybindings)
- [Packages, editors, & tools](#packages-editors--tools)
- [Local Overrides, AI, & Secrets](#local-overrides-ai--secrets)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Overview & Stack

This repository keeps configuration sources separate from files installed in
your home directory. Chezmoi renders templates and manages updates; platform
scripts install packages and configure profile-specific CLI and application
state.

| Area                        | Tools and configuration                                                                  |
| --------------------------- | ---------------------------------------------------------------------------------------- |
| Shell                       | Zsh startup files, aliases, helper functions, environment exports, Atuin, and Starship   |
| Package and tool management | Homebrew, Linux package managers, WinGet, and mise                                       |
| Editors and terminals       | Vim, Neovim, Visual Studio Code, and Ghostty                                             |
| Git and GitHub              | Shared Git settings and isolated Git/GitHub CLI profiles                                 |
| AI tools                    | Codex, Claude Code, GitHub Copilot, Gemini CLI, Cline, Continue, Cursor, and Antigravity |
| Platforms                   | macOS, Linux, WSL, and native Windows                                                    |

Managed configuration is applied to your home directory. Review the rendered
changes with `chezmoi diff` before running `chezmoi apply`.

## Repository Structure

`.chezmoiroot` sets `home/` as the chezmoi source root. Chezmoi filename
attributes map source names to destination paths: for example,
`home/dot_zshrc` becomes `~/.zshrc`, and `home/dot_config/zsh/` becomes
`~/.config/zsh/`. The `.tmpl` suffix marks a template; `private_` marks
private files.

```text
.
├── .agents/skills/dotfiles/   Dotfiles workflows and references
├── examples/.chezmoidata/     Safe starter files for local machine data
├── docs/                      Installation, package, shell, checks, and recovery guides
├── ARCHITECHTURE.md           System and data-flow overview
├── CONTRIBUTING.md            Contribution workflow and validation
├── CODE_OF_CONDUCT.md         Community expectations and reporting
├── home/                      Managed chezmoi source
│   ├── .chezmoiscripts/       Platform setup and profile scripts
│   ├── .chezmoitemplates/     Shared template fragments
│   ├── .chezmoidata.yaml      Tracked shared template defaults
│   └── dot_config/            Git, Zsh, mise, editor, and app settings
├── scripts/                   Checks and setup helpers
├── install.sh                 macOS, Linux, and WSL bootstrap
├── install.ps1                Native Windows bootstrap
├── Makefile                   Repository checks
└── README.md
```

Machine-specific data belongs in the ignored `home/.chezmoidata/` directory
or in `~/.config/chezmoi/chezmoi.yaml`; do not put it in shared templates.

## Quick Start

### Platform support

| Platform       | Setup                                                                                                                                                                                         |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| macOS          | Use the POSIX bootstrap. Homebrew manages packages and applications; GitHub CLI settings use `~/.config/gh/`.                                                                                 |
| Linux          | Use the POSIX bootstrap. Package setup supports apt, dnf, pacman, and zypper where packages are available; GitHub CLI settings use `~/.config/gh/`.                                           |
| WSL            | Use the Linux bootstrap and package setup; desktop app installation is skipped. VS Code settings can target Windows when `code` resolves to the Windows CLI.                                  |
| Native Windows | Use the PowerShell bootstrap. WinGet installs packages and a user-local Cygwin environment provides Zsh. GitHub CLI configuration is at `%APPDATA%\GitHub CLI\config.yml`; Vim uses `_vimrc`. |

OrbStack is macOS-only. Ghostty is not available as an official Windows
application. Application and package behavior is defined in
`home/.chezmoiscripts/` and `home/.chezmoidata/packages.yaml`.

### macOS, Linux, or WSL

Run the bootstrap script from GitHub:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/soparsio/dotfiles/main/install.sh)"
```

### Native Windows

Run the PowerShell bootstrap:

```powershell
powershell -NoProfile -Command "Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/soparsio/dotfiles/main/install.ps1')"
```

The scripts use an existing chezmoi installation or install it when needed
(with Homebrew on macOS when available, otherwise in a user-local location),
initialize the repository, copy missing examples for local data, show a
preview, and ask before applying. Existing local data files are preserved. Git
is required; the POSIX script also needs `curl` if chezmoi is not already
available.

To use an existing chezmoi installation manually:

```sh
chezmoi init soparsio/dotfiles
source_root=$(chezmoi source-path)
repo_root=$(dirname "$source_root")
sh "$repo_root/scripts/copy-example-data.sh" "$repo_root"
chezmoi diff
chezmoi apply
```

On Windows, copy examples with:

```powershell
$sourceRoot = chezmoi source-path
$repoRoot = Split-Path $sourceRoot -Parent
& "$repoRoot/scripts/copy-example-data.ps1" -SourceDir $repoRoot
chezmoi diff
chezmoi apply
```

For a local checkout, run `./install.sh` from the repository root, or
`powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1` in
PowerShell. Both scripts use the checkout as the chezmoi source.

Applying configuration can install packages using the native package manager:
Homebrew on macOS, apt/dnf/pacman/zypper on supported Linux distributions, and
WinGet on native Windows. Review the diff before applying.

## Documentation

This README is the entry point for installation, platform support, profiles,
daily shell shortcuts, and checks. Use the reference guides for additional
detail:

- **[Architechture Overview](./ARCHITECHTURE.md)** — Source and data flow,
  template rendering, apply lifecycle, profile setup, platform boundaries,
  and validation.
- **[Installation & Bootstrap Guide](./docs/installation.md)** — First-time
  setup from GitHub or a local checkout, manual initialization, and safe
  updates.
- **[Keybindings Cheat Sheet](./docs/keybindings.md)** — Zsh aliases,
  helper functions, Docker commands, and generated profile launchers.
- **[Packages](./docs/packages.md)** — Shared mise tools and platform-specific
  editor/application configuration, package inventories, and install behavior.
- **[Shell Functions & CLI Utilities](./docs/shell.md)** — Zsh startup flow,
  environment setup, helper functions, and profile-aware commands.
- **[Customization & Local Overrides](./docs/customization.md)** — Local data,
  profile identities, assistant instructions, and credential safety.
- **[Testing](./docs/checks.md)** — Local validation targets, prerequisites,
  coverage, and GitHub Actions behavior.
- **[Contributing](./CONTRIBUTING.md)** — Repository conventions, validation,
  and pull request guidance.
- **[Code of Conduct](./CODE_OF_CONDUCT.md)** — Participation expectations,
  reporting, and enforcement.
- **[Troubleshooting & FAQ](./docs/troubleshooting.md)** — Safe diagnostics and
  recovery guidance for chezmoi, profiles, authentication, VS Code, and
  packages.

The `docs/` directory contains repository documentation only; those files are
not managed or installed into the home directory. Reusable starter data is in
[`examples/.chezmoidata/`](examples/.chezmoidata/), while actual managed
configuration sources are under `home/`.

## Core Keybindings

These are terminal commands and aliases, not editor keyboard-chord mappings.
They are defined in `home/dot_config/zsh/aliases.zsh.tmpl` and
`home/dot_config/zsh/functions.zsh.tmpl`.

| Command                              | Action                                                              |
| ------------------------------------ | ------------------------------------------------------------------- |
| `..`, `...`, `....`                  | Move up one, two, or three directories                              |
| `la`, `ll`                           | List all entries, or a detailed listing                             |
| `gs`, `gd`, `gds`                    | Git status, diff, and staged diff                                   |
| `ga`, `gco`, `gcm`                   | Git add, checkout, and commit with a message                        |
| `gb`, `gl`, `gpl`, `gp`              | Git branches, graph log, fast-forward pull, and push                |
| `ws`                                 | Change to the configured workspace directory                        |
| `mkcd DIR`, `up [COUNT]`, `croot`    | Create-and-enter a directory, move up levels, or go to the Git root |
| `extract ARCHIVE`                    | Extract a supported archive into the current directory              |
| `reload`                             | Reload `~/.zshrc`                                                   |
| `code-<profile>`, `<tool>-<profile>` | Launch a configured VS Code or CLI profile                          |

Docker aliases include `dps`, `dcu`, and `dcd`. Profile launchers are generated
for enabled tools; exact names depend on the machine-local profile file.

## Packages, editors, & tools

The package inventory and setup behavior are documented in
[Packages](./docs/packages.md). In brief, mise manages runtimes and CLI tools,
while Homebrew, supported Linux package managers, or WinGet manage platform
packages and applications. The editor setting defaults to `code --wait` and
can be overridden per machine.

## Local Overrides, AI, & Secrets

- [Shared and machine-specific settings](#shared-and-machine-specific-settings)
- [Assistant instructions](#assistant-instructions)
- [Keep credentials out of configuration](#keep-credentials-out-of-configuration)

### Shared and machine-specific settings

Tracked defaults are in `home/.chezmoidata.yaml`. Override values per machine
in `~/.config/chezmoi/chezmoi.yaml`, for example:

```yaml
data:
  ollamaHost: 127.0.0.1:11434
  workspaceDir: Workspace
  editor: code --wait
```

`ollamaHost` sets the Ollama endpoint, `workspaceDir` controls the `ws` helper,
and `editor` sets the editor used by Zsh and Git. The default editor is
`code --wait`.

### Assistant instructions

Copy [`examples/.chezmoidata/ai.yaml.example`](examples/.chezmoidata/ai.yaml.example)
to the ignored local `home/.chezmoidata/ai.yaml` to customize shared
instructions. Profile-level instructions can be set with
`profiles.instructions` or `profiles.<id>.instructions`. The
`profiles.<id>.ai.instructions` value applies to all AI tools in that profile;
`profiles.<id>.<tool>.instructions` applies to one tool. By default,
instructions append to inherited text. Set `force: true` to replace it.

### Keep credentials out of configuration

- Keep profile identities, real email addresses, local AI instructions, and
  machine-specific values in ignored local data or
  `~/.config/chezmoi/chezmoi.yaml`.
- Keep Git-only overrides in `~/.gitconfig.local` only if you have configured
  Git to include that file; this repository does not include it by default.
- Never commit tokens, credentials, private keys, or runtime state. Starter
  examples use placeholders and are safe to customize locally.
- GitHub CLI credentials may be stored in the operating system credential
  manager. Profile directories isolate configuration, but Copilot CLI or Claude
  Code authentication can have platform- or sign-in-specific exceptions.
- Environment variables such as `GH_TOKEN`, `GITHUB_TOKEN`, or
  `COPILOT_GITHUB_TOKEN` may override stored sign-in state. Keep credentials in
  a local secret store or environment, not this repository.

For profiles and identities, local data, assistant instructions, and
credentials, see [Customization & Local Overrides](./docs/customization.md).

## Testing

Run `make check` after changing shell files, templates, or managed JSON. It
validates rendered configuration without applying it. See
[Checks](./docs/checks.md) for prerequisites, test coverage, and other targets.

## Troubleshooting

- **Unexpected file changes:** Run `chezmoi diff` and inspect the rendered
  targets before applying. Edit sources under `home/`, not managed files in
  your home directory.
- **VS Code profile setup refuses to run:** Quit every VS Code window before
  `chezmoi apply`. VS Code can reuse an existing process and keep its original
  environment or profile state.
- **A profile uses the wrong GitHub account:** Sign in through that profile's
  alias (`gh <alias> auth login`) and check for overriding `GH_TOKEN` or
  `GITHUB_TOKEN` variables. For GitHub CLI, inspect the profile's
  `~/.config/profiles/<id>/gh/` configuration.
- **Git identity is unexpected:** Check `profiles.<id>.git`, profile-level
  `name`/`email`, global Git configuration, and any separately configured
  include such as `~/.gitconfig.local`. Profile identity overrides do not change
  global Git configuration.
- **Codex profile setup reports a conflict:** Review existing
  `~/.config/profiles/<id>/codex/config.toml` files. Setup preserves conflicting
  files rather than overwriting them.
- **Checks fail:** Confirm chezmoi, Zsh, Python 3, and Git are installed, then
  rerun `make check` for the detailed failing check.

For detailed diagnostics and platform-specific recovery steps, see
[docs/troubleshooting.md](docs/troubleshooting.md).
