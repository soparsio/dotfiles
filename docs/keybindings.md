# Keybindings Cheat Sheet

These are Zsh aliases and functions typed at a shell prompt, not editor
keyboard-chord mappings. Aliases are defined in
`home/dot_config/zsh/aliases.zsh.tmpl`; functions are defined in
`home/dot_config/zsh/functions.zsh.tmpl`.

## Navigation and files

| Command           | Action                                                 |
| ----------------- | ------------------------------------------------------ |
| `..`              | Move up one directory                                  |
| `...`             | Move up two directories                                |
| `....`            | Move up three directories                              |
| `la`              | List entries, including hidden files                   |
| `ll`              | Detailed listing, including hidden files               |
| `ws`              | Change to the configured workspace directory           |
| `mkcd DIRECTORY`  | Create a directory and enter it                        |
| `up [COUNT]`      | Move up one or more levels; defaults to one            |
| `croot`           | Move to the current Git repository root                |
| `extract ARCHIVE` | Extract a supported archive into the current directory |

`extract` supports tar formats (`.tar`, `.tar.gz`, `.tgz`, `.tar.bz2`,
`.tbz2`, `.tar.xz`, `.txz`, `.tar.zst`, `.tzst`), zip, gzip, bzip2, and xz.
Check for filename conflicts first; extraction uses each system utility's
default behavior.

## Git

| Command       | Equivalent                                                   |
| ------------- | ------------------------------------------------------------ |
| `ga`          | `git add`                                                    |
| `gs`          | `git status --short --branch`                                |
| `gd`          | `git diff`                                                   |
| `gds`         | `git diff --staged`                                          |
| `gb`          | `git branch`                                                 |
| `gco`         | `git checkout`                                               |
| `gcm MESSAGE` | `git commit -m MESSAGE`                                      |
| `gl`          | Graph-style, decorated one-line log of the latest 15 commits |
| `gpl`         | `git pull --ff-only`                                         |
| `gp`          | `git push`                                                   |

## Shell, system, and Docker

| Command  | Action                                        |
| -------- | --------------------------------------------- |
| `reload` | Reload `~/.zshrc`                             |
| `dfh`    | Show filesystem usage in human-readable units |
| `c`      | Launch Claude Code                            |
| `dps`    | List Docker containers with status and ports  |
| `dcu`    | Run `docker compose up -d`                    |
| `dcd`    | Run `docker compose down`                     |

## Profile launchers

Configured profiles generate launchers based on their `tools` in the
machine-local `home/.chezmoidata/profile.yaml`. Common patterns are:

| Command pattern                      | Action                                                                     |
| ------------------------------------ | -------------------------------------------------------------------------- |
| `<tool>-<profile>`                   | Start a configured CLI with that profile's state                           |
| `code-<profile>`                     | Open VS Code with the profile's native VS Code profile and CLI environment |
| `dotfiles-<profile>`                 | Open this repository in that VS Code profile                               |
| `git <alias> COMMAND`                | Run Git with the configured profile identity                               |
| `gh <alias> COMMAND`                 | Use the profile's GitHub CLI configuration                                 |
| `profile-use TOOL PROFILE [ARGS...]` | General launcher for supported profiled tools                              |

For example, if `work` enables the matching tools:

```sh
codex-work
claude-work
code-work .
git work status
gh work auth status
profile-use vscode work .
```

The names and available launchers depend on local profile configuration. See
[Customization & Local Overrides](customization.md) for profile setup.
