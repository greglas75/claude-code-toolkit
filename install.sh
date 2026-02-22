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

# --- 2b. Slash commands (symlink SKILL.md as command name) ---
mkdir -p "$CLAUDE_DIR/commands"
for skill_dir in "$TOOLKIT_DIR"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  [ -f "$skill_dir/SKILL.md" ] && ln -sf "$CLAUDE_DIR/skills/$skill_name/SKILL.md" "$CLAUDE_DIR/commands/$skill_name.md"
done
echo "  + commands/ (slash commands)"

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

# --- 5. Google Antigravity global integration ---
ANTIGRAVITY_DIR="$HOME/.gemini/antigravity"
mkdir -p "$ANTIGRAVITY_DIR/skills"
for skill_dir in "$TOOLKIT_DIR"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  ln -sfn "$CLAUDE_DIR/skills/$skill_name" "$ANTIGRAVITY_DIR/skills/$skill_name" 2>/dev/null || true
done
echo "  + ~/.gemini/antigravity/skills/ (Antigravity global skills)"

# --- 6. Cursor IDE integration (native agent orchestration) ---
# Build Cursor-adapted skills (overlays + agent adaptation)
bash "$TOOLKIT_DIR/scripts/build-cursor-skills.sh" "$TOOLKIT_DIR"

CURSOR_DIR="$HOME/.cursor"

# Install rules from dist (unicode-normalized)
mkdir -p "$CURSOR_DIR/rules"
for f in "$TOOLKIT_DIR"/dist/cursor/rules/*.md; do
  [ -f "$f" ] && ln -sf "$f" "$CURSOR_DIR/rules/$(basename "$f")"
done

# Install protocol files from dist (unicode-normalized)
for f in "$TOOLKIT_DIR"/dist/cursor/protocols/*.md; do
  [ -f "$f" ] && ln -sf "$f" "$CURSOR_DIR/$(basename "$f")"
done

# Install skills
CURSOR_SKILLS_DIR="$CURSOR_DIR/skills"
mkdir -p "$CURSOR_SKILLS_DIR"
for skill_dir in "$TOOLKIT_DIR"/dist/cursor/skills/*/; do
  [ -d "$skill_dir" ] || continue
  ln -sfn "$skill_dir" "$CURSOR_SKILLS_DIR/$(basename "$skill_dir")" 2>/dev/null || true
done

# Install agents
CURSOR_AGENTS_DIR="$CURSOR_DIR/agents"
mkdir -p "$CURSOR_AGENTS_DIR"
for agent in "$TOOLKIT_DIR"/dist/cursor/agents/*.md; do
  [ -f "$agent" ] || continue
  ln -sf "$agent" "$CURSOR_AGENTS_DIR/$(basename "$agent")" 2>/dev/null || true
done
echo "  + ~/.cursor/ (rules, protocols, skills, agents)"

# --- 7. Per-project setup script ---
mkdir -p "$CLAUDE_DIR/scripts"
cp "$TOOLKIT_DIR/scripts/setup-antigravity-all.sh" "$CLAUDE_DIR/scripts/setup-antigravity-all.sh"
chmod +x "$CLAUDE_DIR/scripts/setup-antigravity-all.sh"
echo "  + ~/.claude/scripts/setup-antigravity-all.sh"

echo ""
echo "Done. Installed to $CLAUDE_DIR"
echo ""
echo "Verify with: ls ~/.claude/skills/"
SKILL_LIST=$(ls -d "$TOOLKIT_DIR"/skills/*/ 2>/dev/null | xargs -I{} basename {} | tr '\n' ', ' | sed 's/,$//')
echo "Skills: $SKILL_LIST"
echo ""
echo "Symlinked to:"
echo "  ~/.claude/skills/       (Claude Code)"
echo "  ~/.cursor/skills/       (Cursor — native agent orchestration)"
echo "  ~/.cursor/agents/       (Cursor — sub-agents)"
echo "  ~/.gemini/antigravity/  (Google Antigravity)"
echo ""
echo "All tools auto-update when you edit skills in this repo."
echo ""
echo "Per-project Antigravity setup: bash ~/.claude/scripts/setup-antigravity-all.sh"
