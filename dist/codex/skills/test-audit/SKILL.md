---
name: test-audit
description: "Audit all test files against Q1-Q17 checklist + AP/P-* anti-patterns (see test-patterns.md lookup table -> catalog/domain files). Produces tiered report with scores, gaps, and fix recommendations. Use: /test-audit [path] or /test-audit all. NOT for immediate fixes (use /fix-tests)."
---

# /test-audit -- Test Quality Triage

Mass audit of unit and integration test files against the Q1-Q17 binary checklist + AP anti-patterns.
Produces a tiered report: which files are fine, which need fixes, which need rewrites.

**Scope:** Unit and integration tests only. E2E tests (`*/e2e/*`, `*.e2e.*`, `*.spec.ts` in e2e dirs) are excluded by default -- they follow different quality criteria. Use `--include-e2e` to include them.

## Mandatory File Reading (NON-NEGOTIABLE)

Before starting ANY work, read ALL files below. Confirm each with [x] or [ ]:

```
1. [x]/[ ]  ~/.codex/test-patterns.md              -- Q1-Q17 protocol, lookup table -> routes to catalog/domain files
2. [x]/[ ]  ~/.codex/rules/testing.md              -- iron rules, test requirements by code type, self-eval
```

**If ANY file is [ ] -> STOP. Do not proceed with a partial rule set.**

## Step 0: Parse $ARGUMENTS

| Argument | Behavior |
|----------|----------|
| `all` | Audit ALL test files in the project |
| `[path]` | Audit test files in specific directory |
| `[file]` | Audit single test file (deep mode) |
| `--deep` | Include per-file fix recommendations (slower) |
| `--quick` | Binary checklist only, skip evidence (faster) |
| `--commit=ask\|auto\|off` | Commit mode after fix workflow (default: `ask`) |
| `--include-e2e` | Include E2E test files (excluded by default) |

Default: `all --quick --commit=ask`

## Step 1: Discover Test Files

Find all test files:
```bash
find . \( -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" -o -name "*.spec.tsx" -o -name "test_*.py" -o -name "*_test.py" \) ! -path "*/node_modules/*" ! -path "*/.next/*" ! -path "*/__pycache__/*" ! -path "*/e2e/*" | sort
```

Count total. If >50 files **and no explicit `--deep` flag was provided**, switch to `--quick` mode automatically (skip evidence gathering). An explicit `--deep` always takes precedence -- never auto-downgrade a user's explicit mode choice.

## Step 2: Pair with Production Files

For each test file, identify the production file it tests:
- `__tests__/api/projects/[id]/route.test.ts` -> `app/api/projects/[id]/route.ts`
- `__tests__/components/Foo.test.tsx` -> `components/Foo.tsx`
- `tests/unit/services/bar.test.ts` -> `lib/services/bar.ts` (or similar)

If production file not found -> flag as ORPHAN (test without source).

## Step 2.5: Golden File Calibration (optional, recommended for first audit)

If this is the first audit of a project, or agent scores seem inconsistent:
1. Pick 2-3 test files with **known scores** (one good ~14+, one bad ~5, one mid ~9)
2. Run a single calibration agent on just those files
3. Compare agent scores to known scores -- if drift >2 points, adjust agent prompt wording
4. Once calibrated, proceed with full batch evaluation

This prevents systematic over/under-scoring across the entire audit.

## Step 3: Parallel Evaluation

**Pre-batch grouping:** Before splitting into batches, group test files by production file. If multiple test files target the same production file (e.g., `foo.test.ts` + `foo.errors.test.ts`), they MUST go into the same batch so suite-aware Q7/Q11 evaluation works correctly.

After grouping, split into batches of 8-10 files. For each batch, evaluate each batch with this prompt:

---

### AGENT PROMPT (copy this for each batch):

```
You are a test quality auditor. For each test file below, evaluate against the Q1-Q17 binary checklist.

STEP 0 -- RED FLAG PRE-SCAN (do this FIRST, before full evaluation):
Count these in the test file. If any trigger -> auto Tier-D, skip full checklist:
- Tests with zero `expect()` calls (AP13) -> AUTO TIER-D. **RTL exception:** `getByRole`/`getByText`/`getByLabelText` are implicit assertions -- a test with only `getBy*` queries and no `expect()` is NOT AP13 (these throw on missing elements).
- Fixture:assertion ratio > 20:1 (AP16) -> AUTO TIER-D
- 50%+ of tests use `toBeTruthy()`/`toBeDefined()` as sole assertion (AP14) -> AUTO TIER-D

QUICK HEURISTICS (not Tier-D triggers, but predict score):
- 0 CalledWith in entire file -> likely score <=4
- 10+ DI providers in test setup -> likely score <=5
- Tests calling __privateMethod() directly -> likely score <=5
- Factory functions with overrides present -> likely score >=8

CHECKLIST (score 1=YES, 0=NO for each):
Q1:  Every test name describes expected behavior (not "should work")?
Q2:  Tests grouped in logical describe blocks?
Q3:  Every mock has CalledWith + not.toHaveBeenCalled?
Q4:  Assertions use exact matchers (toEqual/toBe, not toBeTruthy)?
Q5:  Mocks are typed (no `as any`/`as never`)?
Q6:  Mock state fresh per test (beforeEach, no shared mutable)?
Q7:  CRITICAL -- At least one error path test (throws/rejects)?
Q8:  Null/empty/edge inputs tested?
Q9:  Repeated setup (3+ tests) extracted to helper/factory?
Q10: No magic values -- test data is self-documenting?
Q11: CRITICAL -- All code branches exercised?
Q12: Symmetric: "does X when Y" has "does NOT do X when not-Y"?
Q13: CRITICAL -- Tests import actual production function?
Q14: Behavioral assertions (not just mock-was-called)?
Q15: CRITICAL -- Content/values assertions, not just counts/shape?
Q16: Cross-cutting isolation: change to A verified not to affect B?
Q17: CRITICAL -- Assertions verify COMPUTED output, not input echo?

ANTI-PATTERNS (each found = -1 point):
AP1:  try/catch in test swallowing errors
AP2:  Conditional assertions (if/else in test)
AP3:  Re-implementing production logic in test
AP4:  Snapshot as only test for component
AP5:  `as any` -> `as never` (both bypass types)
AP6:  Testing CSS classes instead of behavior
AP7:  `.catch(() => {})` swallowing errors
AP8:  document.querySelector bypassing Testing Library
AP9:  Always-true assertion (expect(true).toBe(true))
AP10: Tautological mock (call mock -> verify mock called, no production code)
AP11: vi.mocked(vi.fn()) -- mock targeting fresh fn
AP12: waitForTimeout(N) hardcoded delays
AP13: Test with zero expect() calls -- AUTO TIER-D
AP14: toBeTruthy()/toBeDefined() as SOLE assertion on complex object
AP15: Testing private methods directly (controller.__method()) -- avg 3.0/10
AP16: Fixture:assertion ratio > 20:1 -- AUTO TIER-D
AP17: Unused test data declared but never used in any test
AP18: Duplicate test numbers/names (copy-paste indicator)

N/A HANDLING: N/A counts as 1 (yes). Score = (yes-count + N/A-count) out of 17. Q3/Q5/Q6 score as 1 (N/A) for pure functions with zero mocks. Q16 scores as 1 (N/A) for simple single-responsibility units.
Q17 AUDIT RULE: If >=50% of assertions check values that are direct copies of input/request/mock-return without transformation -> Q17=0.

CRITICAL GATE: Q7, Q11, Q13, Q15, Q17 -- any = 0 -> capped at Tier B (Fix) regardless of total.

SCORING MATH (aligned with testing.md):
  Total = (yes-count + N/A-count) - AP-deductions
  No normalization. N/A=1 is the only adjustment.
  AP deduction: each unique AP found = -1 (max -5). Same AP occurring multiple times in one file = still -1.
  Example: 12 yes + 3 N/A = 15, minus 2 APs = 13 -> Tier B
  Note: test-patterns.md may reference stack-specific deductions (Redux P-40/P-41, NestJS NestJS-P1). These apply ONLY when auditing that code type -- they are included in the AP list above (not a separate deduction).

FOR AUTO TIER-D FILES (red flag triggered), output SHORT format:
```
### [filename]
Production file: [path or ORPHAN]
Red flags: [AP13/AP14/AP16 found] -> AUTO TIER-D
Reason: [brief -- e.g., "6/10 tests have zero expect() calls (AP13)"]
Top 3 gaps: [brief]
```

FOR ALL OTHER FILES, output FULL format:
```
### [filename]
Production file: [path or ORPHAN]
Red flags: [AP15 = warning only; or "none"] -> continue
Untested methods: [list of public methods in production file with no test coverage, or "all covered"]
Score: Q1=[0/1] Q2=[0/1] Q3=[0/1/N/A] Q4=[0/1] Q5=[0/1/N/A] Q6=[0/1/N/A] Q7=[0/1] Q8=[0/1] Q9=[0/1] Q10=[0/1] Q11=[0/1] Q12=[0/1] Q13=[0/1] Q14=[0/1] Q15=[0/1] Q16=[0/1/N/A] Q17=[0/1]
Anti-patterns: [AP IDs found, or "none"]
Total: [yes+N/A]/17 - [AP count] = [final]/17
Critical gate: Q7=[0/1] Q11=[0/1] Q13=[0/1] Q15=[0/1] Q17=[0/1] -> [PASS/FAIL]
Tier: [A/B/C/D]
Top 3 gaps: [brief description of worst 3 issues]
```

TIER CLASSIFICATION:
  A (>=14, critical gate PASS): Leave alone -- good ROI on other files
  B (9-13, or critical gate FAIL with score >=9): Fix gaps -- 2-5 targeted fixes
  C (5-8): Major rewrite needed -- significant gaps
  D (<5 or tautological or AUTO TIER-D red flag): Delete and rewrite from scratch

IMPORTANT:
- You MUST read both the test file AND its production file
- Do RED FLAG PRE-SCAN first. If any auto Tier-D trigger found, report it and skip full checklist.
- COVERAGE COMPLETENESS: List all public methods/exported functions in the production file. For each, check if the test file has at least one `it()` block that exercises it. Flag any untested public method as: "UNTESTED: [method_name]() -- no test coverage". Report untested methods in "Top 3 gaps" section. This is separate from Q11 (which checks branches within tested code).
- For Q11 (branches): scan production file for if/else/switch/ternary, check if test covers both sides
- For Q13: verify import actually points to production code, not a local mock/copy
- For Q10: look for hardcoded numbers (100, 50, "test-id") without named constants
- For Q16 (isolation): look for tests that modify one entity and verify another entity is unchanged
- For Q17 (computed): compare assertion values against test input -- if result.X === input.X, that's input echo (score 0)
- For AP10: if test only calls mocks and verifies mocks without any production function in between -> tautological
- For AP13: count `it(` blocks and `expect(` calls -- if any `it` block has 0 expects -> AP13. **RTL exception:** `getByRole`/`getByText`/`getByLabelText` are implicit assertions -- a test with only `getBy*` queries is NOT AP13.
- For AP15: check if test calls methods with `__` or `_` prefix (private/internal methods)
- For AP16: count lines of fixture data vs lines containing `expect(` -- ratio > 20:1 -> AP16
- For AP17: search for `const .*= {` or `const .*= [` declarations that are never referenced in any `it()` block
- For AP18: check for duplicate `it(` descriptions or duplicate test numbering (e.g., two `#1.1`)
- NestJS specific: check for `spyOn(service, service.ownMethod)` self-mock pattern -> likely AP10
- NestJS specific: count providers in TestingModule -- 10+ is a red flag for quality
- SmartMock/Proxy pattern: if tests use `as Record<string, jest.Mock>` or Proxy-based mock factories, Q5=0 is correct (no type safety) but note this is a deliberate trade-off vs boilerplate. Recommend typed accessor helper (e.g., `mockMethod(service, 'findOne')`) rather than full typed mocks.
- SUITE-AWARE MODE: If you see sibling test files for same production file (e.g., `foo.test.ts`, `foo.errors.test.ts`, `foo.edge-cases.test.ts`), evaluate Q7/Q11 at suite level -- error paths in `foo.errors.test.ts` satisfy Q7 for the suite group. Report as: "Suite group: [files] -- Q7 covered by [file]".

Files to audit:
[LIST OF FILES FOR THIS BATCH]
```

---

## Step 4: Aggregate Results

Collect all agent results. Build summary table:

```markdown
# Test Quality Audit Report

Date: [date]
Project: [name]
Files audited: [N]
Total tests: [count from test runner]

## Summary by Tier

| Tier | Count | % | Action |
|------|-------|---|--------|
| A (>=14) | [N] | [%] | No action needed |
| B (9-13) | [N] | [%] | Fix targeted gaps |
| C (5-8) | [N] | [%] | Major rewrite |
| D (<5 or red flag) | [N] | [%] | Delete + rewrite |
| ORPHAN | [N] | [%] | Verify or delete |

## Critical Gate Failures

Files where Q7/Q11/Q13/Q15/Q17 = 0 (highest priority):

| File | Score | Failed Qs | Top Gap |
|------|-------|-----------|---------|

## Red Flag Summary (Auto Tier-D)

| File | Red Flag | Details |
|------|----------|---------|

## Untested Public Methods

| File | Untested Methods | Impact |
|------|-----------------|--------|

## Top Failed Questions (across all files)

| Question | Fail count | % of files | Notes |
|----------|-----------|------------|-------|
| Q[N] | [count] | [%] | [pattern observed] |

## Top Critical Gate Failures

| Question | Fail count | Files |
|----------|-----------|-------|
| Q7 | [N] | [list] |
| Q11 | [N] | [list] |
| Q13 | [N] | [list] |
| Q15 | [N] | [list] |
| Q17 | [N] | [list] |

## Anti-pattern Hot Spots

| Anti-pattern | Files affected | Total instances |
|-------------|---------------|-----------------|

## Tier D -- Rewrite Queue (worst first)

| File | Score | Why rewrite |
|------|-------|-------------|

## Tier C -- Major Fix Queue

| File | Score | Top 3 gaps |
|------|-------|------------|

## Tier B -- Targeted Fix Queue

| File | Score | Gaps to fix |
|------|-------|-------------|

## Tier A -- No Action

| File | Score |
|------|-------|
```

## Step 5: Save Report

Save to: `audits/test-quality-audit-[date].md`

If `--deep` mode: also save per-file reports to `audits/test-audit-details/[filename].md`

## Step 5.5: Backlog Persistence (MANDATORY)

After generating the report, persist ALL findings to `memory/backlog.md`:

1. **Read** the project's `memory/backlog.md` (from the auto memory directory shown in system prompt)
2. **If file doesn't exist**: create it with this template:
   ```markdown
   # Tech Debt Backlog
   | ID | File | Issue | Severity | Source | Status | Seen | Dates |
   |----|------|-------|----------|--------|--------|------|-------|
   ```
3. For each Tier C/D file:
   - **Fingerprint:** `file|Q/AP-id|signature` (e.g., `user.test.ts|Q7|no-error-path-test`). Search backlog for matching fingerprint.
   - **Duplicate** (same fingerprint found): increment `Seen` count, add date, keep highest severity
   - **New** (no match): append with next `B-{N}` ID, source: `test-audit/{date}`, status: OPEN
   - Include: top 3 gaps, critical gate failures, untested methods
4. For Tier B files with critical gate failures (Q7/Q11/Q13/Q15/Q17=0):
   - Persist each critical gate failure as separate backlog item (fingerprint: `file|Q-id|gate-fail`)
5. **Auto Tier-D red flags** (AP13/AP14/AP16): always persist as HIGH (fingerprint: `file|AP-id|red-flag`)

**THIS IS REQUIRED, NOT OPTIONAL.** Findings that aren't fixed must be tracked. Zero issues may be silently discarded.

## Step 6: Post-Audit Fix Workflow

After presenting the report, the user may request fixes. Follow this sequence:

1. **Fix** -- user says "napraw X" or "fix tier D files" -> rewrite test files following `~/.codex/test-patterns.md`
2. **Test** -- run test suite (`npm run test:run` or equivalent) to confirm all tests pass
3. **Execute Verification Checklist** -- after tests pass, verify ALL of these. Print each with [x]/[ ]:

```
EXECUTE VERIFICATION
------------------------------------
[x]/[ ]  SCOPE: Only test files from the audit report modified (no production code changes)
[x]/[ ]  SCOPE: No new tests added beyond what the fix requires (no "bonus" tests)
[x]/[ ]  TESTS PASS: Full test suite green (not just fixed files)
[x]/[ ]  FILE LIMITS: All modified/created test files <= 400 lines
[x]/[ ]  Q1-Q17: Self-eval on each fixed/rewritten test file (individual scores + critical gate)
[x]/[ ]  TIER IMPROVEMENT: Fixed files now score higher tier than before (D->C+, C->B+, B->A)
[x]/[ ]  NO SCOPE CREEP: Only fixes from the audit applied, nothing extra
------------------------------------
```

**If ANY is [ ] -> fix before committing.** Common failures:
- Scope creep: adding tests for files not in the audit -> revert extra files
- Q1-Q17 not run: after rewriting test files, re-eval is mandatory
- No tier improvement: fix didn't address root cause -> revisit top gaps

4. **Commit** -- behavior depends on `--commit` flag:
   - `--commit=ask` (default): show staged diff, ask user before committing
   - `--commit=auto`: commit without asking (for CI/batch runs)
   - `--commit=off`: skip commit entirely
   - If committing:
     - `git add [specific test files]`
     - `git commit -m "test-fix: [brief description]"`
     - `git tag test-fix-[YYYY-MM-DD]-[short-slug]`
5. **Re-audit** -- optionally re-run `/test-audit` on fixed files to verify tier improvement

**Do NOT push.** Push is a separate user decision.

## Execution Notes

- Use Sonnet for `--quick` mode (binary checks -- Haiku inflates scores on nuanced checks like Q11, Q15, AP10)
- Use Sonnet for `--deep` mode (evidence + fix recommendations)
- Max 6 parallel agents for batch evaluation
- Each agent gets 8-10 files per batch
- Total time estimate: ~2 min for quick (50 files), ~10 min for deep (50 files)
- Always run the project's test suite first to confirm baseline passes. Auto-detect runner:
  - `vitest.config.*` or `vitest` in devDeps -> `npx vitest run`
  - `jest.config.*` or `jest` in devDeps -> `npx jest`
  - `pyproject.toml` with pytest -> `pytest`
  - `turbo.json` with test task -> `turbo run test`
  - Fallback: `npm run test` (check package.json scripts)
