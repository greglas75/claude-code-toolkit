#!/bin/bash
# Build OpenAI Codex CLI-adapted skills from Claude Code source skills.
# Codex has no sub-agents — agent prompts become references/ within each skill.
# Adapts paths (~/.claude/ -> ~/.codex/), strips Claude Code tool references.
#
# Usage: bash scripts/build-codex-skills.sh [toolkit-dir]

set -e

TOOLKIT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
DIST="$TOOLKIT_DIR/dist/codex"

echo "Building Codex skills..."
echo "  Source: $TOOLKIT_DIR"
echo "  Output: $DIST"
echo ""

# Clean previous build
rm -rf "$DIST"
mkdir -p "$DIST/skills"

# --- Unicode Normalization (reusable) ---
normalize_unicode() {
  sed \
    -e 's/—/--/g' \
    -e 's/→/->/g' \
    -e 's/✅/[x]/g' \
    -e 's/❌/[ ]/g' \
    -e 's/━/-/g' \
    -e 's/═/=/g' \
    -e 's/≤/<=/g' \
    -e 's/≥/>=/g'
}

# --- Path Replacement (reusable) ---
# Replaces ~/.claude/ paths with ~/.codex/ paths.
# Agent paths must be replaced BEFORE general ~/.claude/ replacement.
replace_paths() {
  sed \
    -e 's|~/.claude/skills/[a-z-]*/agents/|references/|g' \
    -e 's|~/.claude/skills/|~/.codex/skills/|g' \
    -e 's|~/.claude/rules/|~/.codex/rules/|g' \
    -e 's|~/.claude/|~/.codex/|g'
}

# --- Strip Claude Code Tool Names (reusable) ---
# Replaces tool names with plain English equivalents.
strip_tool_names() {
  sed \
    -e 's/`TaskCreate`/task creation/g' \
    -e 's/`TaskUpdate`/task update/g' \
    -e 's/`TaskList`/task list/g' \
    -e 's/`EnterPlanMode`/plan mode/g' \
    -e 's/`ExitPlanMode`/exit plan mode/g' \
    -e 's/`AskUserQuestion`/ask the user/g' \
    -e 's/TaskCreate/task creation/g' \
    -e 's/TaskUpdate/task update/g' \
    -e 's/TaskList/task list/g' \
    -e 's/ExitPlanMode/finalize the plan/g' \
    -e 's/EnterPlanMode/enter plan mode/g' \
    -e 's/AskUserQuestion/ask the user/g' \
    -e 's/TeamCreate/create team/g' \
    -e 's/SendMessage/send message/g' \
    -e 's/`Task` tool to spawn parallel sub-agents/parallel analysis/g' \
    -e 's/`Task` tool/inline analysis/g' \
    -e 's/Task tool/inline analysis/g' \
    -e 's/shutdown_request/shutdown request/g' \
    -e 's/TeamDelete/delete team/g'
}

# --- Strip Team/Multi-Agent Sections from Protocols (reusable) ---
# Removes ### Team Execution, #### Step N blocks inside it, up to next ### at same level.
strip_team_sections() {
  awk '
    /^### Team Execution/ { skip=1; next }
    skip && /^### / { skip=0 }
    skip { next }
    { print }
  '
}

# --- Skill Transform for Codex ---
# Mechanical transform: strip sections, replace spawn blocks, fix paths.
transform_skill_for_codex() {
  local src="$1"
  local dst="$2"

  awk '
    BEGIN { in_fm=0; past_fm=0; skip_section=0; in_code=0; in_spawn=0; agent="" }

    # --- Frontmatter: keep name + description only ---
    /^---$/ && !in_fm && !past_fm { in_fm=1; print; next }
    /^---$/ && in_fm { in_fm=0; past_fm=1; print; next }
    in_fm && /^(name|description):/ { print; next }
    in_fm { next }

    # --- Skip sections: Progress Tracking, Multi-Agent Compatibility, Model Routing ---
    /^## Progress Tracking/ { skip_section=1; next }
    /^## Multi-Agent Compatibility/ { skip_section=1; next }
    /^## Model Routing/ { skip_section=1; next }
    skip_section && /^## / { skip_section=0 }
    skip_section && /^---$/ { skip_section=0 }
    skip_section { next }

    # --- Spawn block replacement ---
    # Opening code fence: check if next line is a spawn block
    /^```/ && !in_code {
      in_code=1
      saved_fence=$0
      next
    }

    # First line inside code block — decide if spawn or normal
    in_code && !in_spawn && saved_fence != "" {
      if ($0 ~ /Spawn via Task tool/) {
        in_spawn=1
        agent=""
        saved_fence=""
        next
      } else if ($0 ~ /^Task\(/) {
        in_spawn=1
        agent=""
        saved_fence=""
        next
      } else {
        # Normal code block — print buffered fence + current line
        print saved_fence
        saved_fence=""
        print
        next
      }
    }

    # Inside spawn block: capture agent name, skip content
    in_spawn && /agents\/[a-z][-a-z]*\.md/ {
      s=$0
      gsub(/.*agents\//, "", s)
      gsub(/\.md.*/, "", s)
      agent=s
      next
    }
    in_spawn && /^```/ {
      # End of spawn block — output replacement
      if (agent != "") {
        print "Read `references/" agent ".md` and perform this analysis yourself."
      } else {
        print "Perform this analysis inline."
      }
      print ""
      in_code=0
      in_spawn=0
      agent=""
      next
    }
    in_spawn { next }

    # Normal code block closing fence
    /^```/ && in_code { in_code=0; print; next }

    # --- Remove tool metadata lines (outside code blocks) ---
    /^[[:space:]]*model: "(sonnet|haiku|opus)"/ { next }
    /^[[:space:]]*subagent_type:/ { next }
    /^[[:space:]]*run_in_background:/ { next }

    # --- Remove table rows/headers with subagent_type column ---
    /\| *subagent_type *\|/ { next }

    # --- Remove Claude Code-specific paragraphs ---
    /^The Task tool does NOT read/ { next }
    /^.*MUST specify the `model` parameter explicitly on every Task call/ { next }

    # --- Default: print ---
    { print }
  ' "$src" \
    | replace_paths \
    | strip_tool_names \
    | sed \
      -e 's/spawn a Task agent (subagent_type: "general-purpose") with this prompt/evaluate each batch with this prompt/g' \
      -e 's/spawn a Task agent (`subagent_type: "general-purpose"`, `model: "sonnet"`)/evaluate each batch inline/g' \
      -e 's/`subagent_type: "general-purpose"`//g' \
      -e 's/Spawn up to [0-9]* general-purpose agents via inline analysis/Perform these fixes sequentially/g' \
      -e 's/run_in_background=true/sequentially/g' \
      -e 's/run_in_background: true//g' \
      -e 's/(use inline analysis, sequentially)/sequentially/g' \
      -e 's/Spawn applicable agents in parallel.*Incorporate results when available\./Perform these analyses sequentially. Start auditing immediately./g' \
    | normalize_unicode > "$dst"
}

# --- Agent -> Reference Adaptation ---
# Strips model/tools from frontmatter, replaces paths, normalizes unicode.
adapt_agent_as_reference() {
  local src="$1"
  local dst="$2"

  awk '
    BEGIN { in_fm=0; past_fm=0; skip_tools=0; skip_section=0 }

    # Frontmatter boundaries
    /^---$/ && !in_fm && !past_fm { in_fm=1; print; next }
    /^---$/ && in_fm { in_fm=0; past_fm=1; skip_tools=0; print; next }

    # Inside frontmatter: keep name + description, skip model + tools
    in_fm && /^model:/ { next }
    in_fm && /^tools:/ { skip_tools=1; next }
    in_fm && skip_tools && /^  - / { next }
    in_fm && skip_tools && !/^  - / { skip_tools=0 }
    in_fm { print; next }

    # Skip "Team Mode Verification" section
    /^### .*Team Mode/ { skip_section=1; next }
    skip_section && /^(### |## |---)/ { skip_section=0 }
    skip_section { next }

    # Body: pass through
    { print }
  ' "$src" \
    | replace_paths \
    | normalize_unicode > "$dst"
}

# ============================================================
# 1. Normalize rules + protocol files
# ============================================================
echo "Normalizing rules and protocols..."
mkdir -p "$DIST/rules" "$DIST/protocols"

for f in "$TOOLKIT_DIR"/rules/*.md; do
  [ -f "$f" ] && cat "$f" \
    | replace_paths \
    | strip_tool_names \
    | normalize_unicode > "$DIST/rules/$(basename "$f")"
done
echo "  + rules/ ($(ls "$TOOLKIT_DIR"/rules/*.md 2>/dev/null | wc -l | tr -d ' ') files)"

for f in "$TOOLKIT_DIR"/*.md; do
  base=$(basename "$f")
  [ "$base" = "README.md" ] && continue
  cat "$f" \
    | replace_paths \
    | strip_team_sections \
    | strip_tool_names \
    | normalize_unicode > "$DIST/protocols/$base"
done
echo "  + protocols/ (test-patterns, refactoring-protocol, review-protocol)"

# ============================================================
# 2. Assemble skills
# ============================================================
echo ""
echo "Assembling skills..."
skill_count=0
ref_count=0

for skill_dir in "$TOOLKIT_DIR"/skills/*/; do
  skill=$(basename "$skill_dir")
  mkdir -p "$DIST/skills/$skill"

  # --- SKILL.md: overlay or mechanical transform ---
  if [ -f "$skill_dir/codex/SKILL.codex.md" ]; then
    cp "$skill_dir/codex/SKILL.codex.md" "$DIST/skills/$skill/SKILL.md"
    echo "  + $skill (overlay)"
  else
    transform_skill_for_codex "$skill_dir/SKILL.md" "$DIST/skills/$skill/SKILL.md"
    echo "  + $skill (auto-transform)"
  fi

  # --- Shared files (rules.md, dimensions.md, agent-prompt.md, orchestrator-prompt.md) ---
  for f in rules.md dimensions.md agent-prompt.md orchestrator-prompt.md; do
    if [ -f "$skill_dir/$f" ]; then
      awk '
        # Skip "## Team Mode" section
        /^## Team Mode/ { skip=1; next }
        skip && /^## / { skip=0 }
        skip { next }
        # Replace "## Sub-Agents" section with references note
        /^## Sub-Agents/ {
          print "## Reference Files"
          print ""
          print "Analysis prompts are in `references/*.md`. Read the relevant reference file and perform the analysis inline."
          skip=1; next
        }
        { print }
      ' "$skill_dir/$f" \
        | replace_paths \
        | strip_tool_names \
        | sed \
          -e '/^[[:space:]]*subagent_type:/d' \
          -e '/^[[:space:]]*run_in_background:/d' \
        | normalize_unicode > "$DIST/skills/$skill/$f"
    fi
  done

  # --- Agents -> References ---
  # Copy agents from the skill's own agents/ directory
  if [ -d "$skill_dir/agents" ]; then
    mkdir -p "$DIST/skills/$skill/references"
    for agent in "$skill_dir/agents/"*.md; do
      [ -f "$agent" ] || continue
      name=$(basename "$agent" .md)
      adapt_agent_as_reference "$agent" "$DIST/skills/$skill/references/$name.md"
      echo "    ref: $name"
      ref_count=$((ref_count + 1))
    done
  fi

  # Copy cross-referenced agents (e.g., build references refactor's agents)
  # Scan SKILL.md for agent paths pointing to other skills
  if [ ! -d "$skill_dir/agents" ]; then
    cross_agents=$(grep -o '~/.claude/skills/[a-z-]*/agents/[a-z-]*\.md' "$skill_dir/SKILL.md" 2>/dev/null | sort -u || true)
    if [ -n "$cross_agents" ]; then
      mkdir -p "$DIST/skills/$skill/references"
      echo "$cross_agents" | while IFS= read -r agent_path; do
        # Resolve path: ~/.claude/skills/refactor/agents/dependency-mapper.md -> skills/refactor/agents/dependency-mapper.md
        rel_path=$(echo "$agent_path" | sed 's|~/.claude/||')
        src_file="$TOOLKIT_DIR/$rel_path"
        name=$(basename "$agent_path" .md)
        if [ -f "$src_file" ]; then
          adapt_agent_as_reference "$src_file" "$DIST/skills/$skill/references/$name.md"
          echo "    ref: $name (from $(echo "$rel_path" | sed 's|/agents/.*||'))"
          ref_count=$((ref_count + 1))
        fi
      done
    fi
  fi

  skill_count=$((skill_count + 1))
done

# ============================================================
# 3. Validation
# ============================================================
echo ""
echo "Validating..."
errors=0
warnings=0

# Check for Claude Code-specific tool references in entire dist (excluding references/)
tool_refs=$(grep -rln \
  'TaskCreate\|TaskUpdate\|TaskList\|EnterPlanMode\|ExitPlanMode\|AskUserQuestion\|run_in_background\|TeamCreate\|SendMessage' \
  "$DIST" --include="*.md" 2>/dev/null | grep -v '/references/' || true)

if [ -n "$tool_refs" ]; then
  echo "  ERROR: Claude Code tool references found (build blocked):"
  echo "$tool_refs" | while IFS= read -r f; do
    echo "    $(echo "$f" | sed "s|$DIST/||")"
    grep -n 'TaskCreate\|TaskUpdate\|TaskList\|EnterPlanMode\|ExitPlanMode\|AskUserQuestion\|run_in_background\|TeamCreate\|SendMessage' "$f" | head -5 | while IFS= read -r line; do
      echo "      $line"
    done
  done
  errors=$((errors + 1))
fi

# Check for untransformed ~/.claude/ or ~/.cursor/ paths (but allow ~/.codex/)
bad_paths=$(grep -rln '~/.claude/\|~/.cursor/' "$DIST" 2>/dev/null || true)

if [ -n "$bad_paths" ]; then
  echo "  ERROR: Untransformed paths found (build blocked):"
  echo "$bad_paths" | while IFS= read -r f; do
    echo "    $(echo "$f" | sed "s|$DIST/||")"
  done
  errors=$((errors + 1))
fi

# Check for subagent_type in SKILL.md
subagent_refs=$(grep -rln 'subagent_type:' "$DIST"/skills/*/SKILL.md 2>/dev/null || true)

if [ -n "$subagent_refs" ]; then
  echo "  ERROR: subagent_type found in SKILL.md (build blocked):"
  echo "$subagent_refs" | while IFS= read -r f; do
    echo "    $(echo "$f" | sed "s|$DIST/||")"
  done
  errors=$((errors + 1))
fi

# Agent reference coverage check
for skill_dir in "$TOOLKIT_DIR"/skills/*/; do
  skill=$(basename "$skill_dir")
  if [ -d "$skill_dir/agents" ]; then
    for agent in "$skill_dir/agents/"*.md; do
      [ -f "$agent" ] || continue
      name=$(basename "$agent" .md)
      if [ ! -f "$DIST/skills/$skill/references/$name.md" ]; then
        echo "  WARN: Missing reference $skill/references/$name.md"
        warnings=$((warnings + 1))
      fi
    done
  fi
done

# Line count warnings
for f in "$DIST"/skills/*/SKILL.md; do
  lines=$(wc -l < "$f" | tr -d ' ')
  skill=$(basename "$(dirname "$f")")
  if [ "$lines" -gt 500 ]; then
    echo "  WARN: $skill/SKILL.md exceeds 500 lines ($lines)"
    warnings=$((warnings + 1))
  fi
done

# ============================================================
# Summary
# ============================================================
echo ""
if [ "$errors" -gt 0 ]; then
  echo "BUILD FAILED: $errors error(s)"
  exit 1
fi

echo "Build complete: $DIST"
echo "  Skills: $skill_count"
echo "  References: $ref_count"
if [ "$warnings" -gt 0 ]; then
  echo "  Warnings: $warnings"
fi
