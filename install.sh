#!/bin/bash
# Install Claude Code toolkit — rules, skills, and protocols
# Usage: bash install.sh [--symlink | --copy]
#
# --symlink (default): symlinks to this repo — updates automatically on git pull
# --copy: copies files — independent of this repo after install

set -e
TOOLKIT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
MODE="${1:---symlink}"

echo "Installing Claude Code toolkit..."
echo "  Source: $TOOLKIT_DIR"
echo "  Target: $CLAUDE_DIR"
echo "  Mode:   $MODE"
echo ""

# Create target directories
mkdir -p "$CLAUDE_DIR/rules"
mkdir -p "$CLAUDE_DIR/skills"
mkdir -p "$CLAUDE_DIR/conditional-rules"

install_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ "$MODE" = "--symlink" ]; then
    ln -sf "$src" "$dst"
  else
    cp "$src" "$dst"
  fi
}

install_dir() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  if [ "$MODE" = "--symlink" ]; then
    for f in "$src"/*.md; do
      [ -f "$f" ] && ln -sf "$f" "$dst/$(basename "$f")"
    done
  else
    cp "$src"/*.md "$dst/"
  fi
}

# --- 1. Global rules (always-on) ---
for f in "$TOOLKIT_DIR"/rules/*.md; do
  base=$(basename "$f")
  install_file "$f" "$CLAUDE_DIR/rules/$base"
done
echo "  + rules/ ($(ls "$TOOLKIT_DIR"/rules/*.md | wc -l | tr -d ' ') files)"

# --- 2. Skills ---
for skill_dir in "$TOOLKIT_DIR"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  install_dir "$skill_dir" "$CLAUDE_DIR/skills/$skill_name"
done
echo "  + skills/ ($(ls -d "$TOOLKIT_DIR"/skills/*/ | wc -l | tr -d ' ') skills)"

# --- 3. Conditional rules ---
for f in "$TOOLKIT_DIR"/conditional-rules/*.md; do
  [ -f "$f" ] && install_file "$f" "$CLAUDE_DIR/conditional-rules/$(basename "$f")"
done
echo "  + conditional-rules/"

# --- 4. Protocol files (root level) ---
for f in "$TOOLKIT_DIR"/*.md; do
  base=$(basename "$f")
  [ "$base" = "README.md" ] && continue
  install_file "$f" "$CLAUDE_DIR/$base"
done
echo "  + protocol files (test-patterns, refactoring-protocol, review-protocol)"

echo ""
echo "Done. Installed to $CLAUDE_DIR"
echo ""
echo "Verify with: ls ~/.claude/skills/"
echo "Use skills: /test-audit all, /review, /refactor, /backlog"
