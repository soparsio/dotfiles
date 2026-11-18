---
name: format-template
description: Identify and format Go templates using both Go action layout and the rendered file type's formatting rules.
---

# Format Go Templates

Use this skill when formatting Go template source or deciding whether a file should be treated as a Go template.

## Choose the formatting scope

- If the request names a file or path, format only that file or the templates inside that path.
- If the request invokes this skill without naming a file or path, search the workspace, identify all Go template files, and format them all.
- Before editing, list the identified files and exclude generated, vendored, or ignored directories unless the user explicitly includes them.

## Identify template files

- Treat `*.tmpl` files as Go templates when they contain Go template actions or are used as chezmoi template sources.
- Treat files under a `.chezmoitemplates/` directory as Go template fragments, including extensionless files. Chezmoi includes these files as templates.
- Also consider template actions such as `{{ ... }}` and references from `includeTemplate` when filenames alone are inconclusive. Do not classify every file containing braces as a template without checking its role.

## Formatting convention

Read [the Go template formatting reference](references/go-template-format.md) before formatting. It covers directive alignment, rendered file type detection, type-specific formatting, whitespace trimming, and safe formatting boundaries.
