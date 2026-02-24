# Refactoring Rules (Always Active)

These rules govern all refactoring work via `/refactor` and manual refactoring sessions.
Full protocol (ETAP-1A → 1B → 2) is at `~/.claude/refactoring-protocol.md` — read on-demand when `/refactor` starts.
Stack-specific examples are at `~/.claude/refactoring-examples/{stack}.md` — loaded after auto-detection.

---

## Refactoring Types (10)

| Type | Description | Test Mode | Verification |
|------|-------------|-----------|--------------|
| `EXTRACT_METHODS` | Extract methods to service/helper | WRITE_NEW | tests |
| `SPLIT_FILE` | Split god class into N files by concern | WRITE_NEW | tests + no file > limit + encoding + setup dedup + backlog |
| `GOD_CLASS` | Iterative decomposition of massive file (>500 lines AND >15 deps) | WRITE_FUNCTIONAL | functional tests → iterative extract + unit test loop |
| `BREAK_CIRCULAR` | Fix circular dependencies | RUN_EXISTING | madge + tsc (fallback: eslint import/no-cycle if madge fails) |
| `MOVE` | Move files/modules/types | RUN_EXISTING | tsc + grep old imports = 0 |
| `RENAME_MOVE` | Rename + update all references | RUN_EXISTING | tsc + grep old_name = 0 |
| `INTRODUCE_INTERFACE` | Add interfaces for DIP | RUN_EXISTING | tsc |
| `FIX_ERROR_HANDLING` | Fix error handling patterns | RUN_IF_EXISTS | lint + grep patterns |
| `DELETE_DEAD` | Remove dead/unused code | RUN_EXISTING | grep usage = 0 + tsc |
| `SIMPLIFY` | Simplify logic in-place | RUN_EXISTING + NEW_EDGES | tests + complexity down |
| `IMPROVE_TESTS` | Strengthen test assertions + structural cleanup | IMPROVE_TEST_QUALITY | Q1-Q17 self-eval → gap fixes → re-score |

### GOD_CLASS Auto-Detection

GOD_CLASS is detected automatically during Stage 1 Audit when ANY of these are true:

| Condition | How to check |
|-----------|-------------|
| File > 500 lines AND > 15 injected dependencies | `wc -l` + dependency count (see stack table below) |
| File > 1000 lines (regardless of deps) | `wc -l` |
| Constructor / `__init__` has > 15 parameters | Count constructor params |

**Dependency counting by stack:**

| Stack | Command | Notes |
|-------|---------|-------|
| TypeScript (NestJS) | `grep -c '@Inject\|private readonly'` in constructor | |
| React (hooks) | Count `useQuery`, `useMutation`, `useStore`, `useContext` hooks | `useState`/`useRef`/`useMemo`/`useCallback` are local state — do NOT count as dependencies |
| Python (class-based) | Count `self.xxx =` assignments in `__init__` | |
| Python (FastAPI + Depends) | `grep -c 'Depends('` in function/class | |
| Python (Django) | Count class-level field definitions + `__init__` params | |

When detected, show:
```
GOD_CLASS DETECTED: [file] ([N] lines, [M] dependencies)
Standard EXTRACT_METHODS/SPLIT_FILE won't work — switching to iterative mode.
  - ETAP-1B: functional tests for ALL public endpoints (SmartMock Proxy)
  - ETAP-2: iterative extract → unit test → verify → commit loop
OK?
```

### Test Mode Summary

| Mode | Types | What to do |
|------|-------|------------|
| WRITE_NEW | EXTRACT_METHODS, SPLIT_FILE | Write new behavioral tests BEFORE refactoring |
| WRITE_FUNCTIONAL | GOD_CLASS | Write functional tests for ALL public endpoints using SmartMock Proxy, then unit tests per extraction |
| RUN_EXISTING | BREAK_CIRCULAR, MOVE, RENAME_MOVE, INTRODUCE_INTERFACE, DELETE_DEAD | Run existing tests; compiler is primary check |
| RUN_IF_EXISTS | FIX_ERROR_HANDLING | Run tests if they exist; lint + compile otherwise |
| RUN_EXISTING + NEW_EDGES | SIMPLIFY | Run existing + write new edge case tests |
| IMPROVE_TEST_QUALITY | IMPROVE_TESTS | Q1-Q17 audit → structural cleanup → assertion strengthening → re-score |

---

## 5 Iron Rules

### 1. CONTRACT IS LAW
Only do what's in the CONTRACT from ETAP-1A. No additions, no "improvements", no scope creep. If you discover something not in CONTRACT: STOP, report, ask "Add?" or "Ignore?".

### 2. TESTS FIRST
Verify pre-extraction tests pass BEFORE making changes. Same tests must pass AFTER changes. If tests fail after refactoring — fix the code, not the tests.
Before writing tests: read `~/.claude/test-patterns.md` (global). Classify code type, load matching patterns from lookup table, apply them.
After writing tests: run Step 4 self-eval checklist (17 yes/no questions, scored individually). Score < 14 = fix before proceeding to ETAP-2. Critical gate: Q7, Q11, Q13, Q15, Q17 — any = 0 → auto-capped at FIX.
For SPLIT_FILE/EXTRACT_METHODS: (a) run Step 4 on EACH existing test file during Stage 1 audit — files < 14 → gaps into CONTRACT; (b) resolve ALL gaps in ETAP-1B — unresolved gaps block ETAP-2; (c) re-run Step 4 on each NEW split file — must score ≥ 14 and not lower than pre-split. A split that only moves code without improving test quality is a failed split.

### 3. VERIFY APPROPRIATELY
After each TASK: run relevant spec. After each PHASE: full test suite + tsc + lint. Use commands from project CLAUDE.md/package.json if present; else use defaults.

### 4. COMMIT PER PHASE
One commit per phase = easy rollback. Never push mid-phases. Never start Phase N+1 until Phase N commit + verification PASS.

### 5. NO TRUNCATION
Output complete files, not snippets. For files >250 lines: use chunking (100% coverage, no omissions).

---

## Scope Fence (Mandatory)

Before starting ETAP-1B or ETAP-2, define:

- **ALLOWED FILES:** source files being refactored + target files + test files (one per extracted function)
- **FORBIDDEN:** all other files, new public APIs/DTOs, new dependencies, "while we're here" improvements

If a fix requires touching a file not in ALLOWED: STOP, ask user to expand scope.

---

## Hard Gates (11 Blocking Conditions)

A CONTRACT is invalid if ANY of these are true:

1. **TODO/SKIP present** — no `it.todo`, `it.skip`, `pytest.mark.skip` (except post-extraction markers)
2. **Only contract tests** — every function MUST have behavioral tests (not just `toBeDefined`)
3. **Mocking unit under test** — never mock the function being tested
4. **Min test count not met** — Low: 3+, Medium: 5+, High: 8+ (per complexity)
5. **Tests not passing** — all tests must PASS or be marked NOT VERIFIED
6. **Structure violation** — one function = one spec file (no monolith spec files)
7. **Mixed test runners** — cannot mix Jest/Vitest or pytest/unittest in same file
8. **Mock budget violation** — max 3 ACTIVE mocks per spec (passive DI stubs unlimited)
9. **No integration test** — at least 1 test must call original entry point
10. **Weak assertions only** — must have at least 1 STRONG assertion per test
11. **String matching for structure** — must use AST parsing, not string matching

---

## Backup

Git-based backup commands are in `refactoring-protocol.md` Stage 0. Rollback: `git checkout backup/refactor-[name]-* -- [files]`

---

## Sub-Agents (spawned by /refactor)

| Agent | Model | subagent_type | When | Purpose |
|-------|-------|---------------|------|---------|
| Dependency Mapper | Sonnet | Explore | Phase 2 (parallel) | Trace importers/callers of target files |
| Existing Code Scanner | Haiku | Explore | Phase 2 (parallel) | Find similar services, check for existing helpers |
| Test Quality Auditor | Sonnet | Explore | After ETAP-1B | Verify test quality against hard gates + self-eval |
| Post-Extraction Verifier | Sonnet | Explore | After ETAP-2 | Verify delegation, imports, file sizes, orphans |

Agent definition files: `~/.claude/skills/refactor/agents/*.md`

**Backlog persistence:** Both Agent 3 and Agent 4 may output a `BACKLOG ITEMS` section. The lead MUST persist these to `memory/backlog.md` (see SKILL.md Phase 4.5).

---

## Team Mode (Multi-Agent Execution)

Team mode uses `TeamCreate` + `TaskCreate` + spawned teammates to parallelize independent work within a refactoring CONTRACT. It is an **optional execution path** — solo mode remains the default.

### When Team Mode Activates

Determined in ETAP-1A Stage 2.5 (Parallelism Analysis). Conditions — ALL must be true:

1. **2+ independent tasks** with no shared write targets (different files)
2. **Type is eligible:** EXTRACT_METHODS, SPLIT_FILE, SIMPLIFY, MOVE, DELETE_DEAD
3. **Tasks are substantial enough** to justify coordination overhead (not trivial 5-line changes)

### When Team Mode is FORBIDDEN

| Condition | Reason |
|-----------|--------|
| Tasks modify the SAME file | Write conflicts between agents |
| Type = RENAME_MOVE | Global search-replace, not splittable |
| Type = BREAK_CIRCULAR | Requires holistic graph reasoning |
| < 2 independent tasks | Overhead > benefit |
| User says "solo" or "no team" | Explicit override |

### Team Structure

| Role | Type | Count | Responsibility |
|------|------|-------|----------------|
| refactor-lead | Main agent | 1 | Coordinates, monitors TaskList, handles sequential tasks, runs verification, commits |
| worker-N | general-purpose | min(parallel_tasks, 3) | Claims and executes parallel tasks from TaskList |

### Agent Rules (included in each worker's prompt)

1. **SCOPE LOCK:** ONLY modify files listed in YOUR task's allowed scope
2. **NO CROSS-CONTAMINATION:** NEVER touch files assigned to another agent
3. **CONTRACT IS LAW:** Follow task description exactly — no "improvements" or extras
4. **TEST AFTER:** Run task-specific tests after completing your work
5. **REPORT, DON'T FIX:** If you discover issues outside your scope → message lead
6. **BLOCK, DON'T IMPROVISE:** If confused or blocked → message lead and wait

### Team Lifecycle

```
ETAP-1A: Stage 2.5 → TEAM_MODE decision (included in CONTRACT)
         ↓
ETAP-1B: [optional] Team for parallel test writing (each worker → own spec file)
         → Test Quality Auditor verifies all specs
         → Team dissolved OR kept for ETAP-2
         ↓
ETAP-2:  TeamCreate → TaskCreate (with blockedBy) → Spawn workers
         → Workers execute parallel tasks (Group A)
         → Lead executes sequential tasks (Group B, C) as dependencies resolve
         → All tasks done → Full verification (solo)
         → shutdown_request to all workers → TeamDelete
         ↓
         Continue to 4B.5+ (solo — Delegation Verification, Commit, etc.)
```

### Task Dependencies

Use `TaskCreate` + `TaskUpdate(addBlockedBy)` to model the dependency graph from Stage 2.5:

- **Group A** tasks: no blockers → claimed immediately by workers
- **Group B** tasks: `blockedBy: [all Group A IDs]` → auto-unblock when A completes
- **Group C** tasks: `blockedBy: [Group B IDs]` → sequential chain

Workers check `TaskList` after completing each task. If unblocked tasks exist → claim next. If none → go idle and notify lead.

### Failure Handling

| Scenario | Action |
|----------|--------|
| Worker fails a task (tests don't pass) | Worker messages lead → lead investigates → reassign or fix |
| Worker modifies wrong file | Lead detects in verification → revert worker's changes → reassign |
| Team member goes unresponsive | Lead claims remaining tasks → solo fallback |
| Any agent discovers CONTRACT violation | STOP all → lead decides: fix, rollback, or abort |

If team mode fails mid-execution: dissolve team → revert to solo → resume from last committed phase.

---

## Modes

| Command | Behavior |
|---------|----------|
| `/refactor` | Full flow with STOPs (plan approval + test approval) |
| `/refactor auto` | Minimal STOPs (only plan approval) |
| `/refactor plan-only` | ETAP-1A only — analyze and plan, no execution |
| `/refactor continue` | Resume from existing CONTRACT.json |

---

## File Size Limits

Read project CLAUDE.md for overrides. Defaults: `~/.claude/rules/file-limits.md`.

---

## Review Integration

After refactoring completes, the next step is `/review` on the changes. The refactoring completion output includes this prompt.
