---
name: build
description: "Structured feature development with analysis sub-agents, quality gates, and backlog integration. Use for non-trivial new features (3+ files)."
user-invocable: true
---

# /build — Structured Feature Development

Lightweight workflow for building new features with quality gates. Lighter than `/refactor` (no CONTRACT, no ETAP), heavier than raw coding (sub-agents, scope fence, backlog).

**When to use:** New features touching 3+ files, or any feature where blast radius matters.
**When NOT to use:** Simple fixes (<3 files), pure refactoring (`/refactor`), code review (`/review`).

Parse $ARGUMENTS as the feature description.

## Progress Tracking

Use `TaskCreate` at the start to create a todo list from the phases below. Update task status (`in_progress` → `completed`) as you progress. This gives the user visibility into multi-step execution.

## Multi-Agent Compatibility

This skill uses `Task` tool to spawn parallel sub-agents. **If `Task` tool is not available** (Cursor, Antigravity, other IDEs):
- **Skip all "Spawn via Task tool" blocks** — do NOT attempt to call tools that don't exist
- **Execute the agent's work inline yourself**, sequentially — read the agent's prompt/instructions and perform that analysis directly
- **Model routing is ignored** — use whatever model you are running on
- The quality gates, checklists, and output format remain identical

---

## Model Routing (Sub-Agents)

| Agent | Model | subagent_type | When |
|-------|-------|---------------|------|
| Blast Radius Mapper | Sonnet | Explore | Phase 1 (background) |
| Existing Code Scanner | Haiku | Explore | Phase 1 (background) |
| Test Quality Auditor | Sonnet | Explore | Phase 4 (after tests) |

**All agents are read-only (Explore type).** Reuses agent definitions from `~/.claude/skills/refactor/agents/`.

## Path Resolution (non-Claude-Code environments)

If running in Antigravity, Cursor, or other IDEs where `~/.claude/` is not accessible, resolve paths from `_agent/` in project root:
- `~/.claude/skills/` → `_agent/skills/`
- `~/.claude/rules/` → `_agent/rules/`
- `~/.claude/test-patterns.md` → `_agent/test-patterns.md`

---

## Mandatory File Reading (NON-NEGOTIABLE)

Before starting ANY work, read ALL files below. Confirm each with ✅ or ❌:

```
1. ✅/❌  ~/.claude/rules/code-quality.md         — CQ1-CQ20 production code checklist
2. ✅/❌  ~/.claude/rules/testing.md              — Q1-Q17 test self-eval checklist
3. ✅/❌  ~/.claude/test-patterns.md              — Q1-Q17 protocol, lookup table → routes to catalog/domain files
4. ✅/❌  ~/.claude/rules/file-limits.md          — 250-line file limit, 50-line function limit
```

**If ANY file is ❌ → STOP. Do not proceed with a partial rule set.**

---

## Phase 0: Context

1. Read project `CLAUDE.md` and `.claude/rules/` (or `_agent/rules/`) for conventions
2. Detect stack (check `package.json`, `tsconfig.json`, `pyproject.toml`, etc.)
3. Read `memory/backlog.md` if it exists — check for related OPEN items

Output:
```
STACK: [language] | RUNNER: [test runner]
BACKLOG: [N open items in related files, or "none"]
```

---

## Phase 1: Analysis (parallel, background)

Before planning, spawn 2 sub-agents to gather context:

**Agent 1: Blast Radius Mapper** — uses `~/.claude/skills/refactor/agents/dependency-mapper.md`
```
Spawn via Task tool with:
  subagent_type: "Explore"
  model: "sonnet"
  run_in_background: true
  prompt: "You are a Dependency Mapper. Read ~/.claude/skills/refactor/agents/dependency-mapper.md for full instructions.

FEATURE: [description]
TARGET FILES/DIRECTORIES: [files the feature will likely touch]
PROJECT ROOT: [cwd]

Trace all importers/callers of the target files. Identify what might break or need updates.
Read project CLAUDE.md for import conventions."
```

**Agent 2: Existing Code Scanner** — uses `~/.claude/skills/refactor/agents/existing-code-scanner.md`
```
Spawn via Task tool with:
  subagent_type: "Explore"
  model: "haiku"
  run_in_background: true
  prompt: "You are an Existing Code Scanner. Read ~/.claude/skills/refactor/agents/existing-code-scanner.md for full instructions.

FEATURE: [description]
PLANNED NEW CODE: [functions/components/services to create]
PROJECT ROOT: [cwd]

Search for existing services/helpers/components similar to what's planned. Prevent duplication.
Read project CLAUDE.md for file organization conventions."
```

Don't wait — start Phase 2 immediately. Incorporate results when ready.

---

## Phase 2: Plan

Enter plan mode (`EnterPlanMode`) and create a plan with ALL of these sections:

### Required Plan Sections

```
## 1. Feature Summary
[1-2 sentences: what and why]

## 2. Scope Fence
ALLOWED: [files to create/modify]
FORBIDDEN: files outside scope, unrelated improvements

## 3. Blast Radius
[From Agent 1 results — who depends on files we're changing]
[If Agent 1 not ready yet: list known dependents manually]

## 4. Duplication Check
[From Agent 2 results — existing code that overlaps]
[If Agent 2 not ready yet: note "pending scan"]

## 5. Implementation Plan
[Ordered list of changes with file paths]

## 6. Test Strategy (MANDATORY)
- Code types being added (function/component/endpoint/hook)
- Test files to create/modify
- Critical scenarios (error paths, edge cases)
- Self-eval targets: CQ PASS (≥16 + critical gate) + Q ≥ 14/17 (tests)

## 7. File Size Check
[For each file to modify: current LOC + estimated after change]
[Flag any file that will exceed 250 lines → plan split]

## 8. Questions for Author
[Only if genuine uncertainty about requirements or approach — e.g. two valid architectures,
ambiguous business rules, conflicting patterns found in codebase. Leave empty if clear.]
```

**A plan missing any section is INCOMPLETE — do not ExitPlanMode.**

### Questions Gate (before ExitPlanMode)

If section 8 is non-empty:
1. Use `AskUserQuestion` to ask each question interactively — max 4 at a time
2. Wait for answers
3. Update the plan based on answers (revise approach, scope, implementation strategy)
4. Then call `ExitPlanMode`

If section 8 is empty → call `ExitPlanMode` directly.

Wait for user approval via `ExitPlanMode`.

---

## Phase 3: Implement

### 3.1: Pre-flight

Before coding, verify:
- [ ] Agent 1 + Agent 2 results incorporated (if not in plan, add now)
- [ ] Scope fence defined
- [ ] No file will exceed 250 lines (plan splits if needed)

### 3.2: Code

Implement the feature following the plan. Rules:
- **Stay in scope** — only touch ALLOWED files
- **Business logic in services** — not in components or API routes
- **Follow project conventions** — from CLAUDE.md and `.claude/rules/`
- **Check file size after each file** — if approaching 250 lines, split NOW. Ad-hoc splits to respect the 250-line limit automatically expand Scope Fence to include newly created helper/sub-files. Justify in execution output.

### 3.3: Code Quality Self-Eval

Run CQ1-CQ20 self-eval (from `~/.claude/rules/code-quality.md`) on each production file you wrote/modified.

- Score each CQ individually (1/0)
- Static critical gate: CQ3, CQ4, CQ5, CQ6, CQ8, CQ14 — any = 0 → fix before writing tests
- Conditional critical gate: CQ16 (if money code), CQ19 (if I/O boundary), CQ20 (if dual fields) — any = 0 → fix
- Score < 14 → FAIL, 14-15 → CONDITIONAL PASS, ≥ 16 → PASS
- Evidence required for each critical gate CQ scored as 1
- Check code-type patterns table for high-risk CQs specific to your code type

**Fix code quality issues BEFORE writing tests.** Tests should cover correct patterns, not broken ones.

### 3.4: Tests

Write tests per the Test Strategy from Phase 2. Requirements:
- Every new function/component/endpoint/hook must have tests
- Follow patterns from `~/.claude/test-patterns.md`
- Run tests: verify GREEN

### 3.5: Test Self-Eval (before Phase 4)

Run Q1-Q17 self-eval (from `~/.claude/rules/testing.md`) on each test file you wrote.

- Score each Q individually (1/0)
- Critical gate: Q7, Q11, Q13, Q15, Q17 — any = 0 → fix before proceeding
- Score < 14 → fix worst gaps, re-score
- **Q12 procedure:** list ALL public methods/endpoints under test → for each repeated test pattern (auth guard, validation, error path), verify ALL methods have it. Missing = 0.

Only proceed to Phase 4 when both self-evals pass (CQ PASS or CONDITIONAL PASS with evidence + Q ≥ 14).

---

## Phase 4: Verify

### 4.1: Test Quality Auditor

Spawn the auditor:

```
Spawn via Task tool with:
  subagent_type: "Explore"
  model: "sonnet"
  prompt: "You are a Test Quality Auditor. Read ~/.claude/skills/refactor/agents/test-quality-auditor.md for full instructions.

TEST FILES: [list of test files written/modified]
CODE TYPE: [function/component/endpoint/hook]
COMPLEXITY: [Low/Medium/High]

Verify 11 hard gates and run 17-question self-eval (Q1-Q17) on each test file.
Read project CLAUDE.md and .claude/rules/ for project-specific test conventions."
```

**If FAIL/BLOCK:** fix issues, re-run auditor. Do not proceed until PASS or FIX (with fixes applied).

### 4.2: Verification Commands

Run in parallel:
- Tests: project test command (`npm run test:run`, `pytest`, etc.)
- Types: `npx tsc --noEmit` or equivalent
- Lint: `npm run lint` or equivalent

**All must pass.** If any fails → fix → re-run.

### 4.3: Execute Verification Checklist (NON-NEGOTIABLE)

After all code is written and before committing, verify ALL of these. Print each with ✅/❌:

```
EXECUTE VERIFICATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅/❌  SCOPE: All files match the approved plan (no unplanned files added)
✅/❌  SCOPE: No extra features/refactoring beyond what the plan specifies
✅/❌  TESTS PASS: Full test suite green (not just new files)
✅/❌  TYPES: `tsc --noEmit` passes (no type errors)
✅/❌  FILE LIMITS: All created/modified files ≤ 250 lines (production) / ≤ 400 lines (test)
✅/❌  CQ1-CQ20: Self-eval on each new/modified PRODUCTION file (scores + evidence)
✅/❌  Q1-Q17: Self-eval on each new/modified TEST file (individual scores + critical gate)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**If ANY is ❌ → fix before committing.** Common failures:
- Scope creep: adding helpers or refactoring existing code not in the plan → revert
- File limit: new files exceed 250 lines → split into modules
- CQ/Q not run: every production file needs CQ1-CQ20, every test file needs Q1-Q17

---

## Phase 5: Completion

### 5.1: Backlog Persistence (MANDATORY)

1. Check Test Quality Auditor output for `BACKLOG ITEMS` section
2. If present → persist to `memory/backlog.md`:
   - Next available B-{N} ID
   - Source: `build/test-quality-auditor`
   - Status: OPEN
   - Date: today
3. If any OPEN backlog items in related files were resolved → mark FIXED

**THIS IS REQUIRED.** Zero issues may be silently discarded.

### 5.2: Auto-Commit + Tag

After verification passes, automatically commit and tag:

1. `git add [list of created/modified files — specific names, not -A]`
2. `git commit -m "build: [feature description]"`
3. `git tag build-[YYYY-MM-DD]-[short-slug]` (e.g., `build-2026-02-22-offer-export`)

This creates a clean rollback point. User can `git reset --hard <tag>` if needed.

**Do NOT push.** Push is a separate user decision.

### 5.3: Output

```
BUILD COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Feature: [description]
Files created: [N]
Files modified: [N]
Tests written: [N], all passing
Verification: tests PASS | types PASS | lint PASS
Backlog: [N items persisted | "none"]
Commit: [hash] — [message]
Tag: [tag name] (rollback: git reset --hard [tag])

Next steps:
  /review             → Review the new code before push
  /docs readme [path] → Write README for the new module (if new service/module created)
  /docs api [path]    → Document the new endpoints (if new endpoints added)
  Push                → git push origin [branch]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Quick Mode (`/build auto`)

If $ARGUMENTS contains "auto":
- Skip user approval at Phase 2 (plan auto-approved)
- Still run all agents and quality gates
- Still require tests to pass
