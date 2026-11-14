# Dotfiles Architecture

This document describes how configuration flows from this repository into a
machine's home directory, how profile-specific state is prepared, and where
platform-specific behavior belongs.

## System overview

```text
install.sh / install.ps1
        |
        v
  chezmoi source (home/)
        |       ^
        |       +-- shared defaults, ignored local data, local chezmoi config
        v
  template rendering
        |
        +-- chezmoi diff --> review
        |
        +-- chezmoi apply --> managed home files and setup scripts
                                   |
                                   +-- packages and CLI tools
                                   +-- profile directories and instructions
                                   +-- VS Code profile storage
```

The repository is the source of shared configuration. Chezmoi handles
destination paths, template evaluation, and change detection. Setup scripts
perform host operations that cannot be represented as static files, such as
installing packages and preparing profile state.

## Components and ownership

| Component                        | Responsibility                                                             |
| -------------------------------- | -------------------------------------------------------------------------- |
| `.chezmoiroot`                   | Selects `home/` as the managed source root                                 |
| `home/`                          | Managed files, templates, data defaults, and chezmoi scripts               |
| `home/.chezmoitemplates/`        | Reusable template fragments shared by managed files                        |
| `home/.chezmoidata.yaml`         | Tracked defaults shared across machines                                    |
| `home/.chezmoidata/`             | Ignored, machine-specific profile and assistant data                       |
| `~/.config/chezmoi/chezmoi.yaml` | Local chezmoi data overrides and host-specific values                      |
| `examples/.chezmoidata/`         | Placeholder-based starter data copied only when missing                    |
| `scripts/`                       | Setup helpers and isolated repository checks                               |
| `install.sh`, `install.ps1`      | Bootstrap chezmoi, initialize/copy examples, preview, and request approval |

### Source paths and rendered targets

Chezmoi's filename attributes encode destination behavior. For example:

| Source                                   | Destination                              |
| ---------------------------------------- | ---------------------------------------- |
| `home/dot_zshrc`                         | `~/.zshrc`                               |
| `home/dot_config/zsh/functions.zsh.tmpl` | `~/.config/zsh/functions.zsh`            |
| `home/private_dot_codex/AGENTS.md.tmpl`  | `~/.codex/AGENTS.md` (private, rendered) |
| `home/AppData/Roaming/...`               | Windows application data targets         |

Templates use chezmoi's merged data. Keep portable defaults in tracked data,
reusable logic in template fragments, and machine-specific values in ignored
local data or local chezmoi configuration. Platform-specific destinations and
conditions belong in the existing OS-aware source layout and templates.

## Apply lifecycle

1. The installer uses an existing chezmoi binary or installs it with Homebrew
   on macOS when available, otherwise in a user-local location.
2. It initializes this repository (or uses the local checkout) and copies
   example data only when the corresponding local files are absent.
3. It displays the rendered diff and asks before applying.
4. `chezmoi apply` updates managed targets and runs applicable `run_before`,
   `run_after`, `run_once`, or `run_onchange` scripts.
5. Post-apply checks can validate generated shell files. Package and profile
   setup scripts handle operations beyond rendering files.

Applying is not just copying configuration: package scripts can install
software, and profile scripts can update local application state. Always review
`chezmoi diff` first.

## Profile setup and runtime

The machine-local `home/.chezmoidata/profile.yaml` describes profile IDs,
enabled tools, identity overrides, and optional assistant instructions. The
`run_onchange_setup-profiles.sh.tmpl` script validates profile data while
rendering and prepares enabled tools under `~/.config/profiles/<id>/`.

The profile setup process:

- Creates per-tool state directories and seeds shared GH configuration where
  appropriate without replacing existing files.
- Links shared assistant configuration when there is no profile-specific
  instruction override. Generated instruction files carry a management marker;
  unrelated custom files and links are preserved.
- Applies instruction precedence from shared instructions to profile-level,
  AI-wide, and tool-specific instructions. `force: true` replaces inherited
  text; otherwise configured text is appended.
- Invokes `scripts/share-codex-config.py` for profiles using Codex and
  `scripts/configure-vscode-profiles.py` for configured VS Code profiles.
- Removes profile directories whose IDs are no longer configured. Keep profile
  definitions in sync with any state you want retained.

Zsh functions and generated aliases launch profiled tools with their isolated
environment. Git and GitHub aliases can set profile identity for the command
and select that profile's GH configuration; they do not rewrite global Git
settings. VS Code launchers pass selected CLI environment paths to the matching
native VS Code profile.

The VS Code helper checks that VS Code is closed before changing profile
storage or settings. It configures selected resources to inherit from Default,
keeps settings and extensions profile-specific, and uses the installed VS Code
CLI to handle Copilot availability on older versions.

## Platform boundaries

Platform-dependent destinations and setup are kept close to the managed
configuration:

- macOS uses Homebrew and macOS application-data paths.
- Linux uses supported native package managers and XDG-style paths.
- WSL uses Linux home paths; VS Code helpers detect when the `code` command
  targets Windows and then locate Windows profile storage.
- Native Windows uses PowerShell, WinGet, Windows application-data paths, and
  the configured user-local Cygwin Zsh environment.

Use `.chezmoi.os` only for real platform differences. Shared behavior should
remain in common templates or reusable helper scripts. VS Code supports stable,
Insiders, OSS, and detected portable storage; custom storage can be selected
with `CHEZMOI_VSCODE_PROFILE_STORAGE_PATH`.

## Security and local state

Credentials, tokens, private keys, and personal identities do not belong in
tracked templates or examples. Local `.chezmoidata` files and the
`~/.config/chezmoi/chezmoi.yaml` file are ignored or outside the repository.
Examples contain placeholders and are copied only if local files do not exist.

Profile directories isolate configuration and CLI state, but do not guarantee
separate authentication for every tool: some sign-ins may use an operating
system credential manager or shared application state. Environment token
variables can override stored credentials. See [README.md](README.md#local-overrides-ai--secrets)
for user-facing local override guidance.

## Validation and change workflow

`make check` renders selected templates into temporary homes and checks
template behavior, shell syntax, JSON, and whitespace without applying files
to the current home directory. `make check-assistant-configs` separately
validates assistant hook JSON.

For a configuration change:

1. Edit the appropriate source under `home/`, shared template, or example.
2. Run the relevant checks (`make check` after shell, template, or managed JSON
   changes).
3. Review `chezmoi --source "$PWD" diff`.
4. Apply only after confirming the diff and any setup-script side effects.

The architecture-oriented source map is in [README.md](README.md#repository-structure);
the [dotfiles skill](.agents/skills/dotfiles/SKILL.md) routes common workflows
to their references.
