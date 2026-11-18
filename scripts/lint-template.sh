#!/bin/sh

# Check source whitespace in Go templates.
set -eu

usage() {
  printf 'Usage: %s [--fix] [template-path]\n' "${0##*/}" >&2
}

fix=0
if [ "${1:-}" = --fix ]; then
  fix=1
  shift
fi

if [ "$#" -eq 0 ] && [ -n "${TEMPLATE_PATH:-}" ]; then
  set -- "$TEMPLATE_PATH"
fi

case ${1:-} in
  -h|--help)
    usage
    exit 0
    ;;
esac

if [ "$#" -gt 1 ] || { [ "$fix" -eq 1 ] && [ "$#" -ne 1 ]; }; then
  usage
  exit 2
fi

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
source_root=${CHEZMOI_SOURCE:-$repo_root}
case $source_root in
  /*) ;;
  *) source_root="$PWD/$source_root" ;;
esac
source_root=$(CDPATH= cd "$source_root" && pwd)

if [ "$#" -eq 1 ]; then
  selected_path=$1
  case $selected_path in
    /*) ;;
    *) selected_path="$source_root/$selected_path" ;;
  esac
  if [ -d "$selected_path" ]; then
    templates=$(find "$selected_path" -type f -name '*.tmpl' -print)
    case $selected_path in
      */.chezmoitemplates|"$source_root"|"$source_root/home")
        fragments=$(find "$selected_path" -type d -name .chezmoitemplates -prune -exec find {} -type f -print \;)
        case $selected_path in
          */.chezmoitemplates) fragments=$(find "$selected_path" -type f -print) ;;
        esac
        templates=$(printf '%s\n%s' "$templates" "$fragments")
        ;;
    esac
    if [ -z "$(printf '%s' "$templates" | tr -d '\n')" ]; then
      printf 'No Go templates found under %s\n' "$selected_path" >&2
      exit 1
    fi
  elif [ -f "$selected_path" ]; then
    templates=$selected_path
  else
    printf 'Template path not found: %s\n' "$selected_path" >&2
    exit 1
  fi
else
  templates=$(find "$source_root/home" -type f -name '*.tmpl' -print)
  fragments=$(find "$source_root/home" -type d -name .chezmoitemplates -prune -exec find {} -type f -print \;)
  templates=$(printf '%s\n%s' "$templates" "$fragments")
fi

normalize_whitespace() {
  python3 - "$1" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
original = path.read_bytes()
newline = b"\r\n" if b"\r\n" in original else b"\n"
text = original.decode("utf-8")
lines = text.splitlines()
normalized = newline.join(line.rstrip(" \t") for line in lines)
if original.endswith((b"\n", b"\r")):
    normalized += newline
if normalized.encode("utf-8") != original:
    path.write_bytes(normalized.encode("utf-8"))
    print(f"Normalized whitespace: {path}")
PY
}

check_whitespace() {
  python3 - "$1" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
errors = []
for number, line in enumerate(path.read_text().splitlines(), start=1):
    if line.endswith((" ", "\t")):
        errors.append(f"{path}:{number}: trailing whitespace")
    if line and not line.strip():
        errors.append(f"{path}:{number}: whitespace-only line")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
PY
}

printf '%s\n' "$templates" | while IFS= read -r template; do
  [ -n "$template" ] || continue
  case $template in
    /*) ;;
    *) template="$source_root/$template" ;;
  esac
  if [ ! -f "$template" ]; then
    printf 'Template not found: %s\n' "$template" >&2
    exit 1
  fi
  if [ "$fix" -eq 1 ]; then
    normalize_whitespace "$template"
  fi
  check_whitespace "$template"
  printf 'Template whitespace check passed: %s\n' "$template"
done
