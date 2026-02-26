#!/bin/bash
# Build Antigravity-adapted skills from Cursor dist.
# Antigravity has the same capabilities as Cursor (no Task tool, no plan mode,
# _agent/ path fallback). The only difference is the home directory prefix.
#
# Usage: bash scripts/build-antigravity-skills.sh [toolkit-dir]

set -e

TOOLKIT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
CURSOR_DIST="$TOOLKIT_DIR/dist/cursor"
DIST="$TOOLKIT_DIR/dist/antigravity"

# Require cursor build to exist
if [ ! -d "$CURSOR_DIST/skills" ]; then
  echo "ERROR: Cursor dist not found at $CURSOR_DIST"
  echo "  Run: bash scripts/build-cursor-skills.sh first"
  exit 1
fi

echo "Building Antigravity skills (from Cursor dist)..."
echo "  Source: $CURSOR_DIST"
echo "  Output: $DIST"
echo ""

# Clean previous build
rm -rf "$DIST"

# Copy entire cursor dist
cp -r "$CURSOR_DIST" "$DIST"

# Replace ~/.cursor/ paths with ~/.antigravity/ across all files
echo "Replacing paths: ~/.cursor/ -> ~/.antigravity/"
find "$DIST" -name "*.md" -type f -print0 | while IFS= read -r -d '' f; do
  sed -i '' \
    -e 's|~/.cursor/skills/|~/.antigravity/skills/|g' \
    -e 's|~/.cursor/rules/|~/.antigravity/rules/|g' \
    -e 's|~/.cursor/|~/.antigravity/|g' \
    -e 's|\.cursor/rules/|.antigravity/rules/|g' \
    "$f"
done

# Validation
echo ""
echo "Validating..."
errors=0

# Check for untransformed ~/.cursor/ paths
bad_paths=$(grep -rln '~/.cursor/' "$DIST" 2>/dev/null || true)
if [ -n "$bad_paths" ]; then
  echo "  ERROR: Untransformed ~/.cursor/ paths found:"
  echo "$bad_paths" | while IFS= read -r f; do
    echo "    $(echo "$f" | sed "s|$DIST/||")"
  done
  errors=$((errors + 1))
fi

# Count skills
skill_count=$(ls -d "$DIST"/skills/*/ 2>/dev/null | wc -l | tr -d ' ')

echo ""
if [ "$errors" -gt 0 ]; then
  echo "BUILD FAILED: $errors error(s)"
  exit 1
fi

echo "Build complete: $DIST"
echo "  Skills: $skill_count"
echo "  Based on: Cursor dist (same capabilities)"
