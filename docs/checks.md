# Checks

Use the repository checks to validate rendered configuration without applying
it to your home directory. The checks use temporary files and homes and clean
them up on exit.

## Requirements

Install these tools before running the full check target:

- chezmoi
- Zsh
- Python 3
- Git
- Make and a POSIX-compatible shell

## Run the standard checks

From the repository root:

```sh
make check
```

The target runs `scripts/check.sh` and `scripts/lint-shell-template.sh`. It
renders selected templates, validates shell syntax and JSON, exercises local
profile setup behavior and starter-data copying, checks package and profile
configuration, and runs `git diff --check`. It does not apply configuration
or install the managed packages.

Run this target after changing shell files, templates, or managed JSON. Review
its output for the failing check; it prints a pass list for the major checked
areas.

## Additional validation

The assistant hook and tool configuration files can be checked separately:

```sh
make check-assistant-configs
```

This target validates the tracked JSON files listed in the repository
`Makefile` using Python's JSON parser.

## Continuous integration

The GitHub Actions workflow runs `make check` on Ubuntu 24.04 for pull requests
targeting `main` and pushes to `main`. It can also be started manually with
`workflow_dispatch`. The workflow installs Zsh and chezmoi before running the
same checks used locally.

For package and shell setup details, see [Packages](packages.md) and
[Shell Functions & CLI Utilities](shell.md). For setup failures, see
[Troubleshooting & FAQ](troubleshooting.md).
