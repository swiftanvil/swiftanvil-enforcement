#!/usr/bin/env sh
set -eu

root="."
registry_root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      root="${2:-}"
      shift 2
      ;;
    --registry-root)
      registry_root="${2:-}"
      shift 2
      ;;
    --help)
      cat <<'EOF'
Usage: enforce-local.sh [--root PATH] [--registry-root PATH]

Runs the same SwiftAnvil enforcement checks locally without consuming GitHub
Actions minutes.
EOF
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ -z "$registry_root" ]; then
  registry_root="$root"
  if [ ! -f "$registry_root/REGISTRY.yml" ]; then
    registry_root="$(CDPATH= cd -- "$root/.." && pwd)/swiftanvil-meta"
  fi
fi

"$script_dir/validate-document-registry.sh" --registry-root "$registry_root" --root "$root"
"$script_dir/validate-review-artifacts.sh" --root "$root"
