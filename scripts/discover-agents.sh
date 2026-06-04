#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$script_dir/lib/agent-common.sh"

probe=false
format="tsv"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --probe)
      probe=true
      shift
      ;;
    --format)
      format="${2:-}"
      shift 2
      ;;
    --help)
      cat <<'EOF'
Usage: discover-agents.sh [--probe] [--format tsv|markdown]

Discovers known local agent CLIs through adapters. With --probe, performs a
minimal authenticated call using the login home directory.
EOF
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

home=$(login_home)
adapter_root=$(CDPATH='' cd -- "$script_dir/../adapters" && pwd)

if [ "$format" = "markdown" ]; then
  printf '| Agent | Installed | Auth | Command | Notes |\n'
  printf '|-------|-----------|------|---------|-------|\n'
else
  printf 'agent\tinstalled\tauth\tcommand\tnotes\n'
fi

for adapter in "$adapter_root"/*.sh; do
  [ -f "$adapter" ] || continue
  id=$("$adapter" id)
  cmd=$("$adapter" command)

  installed="no"
  auth="not_checked"
  notes=""

  if [ -n "$cmd" ] && "$adapter" detect >/dev/null 2>&1; then
    installed="yes"
    if [ "$probe" = true ]; then
      if SWIFTANVIL_AGENT_HOME="$home" "$adapter" probe >/dev/null 2>&1; then
        auth="ok"
      else
        auth="failed"
        notes="probe failed; check auth, plan, network, or provider limits"
      fi
    fi
  else
    cmd="-"
    notes="not found on PATH"
  fi

  if [ "$format" = "markdown" ]; then
    printf "| \`%s\` | %s | %s | \`%s\` | %s |\n" "$id" "$installed" "$auth" "$cmd" "$notes"
  else
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$installed" "$auth" "$cmd" "$notes"
  fi
done
