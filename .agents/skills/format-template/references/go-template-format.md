# Go Template Formatting

Use this convention for Go template source, including chezmoi `.tmpl` files and files under `.chezmoitemplates/`.

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
