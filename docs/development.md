# Development

This guide describes the local development workflow for changing and validating
the dotfiles repository. Start from the repository root and keep changes in the
source files; do not edit generated files in your home directory as a lasting
fix.

## Development requirements

The full repository check uses:

- chezmoi to render templates
- Zsh to validate Zsh configuration
- Python 3 for isolated tests and configuration helpers
- Git, Make, and a POSIX-compatible shell
- `shfmt` for shell-template formatting checks

Install any missing tools using the environment's normal package or version
manager. The checks do not install dependencies or apply dotfiles.

## Development workflow

1. Inspect the current branch and worktree. Preserve existing local edits and
   never add machine-specific data from `home/.chezmoidata/`.
2. Locate the managed source under `home/`, which `.chezmoiroot` selects as the
   chezmoi source root. Preserve filename attributes such as `dot_`, `private_`,
   and `.tmpl`.
3. Keep portable defaults in tracked data, reusable template logic in
   `home/.chezmoitemplates/`, and machine-specific values in ignored local data
   or `~/.config/chezmoi/chezmoi.yaml`.
4. Consider macOS, Linux, WSL, and native Windows behavior when modifying
   paths, packages, shell setup, or application configuration.
5. Run checks appropriate to the change, then review the rendered diff before
   applying anything locally.

For repository conventions, branch guidance, and pull request expectations,
see [Contributing](../CONTRIBUTING.md). For the source-to-target mapping and
overall system design, see [Architecture](../ARCHITECHTURE.md).

## Run the repository checks

Run the full check from the repository root:

```sh
make check
```

The target runs `scripts/check.sh` and `scripts/lint-shell-template.sh`. It
renders selected templates, validates shell syntax and JSON, exercises profile
setup behavior and starter-data copying, checks package and profile
configuration, and validates tracked whitespace. Temporary files and test
homes are removed when the checks finish. The target does not apply
configuration or install managed packages.

Run `make check` after changing shell files, templates, or managed JSON. The
check scripts print progress and a pass list; stop on the first failure and
resolve it before treating the change as validated.

### Check assistant configuration JSON

To validate the tracked assistant hook and tool configuration files separately:

```sh
make check-assistant-configs
```

This target uses Python's JSON parser on the files listed in the `Makefile`.

### Lint a shell template

The shell-template linter renders templates with sample profile data, then
checks formatting, whitespace, and shell syntax. Run it for the complete
source tree with `make check`, or focus on a changed template:

```sh
make lint-shell-template TEMPLATE_PATH=home/dot_config/zsh/functions.zsh.tmpl
```

Pass a directory to check all shell templates in that directory. Use
`FIX=1` only when intentionally allowing the linter to normalize whitespace in
the selected source. Formatting runs on rendered temporary files; it does not
rewrite the source template with `shfmt`.

## Review the rendered result

Chezmoi renders templates and computes target changes without applying them:

```sh
chezmoi --source "$PWD" diff
```

Inspect the diff for unexpected targets, local identities, secrets, or
machine-specific values. Applying can install software and modify profile or
application state. Do not run `chezmoi apply` unless you intend to update this
machine and have reviewed the changes.

## Documentation development

Keep guides aligned with actual source behavior. Verify local Markdown links
and heading anchors when moving or renaming documentation. Format Markdown
consistently and run `git diff --check` before submitting documentation-only
changes.

## Continuous integration

GitHub Actions runs `make check` on Ubuntu 24.04 for pull requests targeting
`main` and pushes to `main`; the workflow can also be started manually. It
installs Zsh and chezmoi before running the same repository checks.

For platform package details, see [Packages](packages.md). For shell startup
and CLI behavior, see [Shell Functions & CLI Utilities](shell.md). For help
diagnosing a failed setup or check, see [Troubleshooting & FAQ](troubleshooting.md).
