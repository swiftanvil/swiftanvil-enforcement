#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: validate-document-registry.sh [--registry PATH | --registry-root PATH] --root PATH

Validates that files under --root do not hardcode document paths owned by
the central document registry. Refer to stable document IDs instead.

If --root contains .swiftanvil-registry-ignore, each non-empty, non-comment
line is treated as a shell glob for files to skip.

Options:
  --registry PATH       Path to the document registry YAML file.
  --registry-root PATH  Repository root containing the document registry.
  --root PATH           Repository root to scan.
  --help                Show this help text.
EOF
}

registry=""
registry_root=""
root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --registry)
      registry="${2:-}"
      shift 2
      ;;
    --registry-root)
      registry_root="${2:-}"
      shift 2
      ;;
    --root)
      root="${2:-}"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$registry" ] && [ -n "$registry_root" ]; then
  if [ ! -d "$registry_root" ]; then
    echo "error: registry root not found: $registry_root" >&2
    exit 2
  fi

  registry="$(find "$registry_root" -maxdepth 2 -type f -name 'REGISTRY.yml' | head -n 1)"
fi

if [ -z "$registry" ] || [ -z "$root" ]; then
  usage >&2
  exit 2
fi

if [ ! -f "$registry" ]; then
  echo "error: registry not found: $registry" >&2
  exit 2
fi

if [ ! -d "$root" ]; then
  echo "error: root not found: $root" >&2
  exit 2
fi

tmp_refs="$(mktemp)"
tmp_files="$(mktemp)"
tmp_ignores="$(mktemp)"
trap 'rm -f "$tmp_refs" "$tmp_files" "$tmp_ignores"' EXIT

awk '
  /^[[:space:]]+path:[[:space:]]/ {
    value = $0
    sub(/^[[:space:]]+path:[[:space:]]*/, "", value)
    gsub(/^"|"$/, "", value)
    print value
  }
  /^[[:space:]]+mirror:[[:space:]]/ {
    value = $0
    sub(/^[[:space:]]+mirror:[[:space:]]*/, "", value)
    gsub(/^"|"$/, "", value)
    print value
  }
  /^[[:space:]]+aliases:[[:space:]]*\[/ {
    value = $0
    sub(/^[[:space:]]+aliases:[[:space:]]*\[/, "", value)
    sub(/\][[:space:]]*$/, "", value)
    gsub(/,/, "\n", value)
    n = split(value, parts, "\n")
    for (i = 1; i <= n; i++) {
      item = parts[i]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", item)
      gsub(/^"|"$/, "", item)
      if (item != "") print item
    }
  }
' "$registry" | sort -u > "$tmp_refs"

if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$root" ls-files --cached --others --exclude-standard \
    '*.md' '*.markdown' '*.txt' \
    > "$tmp_files"
else
  find "$root" -type f \( \
    -name '*.md' -o -name '*.markdown' -o -name '*.txt' \
  \) | sed "s#^$root/##" > "$tmp_files"
fi

if [ -f "$root/.swiftanvil-registry-ignore" ]; then
  sed '/^[[:space:]]*$/d; /^[[:space:]]*#/d' "$root/.swiftanvil-registry-ignore" > "$tmp_ignores"
fi

should_skip() {
  candidate="$1"

  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    case "$candidate" in
      $pattern)
        return 0
        ;;
    esac
  done < "$tmp_ignores"

  return 1
}

violations=0

while IFS= read -r file; do
  [ -n "$file" ] || continue

  case "$file" in
    REGISTRY.yml|*/REGISTRY.yml)
      continue
      ;;
  esac

  if should_skip "$file"; then
    continue
  fi

  full_path="$root/$file"
  [ -f "$full_path" ] || continue

  while IFS= read -r ref; do
    [ -n "$ref" ] || continue

    if grep -nF "$ref" "$full_path" >/dev/null 2>&1; then
      grep -nF "$ref" "$full_path" | while IFS= read -r line; do
        printf '%s:%s: hardcoded registered document path "%s"; use its document ID from the registry\n' "$file" "$line" "$ref" >&2
      done
      violations=$((violations + 1))
    fi
  done < "$tmp_refs"
done < "$tmp_files"

if [ "$violations" -gt 0 ]; then
  echo "document registry validation failed with $violations violation group(s)" >&2
  exit 1
fi

echo "document registry validation passed"
