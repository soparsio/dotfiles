# Installation & Bootstrap Guide

This guide covers first-time setup, local-checkout setup, and safe updates.
Chezmoi renders configuration from the repository and applies it to your home
directory; setup scripts can also install packages and update application
state.

## Requirements

| Platform       | Required or useful tools                                                                                |
| -------------- | ------------------------------------------------------------------------------------------------------- |
| macOS          | Git; Homebrew is used when available. `curl` is needed to bootstrap chezmoi if Homebrew is unavailable. |
| Linux / WSL    | Git and `curl`; package setup may require `sudo` or root access.                                        |
| Native Windows | Git and PowerShell; WinGet is required for package installation during apply.                           |

Profile setup for VS Code also requires Python 3 and a matching `code`,
`code-insiders`, or `code-oss` command. VS Code must be closed when its profile
storage is being changed.

## Bootstrap from GitHub

On macOS, Linux, or WSL:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/soparsio/dotfiles/main/install.sh)"
```

On native Windows, run from PowerShell:

```powershell
powershell -NoProfile -Command "Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/soparsio/dotfiles/main/install.ps1')"
```

The installers use or install chezmoi, initialize the repository, copy starter
files only when local machine-data files are missing, show a rendered diff,
and ask before applying. Answer `y` or `yes` to apply; any other response
leaves the home directory unchanged.

## Install from a local checkout

Run the bootstrap in the checkout root:

```sh
./install.sh
```

On Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

These commands use the checkout as the chezmoi source. They still copy missing
example data and preview the rendered changes before asking to apply.

## Manual setup and updates

If chezmoi is already installed, initialize the repository:

```sh
chezmoi init soparsio/dotfiles
source_root=$(chezmoi source-path)
repo_root=$(dirname "$source_root")
sh "$repo_root/scripts/copy-example-data.sh" "$repo_root"
chezmoi diff
chezmoi apply
```

On Windows:

```powershell
chezmoi init soparsio/dotfiles
$sourceRoot = chezmoi source-path
$repoRoot = Split-Path $sourceRoot -Parent
& "$repoRoot/scripts/copy-example-data.ps1" -SourceDir $repoRoot
chezmoi diff
chezmoi apply
```

`chezmoi source-path` points to the `home/` source root because `.chezmoiroot`
selects that directory; the example-copy scripts live at the repository root.
The helper preserves any local data files that already exist.

For ongoing updates, review the diff before applying:

```sh
chezmoi diff
chezmoi apply
```

When working in a local checkout, specify its root if it is not already the
configured source:

```sh
chezmoi --source "$PWD" diff
chezmoi --source "$PWD" apply
```

## Before applying

- Inspect the diff. Applying can install software through Homebrew, a supported
  Linux package manager, or WinGet.
- Review local profile changes before removing or renaming profiles. Profile
  setup removes state directories for profile IDs that are no longer configured.
- Quit all VS Code windows before applying changes that update VS Code profile
  storage.
- Keep personal identities and credentials in local ignored data or a secret
  store. See [Customization & Local Overrides](customization.md).

For package inventories and platform behavior, see [Packages](packages.md). For
installation problems, see [Troubleshooting & FAQ](troubleshooting.md).
