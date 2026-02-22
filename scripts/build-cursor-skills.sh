#!/bin/bash
# Build Cursor-adapted skills from Claude Code source skills.
# Adapts agents, assembles overlays + shared files, validates output.
#
# Usage: bash scripts/build-cursor-skills.sh [toolkit-dir]

set -e

TOOLKIT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DIST="$TOOLKIT_DIR/dist/cursor"

echo "Building Cursor skills..."
echo "  Source: $TOOLKIT_DIR"
echo "  Output: $DIST"
echo ""

# Clean previous build
rm -rf "$DIST"
mkdir -p "$DIST/agents" "$DIST/skills"

# --- Agent Adaptation ---
# Converts Claude Code agent definitions to Cursor agent format.
# Removes model: and tools: from frontmatter, keeps name + description.
adapt_agent() {
  local src="$1"
  local dst="$2"

  awk '
    BEGIN { in_fm=0; past_fm=0; skip_tools=0 }

    # Frontmatter boundaries
    /^---$/ && !in_fm && !past_fm { in_fm=1; print; next }
    /^---$/ && in_fm { in_fm=0; past_fm=1; skip_tools=0; print; next }

    # Inside frontmatter: keep name + description, skip model + tools
    in_fm && /^model:/ { next }
    in_fm && /^tools:/ { skip_tools=1; next }
    in_fm && skip_tools && /^  - / { next }
    in_fm && skip_tools && !/^  - / { skip_tools=0 }
    in_fm { print; next }

    # Body: pass through unchanged
    { print }
  ' "$src" | awk '
    # Skip "## Team Mode Verification" section in agent bodies
    /^### .*Team Mode/ { skip=1; next }
    skip && /^(### |## |---)/ { skip=0 }
    skip { next }
    { print }
  ' | sed \
    -e 's|~/.claude/skills/|~/.cursor/skills/|g' \
    -e 's|~/.claude/rules/|~/.cursor/rules/|g' \
    -e 's|~/.claude/|~/.cursor/|g' \
    -e 's/—/--/g' \
    -e 's/→/->/g' \
    -e 's/✅/[x]/g' \
    -e 's/❌/[ ]/g' \
    -e 's/━/-/g' \
    -e 's/═/=/g' \
    -e 's/≤/<=/g' \
    -e 's/≥/>=/g' \
    > "$dst"
}

# --- Skill Transform (mechanical, for skills without overlay) ---
# Used as fallback when no cursor/SKILL.cursor.md exists.
transform_skill() {
  local src="$1"
  local dst="$2"

  awk '
    # Skip "## Progress Tracking" section (until next ## or ---)
    /^## Progress Tracking$/ { skip=1; next }

    # Skip "## Multi-Agent Compatibility" section
    /^## Multi-Agent Compatibility$/ { skip=1; next }

    # End skip at next heading or horizontal rule
    skip && /^(## |---)/ { skip=0 }
    skip { next }

    # Path replacements
    { gsub(/~\/\.claude\/skills\//, "~/.cursor/skills/") }
    { gsub(/~\/\.claude\/rules\//, "~/.cursor/rules/") }
    { gsub(/~\/\.claude\//, "~/.cursor/") }

    # Remove tool-specific metadata lines (only in spawn blocks)
    /^[[:space:]]*model: "(sonnet|haiku|opus)"/ { next }
    /^[[:space:]]*subagent_type:/ { next }
    /^[[:space:]]*run_in_background:/ { next }

    { print }
  ' "$src" | sed \
    -e 's/—/--/g' \
    -e 's/→/->/g' \
    -e 's/✅/[x]/g' \
    -e 's/❌/[ ]/g' \
    -e 's/━/-/g' \
    -e 's/═/=/g' \
    -e 's/≤/<=/g' \
    -e 's/≥/>=/g' \
    > "$dst"
}

# ============================================================
# 1. Adapt agents
# ============================================================
echo "Adapting agents..."
agent_count=0
for agent_dir in "$TOOLKIT_DIR"/skills/*/agents; do
  [ -d "$agent_dir" ] || continue
  for agent in "$agent_dir"/*.md; do
    [ -f "$agent" ] || continue
    name=$(basename "$agent" .md)
    adapt_agent "$agent" "$DIST/agents/$name.md"
    echo "  + $name"
    agent_count=$((agent_count + 1))
  done
done

# ============================================================
# 2. Assemble skills
# ============================================================
echo ""
echo "Assembling skills..."
skill_count=0
for skill_dir in "$TOOLKIT_DIR"/skills/*/; do
  skill=$(basename "$skill_dir")
  mkdir -p "$DIST/skills/$skill"

  # Use overlay if present, otherwise mechanical transform
  if [ -f "$skill_dir/cursor/SKILL.cursor.md" ]; then
    cp "$skill_dir/cursor/SKILL.cursor.md" "$DIST/skills/$skill/SKILL.md"
    echo "  + $skill (overlay)"
  else
    transform_skill "$skill_dir/SKILL.md" "$DIST/skills/$skill/SKILL.md"
    echo "  + $skill (auto-transform)"
  fi

  # Copy shared files with path + tool transformation
  for f in rules.md dimensions.md agent-prompt.md orchestrator-prompt.md; do
    if [ -f "$skill_dir/$f" ]; then
      awk '
        # Skip "## Team Mode" section (Claude Code only, not applicable in Cursor)
        /^## Team Mode/ { skip=1; next }
        skip && /^## / { skip=0 }
        skip { next }
        { print }
      ' "$skill_dir/$f" | sed \
          -e 's|~/.claude/skills/|~/.cursor/skills/|g' \
          -e 's|~/.claude/rules/|~/.cursor/rules/|g' \
          -e 's|~/.claude/|~/.cursor/|g' \
          -e '/^[[:space:]]*subagent_type:/d' \
          -e '/^[[:space:]]*run_in_background:/d' \
          -e 's/—/--/g' \
          -e 's/→/->/g' \
          -e 's/✅/[x]/g' \
          -e 's/❌/[ ]/g' \
          -e 's/━/-/g' \
          -e 's/═/=/g' \
          -e 's/≤/<=/g' \
          -e 's/≥/>=/g' \
          > "$DIST/skills/$skill/$f"
    fi
  done

  skill_count=$((skill_count + 1))
done

# ============================================================
# 3. Validation
# ============================================================
echo ""
echo "Validating..."
warnings=0

# Check line counts
for f in "$DIST"/skills/*/SKILL.md; do
  lines=$(wc -l < "$f" | tr -d ' ')
  skill=$(basename "$(dirname "$f")")
  if [ "$lines" -gt 500 ]; then
    echo "  WARN: $skill/SKILL.md exceeds 500 lines ($lines)"
    warnings=$((warnings + 1))
  fi
done

# Check for Claude Code-specific tool references in ALL dist SKILL.md files
# (skip shared docs like rules.md where terms may appear in documentation tables)
claude_refs=$(grep -rln \
  'TaskCreate\|TaskUpdate\|TaskList\|EnterPlanMode\|ExitPlanMode\|AskUserQuestion\|run_in_background\|TeamCreate\|SendMessage' \
  "$DIST"/skills/*/SKILL.md "$DIST"/agents/*.md 2>/dev/null || true)

if [ -n "$claude_refs" ]; then
  echo "  ERROR: Claude Code-specific references found (build blocked):"
  echo "$claude_refs" | while IFS= read -r f; do
    echo "    $(echo "$f" | sed "s|$DIST/||")"
  done
  echo ""
  echo "  Fix: update the overlay or source file to remove Claude Code tool references."
  exit 1
fi

# Check for untransformed ~/.claude/ paths
claude_paths=$(grep -rln '~/.claude/' "$DIST" 2>/dev/null || true)

if [ -n "$claude_paths" ]; then
  echo "  ERROR: Untransformed ~/.claude/ paths found (build blocked):"
  echo "$claude_paths" | while IFS= read -r f; do
    echo "    $(echo "$f" | sed "s|$DIST/||")"
  done
  echo ""
  echo "  Fix: update the overlay or add path replacement to transform_skill()."
  exit 1
fi

# Verify all agents were adapted
for agent_dir in "$TOOLKIT_DIR"/skills/*/agents; do
  [ -d "$agent_dir" ] || continue
  for agent in "$agent_dir"/*.md; do
    [ -f "$agent" ] || continue
    name=$(basename "$agent" .md)
    if [ ! -f "$DIST/agents/$name.md" ]; then
      echo "  WARN: Agent $name not found in dist"
      warnings=$((warnings + 1))
    fi
  done
done

# ============================================================
# Summary
# ============================================================
echo ""
echo "Build complete: $DIST"
echo "  Agents: $agent_count"
echo "  Skills: $skill_count"
if [ "$warnings" -gt 0 ]; then
  echo "  Warnings: $warnings"
fi
