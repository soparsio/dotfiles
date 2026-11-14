# Troubleshooting

Use this guide to diagnose setup and profile issues without discarding local
configuration. Avoid posting command output that contains personal identities,
tokens, paths, or other machine-specific data.

## Start with the rendered state

Check what chezmoi will manage before applying:

```sh
chezmoi --source "$PWD" status
chezmoi --source "$PWD" diff
```

Edit source files under `home/`, then rerun the diff. Do not edit managed files
in your home directory as the lasting fix; chezmoi can replace those changes.
Use `chezmoi --source "$PWD" apply --verbose` when you need more detail about
an apply operation.

## Bootstrap and missing machine data

The install scripts copy starter data only when a local file does not exist.
If profiles or shared AI instructions are missing, check that the files are in
the source's `home/.chezmoidata/` directory:

```sh
source_root=$(chezmoi source-path)
repo_root=$(dirname "$source_root")
ls "$source_root/.chezmoidata"
```

Copy missing examples without overwriting local files:

```sh
sh "$repo_root/scripts/copy-example-data.sh" "$repo_root"
```

On native Windows, use the PowerShell helper:

```powershell
$sourceRoot = chezmoi source-path
$repoRoot = Split-Path $sourceRoot -Parent
& "$repoRoot/scripts/copy-example-data.ps1" -SourceDir $repoRoot
```

The local profile data file is `home/.chezmoidata/profile.yaml`; the local
assistant defaults file is `home/.chezmoidata/ai.yaml`. Both are machine-local
and ignored by Git.

To confirm which profile IDs chezmoi loaded without printing their settings:

```sh
chezmoi data --format=json |
  python3 -c 'import json,sys; print("\n".join(sorted(json.load(sys.stdin).get("profiles", {}))))'
```

If a value is absent, confirm it is valid YAML and is under the expected
`profiles:` or `ai:` key. Keep personal values out of diagnostic output you
share.

## Applying changes or running setup

Review `chezmoi diff` before applying. Applying may install packages, create
profile state, update VS Code profile storage, or remove profile state that is
no longer configured.

If an apply reports a conflict, preserve the existing destination and inspect
both source and target before deciding which version should win. Do not use
`--force` as a first troubleshooting step.

If profile setup deletes a directory, check whether its profile ID is still
present in `home/.chezmoidata/profile.yaml` and whether that profile has a
non-empty `tools` list. The setup script removes profile directories whose IDs
are no longer configured. Back up any local state before removing a profile
from the data file.

## Profile launch, Git identity, and GitHub authentication

### A profile command uses the wrong identity

Profile Git identity resolves from `profiles.<id>.git.name/email`, then the
profile's `name` and `email`, then global Git configuration. Check the relevant
local profile entry and any `~/.gitconfig.local` override. To inspect the
effective Git identity locally:

```sh
git config --show-origin user.name
git config --show-origin user.email
```

Profile aliases apply identity only to the launched command; they do not
rewrite global Git settings.

### A GitHub CLI profile uses the wrong account

Sign in through the profile alias, then check its authentication state:

```sh
gh <alias> auth login
gh <alias> auth status
```

Profile GH configuration is stored under
`~/.config/profiles/<profile-id>/gh/`. Inherited token variables can override
stored authentication. Check whether an override is set without printing its
value:

```sh
for name in GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN; do
  if printenv "$name" >/dev/null; then printf '%s is set\n' "$name"; fi
done
```

The profile GH alias clears these token overrides when it launches `gh`. For
Git over HTTPS, use `git <alias> <command>` so the selected GH credential
helper is used. SSH remotes continue to use the SSH key selected by SSH.

### A VS Code terminal keeps the previous profile environment

Fully quit all VS Code windows before switching profiles. VS Code may reuse an
already-running process and keep the environment from the first instance.
Launch again with `code-<profile>` after it has exited.

## Assistant instructions and Codex configuration

Profile instruction files are generated from local data. Edit
`home/.chezmoidata/profile.yaml` or `home/.chezmoidata/ai.yaml`, not generated
files under `~/.config/profiles/`. With `force: true`, custom instructions
replace inherited text; otherwise they append. Existing unmanaged instruction
files and custom symlinks are preserved, so an old custom file may keep the
generated instructions from taking effect.

If Codex profile setup reports a conflict, inspect both
`~/.config/codex/config.toml` and
`~/.config/profiles/<profile-id>/codex/config.toml`. The setup helper does not
overwrite a conflicting profile file. Back up the local files, resolve the
settings you want to keep, then apply again.

Some assistant sign-ins use an operating-system credential store or shared
application state. Separate profile directories alone do not guarantee
separate authentication. Check the provider's sign-in behavior before relying
on account isolation.

## VS Code profile setup or settings

The profile setup script refuses to change VS Code profile storage while VS
Code is running. Quit all VS Code windows and rerun:

```sh
chezmoi --source "$PWD" apply
```

The script requires Python 3 and a matching `code`, `code-insiders`, or
`code-oss` CLI. In WSL, it detects when `code` targets Windows and locates
Windows profile storage. For a custom VS Code user-data directory, set
`CHEZMOI_VSCODE_PROFILE_STORAGE_PATH` to its
`User/globalStorage/storage.json` path.

Configured profiles keep settings and extensions profile-specific while
keyboard shortcuts, tasks, MCP servers, snippets, prompts, and language models
inherit from Default. User settings paths vary by platform; WSL may use the
Windows settings path when the Windows CLI is selected.

## Package setup and checks

Package setup depends on the platform's package manager and available
repositories: Homebrew on macOS, supported Linux package managers, or WinGet on
native Windows. Read the script output for the failing package or prerequisite
before rerunning setup.

Run repository checks to validate rendered templates, shell syntax, JSON, and
profile behavior:

```sh
make check
```

The checks require chezmoi, Zsh, Python 3, and Git. Validate assistant-hook
JSON separately with `make check-assistant-configs`. On native Windows, run
those repository checks from an environment with the required tools available.

For general setup instructions, see [README.md](../README.md). For system
components and data flow, see [ARCHITECHTURE.md](../ARCHITECHTURE.md).
