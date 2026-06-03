#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage: run-agent-review.sh --agent AGENT --request PATH --output PATH [--prompt TEXT] [--builder AGENT]

Runs an independent review request through a local agent CLI while avoiding
sandbox-home authentication failures.

Options:
  --agent AGENT    Reviewer agent, "auto", or a command name.
  --request PATH   Markdown/text file containing the review request.
  --output PATH    File where full reviewer output is written.
  --prompt TEXT    Optional instruction prepended to the request.
  --builder AGENT  Current builder agent; used to prevent self-review.
  --help           Show this help text.

Environment:
  SWIFTANVIL_AGENT_HOME  Override the home directory used for reviewer CLIs.
EOF
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$script_dir/lib/agent-common.sh"

agent=""
builder="${SWIFTANVIL_CURRENT_AGENT:-}"
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
    --builder)
      builder="${2:-}"
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

agent_home="$(login_home)"

if [ -z "$agent_home" ] || [ ! -d "$agent_home" ]; then
  echo "error: could not determine a valid agent home directory" >&2
  exit 2
fi

mkdir -p "$(dirname "$output")"
metadata="$output.review.yml"
started_at=$(iso_now)

if [ "$agent" = "auto" ]; then
  agent=$("$script_dir/select-reviewer.sh" --current "$builder")
fi

if [ -n "$builder" ] && [ "$agent" = "$builder" ]; then
  echo "error: reviewer agent must differ from builder agent" >&2
  exit 2
fi

adapter="$script_dir/../adapters/$agent.sh"

set +e
if [ -x "$adapter" ]; then
  SWIFTANVIL_AGENT_HOME="$agent_home" "$adapter" review "$request" "$output" "$prompt"
  exit_code=$?
else
  {
    printf '%s\n\n' "$prompt"
    cat "$request"
  } > "$output.prompt"
  HOME="$agent_home" "$agent" < "$output.prompt" > "$output" 2>&1
  exit_code=$?
  rm -f "$output.prompt"
fi
set -e

finished_at=$(iso_now)
status="failure"
verdict="UNKNOWN"

if [ "$exit_code" -eq 0 ]; then
  status="success"
  verdict=$(extract_verdict "$output")
fi

cat > "$metadata" <<EOF
schema_version: 1
status: $status
agent: $agent
builder: $builder
request: '$(yaml_escape "$request")'
output: '$(yaml_escape "$output")'
verdict: $verdict
started_at: '$started_at'
finished_at: '$finished_at'
exit_code: $exit_code
home_strategy: login_home
EOF

exit "$exit_code"
