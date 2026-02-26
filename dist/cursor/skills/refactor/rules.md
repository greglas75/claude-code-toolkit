# Refactoring Rules (Always Active)

These rules govern all refactoring work via `/refactor` and manual refactoring sessions.
Full protocol (ETAP-1A -> 1B -> 2) is at `~/.cursor/refactoring-protocol.md` -- read on-demand when `/refactor` starts.
Stack-specific examples are at `~/.cursor/refactoring-examples/{stack}.md` -- loaded after auto-detection.

---

## Refactoring Types (10)

| Type | Description | Test Mode | Verification |
|------|-------------|-----------|--------------|
| `EXTRACT_METHODS` | Extract methods to service/helper | WRITE_NEW | tests |
| `SPLIT_FILE` | Split god class into N files by concern | WRITE_NEW | tests + no file > limit + encoding + setup dedup + backlog |
| `GOD_CLASS` | Iterative decomposition of massive file (>500 lines AND >15 deps) | WRITE_FUNCTIONAL | functional tests -> iterative extract + unit test loop |
| `BREAK_CIRCULAR` | Fix circular dependencies | RUN_EXISTING | madge + tsc (fallback: eslint import/no-cycle if madge fails) |
| `MOVE` | Move files/modules/types | RUN_EXISTING | tsc + grep old imports = 0 |
| `RENAME_MOVE` | Rename + update all references | RUN_EXISTING | tsc + grep old_name = 0 |
| `INTRODUCE_INTERFACE` | Add interfaces for DIP | RUN_EXISTING | tsc |
| `FIX_ERROR_HANDLING` | Fix error handling patterns | RUN_IF_EXISTS | lint + grep patterns |
| `DELETE_DEAD` | Remove dead/unused code | RUN_EXISTING | grep usage = 0 + tsc |
| `SIMPLIFY` | Simplify logic in-place | RUN_EXISTING + NEW_EDGES | tests + complexity down |
| `IMPROVE_TESTS` | Strengthen test assertions + structural cleanup | IMPROVE_TEST_QUALITY | Q1-Q17 self-eval -> gap fixes -> re-score |

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
| React (hooks) | Count `useQuery`, `useMutation`, `useStore`, `useContext` hooks | `useState`/`useRef`/`useMemo`/`useCallback` are local state -- do NOT count as dependencies |
| Python (class-based) | Count `self.xxx =` assignments in `__init__` | |
| Python (FastAPI + Depends) | `grep -c 'Depends('` in function/class | |
| Python (Django) | Count class-level field definitions + `__init__` params | |

When detected, show:
```
GOD_CLASS DETECTED: [file] ([N] lines, [M] dependencies)
Standard EXTRACT_METHODS/SPLIT_FILE won't work -- switching to iterative mode.
  - ETAP-1B: functional tests for ALL public endpoints (SmartMock Proxy)
  - ETAP-2: iterative extract -> unit test -> verify -> commit loop
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
| IMPROVE_TEST_QUALITY | IMPROVE_TESTS | Q1-Q17 audit -> structural cleanup -> assertion strengthening -> re-score |

---

## 5 Iron Rules

### 1. CONTRACT IS LAW
Only do what's in the CONTRACT from ETAP-1A. No additions, no "improvements", no scope creep. If you discover something not in CONTRACT: STOP, report, ask "Add?" or "Ignore?".

### 2. TESTS FIRST
Verify pre-extraction tests pass BEFORE making changes. Same tests must pass AFTER changes. If tests fail after refactoring -- fix the code, not the tests.
Before writing tests: read `~/.cursor/test-patterns.md` (global). Classify code type, load matching patterns from lookup table, apply them.
After writing tests: run Step 4 self-eval checklist (17 yes/no questions, scored individually). Score < 14 = fix before proceeding to ETAP-2. Critical gate: Q7, Q11, Q13, Q15, Q17 -- any = 0 -> auto-capped at FIX.
For SPLIT_FILE/EXTRACT_METHODS: (a) run Step 4 on EACH existing test file during Stage 1 audit -- files < 14 -> gaps into CONTRACT; (b) resolve ALL gaps in ETAP-1B -- unresolved gaps block ETAP-2; (c) re-run Step 4 on each NEW split file -- must score >= 14 and not lower than pre-split. A split that only moves code without improving test quality is a failed split.

### 3. VERIFY APPROPRIATELY
After each TASK: run relevant spec. After each PHASE: `tsc --noEmit` + affected spec files + lint. After LAST PHASE: full test suite (`npm test` / `npx turbo test`). Use commands from project CLAUDE.md/package.json if present; else use defaults. QUICK mode: single verification pass at the end (tsc + affected tests + CQ self-eval).

### 4. COMMIT PER PHASE
One commit per phase = easy rollback. Never push mid-phases. Never start Phase N+1 until Phase N commit + verification PASS. **Exception:** `no-commit` mode -- show staged diff + commit plan instead of committing. User controls git history.

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

1. **TODO/SKIP present** -- no `it.todo`, `it.skip`, `pytest.mark.skip` (except post-extraction markers)
2. **Only contract tests** -- every function MUST have behavioral tests (not just `toBeDefined`)
3. **Mocking unit under test** -- never mock the function being tested
4. **Min test count not met** -- Low: 3+, Medium: 5+, High: 8+ (per complexity)
5. **Tests not passing** -- all tests must PASS or be marked NOT VERIFIED
6. **Structure violation** -- one function = one spec file (no monolith spec files)
7. **Mixed test runners** -- cannot mix Jest/Vitest or pytest/unittest in same file
8. **Mock budget violation** -- max 3 ACTIVE mocks per spec (passive DI stubs unlimited)
9. **No integration test** -- at least 1 test must call original entry point
10. **Weak assertions only** -- must have at least 1 STRONG assertion per test
11. **String matching for structure** -- must use AST parsing, not string matching

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

Agent definition files: `~/.cursor/skills/refactor/agents/*.md`

**Backlog persistence:** Both Agent 3 and Agent 4 may output a `BACKLOG ITEMS` section. The lead MUST persist these to `memory/backlog.md` (see SKILL.md Phase 4.5).

---

## Modes

| Command | Behavior |
|---------|----------|
| `/refactor` | Full flow with STOPs (plan approval + test approval) |
| `/refactor auto` | Minimal STOPs (only plan approval) |
| `/refactor quick` | Lightweight -- no sub-agents, no CONTRACT.json, single phase. Auto-detected for <=120 lines, <=1 file, simple types |
| `/refactor no-commit` | Full flow but skip auto-commits -- show staged diff + commit plan instead |
| `/refactor plan-only` | ETAP-1A only -- analyze and plan, no execution |
| `/refactor continue` | Resume from existing CONTRACT.json |

---

## File Size Limits

Read project CLAUDE.md for overrides. Defaults: `~/.cursor/rules/file-limits.md`.

---

## Review Integration

After refactoring completes, the next step is `/review` on the changes. The refactoring completion output includes this prompt.
