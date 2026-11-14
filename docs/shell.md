# Shell Functions & CLI Utilities

The shell configuration is Zsh-based and divided into startup files and
modules. Chezmoi renders or installs the source files under `home/` to the
matching paths in your home directory.

## Startup flow

1. `~/.zprofile` initializes Homebrew on macOS when installed, loads shared
   exports, and marks them as loaded.
2. `~/.zshrc` loads exports once, starts Oh My Zsh when available, then loads
   the other `~/.config/zsh/*.zsh` modules.
3. `~/.config/zsh/integrations.zsh` activates mise, Atuin, and Starship only
   when each command is installed.

The main sources are:

| Source                                   | Destination                      | Purpose                                           |
| ---------------------------------------- | -------------------------------- | ------------------------------------------------- |
| `home/dot_zprofile`                      | `~/.zprofile`                    | Login-shell setup and Homebrew initialization     |
| `home/dot_zshrc`                         | `~/.zshrc`                       | Interactive startup and module loading            |
| `home/dot_config/zsh/exports.zsh.tmpl`   | `~/.config/zsh/exports.zsh`      | PATH additions and environment variables          |
| `home/dot_config/zsh/aliases.zsh.tmpl`   | `~/.config/zsh/aliases.zsh`      | Short aliases and profile launch aliases          |
| `home/dot_config/zsh/functions.zsh.tmpl` | `~/.config/zsh/functions.zsh`    | Navigation, archive, and profile helper functions |
| `home/dot_config/zsh/integrations.zsh`   | `~/.config/zsh/integrations.zsh` | Optional tool activation                          |

## Environment behavior

The exports module:

- Keeps PATH entries unique and prepends optional OrbStack, local-bin, and
  LM Studio paths only when those directories exist.
- Preserves an already-set `OLLAMA_HOST`; otherwise, it sets the configured
  host when the `ollama` command is available.
- Sets `EDITOR`, `VISUAL`, and `GIT_EDITOR` from the local `editor` data value.
- Points Atuin to `~/.config/atuin/`.

Shared defaults are in `home/.chezmoidata.yaml`; override machine-specific
values in `~/.config/chezmoi/chezmoi.yaml`. See
[Customization & Local Overrides](customization.md).

## Functions

| Function      | Usage                                | Behavior                                                                                  |
| ------------- | ------------------------------------ | ----------------------------------------------------------------------------------------- |
| `mkcd`        | `mkcd DIRECTORY`                     | Creates parent directories and changes into the requested directory.                      |
| `up`          | `up [POSITIVE_NUMBER]`               | Moves up the given number of directory levels; defaults to one.                           |
| `croot`       | `croot`                              | Changes to the root of the current Git repository; reports an error outside a repository. |
| `extract`     | `extract ARCHIVE`                    | Extracts supported tar, zip, gzip, bzip2, and xz files into the current directory.        |
| `ws`          | `ws`                                 | Changes to the configured workspace directory.                                            |
| `profile-use` | `profile-use TOOL PROFILE [ARGS...]` | Starts a supported CLI or VS Code profile with its configured environment.                |

`mkcd`, `up`, `croot`, and `extract` validate their arguments and report usage
errors. `extract` uses the system utility's default overwrite behavior; check
for filename conflicts before extraction.

## Profile-aware commands

Profile launchers are generated from each profile's `tools` list. CLI
launchers set the matching state directory (`CODEX_HOME`, `CLAUDE_CONFIG_DIR`,
`COPILOT_HOME`, or `GEMINI_CLI_HOME`). GH launches set `GH_CONFIG_DIR` and
clear inherited GitHub token overrides. Git and VS Code commands use
profile-specific identity and environment settings when configured.

VS Code may reuse a running process and preserve the original environment.
Fully quit VS Code before switching profiles. Profile IDs and local tool
settings are documented in [Customization & Local Overrides](customization.md).

## Reload and validate

After applying changes, start a new shell or reload the configuration:

```sh
source ~/.zshrc
```

Run `make check` after changing Zsh sources or templates. It renders and syntax
checks the shell configuration without applying changes to your home directory.
