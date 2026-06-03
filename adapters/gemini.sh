#!/usr/bin/env sh
set -eu

case "${1:-}" in
  id)
    echo "gemini"
    ;;
  detect)
    command -v gemini >/dev/null 2>&1
    ;;
  command)
    command -v gemini 2>/dev/null || true
    ;;
  probe)
    home="${SWIFTANVIL_AGENT_HOME:?SWIFTANVIL_AGENT_HOME is required}"
    output=$(HOME="$home" GEMINI_CLI_TRUST_WORKSPACE=true gemini --skip-trust -p "Reply with exactly: AUTH_OK" 2>&1 || true)
    printf '%s\n' "$output" | grep -q "AUTH_OK"
    ;;
  review)
    home="${SWIFTANVIL_AGENT_HOME:?SWIFTANVIL_AGENT_HOME is required}"
    request="${2:?request path required}"
    output="${3:?output path required}"
    prompt="${4:-You are an independent reviewer. Review the request below.}"
    HOME="$home" GEMINI_CLI_TRUST_WORKSPACE=true gemini --skip-trust -p "$prompt" < "$request" > "$output" 2>&1
    ;;
  *)
    echo "usage: $0 id|detect|command|probe|review REQUEST OUTPUT PROMPT" >&2
    exit 2
    ;;
esac
