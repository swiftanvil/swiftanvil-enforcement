#!/usr/bin/env sh
set -eu

root="."

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      root="${2:-}"
      shift 2
      ;;
    --help)
      cat <<'EOF'
Usage: run-local-actions.sh [--root PATH]

Runs the document registry policy workflow locally through act when available.
Falls back to enforce-local.sh when act is not installed.
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

if command -v act >/dev/null 2>&1; then
  (cd "$root" && act -W .github/workflows/document-registry-policy-check.yml)
else
  echo "act not installed; falling back to local enforcement scripts"
  "$script_dir/enforce-local.sh" --root "$root"
fi
