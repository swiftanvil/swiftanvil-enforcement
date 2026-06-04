#!/usr/bin/env sh

login_home() {
  if [ -n "${SWIFTANVIL_AGENT_HOME:-}" ]; then
    printf '%s\n' "$SWIFTANVIL_AGENT_HOME"
    return
  fi

  if [ -n "${USER:-}" ]; then
    if command -v dscl >/dev/null 2>&1; then
      home=$(dscl . -read "/Users/$USER" NFSHomeDirectory 2>/dev/null | awk '{print $2; exit}' || true)
      if [ -n "$home" ]; then
        printf '%s\n' "$home"
        return
      fi
    fi

    if command -v getent >/dev/null 2>&1; then
      home=$(getent passwd "$USER" | awk -F: '{print $6; exit}' || true)
      if [ -n "$home" ]; then
        printf '%s\n' "$home"
        return
      fi
    fi

    expanded=$(eval "printf '%s' ~$USER" 2>/dev/null || true)
    if [ -n "$expanded" ] && [ "$expanded" != "~$USER" ]; then
      printf '%s\n' "$expanded"
      return
    fi
  fi

  printf '%s\n' "${HOME:-}"
}

agent_command() {
  command -v "$1" 2>/dev/null || true
}

iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

yaml_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

extract_verdict() {
  file="$1"
  if grep -Eq '\bNEEDS_REVISION\b' "$file"; then
    printf '%s\n' "NEEDS_REVISION"
  elif grep -Eq '\bAPPROVED_WITH_NOTES\b' "$file"; then
    printf '%s\n' "APPROVED_WITH_NOTES"
  elif grep -Eq '\bAPPROVED\b' "$file"; then
    printf '%s\n' "APPROVED"
  else
    printf '%s\n' "UNKNOWN"
  fi
}

adapter_dir() {
  script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
  printf '%s\n' "$(CDPATH='' cd -- "$script_dir/../adapters" && pwd)"
}

repo_root_from_script() {
  script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
  printf '%s\n' "$(CDPATH='' cd -- "$script_dir/.." && pwd)"
}
