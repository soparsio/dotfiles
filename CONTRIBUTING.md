# Contributing

Thank you for helping improve these dotfiles. Contributions should remain
portable, safe to apply, and consistent with the repository's chezmoi layout.
Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before making a change

- For substantial changes, open an issue or discussion first so the intended
  behavior and platform scope can be agreed on.
- Check the existing templates, platform scripts, and guides for an established
  pattern before adding a new one.
- Keep credentials, tokens, private keys, real personal identities, and local
  AI or tool state out of commits. Use ignored local data and placeholders in
  examples.

## Repository conventions

The `.chezmoiroot` file selects `home/` as the chezmoi source root. Add managed
configuration there and preserve filename attributes such as `dot_`,
`private_`, and `.tmpl`. Put reusable template logic in
`home/.chezmoitemplates/`.

Keep portable defaults in tracked data such as `home/.chezmoidata.yaml`.
Machine-specific data belongs in ignored `home/.chezmoidata/` files or local
`~/.config/chezmoi/chezmoi.yaml`; do not commit those local values. Keep
starter data safe and use placeholders.

Use `.chezmoi.os` only for genuine platform differences. Consider macOS,
Linux, WSL, and native Windows behavior when a change affects setup, paths, or
shell configuration.

## Validate changes

Run the relevant checks from the repository root:

```sh
make check
```

The full check validates rendered templates, shell syntax, JSON, profile
behavior, and tracked whitespace without applying changes to your home
directory. Run the assistant configuration check when changing its JSON files:

```sh
make check-assistant-configs
```

For documentation-only changes, check local links and heading anchors and run:

```sh
git diff --check
```

Before applying managed changes locally, review the rendered diff:

```sh
chezmoi --source "$PWD" diff
```

Applying can install packages and update profile or application state. Only
apply when you intend to make those changes on your machine.

## Branches and pull requests

Use a descriptive branch name with a project prefix, for example
`feature/add-shell-helper`, `fix/bootstrap-path`, or
`docs/update-install-guide`. Prefer a Conventional Commit subject such as
`docs: clarify bootstrap steps` or `fix: resolve remote source root`.

Pull requests should explain the motivation, summarize user-visible changes,
identify affected platforms when relevant, and list the checks that were run.
Do not claim checks passed unless they were run. Include screenshots only when
they clarify a visual change, and remove personal or machine-specific details
from them.

## Documentation

Update the README and relevant guides when a change alters setup, platform
support, package behavior, or everyday use. Keep documentation examples
consistent with the current source and safe to copy.
