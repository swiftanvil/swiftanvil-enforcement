#!/bin/bash
# cleanup.sh — Clean build artifacts, derived data, and temporary files
# Usage: ./cleanup.sh [repo-path]
#   If no path given, uses current directory.

set -euo pipefail

TARGET="${1:-.}"
cd "$TARGET"
TARGET="$(pwd)"

echo "🧹 Cleaning: $TARGET"

# Swift Package Manager build artifacts
if [ -d ".build" ]; then
  echo "  Removing .build/"
  rm -rf .build
fi

# Xcode DerivedData
if [ -d "~/Library/Developer/Xcode/DerivedData" ]; then
  echo "  Clearing Xcode DerivedData..."
  rm -rf ~/Library/Developer/Xcode/DerivedData/*
fi

# Swift Package Manager cache
if [ -d "~/Library/Caches/org.swift.swiftpm" ]; then
  echo "  Clearing SPM cache..."
  rm -rf ~/Library/Caches/org.swift.swiftpm
fi

# SwiftAnvil health JSON (regenerated on demand)
if [ -f ".swiftanvil-health.json" ]; then
  echo "  Removing .swiftanvil-health.json"
  rm -f .swiftanvil-health.json
fi

# Git worktree remnants
for wt in .git/worktrees/merge-*; do
  if [ -d "$wt" ]; then
    echo "  Removing stale worktree: $wt"
    git worktree remove "$wt" --force 2>/dev/null || rm -rf "$wt"
  fi
done

# Temporary files
find "$TARGET" -type f \( \
  -name "*.tmp" -o \
  -name "*.temp" -o \
  -name ".DS_Store" -o \
  -name "*.swp" -o \
  -name "*.swo" -o \
  -name "*~" \
\) -delete 2>/dev/null || true

# Empty directories under .build (already removed, but defensive)
find "$TARGET" -type d -name ".build" -exec rm -rf {} + 2>/dev/null || true

# Remove Xcode user data
find "$TARGET" -type d -name "xcuserdata" -exec rm -rf {} + 2>/dev/null || true

# Remove Package.resolved if it exists (optional — can be regenerated)
# Uncomment if desired:
# rm -f Package.resolved

echo "✅ Cleanup complete."
