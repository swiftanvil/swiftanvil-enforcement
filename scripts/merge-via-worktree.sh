#!/bin/bash
# merge-via-worktree.sh — Rebase-merge feature branch via git worktree
# Usage: ./merge-via-worktree.sh <branch-name>
#
# Workflow:
#   1. Create temporary worktree for main
#   2. Fetch latest main from origin
#   3. Rebase feature branch onto main
#   4. Fast-forward merge main to feature tip
#   5. Push main
#   6. Clean up worktree and local branch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BRANCH="${1:-}"

if [ -z "$BRANCH" ]; then
  echo "Usage: $0 <branch-name>"
  echo "  Merges <branch-name> into main via rebase using a separate git worktree."
  exit 1
fi

cd "$REPO_ROOT"

# Validate branch exists
if ! git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "error: local branch '$BRANCH' not found"
  exit 1
fi

# Validate clean working tree
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "error: working tree is not clean. Commit or stash changes first."
  exit 1
fi

WORKTREE_PATH="$REPO_ROOT/.git/worktrees/merge-$BRANCH"

# Ensure main is up to date
git checkout main
git pull origin main

# If already on main, rebase in-place; otherwise use worktree
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" = "main" ]; then
  echo "🔄 Rebasing $BRANCH onto main (in-place)..."
  git checkout "$BRANCH"
  git rebase main

  echo "⏩ Fast-forwarding main to $BRANCH..."
  git checkout main
  git merge --ff-only "$BRANCH"
else
  echo "🔧 Setting up merge worktree..."
  if [ -d "$WORKTREE_PATH" ]; then
    git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || true
    rm -rf "$WORKTREE_PATH"
  fi
  git worktree add "$WORKTREE_PATH" main
  cd "$WORKTREE_PATH"

  echo "🔄 Rebasing $BRANCH onto main..."
  git fetch origin
  git checkout "$BRANCH"
  git rebase main

  echo "⏩ Fast-forwarding main to $BRANCH..."
  git checkout main
  git merge --ff-only "$BRANCH"

  cd "$REPO_ROOT"
  echo "🧹 Cleaning up worktree..."
  git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || rm -rf "$WORKTREE_PATH"
fi

# Push main
echo "📤 Pushing main..."
git push origin main

echo "🗑️ Deleting feature branch..."
git branch -D "$BRANCH" 2>/dev/null || true
git push origin --delete "$BRANCH" 2>/dev/null || true

# Run cleanup
echo "🧽 Running cleanup..."
"$SCRIPT_DIR/cleanup.sh" "$REPO_ROOT" 2>/dev/null || true

echo ""
echo "✅ Merge complete. '$BRANCH' has been rebased onto main and deleted."
echo "   Main is now at: $(git rev-parse --short HEAD)"
