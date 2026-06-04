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
Usage: validate-review-artifacts.sh [--root PATH]

Validates review artifacts produced by run-agent-review.sh.
EOF
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

reviews_dir="$root/Reviews"
if [ ! -d "$reviews_dir" ]; then
  echo "review artifact validation skipped: no Reviews directory"
  exit 0
fi

failures=0
requests_file=$(mktemp)
trap 'rm -f "$requests_file"' EXIT
find "$reviews_dir" -maxdepth 1 -type f -name '*review-request.md' | sort > "$requests_file"

if [ ! -s "$requests_file" ]; then
  echo "review artifact validation skipped: no review requests"
  exit 0
fi

while IFS= read -r request; do
  [ -n "$request" ] || continue
  found_success=false
  request_rel=${request#"$root/"}

  for meta in "$reviews_dir"/*.review.yml; do
    [ -f "$meta" ] || continue
    if grep -Fq "request: '$request_rel'" "$meta" || grep -Fq "request: '$request'" "$meta"; then
      status=$(awk -F: '/^status:/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}' "$meta")
      verdict=$(awk -F: '/^verdict:/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}' "$meta")
      agent=$(awk -F: '/^agent:/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}' "$meta")
      builder=$(awk -F: '/^builder:/ {gsub(/^[[:space:]]+/, "", $2); print $2; exit}' "$meta")
      output=$(awk -F: '/^output:/ {gsub(/^[[:space:]]+/, "", $2); gsub(/^'\''|'\''$/, "", $2); print $2; exit}' "$meta")

      case "$status" in
        success|failure) ;;
        *)
          echo "$meta: invalid or missing status" >&2
          failures=$((failures + 1))
          ;;
      esac

      if [ "$status" = "success" ]; then
        case "$verdict" in
          APPROVED|APPROVED_WITH_NOTES|NEEDS_REVISION) ;;
          *)
            echo "$meta: successful review must include a valid verdict" >&2
            failures=$((failures + 1))
            ;;
        esac

        if [ -z "$agent" ]; then
          echo "$meta: successful review must record reviewer agent" >&2
          failures=$((failures + 1))
        fi

        if [ -z "$builder" ]; then
          echo "$meta: successful review must record builder agent" >&2
          failures=$((failures + 1))
        elif [ "$builder" = "$agent" ]; then
          echo "$meta: reviewer agent must differ from builder agent" >&2
          failures=$((failures + 1))
        fi

        if [ -n "$output" ] && [ ! -f "$root/$output" ] && [ ! -f "$output" ]; then
          echo "$meta: output file not found: $output" >&2
          failures=$((failures + 1))
        fi

        found_success=true
      fi
    fi
  done

  if [ "$found_success" != true ]; then
    echo "$request: no successful independent review metadata found" >&2
    failures=$((failures + 1))
  fi
done < "$requests_file"

if [ "$failures" -gt 0 ]; then
  echo "review artifact validation failed with $failures issue(s)" >&2
  exit 1
fi

echo "review artifact validation passed"
