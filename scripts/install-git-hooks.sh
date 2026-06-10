#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
enforcement_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
workspace_root=$(CDPATH='' cd -- "$enforcement_root/.." && pwd)
meta_root="$workspace_root/swiftanvil-meta"

if [ ! -f "$meta_root/REGISTRY.yml" ]; then
  echo "error: expected SwiftAnvil meta registry at $meta_root/REGISTRY.yml" >&2
  exit 1
fi

for git_dir in "$workspace_root"/*/.git "$workspace_root"/.github/.git; do
  [ -d "$git_dir" ] || continue

  repo_root=$(CDPATH='' cd -- "$git_dir/.." && pwd)
  hook_path="$git_dir/hooks/pre-commit"

  cat > "$hook_path" <<'EOF'
#!/usr/bin/env sh
set -eu

repo_root=$(git rev-parse --show-toplevel)
workspace_root=$(CDPATH= cd -- "$repo_root/.." && pwd)
branch=$(git rev-parse --abbrev-ref HEAD)

# ── Block direct commits to main ──
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  echo "[pre-commit] ❌ Direct commits to '$branch' are prohibited." >&2
  echo "             Create a feature branch:" >&2
  echo "               git checkout -b feature/<description>" >&2
  echo "               git checkout -b fix/<description>" >&2
  echo "               git checkout -b doc/<description>" >&2
  echo "               git checkout -b chore/<description>" >&2
  exit 1
fi

# ── Document registry & review artifact checks ──
"$workspace_root/swiftanvil-enforcement/scripts/enforce-local.sh" \
  --registry-root "$workspace_root/swiftanvil-meta" \
  --root "$repo_root"

# ── SwiftFormat check (staged files only, for speed) ──
staged_swift=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)
if [ -n "$staged_swift" ]; then
  if command -v swiftformat >/dev/null 2>&1; then
    config_path="$workspace_root/swiftanvil-enforcement/configs/swiftformat.yml"
    if [ -f "$config_path" ]; then
      echo "[pre-commit] Running SwiftFormat lint on staged files..."
      if ! echo "$staged_swift" | xargs swiftformat --lint --config "$config_path"; then
        echo "[pre-commit] ❌ SwiftFormat violations found. Run 'swiftformat .' to fix." >&2
        exit 1
      fi
    else
      echo "[pre-commit] ⚠️ SwiftFormat config not found at $config_path" >&2
    fi
  else
    echo "[pre-commit] ⚠️ SwiftFormat not installed. Skipping format check." >&2
    echo "             Install with: brew install swiftformat" >&2
  fi

  if command -v swiftlint >/dev/null 2>&1; then
    config_path="$workspace_root/swiftanvil-enforcement/configs/swiftlint.yml"
    if [ -f "$config_path" ]; then
      echo "[pre-commit] Running SwiftLint on staged files..."
      if ! echo "$staged_swift" | xargs swiftlint lint --config "$config_path"; then
        echo "[pre-commit] ❌ SwiftLint violations found. Fix before committing." >&2
        exit 1
      fi
    else
      echo "[pre-commit] ⚠️ SwiftLint config not found at $config_path" >&2
    fi
  else
    echo "[pre-commit] ⚠️ SwiftLint not installed. Skipping lint check." >&2
    echo "             Install with: brew install swiftlint" >&2
  fi
fi
EOF

  chmod +x "$hook_path"
  echo "installed pre-commit hook: $repo_root"
done
