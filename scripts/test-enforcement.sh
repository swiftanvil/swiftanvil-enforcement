#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/swiftanvil-enforcement.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

assert_pass() {
  if ! "$@" > "$tmp_dir/out.log" 2>&1; then
    cat "$tmp_dir/out.log" >&2
    echo "expected command to pass: $*" >&2
    exit 1
  fi
}

assert_fail() {
  if "$@" > "$tmp_dir/out.log" 2>&1; then
    cat "$tmp_dir/out.log" >&2
    echo "expected command to fail: $*" >&2
    exit 1
  fi
}

write_success_metadata() {
  builder="$1"
  cat > "$tmp_dir/repo/Reviews/2026-06-04-review.md.review.yml" <<EOF
schema_version: 1
status: success
agent: claude
builder: $builder
request: 'Reviews/2026-06-04-review-request.md'
output: 'Reviews/2026-06-04-review.md'
verdict: APPROVED
started_at: '2026-06-04T00:00:00Z'
finished_at: '2026-06-04T00:00:01Z'
exit_code: 0
home_strategy: login_home
EOF
}

mkdir -p "$tmp_dir/meta" "$tmp_dir/repo/Reviews"

cat > "$tmp_dir/meta/REGISTRY.yml" <<'EOF'
documents:
  - id: docs.example
    path: Docs/example.md
EOF

echo "Use docs.example for references." > "$tmp_dir/repo/README.md"
assert_pass "$script_dir/validate-document-registry.sh" --registry-root "$tmp_dir/meta" --root "$tmp_dir/repo"

echo "Do not hardcode Docs/example.md here." > "$tmp_dir/repo/BAD.md"
assert_fail "$script_dir/validate-document-registry.sh" --registry-root "$tmp_dir/meta" --root "$tmp_dir/repo"
rm "$tmp_dir/repo/BAD.md"

cat > "$tmp_dir/repo/Reviews/2026-06-04-review-request.md" <<'EOF'
# Review Request

Return APPROVED, APPROVED_WITH_NOTES, or NEEDS_REVISION.
EOF

echo "APPROVED" > "$tmp_dir/repo/Reviews/2026-06-04-review.md"
write_success_metadata "codex"
assert_pass "$script_dir/validate-review-artifacts.sh" --root "$tmp_dir/repo"

write_success_metadata "claude"
assert_fail "$script_dir/validate-review-artifacts.sh" --root "$tmp_dir/repo"

write_success_metadata ""
assert_fail "$script_dir/validate-review-artifacts.sh" --root "$tmp_dir/repo"

assert_fail "$script_dir/run-agent-review.sh" \
  --agent auto \
  --request "$tmp_dir/repo/Reviews/2026-06-04-review-request.md" \
  --output "$tmp_dir/repo/Reviews/2026-06-04-review.md"

write_success_metadata "codex"
assert_pass "$repo_root/scripts/enforce-local.sh" --registry-root "$tmp_dir/meta" --root "$tmp_dir/repo"

echo "enforcement self-tests passed"
