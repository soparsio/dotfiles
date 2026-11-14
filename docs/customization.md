# Customization and Local Overrides

Use local overrides for machine-specific preferences, identities, and
instructions. Keep shared, portable defaults in tracked source files and keep
credentials out of the repository.

## Choose where a value belongs

| Value                                               | Location                                                       | Tracked? |
| --------------------------------------------------- | -------------------------------------------------------------- | -------- |
| Defaults shared across machines                     | `home/.chezmoidata.yaml`                                       | Yes      |
| Host-specific chezmoi data                          | `~/.config/chezmoi/chezmoi.yaml`                               | No       |
| Profile identities, tools, and profile instructions | `home/.chezmoidata/profile.yaml`                               | No       |
| Shared local AI instructions                        | `home/.chezmoidata/ai.yaml`                                    | No       |
| Optional Git-only overrides                         | `~/.gitconfig.local` (only if you configure Git to include it) | No       |
| Authentication tokens and private keys              | OS credential manager or local secret store                    | No       |

The `.chezmoiroot` file sets `home/` as the chezmoi source root. In the
examples below, `chezmoi source-path` returns that source root; example-copy
scripts are one directory above it, at the repository root.

## Create the local data files

After initializing chezmoi, copy any missing starter files:

```sh
source_root=$(chezmoi source-path)
repo_root=$(dirname "$source_root")
sh "$repo_root/scripts/copy-example-data.sh" "$repo_root"
```

On native Windows, use PowerShell:

```powershell
$sourceRoot = chezmoi source-path
$repoRoot = Split-Path $sourceRoot -Parent
& "$repoRoot/scripts/copy-example-data.ps1" -SourceDir $repoRoot
```

The helper copies examples into `home/.chezmoidata/` only when the destination
does not already exist. Edit those local files; rerunning the helper will not
replace them. The directory's Git ignore rules exclude local data except for
`.gitignore` and the tracked `packages.yaml`.

To confirm a local file is ignored without displaying its contents:

```sh
git -C "$repo_root" check-ignore -v home/.chezmoidata/profile.yaml
```

## Set host-specific chezmoi data

Add machine-only values to `~/.config/chezmoi/chezmoi.yaml` under `data:`.
These values override shared defaults for templates on this machine:

```yaml
data:
  editor: code --wait
  ollamaHost: 127.0.0.1:11434
  workspaceDir: Workspace
  profilesDir: .config/profiles
  defaultProfile: personal
```

- `editor` sets the editor used by Zsh and Git.
- `ollamaHost` supplies the Ollama endpoint when `OLLAMA_HOST` is not already
  set in the environment.
- `workspaceDir` controls the `ws` shell helper.
- `profilesDir` selects the home-relative location for profile state.
- `defaultProfile` selects the VS Code profile used by plain `code`. Set it to
  `Default` for VS Code's built-in profile, or to a configured profile ID that
  enables `vscode`.

The local chezmoi config template sets `machine` and `os` from the detected
hostname and operating system. Normally, leave those values to auto-detection.
Shared defaults are maintained in `home/.chezmoidata.yaml`; do not put one
machine's personal values there.

## Configure profiles and identities

Customize `home/.chezmoidata/profile.yaml`. The example file uses placeholder
names and addresses:

```yaml
name: Your Name
email: you@example.com
profiles:
  personal:
    name: Your Personal Name
    email: you@example.com
    alias: personal
    tools: [codex, gh, git, vscode]
    gh:
      username: your-github-username
```

Profile IDs are stable directory names under `profilesDir`. Use letters,
numbers, dots, underscores, or hyphens; keep IDs stable because they name
profile state directories. The `name` and `email` fields provide Git identity
fallbacks. `alias` controls the Git and GitHub CLI command aliases and defaults
to the profile ID. The optional profile `name` also selects the native VS Code
profile name. `gh.username` is account metadata, not a credential; authenticate
separately with `gh <alias> auth login`.

### Tools and launchers

Profiles may enable `codex`, `claude`, `copilot`, `gemini`, `gh`, `git`,
`vscode`, and `antigravity`. Tools with separate CLI state use directories
under `$HOME/<profilesDir>/<profile-id>/`:

| Tool               | State or launch behavior                                                                                                                       |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Codex              | Uses `CODEX_HOME` pointing to the profile's `codex/` directory.                                                                                |
| Claude Code        | Uses `CLAUDE_CONFIG_DIR` pointing to the profile's `claude/` directory.                                                                        |
| GitHub Copilot CLI | Uses `COPILOT_HOME` pointing to the profile's `copilot/` directory.                                                                            |
| Gemini CLI         | Uses `GEMINI_CLI_HOME` pointing to the profile's `gemini/` directory.                                                                          |
| GitHub CLI         | Uses `GH_CONFIG_DIR` pointing to the profile's `gh/` directory and clears inherited GitHub token overrides for the launch.                     |
| Git                | Applies the configured Git identity only to the launched Git command; Git over HTTPS uses the selected profile's GitHub CLI credential helper. |
| VS Code            | Opens the configured native VS Code profile and sets profile-aware environment for enabled tools.                                              |

`antigravity` is accepted in profile data, but does not have a generated
`profile-use` launcher.

Generated Zsh launchers use names such as `codex-personal` and
`code-personal`; Git and GitHub CLI aliases use commands such as
`git personal status` and `gh personal auth status` (replace `personal` with
the configured alias). Exact names depend on the local profile file.

Use `profile-use TOOL PROFILE [arguments...]` as the general launcher for
Codex, Claude Code, Copilot CLI, Gemini CLI, GitHub CLI, Git, and VS Code.
SSH remotes continue to use the SSH key selected by SSH.

The `defaultProfile` value in local chezmoi data selects the profile used by
plain `code`. Set it to `Default` for VS Code's built-in profile, or to a
configured profile ID that enables `vscode`.

### Git identity resolution

Identity resolution is per field: `profiles.<id>.git.name/email`, then the
profile-level `name`/`email`, then global Git configuration. These overrides
apply only to profile commands and do not rewrite global Git settings. If you
have configured Git to include `~/.gitconfig.local`, you can keep additional
local Git settings there. This repository does not include that file by
default.

### Profile lifecycle

Profile configuration affects local state. On apply, setup removes profile
directories whose IDs are no longer configured or whose tool list is empty.
Back up any state you want to keep before removing a profile, emptying its tool
list, or changing its ID. Separate directories do not guarantee separate
authentication for providers that use shared operating-system or application
credential storage.

## Customize assistant instructions

Place machine-specific shared instructions in `home/.chezmoidata/ai.yaml`:

```yaml
ai:
  instructions: |
    Add local, non-secret guidance for AI tools here.
```

Profile-specific and tool-specific instructions belong in
`home/.chezmoidata/profile.yaml`:

```yaml
profiles:
  work:
    tools: [codex, claude]
    ai:
      force: false
      instructions: |
        Add work-profile guidance here.
    codex:
      force: true
      instructions: |
        Replace inherited instructions for Codex in this profile.
```

By default, profile and tool instructions append to inherited text. Set
`force: true` to replace inherited instructions. The `ai` key applies to all
configured AI tools in the profile; a tool key such as `codex` applies only to
that tool. `force` is not a security boundary: do not put credentials or
confidential data in instruction text.

Generated instruction files should be changed through the local YAML data, not
by editing files under `~/.config/profiles/`. Existing unmanaged instruction
files and custom links are preserved by setup.

## Keep credentials out of configuration

Do not put access tokens, passwords, private keys, or authentication files in
tracked data, examples, templates, or this repository. Do not copy
`auth.json`, credential caches, or provider state into a profile example.

Use the provider's sign-in command and its supported OS credential manager or
local secret store. For example, authenticate a GitHub CLI profile with
`gh <alias> auth login`. Profile directories isolate much of the CLI
configuration, but some sign-ins (including certain Copilot CLI and Claude
Code flows) may use shared OS or application storage instead.

Environment variables such as `GH_TOKEN`, `GITHUB_TOKEN`, or
`COPILOT_GITHUB_TOKEN` may override stored sign-in state. Keep them in a local
secret manager or environment; avoid printing them in logs or support requests.

## Review and apply changes

Inspect the merged data without sharing its output, since it can include local
identities and instructions:

```sh
chezmoi data --format=json
```

Review the rendered changes before applying:

```sh
chezmoi --source "$PWD" diff
chezmoi --source "$PWD" apply
```

Applying can install packages and update profile or application state. Run
`make check` after changing templates, shell files, or managed JSON. Keep local
data and credentials out of commits.
