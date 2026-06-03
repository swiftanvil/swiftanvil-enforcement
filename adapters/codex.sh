#!/usr/bin/env sh
set -eu

case "${1:-}" in
  id)
    echo "codex"
    ;;
  detect)
    command -v codex >/dev/null 2>&1
    ;;
  command)
    command -v codex 2>/dev/null || true
    ;;
  probe)
    command -v codex >/dev/null 2>&1
    ;;
  review)
    home="${SWIFTANVIL_AGENT_HOME:?SWIFTANVIL_AGENT_HOME is required}"
    request="${2:?request path required}"
    output="${3:?output path required}"
    prompt="${4:-You are an independent reviewer. Review the request below.}"
    tmp="${output}.prompt"
    printf '%s\n\n' "$prompt" > "$tmp"
    cat "$request" >> "$tmp"
    HOME="$home" codex review - < "$tmp" > "$output" 2>&1
    rm -f "$tmp"
    ;;
  *)
    echo "usage: $0 id|detect|command|probe|review REQUEST OUTPUT PROMPT" >&2
    exit 2
    ;;
esac
