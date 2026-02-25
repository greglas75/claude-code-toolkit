#!/bin/zsh
# Setup Antigravity integration for all DEV projects
# Creates _agent/skills/, _agent/workflows/, memory/backlog.md, MEMORY.md
# Also installs git hooks: pre-commit (fast checks) + pre-push (tests)
# Run again after adding new skills or projects

DEV="/Users/greglas/DEV"
CP="$HOME/.claude/projects"
SKILLS="$HOME/.claude/skills"

# --- Detect package manager ---
pkg_manager() {
  local dir="$1"
  [ -f "$dir/yarn.lock" ] && echo "yarn" && return
  [ -f "$dir/pnpm-lock.yaml" ] && echo "pnpm run" && return
  echo "npm run"
}

# --- Detect test script from package.json ---
detect_test_cmd() {
  local pkg="$1/package.json"
  [ -f "$pkg" ] || return 1
  local mgr=$(pkg_manager "$1")
  for script in "test:run" "test:unit" "test:changed" "test"; do
    python3 -c "import json,sys; d=json.load(open('$pkg')); sys.exit(0 if '$script' in d.get('scripts',{}) else 1)" 2>/dev/null \
      && echo "$mgr $script" && return
  done
  return 1
}

# --- Detect lint script from package.json ---
detect_lint_cmd() {
  local pkg="$1/package.json"
  [ -f "$pkg" ] || return 1
  local mgr=$(pkg_manager "$1")
  for script in "lint" "lint:check"; do
    python3 -c "import json,sys; d=json.load(open('$pkg')); sys.exit(0 if '$script' in d.get('scripts',{}) else 1)" 2>/dev/null \
      && echo "$mgr $script" && return
  done
  return 1
}

# --- Detect typecheck script from package.json ---
detect_type_cmd() {
  local pkg="$1/package.json"
  [ -f "$pkg" ] || return 1
  local mgr=$(pkg_manager "$1")
  for script in "type-check" "typecheck" "types"; do
    python3 -c "import json,sys; d=json.load(open('$pkg')); sys.exit(0 if '$script' in d.get('scripts',{}) else 1)" 2>/dev/null \
      && echo "$mgr $script" && return
  done
  return 1
}

# --- Install git hooks ---
setup_hooks() {
  local dir="$1"
  [ -d "$dir/.git/hooks" ] || return
  [ -f "$dir/package.json" ] || return

  local hooks_added=""

  # --- pre-commit: fast checks only (skip if husky manages it) ---
  if [ ! -f "$dir/.git/hooks/pre-commit" ] && [ ! -d "$dir/.husky" ]; then
    # No existing pre-commit and no husky — install our test gate
    if [ -f "$HOME/.claude/scripts/pre-commit-test-gate.sh" ]; then
      ln -sf "$HOME/.claude/scripts/pre-commit-test-gate.sh" "$dir/.git/hooks/pre-commit"
      hooks_added="pre-commit(gate)"
    fi
  fi

  # --- pre-push: tests (skip if already exists) ---
  local push_hook=""
  if [ -d "$dir/.husky" ]; then
    push_hook="$dir/.husky/pre-push"
  else
    push_hook="$dir/.git/hooks/pre-push"
  fi

  if [ ! -f "$push_hook" ]; then
    local test_cmd=$(detect_test_cmd "$dir")
    if [ -n "$test_cmd" ]; then
      cat > "$push_hook" << EOF
#!/bin/bash
echo "🧪 Running tests before push..."
$test_cmd

if [ \$? -ne 0 ]; then
  echo "❌ Tests failed. Fix before pushing."
  exit 1
fi

echo "✅ Tests passed!"
EOF
      chmod +x "$push_hook"
      hooks_added="$hooks_added pre-push($test_cmd)"
    fi
  fi

  [ -n "$hooks_added" ] && echo "  hooks: $hooks_added"
}

# --- Main setup function ---
setup() {
  local dir="$1"
  local mem="$2"   # Claude memory dir key (encoded project name)

  [ ! -d "$dir" ] && return

  local memory_src="$CP/$mem/memory"

  # _agent/skills/ and _agent/workflows/
  mkdir -p "$dir/_agent/skills" "$dir/_agent/workflows"
  for skill_dir in "$SKILLS"/*/; do
    skill=$(basename "$skill_dir")
    [ -f "$skill_dir/SKILL.md" ] || continue
    ln -sf "$SKILLS/$skill"          "$dir/_agent/skills/$skill"
    ln -sf "$SKILLS/$skill/SKILL.md" "$dir/_agent/workflows/$skill.md"
  done

  # Root-level protocols and patterns (referenced by skills via ~/.claude/ paths)
  for f in review-protocol.md refactoring-protocol.md test-patterns.md test-patterns-catalog.md test-patterns-redux.md test-patterns-nestjs.md test-patterns-yii2.md refactoring-god-class.md skill-workflows.md; do
    [ -f "$HOME/.claude/$f" ] && ln -sf "$HOME/.claude/$f" "$dir/_agent/$f"
  done

  # Rules directory (CQ1-CQ20, testing, security, etc.)
  ln -sf "$HOME/.claude/rules" "$dir/_agent/rules"

  # Refactoring examples (stack-specific test patterns)
  [ -d "$HOME/.claude/refactoring-examples" ] && ln -sf "$HOME/.claude/refactoring-examples" "$dir/_agent/refactoring-examples"

  # Conditional rules
  [ -d "$HOME/.claude/conditional-rules" ] && ln -sf "$HOME/.claude/conditional-rules" "$dir/_agent/conditional-rules"

  # Agent instructions (tells IDE agents what's available and how to use it)
  ln -sf "$HOME/.claude/agent-instructions.md" "$dir/_agent/AGENT_INSTRUCTIONS.md"

  # Git hooks (pre-commit gate + pre-push tests)
  setup_hooks "$dir"

  # memory/backlog.md
  local has_mem=""
  if [ -f "$memory_src/backlog.md" ]; then
    mkdir -p "$dir/memory"
    ln -sf "$memory_src/backlog.md" "$dir/memory/backlog.md"
    has_mem="backlog"
  fi

  # MEMORY.md
  if [ -f "$memory_src/MEMORY.md" ]; then
    ln -sf "$memory_src/MEMORY.md" "$dir/MEMORY.md"
    has_mem="$has_mem memory"
  fi

  local label=$(echo "$dir" | sed "s|$DEV/||")
  if [ -n "$has_mem" ]; then
    echo "✓ $label [$has_mem]"
  else
    echo "  $label"
  fi
}

echo "=== Setting up Antigravity for all DEV projects ===\n"

# ── Root-level repos ──────────────────────────────────────────────────────────
setup "$DEV/DATA LAB"            "-Users-greglas-DEV-DATA-LAB"
setup "$DEV/Helper"              "-Users-greglas-DEV-Helper"
setup "$DEV/Inovoicer"           "-Users-greglas-DEV-Inovoicer"
setup "$DEV/MYA"                 "-Users-greglas-DEV-MYA"
setup "$DEV/Mobi 2"              "-Users-greglas-DEV-Mobi-2"
setup "$DEV/Portal & Access"     "-Users-greglas-DEV-Portal---Access"
setup "$DEV/Prefetch"            "-Users-greglas-DEV-Prefetch"
setup "$DEV/RDesigner"           "-Users-greglas-DEV-RDesigner"
setup "$DEV/Rewards-API"         "-Users-greglas-DEV-Rewards-API"
setup "$DEV/TGM Panel website"   "-Users-greglas-DEV-TGM-Panel-website"
setup "$DEV/Offer Module"        "-Users-greglas-DEV-Offer-Module"
setup "$DEV/coding-ui"           "-Users-greglas-DEV-coding-ui"
setup "$DEV/country-data"        "-Users-greglas-DEV-country-data"
setup "$DEV/tgm-privacy-portal"  "-Users-greglas-DEV-tgm-privacy-portal"
setup "$DEV/tgmpanel-cms"        "-Users-greglas-DEV-tgmpanel-cms"
setup "$DEV/translation-qa"      "-Users-greglas-DEV-translation-qa"
setup "$DEV/claude-code-toolkit" "-Users-greglas-DEV-claude-code-toolkit"

# ── Sub-repos (Antigravity opens subdirectory directly) ───────────────────────
# Methodology Platform
setup "$DEV/Methodology Platform/promptvault"    "-Users-greglas-DEV-Methodology-Platform"

# RDesigner
setup "$DEV/RDesigner/tgm-survey-platform"       "-Users-greglas-DEV-RDesigner"

# Mobi 2
setup "$DEV/Mobi 2/survey-designer-ui"           "-Users-greglas-DEV-Mobi-2"
setup "$DEV/Mobi 2/tgmdev-tgm-mailing-service-dbcb7129e3da" "-Users-greglas-DEV-Mobi-2"

# Offer Module
setup "$DEV/Offer Module/tgmdev-tgm.offer.be" "-Users-greglas-DEV-Offer-Module"
setup "$DEV/Offer Module/tgmdev-tgm.offer.fe" "-Users-greglas-DEV-Offer-Module"

# Portal & Access
setup "$DEV/Portal & Access/tgmdev-tgm-portal-f10dcd17fd36" "-Users-greglas-DEV-Portal---Access"
setup "$DEV/Portal & Access/tgmdev-tgm-panel-1428ca602529"  "-Users-greglas-DEV-Portal---Access"

# Shield
setup "$DEV/Shield/tgmdev-rs_be-372f9cdb0a46"   "-Users-greglas-DEV-SHield"
setup "$DEV/Shield/tgmdev-rs_admin-20c71e4ce084" "-Users-greglas-DEV-SHield"
setup "$DEV/Shield/tgmdev-rs_fe-96fd4d443032"    "-Users-greglas-DEV-SHield"
setup "$DEV/Shield/legal-site"                    "-Users-greglas-DEV-SHield"

# tgmpanel-cms
setup "$DEV/tgmpanel-cms/nextjs"                 "-Users-greglas-DEV-tgmpanel-cms"
setup "$DEV/tgmpanel-cms/sanity"                 "-Users-greglas-DEV-tgmpanel-cms"

# translation-qa
setup "$DEV/translation-qa/calque-detector"      "-Users-greglas-DEV-translation-qa"

# country-data
setup "$DEV/country-data/frontend"               "-Users-greglas-DEV-country-data"
setup "$DEV/country-data/backend"                "-Users-greglas-DEV-country-data"

# Helper
setup "$DEV/Helper/frontend"                     "-Users-greglas-DEV-Helper"
setup "$DEV/Helper/kb-public"                    "-Users-greglas-DEV-Helper"

echo "\nDone."
