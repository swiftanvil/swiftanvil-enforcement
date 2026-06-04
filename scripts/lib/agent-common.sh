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
  verdict=$(
    awk '
      {
        line = $0
        line = toupper(line)
        gsub(/[`*]/, "", line)
        gsub(/[[:space:]]+$/, "", line)
        if (line ~ /^(Verdict:|Verdict -|Verdict)/) {
          sub(/^Verdict[: -]*/, "", line)
        }
        if (line ~ /(^|[^A-Z_])APPROVED_WITH_NOTES([^A-Z_]|$)/) {
          print "APPROVED_WITH_NOTES"
          exit
        }
        if (line ~ /(^|[^A-Z_])NEEDS_REVISION([^A-Z_]|$)/) {
          print "NEEDS_REVISION"
          exit
        }
        if (line ~ /(^|[^A-Z_])APPROVED([^A-Z_]|$)/) {
          print "APPROVED"
          exit
        }
      }
    ' "$file"
  )

  if [ -n "$verdict" ]; then
    printf '%s\n' "$verdict"
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
