#!/usr/bin/env sh
set -eu

current="${SWIFTANVIL_CURRENT_AGENT:-}"
probe=true

while [ "$#" -gt 0 ]; do
  case "$1" in
    --current)
      current="${2:-}"
      shift 2
      ;;
    --no-probe)
      probe=false
      shift
      ;;
    --help)
      cat <<'EOF'
Usage: select-reviewer.sh [--current AGENT] [--no-probe]

Selects an installed, authenticated reviewer that differs from the current
builder agent. Set SWIFTANVIL_REVIEWER_PREFERENCE to a comma-separated list
to prefer specific agents.
EOF
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if [ "$probe" = true ]; then
  "$script_dir/discover-agents.sh" --probe > "$tmp"
else
  "$script_dir/discover-agents.sh" > "$tmp"
fi

choose_from_list() {
  list="$1"
  old_ifs=$IFS
  IFS=,
  for candidate in $list; do
    IFS=$old_ifs
    candidate=$(printf '%s' "$candidate" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$candidate" ] || continue
    awk -F '\t' -v agent="$candidate" -v current="$current" '
      NR > 1 && $1 == agent && $1 != current && $2 == "yes" && ($3 == "ok" || $3 == "not_checked") {
        print $1
        exit 0
      }
    ' "$tmp"
    IFS=,
  done
  IFS=$old_ifs
}

selected=""
if [ -n "${SWIFTANVIL_REVIEWER_PREFERENCE:-}" ]; then
  selected=$(choose_from_list "$SWIFTANVIL_REVIEWER_PREFERENCE" | head -n 1)
fi

if [ -z "$selected" ]; then
  selected=$(awk -F '\t' -v current="$current" '
    NR > 1 && $1 != current && $2 == "yes" && $3 == "ok" {
      print $1
      exit 0
    }
  ' "$tmp")
fi

if [ -z "$selected" ] && [ "$probe" != true ]; then
  selected=$(awk -F '\t' -v current="$current" '
    NR > 1 && $1 != current && $2 == "yes" {
      print $1
      exit 0
    }
  ' "$tmp")
fi

if [ -z "$selected" ]; then
  echo "error: no independent reviewer available" >&2
  echo "discovered agents:" >&2
  cat "$tmp" >&2
  exit 1
fi

printf '%s\n' "$selected"
