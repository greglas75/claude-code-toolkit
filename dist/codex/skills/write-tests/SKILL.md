---
name: write-tests
description: "Write tests for existing production code. Runs coverage analysis + pattern selection, writes tests with Q1-Q17 quality gates. Use: /write-tests [path] or /write-tests auto (discover uncovered files). NOT for /build (use Phase 3.4) or mass fixes (use /fix-tests)."
---

# /write-tests -- Test Writing Workflow

Structured workflow for writing tests for **existing** production code.
Heavier than inline test writing (coverage + pattern analysis), lighter than `/build` (no production code changes).

**When to use:**
- Existing production file with no tests or partial coverage
- After `/refactor` when tests need to be rewritten
- Legacy code that was never tested

**When NOT to use:**
- New feature code -> tests written in `/build` Phase 3.4
- Mass repair of existing test quality -> `/fix-tests`
- Auditing existing tests -> `/test-audit`

Parse $ARGUMENTS as: `[path | auto] [--dry-run]`

---

## Path Resolution

If `~/.codex/` is not accessible, resolve paths from `_agent/` in project root:
- `~/.codex/skills/` -> `_agent/skills/`
- `~/.codex/rules/` -> `_agent/rules/`
- `~/.codex/test-patterns.md` -> `_agent/test-patterns.md`

---

## Mandatory File Reading (NON-NEGOTIABLE)

Before starting ANY work, read ALL files below. Confirm each with [x] or [ ]:

```
1. [x]/[ ]  ~/.codex/rules/testing.md              -- Q1-Q17 test self-eval checklist + iron rules
2. [x]/[ ]  ~/.codex/test-patterns.md              -- Q1-Q17 protocol + code-type lookup table
3. [x]/[ ]  ~/.codex/rules/file-limits.md          -- 400-line test file limit
```

**If ANY file is [ ] -> STOP. Do not proceed with a partial rule set.**

---

## Phase 0: Context

1. Read project `CLAUDE.md` and `.claude/rules/` (or `_agent/rules/`) for conventions
2. Detect stack (`package.json`, `tsconfig.json`, `pyproject.toml`, etc.)
3. Check for domain-specific patterns:
   - NestJS detected -> note: load `~/.codex/test-patterns-nestjs.md` when writing CONTROLLER tests
   - Redux detected -> note: load `~/.codex/test-patterns-redux.md` when writing REDUX-SLICE tests
4. Read `memory/backlog.md` -- check for open items in target files

**Parse arguments:**

| Argument | Behavior |
|----------|----------|
| `[file.ts]` | Write tests for single production file |
| `[directory/]` | Write tests for all production files in directory |
| `auto` | Discover production files missing test coverage |
| `--dry-run` | Plan only, do NOT write files (stop before Phase 3) |

Output:
```
STACK: [language] | RUNNER: [test runner] | DOMAIN PATTERNS: [nestjs/redux/none]
TARGET: [file | directory | auto-discover]
BACKLOG: [N open items in related files, or "none"]
```

---

## Phase 1: Analysis

Before planning, gather context with two analyses. Perform both inline (no sub-agents in Codex):

**Analysis 1: Coverage Scanner**

For each production file in target:
1. Find its test file (same name + .test.ts/.spec.ts, or in `__tests__/`)
2. If NO test file exists -> UNCOVERED
3. If test file exists -> read both files and identify:
   a. All exported functions/methods/classes in production file
   b. Which ones have at least one `it()` block -> TESTED
   c. Which ones have NO coverage -> UNTESTED
   d. Count if/else/switch in production code, check if test covers both branches
4. For `auto` mode: glob all .ts/.tsx/.py files (exclude node_modules, .next, dist), find those with no .test.* sibling -> list sorted by file size DESC

Output per file:
- Status: UNCOVERED | PARTIAL | COVERED
- Untested methods: [list or "all covered"]
- Existing test file: [path or "none"]
- Estimated coverage: [~X%]
- Risk: HIGH (service/controller/guard) | MEDIUM | LOW (pure utility)

**Analysis 2: Pattern Selector**

For each production file:
1. Read the file (first 100 lines sufficient for classification)
2. Classify ALL matching code types:
   PURE | REACT | SERVICE | REDIS/CACHE | ORM/DB | API-CALL | GUARD/AUTH |
   STATE-MACHINE | ORCHESTRATOR | EXPORT/FORMAT | ADAPTER/TRANSFORM |
   CONTROLLER | REDUX-SLICE | API-ROUTE

3. Select patterns from lookup:
   - PURE:     Good: G-2,G-3,G-5,G-20,G-22,G-30 | Gap: P-1,P-8,P-13,P-20
   - REACT:    Good: G-1,G-7,G-8,G-10,G-18,G-19,G-25,G-26,G-27 | Gap: P-9,P-10,P-12,P-17,P-39
   - SERVICE:  Good: G-2,G-4,G-9,G-11,G-23,G-24,G-25,G-28,G-30 | Gap: P-1,P-4,P-5,P-11,P-22,P-23
   - ORM/DB:   Good: G-9,G-28,G-30 | Gap: P-5,P-11,P-15,P-29,P-32
   - API-CALL: Good: G-3,G-15,G-28,G-29,G-36,G-55 | Gap: P-1,P-2,P-6,P-16,P-25,P-27
   - GUARD/AUTH: Good: G-6,G-8,G-11,G-20,G-28 | Gap: P-1,P-6,P-7,P-14
   - CONTROLLER: Good: G-2,G-4,G-6,G-9,G-28,G-32,G-33,G-34 | Gap: P-1,P-5,P-28,P-33,P-34
   - ORCHESTRATOR: Good: G-2,G-20,G-21,G-23,G-24,G-25 | Gap: P-5,P-14,P-20,P-21,P-22
   - API-ROUTE: Good: G-2,G-4,G-6,G-11,G-28,G-29,G-32,G-55 | Gap: P-1,P-5,P-6,P-28

4. Flag MOCK HAZARDS -- async patterns requiring special mock implementation:
   - `async function*` / AsyncGenerator -> vi.fn() returns undefined -> test HANGS
   - `stream.pipe()` / EventEmitter -> needs finish/error handler
   - `for await (const chunk of ...)` -> mock must implement Symbol.asyncIterator
   - `.on('data')` / `.on('end')` -> mock needs EventEmitter or manual trigger

Output per file:
- Code types, Good/Gap patterns, Domain file needed, Mock hazards
- Suggested describe blocks matching public methods

---

## Phase 2: Plan

Present a plan with ALL of these sections:

```
## 1. Scope

Files to cover:
| File | Status | Untested methods | Risk |
|------|--------|-----------------|------|

Files to SKIP (already well covered):
[list with reason]

## 2. Test Files

| Production file | Test file | Action |
|----------------|-----------|--------|
| foo.service.ts | foo.service.test.ts | CREATE (no test file) |
| bar.service.ts | bar.service.test.ts | ADD TO (partial, ~40%) |

Note: ADD TO = never replace existing tests. New describe blocks only.
File size: [current LOC] + [estimated new LOC] = [total] -- flag if >400 lines -> plan split

## 3. Test Strategy Per File

For each file:
- Code types + patterns to apply (G-IDs / P-IDs)
- Domain file: [if needed]
- Mock hazards: [from Analysis 2 -- required mock pattern for each]
- Describe blocks + critical scenarios
- Security tests (if CONTROLLER/API-ROUTE/GUARD): S1-S4

## 4. Questions for Author

[Leave empty if clear]
```

**A plan missing any section is INCOMPLETE -- do not proceed.**

If section 4 is non-empty: ask the user, wait for answers, update plan.

Wait for user approval before Phase 3.

**If `--dry-run`:** print plan and STOP here.

---

## Phase 3: Write

### 3.1: Pre-flight

Before writing:
- [ ] Analysis 1 + 2 results incorporated in plan
- [ ] For each ADD TO file: read existing test file fully
- [ ] Mock hazards listed with required patterns

### 3.2: Write Tests

Implement per the plan. Rules:

**Never replace existing tests** -- add new describe/it blocks only.

**Follow patterns from `~/.codex/test-patterns.md`** (G-/P- IDs from Analysis 2).

**Mock Safety -- check before writing each mock:**

| Hazard type | WRONG (causes hang) | CORRECT |
|-------------|---------------------|---------|
| `AsyncGenerator` / `async function*` | `vi.fn()` -- undefined, iteration hangs | `vi.fn().mockImplementation(async function*() { yield chunk; })` |
| `for await (const chunk of stream)` | mock not async iterable | mock must implement `Symbol.asyncIterator` |
| `stream.pipe(writer)` | no-op mock, writer never emits | `writer.on = vi.fn((event, cb) => event === 'finish' && cb())` |
| `EventEmitter.on('data')/.on('end')` | `vi.fn()` -- callbacks never called | mock EventEmitter, call `.emit('data', chunk)` + `.emit('end')` |

**Always verify:** does the mock return something the production code can iterate/await/subscribe to? If not -> the test will hang silently, not fail.

**File size check:** if test file exceeds 400 lines -> split now (e.g., `foo.service.edge-cases.test.ts`).

### 3.3: Test Self-Eval (mandatory per file)

Run Q1-Q17 self-eval (from `~/.codex/rules/testing.md`) on each test file written/modified.

- Score each Q individually (1/0)
- Critical gate: Q7, Q11, Q13, Q15, Q17 -- any = 0 -> fix before Phase 4
- Score < 14 -> fix worst gaps, re-score
- Q12 procedure: list ALL public methods in production file. For each repeated test pattern (auth guard, validation, error path), verify EVERY method has it. One missing = 0.

Output:
```
[filename]: Q1=1 Q2=1 Q3=0 Q4=1 Q5=1 Q6=1 Q7=1 Q8=0 Q9=1 Q10=1 Q11=1 Q12=0 Q13=1 Q14=1 Q15=1 Q16=1 Q17=1
  Score: 14/17 -> PASS | Critical gate: Q7=1 Q11=1 Q13=1 Q15=1 Q17=1 -> PASS
```

Only proceed to Phase 4 when ALL test files score >= 14 AND all critical gates pass.

---

## Phase 4: Verify

### 4.1: Test Quality Audit

Read `~/.codex/skills/refactor/references/test-quality-auditor.md` and perform this analysis yourself on each test file written/modified.

Verify 11 hard gates and run Q1-Q17 on each file.
Pay special attention to:
- Mock hazards: async generator / stream mocks must have proper implementations
- Q17: computed output, not input echo
- Q11: both branches of every if/else/switch in production code

**If score < 14 or any critical gate fails:** fix issues and re-evaluate before proceeding.

### 4.2: Run Tests

```
# New/modified test files first:
[test runner] [test file paths]

# Then full suite:
[npm run test:run | pytest | etc.]
```

All tests must pass. If any fail: read failure output, fix the cause, re-run.

### 4.3: Verification Checklist (NON-NEGOTIABLE)

Print each with [x]/[ ]:

```
WRITE-TESTS VERIFICATION
------------------------------------
[x]/[ ]  SCOPE: Only test files modified (NO production code changes)
[x]/[ ]  SCOPE: No existing tests removed or modified (ADD TO only)
[x]/[ ]  TESTS PASS: Full test suite green (not just new files)
[x]/[ ]  FILE LIMITS: All test files <= 400 lines
[x]/[ ]  Q1-Q17: Self-eval on each written/modified test file (individual scores + critical gate)
[x]/[ ]  MOCK SAFETY: No vi.fn() used for async generators, streams, or EventEmitters
[x]/[ ]  COVERAGE: Each UNTESTED method from Phase 1 now has at least one test
------------------------------------
```

**If ANY is [ ] -> fix before committing.**

---

## Phase 5: Completion

### 5.1: Backlog Persistence (MANDATORY)

1. If Test Quality Audit found issues not immediately fixed -> persist to `memory/backlog.md`:
   - Next available B-{N} ID
   - Source: `write-tests/[date]`
   - Status: OPEN
2. Mark FIXED any open backlog items for the same test files now resolved

**Zero issues may be silently discarded.**

### 5.2: Auto-Commit + Tag

After verification passes:

1. `git add [explicit list of test files -- never -A]`
2. `git commit -m "test: [brief description of what was covered]"`
3. `git tag write-tests-[YYYY-MM-DD]-[short-slug]`

**Do NOT push.** Push is a separate user decision.

### 5.3: Output

```
WRITE-TESTS COMPLETE
------------------------------------
Target: [file | directory | N files auto-discovered]
Test files created: [N]
Test files extended: [N]
Tests written: [N total], all passing
Mock hazards resolved: [N -- list types fixed]
Backlog: [N items persisted | "none"]
Commit: [hash] -- [message]
Tag: [tag name] (rollback: git reset --hard [tag])

Next steps:
  /test-audit [path]   -> Re-audit to confirm tier improvement
  Push                 -> git push origin [branch]
------------------------------------
```

---

## Quick Reference: Mode Summary

| Mode | Behavior |
|------|----------|
| `/write-tests foo.ts` | Coverage + pattern analysis for 1 file -> plan -> write -> verify -> commit |
| `/write-tests src/services/` | Batch: all production files in directory |
| `/write-tests auto` | Auto-discover uncovered files, sorted by size DESC |
| `/write-tests foo.ts --dry-run` | Plan only -- stop before Phase 3 |
