---
name: write-tests
description: "Write tests for existing production code. Runs coverage analysis + pattern selection, writes tests with Q1-Q17 quality gates. Use: /write-tests [path] or /write-tests auto (discover uncovered files). NOT for /build (use Phase 3.4) or mass fixes (use /fix-tests)."
user-invocable: true
---

# /write-tests — Test Writing Workflow

Structured workflow for writing tests for **existing** production code.
Heavier than inline test writing (sub-agents for coverage + pattern analysis), lighter than `/build` (no production code changes).

**When to use:**
- Existing production file with no tests or partial coverage
- After `/refactor` when tests need to be rewritten
- Legacy code that was never tested
- Single file or directory batch

**When NOT to use:**
- New feature code → tests written in `/build` Phase 3.4
- Mass repair of SAME anti-pattern across 10+ files → `/fix-tests` (batch mode)
- Auditing existing tests → `/test-audit`

**Scope rule:** If `/write-tests` identifies quality issues (auto-fail patterns, weak assertions, untested branches) in target files → **fix them directly.** Do NOT delegate to `/fix-tests` unless the issue is outside write-tests scope (e.g., flaky test infrastructure, test runner config, 10+ files with same pattern). Replacing `typeof === 'function'` with behavioral assertions IS in scope. Adding missing branch tests IS in scope.

Parse `$ARGUMENTS` as: `[path | auto] [--dry-run]`

---

## Progress Tracking

Track progress through the phases below, marking each as in_progress → completed as you go.

## Multi-Agent Compatibility

This skill uses `Task` tool to spawn parallel sub-agents. **If `Task` tool is not available** (Cursor, Antigravity, other IDEs):
- Skip all "Spawn via Task tool" blocks
- Execute the agent's work inline yourself, sequentially
- Model routing is ignored — use whatever model you are running on
- Quality gates and output format remain identical

---

## Model Routing (Sub-Agents)

| Agent | Model | subagent_type | When |
|-------|-------|---------------|------|
| Coverage Scanner | Haiku | Explore | Phase 1 (background) |
| Pattern Selector | Haiku | Explore | Phase 1 (background) |
| Test Quality Auditor | Sonnet | Explore | Phase 4 (after tests) |

## Path Resolution (non-Claude-Code environments)

- `~/.claude/skills/` → `_agent/skills/`
- `~/.claude/rules/` → `_agent/rules/`
- `~/.claude/test-patterns.md` → `_agent/test-patterns.md`

---

## Mandatory File Reading (NON-NEGOTIABLE)

Before starting ANY work, read ALL files below. Confirm each with ✅ or ❌:

```
1. ✅/❌  ~/.claude/rules/testing.md                              — Q1-Q17 test self-eval checklist + iron rules
2. ✅/❌  ~/.claude/test-patterns.md                              — Q1-Q17 protocol + code-type lookup table
3. ✅/❌  ~/.claude/rules/file-limits.md                          — 400-line test file limit
4. ✅/❌  ~/.claude/skills/write-tests/agents/quality-rules.md    — edge cases, mock safety, self-eval evidence, auto-fail patterns
```

**If ANY file is ❌ → STOP. Do not proceed with a partial rule set.**

---

## Phase 0: Context

1. Read project `CLAUDE.md` and `.claude/rules/` for conventions (test runner, file locations, mock patterns)
2. Detect stack (check `package.json`, `tsconfig.json`, `pyproject.toml`, etc.)
3. Check for domain-specific test patterns:
   - NestJS detected → note: load `~/.claude/test-patterns-nestjs.md` when writing CONTROLLER tests
   - Redux detected → note: load `~/.claude/test-patterns-redux.md` when writing REDUX-SLICE tests
4. Read `memory/backlog.md` — check for related open items in target files
5. Read `memory/coverage.md` — if exists, use as cached coverage state (skip re-scanning known files)
   - **Path:** `memory/` is in the project root directory (same level as `package.json`/`CLAUDE.md`)
   - If `memory/` dir does not exist → create it: `mkdir -p memory`
   - If `memory/coverage.md` does not exist → create it with the Phase 5.1b template (empty table)

**Parse arguments:**

| Argument | Behavior |
|----------|----------|
| `[file.ts]` | Write tests for single production file |
| `[directory/]` | Write tests for all production files in directory |
| `auto` | **Full autonomy with auto-loop.** Discover uncovered files, write tests, commit — no approval gates, no questions. Quality gates (mandatory reads, Q1-Q17, verification checklist) still enforced. Batch limit: 15 files per batch. **After each batch completes, automatically start next batch** until no UNCOVERED/PARTIAL files remain (see Auto-Loop below). |
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

**Why:** If existing tests already fail, Phase 4 cannot distinguish pre-existing failures from regressions caused by your new tests. Record failures now → ignore them in Phase 4.

If baseline run fails on infrastructure (no test runner, missing deps) → note it and proceed. The baseline is for distinguishing old vs new failures, not a gate.

---

## Phase 1: Analysis

### Non-auto mode (explicit file/dir)

Spawn 2 sub-agents **in parallel** (target files are known upfront):

**Agent 1: Coverage Scanner**

```
Spawn via Task tool with:
  subagent_type: "Explore"
  model: "haiku"
  run_in_background: true
  prompt: |
    You are a Coverage Scanner. Read ~/.claude/skills/write-tests/agents/coverage-scanner.md
    for full instructions.

    TARGET FILES: [list of production files from $ARGUMENTS]
    PROJECT ROOT: [cwd]

    Read project CLAUDE.md for test file location conventions.
```

**Agent 2: Pattern Selector**

```
Spawn via Task tool with:
  subagent_type: "Explore"
  model: "haiku"
  run_in_background: true
  prompt: |
    You are a Pattern Selector. Read ~/.claude/skills/write-tests/agents/pattern-selector.md
    for full instructions.

    TARGET FILES: [list of production files from $ARGUMENTS]
    PROJECT ROOT: [cwd]

    Read project CLAUDE.md for project-specific conventions.
```

Wait for both agents to complete before starting Phase 2 — the plan requires coverage status and code types from both.

### Auto mode: Sequential Discovery → Classify → Prioritize

In `auto` mode, Pattern Selector cannot run until Coverage Scanner discovers the files. Execute sequentially.

If `memory/coverage.md` exists with recent data → scanner uses cached state (much faster). If not → full discovery scan.

**Step 1: Coverage Scanner** (discover + classify coverage)

```
Spawn via Task tool with:
  subagent_type: "Explore"
  model: "haiku"
  prompt: |
    You are a Coverage Scanner. Read ~/.claude/skills/write-tests/agents/coverage-scanner.md
    for full instructions.

    TARGET FILES: auto
    COVERAGE CACHE: [path to memory/coverage.md, or "none"]
    PROJECT ROOT: [cwd]

    Read project CLAUDE.md for test file location conventions.
```

Wait for results. Scanner returns a **DISCOVERY SUMMARY** (mandatory) with total counts + list of UNCOVERED and PARTIAL files.

**Verify discovery is complete:** if DISCOVERY SUMMARY shows fewer than 10 production files for a non-trivial project → scanner likely missed directories. Re-run with explicit paths or check glob patterns.

**Step 2: Pattern Selector** (classify code types for top candidates)

Pass only the top 30 UNCOVERED + PARTIAL files (by scanner's risk ranking) to Pattern Selector. No need to classify all files — only the candidates for this batch.

```
Spawn via Task tool with:
  subagent_type: "Explore"
  model: "haiku"
  prompt: |
    You are a Pattern Selector. Read ~/.claude/skills/write-tests/agents/pattern-selector.md
    for full instructions.

    TARGET FILES: [top 30 UNCOVERED + PARTIAL files from Step 1]
    PROJECT ROOT: [cwd]

    Read project CLAUDE.md for project-specific conventions.
```

Wait for results. Selector returns code types per file.

**Step 3: Merge + Prioritize**

Merge both results — each file now has coverage status + risk (from Scanner) AND code type (from Selector). Apply priority table:

| Priority | Criteria | Why |
|----------|----------|-----|
| 1 (highest) | UNCOVERED + SERVICE, CONTROLLER, GUARD | Core logic / security surface, zero safety net |
| 2 | UNCOVERED + HOOK, ORCHESTRATOR, API-CALL | Complex async / coordination code |
| 3 | UNCOVERED + PURE, COMPONENT, ORM | Lower blast radius |
| 4 | PARTIAL (<50% methods covered) | Some coverage, gaps are surgical |
| 5 (lowest) | PARTIAL (≥50% methods covered) | Diminishing returns |

**PARTIAL-QUALITY files** (covered but weak tests) → **include as FIX action** in this batch. These have auto-fail patterns (typeof, toBeDefined-only) or untested branches despite 100% method coverage. `/write-tests` fixes them directly — do NOT delegate to `/fix-tests` unless there are 10+ such files with the same pattern (batch mode is more efficient).

Sort PARTIAL-QUALITY after UNCOVERED but before PARTIAL in priority.

Within same priority → sort by file size descending (larger = more risk).

**Hard cap: 15 files per run.** Take top 15 from priority-sorted list. If more → note `DEFERRED: [N] files (next run)`.

Log: `AUTO BATCH: [N]/[total] files, priority 1: [N], priority 2: [N], ...`

### Phase 1.5: Mandatory Production Code Read (ALL files, including COVERED)

**Before planning, read EVERY target file's production code.** This is the #1 quality driver — without it, agent writes tests for imagined behavior.

For each file in the batch:

1. **Read the production file** (full — don't stop at line 50)
2. **List ALL branches**: `if/else`, `switch`, ternary `?:`, `??`, `||`, early `return`, `try/catch`
3. **Classify what the file OWNS vs DELEGATES:**
   - **Owns**: business logic computed in this file (transformations, calculations, branching decisions)
   - **Delegates**: calls passed through to dependencies (service.method(), logger.log(), cache.get())
4. **Classify complexity:**

| Classification | Criteria | Test depth | Target tests |
|---------------|----------|------------|-------------|
| **Thin wrapper** | <50 LOC, no owned branching, pure delegation | Wiring correctness + error propagation + cache/singleton if applicable. **Skip edge case checklist.** | 5-12 tests |
| **Standard** | 50-200 LOC, moderate branching (3-10 branches) | Full edge case checklist per parameter. | 15-40 tests |
| **Complex** | >200 LOC or >10 branches | Split test files by concern. Full coverage. | 40-80 tests |

5. **Log per file:**
```
[path]: [N] LOC, [N] branches, [N] owned / [N] delegated → [THIN|STANDARD|COMPLEX]
  Owned logic: [brief description of what this file actually computes]
  Key branches: [list the if/switch that need both-side testing]
```

**Why this matters:** A 25-line wrapper that delegates to logger doesn't need 30 tests with edge cases for every parameter type. A 500-line service with 15 branches needs more than the default minimum. Test depth must match file complexity.

---

## Phase 2: Plan

Create a plan with ALL of these sections before writing any tests:

### Required Plan Sections

```
## 1. Scope

Files to cover (from Coverage Scanner results):
| File | Status | Untested methods | Risk |
|------|--------|-----------------|------|

Files to SKIP (must satisfy ALL three conditions):
- Coverage: 100% methods covered
- Quality: zero auto-fail patterns (no typeof ≥3×, no toBeDefined-only, no echo assertions)
- Branches: no untested branches in production code (requires reading the file)
[list with reason for each SKIP — cite evidence for all 3 conditions]

Files to FIX (100% coverage but auto-fail patterns or weak assertions):
[list — these are NOT skipped, they go through Phase 3 with action=FIX]

Files to ADD TO (existing tests, but missing methods or branches):
[list with untested methods/branches]

## 2. Test Files

For each target:
| Production file | Test file | Action |
|----------------|-----------|--------|
| foo.service.ts | foo.service.test.ts | CREATE (no test file) |
| bar.service.ts | bar.service.test.ts | ADD TO (partial, ~40%) |
| baz.service.ts | baz.service.test.ts | FIX (100% coverage, but 14× typeof auto-fail + untested branches) |

⚠️ ADD TO: never DELETE or REPLACE existing tests. New describe/it blocks only.
   Allowed modifications to existing code: imports, beforeEach/afterEach setup, shared helpers/factories
   (when needed by new tests). Do NOT rewrite existing assertions or test logic.
⚠️ FIX: REPLACE auto-fail assertions (typeof, toBeDefined-only) with behavioral tests.
   DELETE weak assertions and write proper ones. Add missing branch/error tests.
   This is the ONLY action that modifies existing test logic.
⚠️ File size: [current LOC of existing test file] + [estimated new LOC] = [total]
   Flag if total > 400 lines → plan split into [foo.service.errors.test.ts] etc.

## 3. Test Strategy Per File

For each file, list:
- Complexity: [THIN | STANDARD | COMPLEX] (from Phase 1.5)
- Owned logic: [what this file computes — from Phase 1.5]
- Code types: [from Pattern Selector]
- Patterns to apply: [G-IDs to follow, P-IDs to avoid]
- Domain file: [if needed]
- Mock hazards: [from Pattern Selector — async generators, streams, etc.]
  → For each hazard: required mock pattern (see Phase 3.2 Mock Safety section)
- Describe blocks (scope to complexity):
  - THIN: wiring + error propagation only (no edge case checklist)
  - STANDARD/COMPLEX: full edge case checklist per parameter
  - describe('[MethodName]')
    - it('should [happy path]')
    - it('should [error case]')
    - it('should [edge case — STANDARD/COMPLEX only]')
- Security tests (if CONTROLLER/API-ROUTE/GUARD):
  S1: Invalid schema → 400
  S2: No auth → 401
  S3: Wrong role → 403
  S4: Tenant isolation → 403 + service.not.toHaveBeenCalled()
- Q1-Q17 target: ≥14/17, all critical gates (Q7, Q11, Q13, Q15, Q17) = 1

## 4. Questions for Author

[Only if genuine uncertainty — ambiguous test scope, conflicting patterns.
Leave empty if clear. Auto mode: write "N/A (auto mode)" and proceed.]
```

**A plan missing sections 1-3 is INCOMPLETE — do not proceed.** Section 4 is optional in auto mode.

### Questions Gate

**Auto mode:** write `## 4. Questions: N/A (auto mode)` — make best-judgment decisions, document assumptions in plan, proceed immediately.

Non-auto modes: if section 4 is non-empty → ask user, wait for answers, update plan. If empty → present plan and wait for approval.

**Auto mode:** do NOT wait for approval — print plan summary and proceed immediately to Phase 3.
Non-auto modes: wait for user approval.

**If `--dry-run`:** print plan and STOP here. Do not proceed to Phase 3.

---

## Phase 3: Write

### 3.1: Pre-flight

Before writing, verify:
- [ ] Coverage Scanner and Pattern Selector results incorporated
- [ ] For each ADD TO file: read existing test file fully (know what's already there)
- [ ] Mock hazards listed and mock patterns identified for each

### 3.2: Write Tests

**Process EVERY file in the Phase 2 plan.** For each production file listed in the Scope table:

1. Log: `FILE [N]/[total]: [path] — Action: [CREATE | ADD TO | FIX]`
2. Read the production file (full — don't skip methods). **This is mandatory for ALL actions including FIX.**
   List all branches (if/else, switch, ternary, `??`, `||`) — these are needed for Q11.
3. If ADD TO or FIX: read the existing test file to know what's already there.
   For FIX: identify auto-fail patterns to remove (typeof, toBeDefined-only, echo assertions).
4. Write/fix the test file following Phase 2 strategy for this file
5. Run Q1-Q17 self-eval (Phase 3.3) on this test file
6. Fix loop until score = 17/17 (or all Q=0 justified N/A) with all critical gates passing
7. → Move to next file

**Do NOT stop after one file.** After each file, print progress with explicit next target:
```
BATCH: [N]/[total] complete. Next: [next-filename] (do NOT stop)
```
The batch is complete only when ALL files in the plan have tests written and self-eval passing.

**Minimum tests — scaled by complexity (from Phase 1.5):**

| Complexity | Minimum per method | Edge case checklist | Total target |
|------------|-------------------|--------------------|----|
| **THIN** | 1 happy + 1 error propagation | **NO** — test wiring, caching, error passthrough only | 5-12 total |
| **STANDARD** | 2 per method (positive + negative) + 1 per branch | **YES** — full checklist per parameter | 15-40 total |
| **COMPLEX** | 1 per branch + error per method | **YES** + split test files by concern | 40-80 total |

**Always required regardless of complexity:**
- 1 error/rejection test per public method (Q7 critical gate)
- 1 test per branch/path (Q11 critical gate) — even THIN wrappers need error propagation
- Tests must verify OWNED logic, not re-test dependencies (Q17)

A single `it('should work')` per method is NOT sufficient. Controllers/API routes additionally need S1-S4 security tests from the plan.

**Edge Case Checklist + Validator Depth (STANDARD/COMPLEX only):**

Apply `quality-rules.md` § **Edge Case Checklist** (loaded in Phase 0). For every parameter, apply the input-type table. For VALIDATOR code type, apply § **Validator/Schema/DTO** depth requirements (N×3 + 2 minimum tests). **Skip for THIN wrappers** — they don't own the logic that processes edge cases.

**Rules:**

**Never delete or replace existing tests** — add new `describe` blocks or `it` blocks only.
Allowed modifications to existing code: imports, `beforeEach`/`afterEach` setup, shared helpers/factories (when needed by new tests). Do NOT rewrite existing assertions or test logic.

**For each test file, follow patterns from `~/.claude/test-patterns.md`** (loaded in Phase 0). The lookup from Pattern Selector gives the G-/P- IDs — read those pattern entries before writing.

**Mock Safety — REQUIRED check before writing mocks:**

Apply `quality-rules.md` § **Mock Safety** (loaded in Phase 0). For each mock hazard from Pattern Selector, use the correct mock pattern. Mental trace: does the mock return something the production code can iterate/await/subscribe to? If not → test will hang silently.

**File size — plan splits early, not after:**
- If production file has >15 public methods → plan the split in Phase 2:
  - `[file].test.ts` — core business logic methods
  - `[file].errors.test.ts` — error paths for all methods
  - `[file].edge-cases.test.ts` — boundary conditions
- If test file exceeds 400 lines during writing → split NOW into above pattern
- Example: `foo.service.test.ts` (300 lines existing) + 150 new lines → split new tests into `foo.service.edge-cases.test.ts`

### 3.3: Test Self-Eval (mandatory per file)

Run Q1-Q17 self-eval (from `~/.claude/rules/testing.md`) on each test file written/modified.

- Score each Q individually (1/0). N/A counts as 1 (with justification).
- **AP deductions:** scan for anti-patterns (AP9, AP10, AP13, AP14, AP16, etc. from `~/.claude/test-patterns.md`). Each unique AP found = −1 (max −5). Same AP occurring multiple times in one file = still −1.
- **Scoring formula:** Total = (yes-count + N/A-count) − AP-deductions
- Critical gate: Q7, Q11, Q13, Q15, Q17 — any = 0 → fix before Phase 4
- **Target: 17/17.** For each Q=0: fix the tests, then re-score. Only accept Q=0 if genuinely N/A with written justification (e.g., "Q3=N/A — pure function, zero mocks"). "Hard to test" or "not important" are NOT valid reasons — fix it.
- **Fix loop:** score → fix worst Q=0 → re-score → repeat until 17/17 or all remaining Q=0 are justified N/A. Do NOT proceed with Q=0 that can be fixed.
- **Fix priority: address flagged gaps FIRST.** If self-eval or reviewer flags a specific missing test (e.g., "log level filtering not tested"), write THAT test before adding anything else. Do NOT add more tests in areas that already pass while ignoring Q=0 items. Pattern: agent adds "more of what it knows" instead of "what's missing" — this is the #1 fix loop failure mode.
- Q12 procedure: list ALL public methods in production file → for each repeated test pattern (auth guard, validation, error path) verify EVERY method has it. One missing = 0.
- Stack-specific deductions (Redux P-40/P-41, NestJS NestJS-P1 from domain pattern files) apply only when auditing that code type — included in the AP list, not a separate deduction.

**EVIDENCE REQUIRED for critical gates — Q=1 without evidence = Q=0:**

Apply `quality-rules.md` § **Self-Eval Evidence Requirements** and § **Auto-Fail Patterns** (loaded in Phase 0). For each critical gate (Q7, Q11, Q15, Q17), provide proof citing specific test names or line ranges. Without proof → score as 0. Scan for auto-fail patterns — if found, corresponding Q = 0 regardless of other evidence.

**Auto-fail patterns must be REMOVED, not just scored.** If `typeof === 'function'` appears ≥3× → delete or replace those assertions with behavioral tests (`expect(fn(input)).toEqual(output)`). If `toBeDefined()` is the sole assertion → add a value assertion. Leaving auto-fail patterns in place and accepting Q=0 is NOT acceptable — fix the tests.

**Output format — compact when passing, verbose when failing:**

When 17/17 and all critical gates pass:
```
[filename]: 17/17 ✅ | Q7→line45 Q11→5branches Q13→real-imports Q15→80%value Q17→computed
```

When score < 17 or critical gate = 0 (verbose — show what to fix):
```
[filename]: Q1=1 Q2=1 Q3=0 Q4=1 Q5=1 Q6=1 Q7=1 Q8=0 Q9=1 Q10=1 Q11=0 Q12=0 Q13=1 Q14=1 Q15=1 Q16=1 Q17=1
  APs: AP10(−1) | Total: 14 − 1 = 13/17 → FIX
  Critical gate FAIL: Q11=0 → branch `if(!correction)` has no test
  Fix: add it('should handle missing correction') testing the !correction path
```

Only proceed to Phase 4 when ALL test files score 17/17 (or all Q=0 are justified N/A), zero AP deductions, AND all critical gates pass with evidence.

### 3.4: Batch Completion Gate

Before moving to Phase 4, verify the batch is complete:

```
BATCH PROGRESS: [N]/[total] files completed
```

If `N < total` → you are NOT done. Go back to Phase 3.2 and continue with the next file. Do NOT proceed to Phase 4 until all files are processed.

---

## Phase 4: Verify

### 4.1: Test Quality Auditor

**Why both 3.3 AND 4.1?** Phase 3.3 = writer self-check (fast, inline, catches obvious gaps). Phase 4.1 = independent audit by different model — catches blind spots the writer is blind to (mock hazards assumed safe, production behavior assumed but not verified).

Spawn the auditor:

```
Spawn via Task tool with:
  subagent_type: "Explore"
  model: "sonnet"
  prompt: |
    You are a Test Quality Auditor. Read ~/.claude/skills/write-tests/agents/test-quality-auditor.md
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
- `PASS` (≥14, all critical gates) → proceed
- `FIX` (9-13, or critical gate fail) → fix issues, re-run auditor
- `BLOCK` (<9) → rewrite test file, re-run auditor

Do not proceed to Phase 5 until auditor returns PASS or FIX-with-fixes-applied.

### 4.2: Run Tests

```bash
# Run only the new/modified test files first (fast feedback):
[test runner] [test file paths]

# Then full suite (regression check):
[npm run test:run | pytest | etc.]
```

All tests must pass. If any fail:
1. Check against Phase 0.5 baseline — if test was already failing before your changes → pre-existing, not your bug
2. Read the failure output for NEW failures
3. Fix the cause (test bug or mock hazard)
4. Re-run

**Capture test run time per file** from the runner output (e.g., Vitest `Duration 361ms`, Jest `Time: 1.2s`, pytest `passed in 0.45s`). Record this as `TestRunTime` in coverage.md — used to identify slow tests for optimization.

### 4.3: Verification Checklist (NON-NEGOTIABLE)

Print each with ✅/❌:

```
WRITE-TESTS VERIFICATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅/❌  SCOPE: Only test files modified (NO production code changes)
✅/❌  SCOPE: No existing tests deleted or rewritten (setup/import changes OK)
✅/❌  TESTS PASS: Full test suite green (not just new files)
✅/❌  FILE LIMITS: All test files ≤ 400 lines
✅/❌  Q1-Q17: Self-eval on each written/modified test file (individual scores + critical gate)
✅/❌  MOCK SAFETY: No vi.fn() used for async generators, streams, or EventEmitters
✅/❌  COVERAGE: Each method listed as UNTESTED in Phase 1 now has at least one test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**If ANY is ❌ → fix before committing.**

---

## Phase 5: Completion

### 5.1: Backlog Persistence (MANDATORY)

Collect items from ALL sources:
1. **Test Quality Auditor** — `BACKLOG ITEMS` section from Phase 4.1
2. **Self-Eval** — any Q scored 0 that was not fixed, any AP deductions applied
3. **Review warnings** — warnings from Phase 5.2 `/review` (if run)

For each item → persist to `memory/backlog.md`:

1. **Read** the project's `memory/backlog.md` (from the auto memory directory shown in system prompt)
2. **If file doesn't exist**: create it with this template:
   ```markdown
   # Tech Debt Backlog
   | ID | Fingerprint | File | Issue | Severity | Category | Source | Seen | Dates |
   |----|-------------|------|-------|----------|----------|--------|------|-------|
   ```
3. For each finding:
   - **Fingerprint:** `file|Q/AP-id|signature` (e.g., `user.test.ts|Q7|no-error-path-test`). Search the `Fingerprint` column for an existing match.
   - **Duplicate** (same fingerprint found): increment `Seen` count, update date, keep highest severity
   - **New** (no match): append with next `B-{N}` ID, category: Test, source: `write-tests/{date}`, date: today

If any OPEN backlog items for the same test files were resolved → delete them (fixed = deleted; git has history).

**THIS IS REQUIRED.** Zero issues may be silently discarded.

### 5.1b: Coverage Persistence (MANDATORY)

Update `memory/coverage.md` with results of this session. This file is the project's **persistent coverage registry** — read by all skills that write or audit tests.

1. **Read** `memory/coverage.md` (path defined in Phase 0 step 5). Create `memory/` dir if missing.
2. **If file doesn't exist**: create it from `~/.claude/skills/write-tests/agents/coverage-template.md` (template + column definitions).
3. For each file processed in this session:
   - **Search** the `File` column for an existing row
   - **Existing row**: update Status, Methods, Covered, Test file, Updated date, Source, Duration, TestRunTime
   - **New row**: append with current data
4. For files from Coverage Scanner's DISCOVERY SUMMARY that were NOT processed (DEFERRED):
   - Add as UNCOVERED rows (if not already present) with `Source: write-tests/scan`
   - This seeds the registry for the next run — subsequent `/write-tests auto` reads these instead of re-scanning
5. For files that were COVERED in scanner results:
   - Add/update as COVERED rows — so next run skips them entirely

**Column definitions and cross-skill usage:** see `~/.claude/skills/write-tests/agents/coverage-template.md`.

### 5.2: Stage + Pre-Commit Review

Stage only test files (never production files):

```bash
git add [explicit list of test files — never -A or .]
```

**Auto mode:** skip `/review` — Phase 4 verification checklist is sufficient. Proceed directly to 5.3.

Non-auto modes: run `/review` scoped to staged:

```
/review staged
```

If review finds BLOCKING issues → unstage, fix, re-stage, re-run review.
If warnings only → proceed, add warnings to backlog.

### 5.3: Commit + Tag

After verification passes (Phase 4.3 all ✅):

```bash
git commit -m "test: [brief description of what was covered]"
git tag write-tests-[YYYY-MM-DD]-[short-slug]
```

(e.g. tag: `write-tests-2026-02-25-ai-service-coverage`)

**Do NOT push.** Push is a separate user decision.

### 5.4: Output

```
WRITE-TESTS COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Target: [file | directory | N files auto-discovered]
Duration: [total time from Phase 1 start to Phase 5 end]
Test files created: [N]
Test files extended: [N]
Tests written: [N total], all passing
Coverage: [methods covered: X/Y | "see report"]
Verification: tests PASS | types PASS (if applicable)
Quality: [N files at Tier A, N at Tier B after auditor]
Backlog: [N items persisted | "none"]
Coverage registry: [N entries updated in memory/coverage.md]
Commit: [hash] — [message]
Tag: [tag name] (rollback: git reset --hard [tag])

Mock hazards resolved: [N — list hazard types fixed]

Next steps:
  /test-audit [path]   → Re-audit to confirm tier improvement
  Push                 → git push origin [branch]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 5.5: Auto-Loop (auto mode only)

**After Phase 5.4 output, check if more work remains:**

1. Read `memory/coverage.md` — count UNCOVERED + PARTIAL entries
2. If UNCOVERED + PARTIAL > 0 → **automatically start next batch:**
   - Log: `AUTO-LOOP: batch [N] complete. [M] UNCOVERED + [K] PARTIAL remaining. Starting next batch...`
   - Go back to **Phase 1** (auto mode) — Coverage Scanner reads updated coverage.md, skips already-COVERED files
   - Each batch gets its own commit + tag (Phase 5.3)
3. If UNCOVERED + PARTIAL = 0 → **all done:**
   - Log: `AUTO-LOOP COMPLETE: all files covered after [N] batches`
   - Stop

**Loop continues until:**
- All files COVERED (normal exit)
- A batch produces zero new test files (nothing left to cover — stop to prevent infinite loop)
- A Phase 4 verification fails 3 times in a row (something is broken — stop and report)

**Each batch is independent:** own commit, own tag, own backlog persistence. If interrupted, previous batches are already committed and safe.

---

## Quick Reference: Mode Summary

| Mode | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|------|---------|---------|---------|---------|---------|
| `/write-tests foo.ts` | Scan 1 file | Plan 1 file | Write 1 test file | Audit + run | Commit |
| `/write-tests src/services/` | Scan N files | Plan N files | Write N test files | Audit + run | Commit |
| `/write-tests auto` | Discover → loop batches | Plan (no approval) | Write batch | Audit + run | Commit → next batch |
| `/write-tests foo.ts --dry-run` | Scan 1 file | Plan + STOP | — | — | — |
