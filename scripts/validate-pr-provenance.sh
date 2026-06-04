#!/usr/bin/env sh
set -eu

body_file=""

usage() {
  cat <<'EOF'
Usage: validate-pr-provenance.sh --body-file PATH

Validates that a pull request body contains the required SwiftAnvil review
provenance table.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --body-file)
      body_file="${2:-}"
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

if [ -z "$body_file" ]; then
  usage >&2
  exit 2
fi

if [ ! -f "$body_file" ]; then
  echo "error: PR body file not found: $body_file" >&2
  exit 2
fi

failures=0

contains_required_table_header() {
  awk '
    BEGIN { found = 0 }
    /^\|/ {
      line = tolower($0)
      gsub(/[[:space:]*`]/, "", line)
      if (line ~ /^\|phase\|reviewer\|model\|verdict\|rounds\|keyfindings\|$/) {
        found = 1
      }
    }
    END { exit found ? 0 : 1 }
  ' "$body_file"
}

has_phase_row() {
  phase="$1"
  awk -v phase="$phase" '
    BEGIN { found = 0 }
    /^\|/ {
      line = tolower($0)
      gsub(/[[:space:]*`]/, "", line)
      split(line, cells, "|")
      if (cells[2] == phase) {
        found = 1
      }
    }
    END { exit found ? 0 : 1 }
  ' "$body_file"
}

phase_row_has_valid_verdict() {
  phase="$1"
  awk -v phase="$phase" '
    BEGIN { found = 0 }
    /^\|/ {
      line = tolower($0)
      gsub(/[[:space:]*`]/, "", line)
      split(line, cells, "|")
      if (cells[2] == phase) {
        verdict = toupper(cells[5])
        if (verdict == "APPROVED" || verdict == "APPROVED_WITH_NOTES" || verdict == "NEEDS_REVISION" || verdict == "SELF-REVIEWED") {
          found = 1
        }
      }
    }
    END { exit found ? 0 : 1 }
  ' "$body_file"
}

phase_row_has_real_values() {
  phase="$1"
  awk -v phase="$phase" '
    BEGIN { found = 0 }
    function placeholder(value) {
      value = tolower(value)
      gsub(/[[:space:]*`]/, "", value)
      return value == "" || value == "tbd" || value == "todo" || value == "pending" || value == "n/a"
    }
    /^\|/ {
      line = $0
      split(line, cells, "|")
      normalized = tolower(cells[2])
      gsub(/[[:space:]*`]/, "", normalized)
      if (normalized == phase) {
        if (!placeholder(cells[3]) && !placeholder(cells[4]) && !placeholder(cells[5]) && !placeholder(cells[6]) && !placeholder(cells[7])) {
          found = 1
        }
      }
    }
    END { exit found ? 0 : 1 }
  ' "$body_file"
}

if ! contains_required_table_header; then
  echo "PR body must include review provenance table header:" >&2
  echo "| Phase | Reviewer | Model | Verdict | Rounds | Key Findings |" >&2
  failures=$((failures + 1))
fi

for phase in plan impl; do
  if ! has_phase_row "$phase"; then
    echo "PR body must include a review provenance row for phase: $phase" >&2
    failures=$((failures + 1))
    continue
  fi

  if ! phase_row_has_valid_verdict "$phase"; then
    echo "PR body phase '$phase' must include a valid verdict" >&2
    failures=$((failures + 1))
  fi

  if ! phase_row_has_real_values "$phase"; then
    echo "PR body phase '$phase' must not use placeholder provenance values" >&2
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "PR provenance validation failed with $failures issue(s)" >&2
  exit 1
fi

echo "PR provenance validation passed"
