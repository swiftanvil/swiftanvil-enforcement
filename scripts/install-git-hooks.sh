#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
enforcement_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
workspace_root=$(CDPATH= cd -- "$enforcement_root/.." && pwd)
meta_root="$workspace_root/swiftanvil-meta"

if [ ! -f "$meta_root/REGISTRY.yml" ]; then
  echo "error: expected SwiftAnvil meta registry at $meta_root/REGISTRY.yml" >&2
  exit 1
fi

for git_dir in "$workspace_root"/*/.git "$workspace_root"/.github/.git; do
  [ -d "$git_dir" ] || continue

  repo_root=$(CDPATH= cd -- "$git_dir/.." && pwd)
  hook_path="$git_dir/hooks/pre-commit"

  cat > "$hook_path" <<'EOF'
#!/usr/bin/env sh
set -eu

repo_root=$(git rev-parse --show-toplevel)
workspace_root=$(CDPATH= cd -- "$repo_root/.." && pwd)

exec "$workspace_root/swiftanvil-enforcement/scripts/validate-document-registry.sh" \
  --registry-root "$workspace_root/swiftanvil-meta" \
  --root "$repo_root"
EOF

  chmod +x "$hook_path"
  echo "installed pre-commit hook: $repo_root"
done
