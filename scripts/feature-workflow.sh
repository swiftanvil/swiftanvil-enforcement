#!/bin/bash
# feature-workflow.sh — Feature branch creation and PR workflow for SwiftAnvil
# Usage: ./feature-workflow.sh <type> <description>
#   type: feature | fix | doc | chore
#   description: kebab-case description (e.g. "health-monitor")
#
# Example: ./feature-workflow.sh feature health-monitor

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

TYPE="${1:-}"
DESC="${2:-}"

if [ -z "$TYPE" ] || [ -z "$DESC" ]; then
  echo "Usage: $0 <type> <description>"
  echo "  type: feature | fix | doc | chore"
  echo "  description: kebab-case (e.g. health-monitor)"
  exit 1
fi

case "$TYPE" in
  feature|fix|doc|chore) ;;
  *)
    echo "error: type must be one of: feature, fix, doc, chore"
    exit 1
    ;;
esac

BRANCH_NAME="$TYPE/$DESC"

cd "$REPO_ROOT"

# Ensure we're on main and it's up to date
echo "📥 Syncing main..."
git checkout main
git pull origin main

# Create and switch to feature branch
echo "🌿 Creating branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

echo ""
echo "✅ Feature branch '$BRANCH_NAME' created."
echo ""
echo "Next steps:"
echo "  1. Make your changes"
echo "  2. git add -A"
echo "  3. git commit -m \"<type>: <message>\""
echo "  4. git push -u origin $BRANCH_NAME"
echo "  5. Open a PR on GitHub"
echo ""
echo "After PR approval, merge with:"
echo "  $SCRIPT_DIR/merge-via-worktree.sh $BRANCH_NAME"
