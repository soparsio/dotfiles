# Go Template Formatting

Use this convention for Go template source, including chezmoi `.tmpl` files and files under `.chezmoitemplates/`.

## Determine the rendered file type

- Apply two independent conventions: the Go template action layout below and the format of the file the template renders.
- For a managed source such as `settings.json.tmpl` or `private_config.yml.tmpl`, infer the output type from the target filename by removing `.tmpl` and chezmoi filename attributes such as `dot_` and `private_`.
- For files under `.chezmoitemplates/`, use the fragment's extension when present. For extensionless fragments, inspect `includeTemplate` callers and the surrounding output to determine the format; do not guess when the role is unclear.
- Follow `.editorconfig` and nearby files for indentation and other repository-specific choices.

## Format output content by type

- JSON: use tabs for indentation in this repository, as specified by `.editorconfig` for `*.json`. Preserve key order, values, and Go template expressions.
- YAML and TOML: use two spaces for indentation, following `.editorconfig` and existing sources.
- Shell: follow the shell style and formatter used by the repository. Format rendered shell when needed rather than passing mixed Go template source to a plain shell formatter.
- For other types, follow the applicable `.editorconfig` rule and established neighboring files.
- When a formatter cannot parse template expressions, protect them with context-appropriate placeholders, format only the literal output structure, then restore each expression exactly. For dynamic JSON keys, use a valid quoted placeholder key during formatting and restore the original key expression afterward.
- Validate the rendered output with an existing repository check or representative safe data when available. Do not substitute machine-local data or expose secrets to make a template render.

## Directive layout

- Start standalone template directive lines at column zero. Do not put literal indentation before `{{-` when its left-trim marker makes that indentation insignificant.
- Show nesting with spaces between the opening delimiter and the action. At the first nested level, use three spaces after `{{-`; add two spaces for each deeper level.
- Align `else`, `else if`, and `end` with the action that opened their block. Top-level actions have one separator space after `{{-` and no nesting spaces.
- Keep interpolation actions embedded in literal output at the position required by the rendered file. Whitespace before a non-left-trimming `{{` can be output content, so do not move it if doing so changes rendered output.

Example:

```gotemplate
{{- if condition -}}
{{-   range $item := $items -}}
{{-     if $item.enabled -}}
{{-       print $item.name -}}
{{-     end -}}
{{-   end -}}
{{- else -}}
{{-   print "none" -}}
{{- end -}}
```

## Preserve behavior

- Keep whitespace trimming (`{{-` and `-}}`) intentional. Formatting must not add whitespace or newlines to rendered output.
- Make formatting-only changes without altering expressions, control flow, comments, or output content.
- Do not use a generic formatter unless it understands Go template delimiters and preserves this layout and rendered output.
