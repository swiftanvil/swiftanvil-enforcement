#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: run-agent-review.sh --agent AGENT --request PATH --output PATH [--prompt TEXT]

Runs an independent review request through a local agent CLI while avoiding
sandbox-home authentication failures.

Options:
  --agent AGENT    Reviewer agent: claude, gemini, kimi, or a command name.
  --request PATH   Markdown/text file containing the review request.
  --output PATH    File where full reviewer output is written.
  --prompt TEXT    Optional instruction prepended to the request.
  --help           Show this help text.

Environment:
  SWIFTANVIL_AGENT_HOME  Override the home directory used for reviewer CLIs.
EOF
}

agent=""
request=""
output=""
prompt="You are an independent reviewer. Review the request below and return the requested verdict, risks, and recommendations."

while [ "$#" -gt 0 ]; do
  case "$1" in
    --agent)
      agent="${2:-}"
      shift 2
      ;;
    --request)
      request="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    --prompt)
      prompt="${2:-}"
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

if [ -z "$agent" ] || [ -z "$request" ] || [ -z "$output" ]; then
  usage >&2
  exit 2
fi

if [ ! -f "$request" ]; then
  echo "error: request not found: $request" >&2
  exit 2
fi

login_home() {
  if [ -n "${SWIFTANVIL_AGENT_HOME:-}" ]; then
    printf '%s\n' "$SWIFTANVIL_AGENT_HOME"
    return
  fi

  if [ -n "${USER:-}" ]; then
    if command -v dscl >/dev/null 2>&1; then
      dscl . -read "/Users/$USER" NFSHomeDirectory 2>/dev/null | awk '{print $2; exit}' && return
    fi

    if command -v getent >/dev/null 2>&1; then
      getent passwd "$USER" | awk -F: '{print $6; exit}' && return
    fi

    expanded=$(eval "printf '%s' ~$USER" 2>/dev/null || true)
    if [ -n "$expanded" ] && [ "$expanded" != "~$USER" ]; then
      printf '%s\n' "$expanded"
      return
    fi
  fi

  printf '%s\n' "${HOME:-}"
}

agent_home="$(login_home)"

if [ -z "$agent_home" ] || [ ! -d "$agent_home" ]; then
  echo "error: could not determine a valid agent home directory" >&2
  exit 2
fi

mkdir -p "$(dirname "$output")"

{
  printf '%s\n\n' "$prompt"
  cat "$request"
} > "$output.prompt"

case "$agent" in
  claude)
    HOME="$agent_home" claude -p "$(cat "$output.prompt")" > "$output" 2>&1
    ;;
  gemini)
    HOME="$agent_home" GEMINI_CLI_TRUST_WORKSPACE=true gemini --skip-trust \
      -p "$prompt" < "$request" > "$output" 2>&1
    ;;
  kimi)
    HOME="$agent_home" kimi -p "$(cat "$output.prompt")" > "$output" 2>&1
    ;;
  *)
    HOME="$agent_home" "$agent" < "$output.prompt" > "$output" 2>&1
    ;;
esac

rm -f "$output.prompt"
