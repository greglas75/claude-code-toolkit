---
name: write-tests
description: "Write tests for existing production code. Runs coverage analysis + pattern selection, writes tests with Q1-Q17 quality gates. Use: /write-tests [path] or /write-tests auto (discover uncovered files). NOT for /build (use Phase 3.4) or mass fixes (use /fix-tests)."
user-invocable: true
---

# /write-tests -- Test Writing Workflow

Structured workflow for writing tests for **existing** production code.
Heavier than inline test writing (sub-agents for coverage + pattern analysis), lighter than `/build` (no production code changes).

**When to use:**
- Existing production file with no tests or partial coverage
- After `/refactor` when tests need to be rewritten
- Legacy code that was never tested
- Single file or directory batch

**When NOT to use:**
- New feature code -> tests written in `/build` Phase 3.4
- Mass repair of existing test quality -> `/fix-tests`
- Auditing existing tests -> `/test-audit`

Parse `$ARGUMENTS` as: `[path | auto] [--dry-run]`

---

---

## Model Routing (Sub-Agents)

| Agent | Model | subagent_type | When |
|-------|-------|---------------|------|
| Coverage Scanner | Haiku | Explore | Phase 1 (background) |
| Pattern Selector | Haiku | Explore | Phase 1 (background) |
| Test Quality Auditor | Sonnet | Explore | Phase 4 (after tests) |

---

## Mandatory File Reading (NON-NEGOTIABLE)

Before starting ANY work, read ALL files below. Confirm each with [x] or [ ]:

```
1. [x]/[ ]  ~/.cursor/rules/testing.md              -- Q1-Q17 test self-eval checklist + iron rules
2. [x]/[ ]  ~/.cursor/test-patterns.md              -- Q1-Q17 protocol + code-type lookup table
3. [x]/[ ]  ~/.cursor/rules/file-limits.md          -- 400-line test file limit
```

**If ANY file is [ ] -> STOP. Do not proceed with a partial rule set.**

---

## Phase 0: Context

1. Read project `CLAUDE.md` and `.claude/rules/` for conventions (test runner, file locations, mock patterns)
2. Detect stack (check `package.json`, `tsconfig.json`, `pyproject.toml`, etc.)
3. Check for domain-specific test patterns:
   - NestJS detected -> note: load `~/.cursor/test-patterns-nestjs.md` when writing CONTROLLER tests
   - Redux detected -> note: load `~/.cursor/test-patterns-redux.md` when writing REDUX-SLICE tests
4. Read `memory/backlog.md` -- check for related open items in target files

**Parse arguments:**

| Argument | Behavior |
|----------|----------|
| `[file.ts]` | Write tests for single production file |
| `[directory/]` | Write tests for all production files in directory |
| `auto` | Discover production files missing test coverage (see Phase 1 auto-mode) |
| `--dry-run` | Plan only, do NOT write files (output plan + stop before Phase 3) |

Output:
```
STACK: [language] | RUNNER: [test runner] | DOMAIN PATTERNS: [nestjs/redux/none]
TARGET: [file | directory | auto-discover]
BACKLOG: [N open items in related files, or "none"]
```

### Phase 0.5: Baseline Test Run

Run existing tests BEFORE writing anything to establish a baseline:

```bash
# Run full suite (or scoped to target directory):
[test runner] [target path if scoped]
```

Record results:
```
BASELINE: [N] tests, [N] passing, [N] failing
PRE-EXISTING FAILURES: [list of already-failing tests, or "none"]
```

**Why:** If existing tests already fail, Phase 4 cannot distinguish pre-existing failures from regressions caused by your new tests. Record failures now -> ignore them in Phase 4.

If baseline run fails on infrastructure (no test runner, missing deps) -> note it and proceed. The baseline is for distinguishing old vs new failures, not a gate.

---

## Phase 1: Analysis (parallel, background)

Spawn 2 sub-agents in background. Start Phase 2 immediately -- incorporate results when ready.

**Agent 1: Coverage Scanner**

```
Spawn via Task tool with:
  prompt: |
    You are a Coverage Scanner. Read ~/.cursor/skills/write-tests/agents/coverage-scanner.md
    for full instructions.

    TARGET FILES: [list of production files from $ARGUMENTS]
    PROJECT ROOT: [cwd]

    Read project CLAUDE.md for test file location conventions.
```

**Agent 2: Pattern Selector**

```
Spawn via Task tool with:
  prompt: |
    You are a Pattern Selector. Read ~/.cursor/skills/write-tests/agents/pattern-selector.md
    for full instructions.

    TARGET FILES: [list of production files]
    PROJECT ROOT: [cwd]

    Read project CLAUDE.md for project-specific conventions.
```

---

## Phase 2: Plan

Create a plan with ALL of these sections before writing any tests:

### Required Plan Sections

```
## 1. Scope

Files to cover (from Coverage Scanner results):
| File | Status | Untested methods | Risk |
|------|--------|-----------------|------|

Files to SKIP (already COVERED tier A):
[list with reason]

## 2. Test Files

For each target:
| Production file | Test file | Action |
|----------------|-----------|--------|
| foo.service.ts | foo.service.test.ts | CREATE (no test file) |
| bar.service.ts | bar.service.test.ts | ADD TO (partial, ~40%) |

⚠️ ADD TO: never DELETE or REPLACE existing tests. New describe/it blocks only.
   Allowed modifications to existing code: imports, beforeEach/afterEach setup, shared helpers/factories
   (when needed by new tests). Do NOT rewrite existing assertions or test logic.
⚠️ File size: [current LOC of existing test file] + [estimated new LOC] = [total]
   Flag if total > 400 lines -> plan split into [foo.service.errors.test.ts] etc.

## 3. Test Strategy Per File

For each file, list:
- Code types: [from Pattern Selector]
- Patterns to apply: [G-IDs to follow, P-IDs to avoid]
- Domain file: [if needed]
- Mock hazards: [from Pattern Selector -- async generators, streams, etc.]
  -> For each hazard: required mock pattern (see Phase 3.2 Mock Safety section)
- Describe blocks:
  - describe('[MethodName]')
    - it('should [happy path]')
    - it('should [error case]')
    - it('should [edge case]')
- Security tests (if CONTROLLER/API-ROUTE/GUARD):
  S1: Invalid schema -> 400
  S2: No auth -> 401
  S3: Wrong role -> 403
  S4: Tenant isolation -> 403 + service.not.toHaveBeenCalled()
- Q1-Q17 target: >=14/17, all critical gates (Q7, Q11, Q13, Q15, Q17) = 1

## 4. Questions for Author

[Only if genuine uncertainty -- ambiguous test scope, conflicting patterns.
Leave empty if clear.]
```

**A plan missing any section is INCOMPLETE -- do not proceed.**

### Questions Gate

If section 4 is non-empty -> ask user, wait for answers, update plan.
If empty -> present plan and wait for approval.

Wait for user approval.

**If `--dry-run`:** print plan and STOP here. Do not proceed to Phase 3.

---

## Phase 3: Write

### 3.1: Pre-flight

Before writing, verify:
- [ ] Coverage Scanner and Pattern Selector results incorporated
- [ ] For each ADD TO file: read existing test file fully (know what's already there)
- [ ] Mock hazards listed and mock patterns identified for each

### 3.2: Write Tests

Implement per the plan. Rules:

**Never delete or replace existing tests** -- add new `describe` blocks or `it` blocks only.
Allowed modifications to existing code: imports, `beforeEach`/`afterEach` setup, shared helpers/factories (when needed by new tests). Do NOT rewrite existing assertions or test logic.

**For each test file, follow patterns from `~/.cursor/test-patterns.md`** (loaded in Phase 0). The lookup from Pattern Selector gives the G-/P- IDs -- read those pattern entries before writing.

**Mock Safety -- REQUIRED check before writing mocks:**

For each mock hazard identified by Pattern Selector:

| Hazard type | WRONG (causes hang) | CORRECT |
|-------------|---------------------|---------|
| `AsyncGenerator` / `async function*` | `vi.fn()` -- returns undefined, iteration hangs | `vi.fn().mockImplementation(async function*() { yield chunk; })` |
| `for await (const chunk of stream)` | mock that is not async iterable | mock must implement `Symbol.asyncIterator` |
| `stream.pipe(writer)` | no-op mock -- writer never emits `finish` | `writer.on = vi.fn((event, cb) => event === 'finish' && cb())` or use a PassThrough stream |
| `EventEmitter.on('data')` / `.on('end')` | `vi.fn()` -- callbacks never called | mock EventEmitter with `.emit('data', chunk)` + `.emit('end')` in implementation |
| Promise returned from `new Promise(resolve => stream.on('finish', resolve))` | stream mock that never emits `finish` | mock stream as PassThrough or manually call finish handler |

**Always verify**: run a quick mental trace -- does the mock return something the production code can iterate/await/subscribe to? If not -> the test will hang silently.

**File size check after each file**: if test file exceeds 400 lines -> split NOW. New files expand the scope fence automatically. Example: `foo.service.test.ts` (300 lines existing) + 150 new lines -> split new tests into `foo.service.edge-cases.test.ts`.

### 3.3: Test Self-Eval (mandatory per file)

Run Q1-Q17 self-eval (from `~/.cursor/rules/testing.md`) on each test file written/modified.

- Score each Q individually (1/0)
- Critical gate: Q7, Q11, Q13, Q15, Q17 -- any = 0 -> fix before Phase 4
- Score < 14 -> fix worst gaps, re-score
- Q12 procedure: list ALL public methods in production file -> for each repeated test pattern (auth guard, validation, error path) verify EVERY method has it. One missing = 0.

Output format:
```
[filename]: Q1=1 Q2=1 Q3=0 Q4=1 Q5=1 Q6=1 Q7=1 Q8=0 Q9=1 Q10=1 Q11=1 Q12=0 Q13=1 Q14=1 Q15=1 Q16=1 Q17=1
  Score: 14/17 -> PASS | Critical gate: Q7=1 Q11=1 Q13=1 Q15=1 Q17=1 -> PASS
```

Only proceed to Phase 4 when ALL test files score >= 14 AND all critical gates pass.

---

## Phase 4: Verify

### 4.1: Test Quality Auditor

Spawn the auditor:

```
Spawn via Task tool with:
  prompt: |
    You are a Test Quality Auditor. Read ~/.cursor/skills/write-tests/agents/test-quality-auditor.md
    for full instructions.

    TEST FILES: [list of test files written/modified]
    CODE TYPE: [from Pattern Selector output]
    COMPLEXITY: [Low/Medium/High based on file size and code types]

    Verify 11 hard gates and run Q1-Q17 self-eval on each test file.
    Pay special attention to:
    - Mock hazards: check that async generator / stream mocks have proper implementations
      (vi.fn() returning undefined for streams = test will hang, not fail = Q15 concern)
    - Q17: verify computed output, not input echo
    - Q11: verify both branches of every if/else/switch in production code

    Read project CLAUDE.md and .claude/rules/ for project-specific test conventions.
```

**Results:**
- `PASS` (>=14, all critical gates) -> proceed
- `FIX` (9-13, or critical gate fail) -> fix issues, re-run auditor
- `BLOCK` (<9) -> rewrite test file, re-run auditor

Do not proceed to Phase 5 until auditor returns PASS or FIX-with-fixes-applied.

### 4.2: Run Tests

```bash
# Run only the new/modified test files first (fast feedback):
[test runner] [test file paths]

# Then full suite (regression check):
[npm run test:run | pytest | etc.]
```

All tests must pass. If any fail:
1. Check against Phase 0.5 baseline -- if test was already failing before your changes -> pre-existing, not your bug
2. Read the failure output for NEW failures
3. Fix the cause (test bug or mock hazard)
4. Re-run

### 4.3: Verification Checklist (NON-NEGOTIABLE)

Print each with [x]/[ ]:

```
WRITE-TESTS VERIFICATION
------------------------------------
[x]/[ ]  SCOPE: Only test files modified (NO production code changes)
[x]/[ ]  SCOPE: No existing tests deleted or rewritten (setup/import changes OK)
[x]/[ ]  TESTS PASS: Full test suite green (not just new files)
[x]/[ ]  FILE LIMITS: All test files <= 400 lines
[x]/[ ]  Q1-Q17: Self-eval on each written/modified test file (individual scores + critical gate)
[x]/[ ]  MOCK SAFETY: No vi.fn() used for async generators, streams, or EventEmitters
[x]/[ ]  COVERAGE: Each method listed as UNTESTED in Phase 1 now has at least one test
------------------------------------
```

**If ANY is [ ] -> fix before committing.**

---

## Phase 5: Completion

### 5.1: Backlog Persistence (MANDATORY)

1. Check Test Quality Auditor output for `BACKLOG ITEMS` section
2. If present -> persist to `memory/backlog.md`:
   - Next available B-{N} ID
   - Source: `write-tests/{date}`
   - Status: OPEN
3. Mark FIXED any OPEN backlog items for the same test files that are now resolved

**Zero issues may be silently discarded.**

### 5.2: Stage + Pre-Commit Review

Stage only test files (never production files):

```bash
git add [explicit list of test files -- never -A or .]
```

Then run `/review` scoped to staged:

```
/review staged
```

If review finds BLOCKING issues -> unstage, fix, re-stage, re-run review.
If warnings only -> proceed, add warnings to backlog.

### 5.3: Auto-Commit + Tag

After review passes:

```bash
git commit -m "test: [brief description of what was covered]"
git tag write-tests-[YYYY-MM-DD]-[short-slug]
```

(e.g. tag: `write-tests-2026-02-25-ai-service-coverage`)

**Do NOT push.** Push is a separate user decision.

### 5.4: Output

```
WRITE-TESTS COMPLETE
------------------------------------
Target: [file | directory | N files auto-discovered]
Test files created: [N]
Test files extended: [N]
Tests written: [N total], all passing
Coverage: [methods covered: X/Y | "see report"]
Verification: tests PASS | types PASS (if applicable)
Quality: [N files at Tier A, N at Tier B after auditor]
Backlog: [N items persisted | "none"]
Commit: [hash] -- [message]
Tag: [tag name] (rollback: git reset --hard [tag])

Mock hazards resolved: [N -- list hazard types fixed]

Next steps:
  /test-audit [path]   -> Re-audit to confirm tier improvement
  /review staged       -> If additional review needed
  Push                 -> git push origin [branch]
------------------------------------
```

---

## Quick Reference: Mode Summary

| Mode | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|------|---------|---------|---------|---------|---------|
| `/write-tests foo.ts` | Scan 1 file | Plan 1 file | Write 1 test file | Audit + run | Commit |
| `/write-tests src/services/` | Scan N files | Plan N files | Write N test files | Audit + run | Commit |
| `/write-tests auto` | Discover uncovered files | Plan batch | Write batch | Audit + run | Commit |
| `/write-tests foo.ts --dry-run` | Scan 1 file | Plan + STOP | -- | -- | -- |
