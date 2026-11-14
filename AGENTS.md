# Dotfiles repository instructions

## Repository model

- `.chezmoiroot` selects `home/` as the chezmoi source root. Put managed target
  sources under `home/`; repository documentation, examples, and helper scripts
  remain at the repository root.
- Preserve chezmoi filename attributes such as `dot_`, `private_`, and `.tmpl`.
  Check neighboring sources before choosing a destination or adding a platform
  variant.
- Reuse template fragments from `home/.chezmoitemplates/` and keep shared
  defaults in `home/.chezmoidata.yaml`. Avoid duplicating template logic.
- Keep machine-specific values in ignored `home/.chezmoidata/` files or local
  `~/.config/chezmoi/chezmoi.yaml`. Do not replace local data with example data;
  examples must use safe placeholders.

## Making changes

- Inspect the worktree and relevant source files first. Preserve existing
  uncommitted changes and do not revert unrelated work.
- Consider macOS, Linux, WSL, and native Windows behavior when changing shell
  configuration, paths, packages, or application setup. Use platform-specific
  conditionals only for actual differences.
- Keep setup scripts rerunnable and consistent with existing `run_once_` or
  `run_onchange_` patterns. Make prerequisites explicit and avoid unrequested
  package installs or destructive operations.
- Update the README and relevant guides when a change affects setup, platform
  support, package behavior, or everyday use.
- Keep comments in code and configuration in English. Never add credentials,
  tokens, private keys, personal machine data, or AI-tool runtime state.

## Validation and application

- Run `make check` after changing shell files, templates, or managed JSON.
  Run `make check-assistant-configs` when changing assistant hook or tool JSON.
- For documentation-only changes, verify local links and heading anchors and
  run `git diff --check`.
- Review `chezmoi --source "$PWD" diff` before applying. Check the target paths
  for unrelated or unexpected home-directory changes; do not apply if the diff
  includes unrelated changes.
- Applying may install packages or update profile and application state. Apply
  only when explicitly requested and after reviewing the diff.
- Do not commit, push, or create a pull request unless the user explicitly
  requests the applicable workflow. Never merge a pull request unless asked.
