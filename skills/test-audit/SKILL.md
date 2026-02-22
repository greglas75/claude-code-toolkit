---
name: test-audit
description: "Audit all test files against Q1-Q17 checklist + AP1-AP18 anti-patterns. Produces tiered report with scores, gaps, and fix recommendations. Use: /test-audit [path] or /test-audit all"
disable-model-invocation: true
---

# /test-audit — Test Quality Triage

Mass audit of test files against the Q1-Q17 binary checklist + AP anti-patterns.
Produces a tiered report: which files are fine, which need fixes, which need rewrites.

**IMPORTANT:** Before starting, read:
```
Read ~/.claude/test-patterns.md    — Q1-Q17 checklist, anti-patterns AP1-AP18, stack adjustments, red flags
```

## Progress Tracking

Use `TaskCreate` at the start to create a todo list from the steps below. Update task status (`in_progress` → `completed`) as you progress. This gives the user visibility into multi-step execution.

## Multi-Agent Compatibility

This skill uses `Task` tool to spawn parallel sub-agents for batch evaluation. **If `Task` tool is not available** (Cursor, Antigravity, other IDEs):
- **Skip all "Spawn via Task tool" blocks** — do NOT attempt to call tools that don't exist
- **Evaluate files sequentially yourself** instead of spawning batch agents — read each test file, apply Q1-Q17 checklist, output per-file scores
- **Model routing is ignored** — use whatever model you are running on
- The quality gates, checklists, and output format remain identical

## Step 0: Parse $ARGUMENTS

| Argument | Behavior |
|----------|----------|
| `all` | Audit ALL test files in the project |
| `[path]` | Audit test files in specific directory |
| `[file]` | Audit single test file (deep mode) |
| `--deep` | Include per-file fix recommendations (slower) |
| `--quick` | Binary checklist only, skip evidence (faster) |

Default: `all --quick`

## Step 1: Discover Test Files

Find all test files:
```bash
find . \( -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" -o -name "*.spec.tsx" -o -name "test_*.py" -o -name "*_test.py" \) ! -path "*/node_modules/*" ! -path "*/.next/*" ! -path "*/__pycache__/*" ! -path "*/e2e/*" | sort
```

Count total. If >50 files, use `--quick` mode automatically (skip evidence gathering).

## Step 2: Pair with Production Files

For each test file, identify the production file it tests:
- `__tests__/api/projects/[id]/route.test.ts` → `app/api/projects/[id]/route.ts`
- `__tests__/components/Foo.test.tsx` → `components/Foo.tsx`
- `tests/unit/services/bar.test.ts` → `lib/services/bar.ts` (or similar)

If production file not found → flag as ORPHAN (test without source).

## Step 2.5: Golden File Calibration (optional, recommended for first audit)

If this is the first audit of a project, or agent scores seem inconsistent:
1. Pick 2-3 test files with **known scores** (one good ~14+, one bad ~5, one mid ~9)
2. Run a single calibration agent on just those files
3. Compare agent scores to known scores — if drift >2 points, adjust agent prompt wording
4. Once calibrated, proceed with full batch evaluation

This prevents systematic over/under-scoring across the entire audit.

## Step 3: Parallel Evaluation

Split files into batches of 8-10. For each batch, spawn a Task agent (subagent_type: "general-purpose") with this prompt:

---

### AGENT PROMPT (copy this for each batch):

```
You are a test quality auditor. For each test file below, evaluate against the Q1-Q17 binary checklist.

STEP 0 — RED FLAG PRE-SCAN (do this FIRST, before full evaluation):
Count these in the test file. If any trigger → auto Tier-D, skip full checklist:
- Tests with zero `expect()` calls (AP13) → AUTO TIER-D
- Fixture:assertion ratio > 20:1 (AP16) → AUTO TIER-D
- 50%+ of tests use `toBeTruthy()`/`toBeDefined()` as sole assertion (AP14) → AUTO TIER-D

QUICK HEURISTICS (not Tier-D triggers, but predict score):
- 0 CalledWith in entire file → likely score ≤4
- 10+ DI providers in test setup → likely score ≤5
- Tests calling __privateMethod() directly → likely score ≤5
- Factory functions with overrides present → likely score ≥8

CHECKLIST (score 1=YES, 0=NO for each):
Q1:  Every test name describes expected behavior (not "should work")?
Q2:  Tests grouped in logical describe blocks?
Q3:  Every mock has CalledWith + not.toHaveBeenCalled?
Q4:  Assertions use exact matchers (toEqual/toBe, not toBeTruthy)?
Q5:  Mocks are typed (no `as any`/`as never`)?
Q6:  Mock state fresh per test (beforeEach, no shared mutable)?
Q7:  CRITICAL — At least one error path test (throws/rejects)?
Q8:  Null/empty/edge inputs tested?
Q9:  Repeated setup (3+ tests) extracted to helper/factory?
Q10: No magic values — test data is self-documenting?
Q11: CRITICAL — All code branches exercised?
Q12: Symmetric: "does X when Y" has "does NOT do X when not-Y"?
Q13: CRITICAL — Tests import actual production function?
Q14: Behavioral assertions (not just mock-was-called)?
Q15: CRITICAL — Content/values assertions, not just counts/shape?
Q16: Cross-cutting isolation: change to A verified not to affect B?
Q17: CRITICAL — Assertions verify COMPUTED output, not input echo?

ANTI-PATTERNS (each found = -1 point):
AP1:  try/catch in test swallowing errors
AP2:  Conditional assertions (if/else in test)
AP3:  Re-implementing production logic in test
AP4:  Snapshot as only test for component
AP5:  `as any` → `as never` (both bypass types)
AP6:  Testing CSS classes instead of behavior
AP7:  `.catch(() => {})` swallowing errors
AP8:  document.querySelector bypassing Testing Library
AP9:  Always-true assertion (expect(true).toBe(true))
AP10: Tautological mock (call mock → verify mock called, no production code)
AP11: vi.mocked(vi.fn()) — mock targeting fresh fn
AP12: waitForTimeout(N) hardcoded delays
AP13: Test with zero expect() calls — AUTO TIER-D
AP14: toBeTruthy()/toBeDefined() as SOLE assertion on complex object
AP15: Testing private methods directly (controller.__method()) — avg 3.0/10
AP16: Fixture:assertion ratio > 20:1 — AUTO TIER-D
AP17: Unused test data declared but never used in any test
AP18: Duplicate test numbers/names (copy-paste indicator)

N/A HANDLING: Q3/Q5/Q6 score as 1 (N/A) for pure functions with zero mocks. Q16 scores as 1 (N/A) for simple single-responsibility units.
Q17 AUDIT RULE: If ≥50% of assertions check values that are direct copies of input/request/mock-return without transformation → Q17=0.

CRITICAL GATE: Q7, Q11, Q13, Q15, Q17 — any = 0 → capped at Tier B (Fix) regardless of total.

FOR EACH FILE, output this exact format:
```
### [filename]
Production file: [path or ORPHAN]
Red flags: [AP13/AP14/AP16 = auto Tier-D; AP15 = warning only; or "none"] → [AUTO TIER-D or "continue"]
Untested methods: [list of public methods in production file with no test coverage, or "all covered"]
Score: Q1=[0/1] Q2=[0/1] Q3=[0/1/N/A] Q4=[0/1] Q5=[0/1/N/A] Q6=[0/1/N/A] Q7=[0/1] Q8=[0/1] Q9=[0/1] Q10=[0/1] Q11=[0/1] Q12=[0/1] Q13=[0/1] Q14=[0/1] Q15=[0/1] Q16=[0/1/N/A] Q17=[0/1]
Anti-patterns: [AP IDs found, or "none"]
Applicable: [N]/17 | Raw: [yes-count]/[applicable] | Normalized: [score]/17
Total (after AP): [normalized] - [AP count] = [final]
Critical gate: Q7=[0/1] Q11=[0/1] Q13=[0/1] Q15=[0/1] Q17=[0/1] → [PASS/FAIL]
Tier: [A/B/C/D]
Top 3 gaps: [brief description of worst 3 issues]
```

TIER CLASSIFICATION:
  A (≥14, critical gate PASS): Leave alone — good ROI on other files
  B (9-13, or critical gate FAIL with score ≥9): Fix gaps — 2-5 targeted fixes
  C (5-8): Major rewrite needed — significant gaps
  D (<5 or tautological or AUTO TIER-D red flag): Delete and rewrite from scratch

IMPORTANT:
- You MUST read both the test file AND its production file
- Do RED FLAG PRE-SCAN first. If any auto Tier-D trigger found, report it and skip full checklist.
- COVERAGE COMPLETENESS: List all public methods/exported functions in the production file. For each, check if the test file has at least one `it()` block that exercises it. Flag any untested public method as: "UNTESTED: [method_name]() — no test coverage". Report untested methods in "Top 3 gaps" section. This is separate from Q11 (which checks branches within tested code).
- For Q11 (branches): scan production file for if/else/switch/ternary, check if test covers both sides
- For Q13: verify import actually points to production code, not a local mock/copy
- For Q10: look for hardcoded numbers (100, 50, "test-id") without named constants
- For Q16 (isolation): look for tests that modify one entity and verify another entity is unchanged
- For Q17 (computed): compare assertion values against test input — if result.X === input.X, that's input echo (score 0)
- For AP10: if test only calls mocks and verifies mocks without any production function in between → tautological
- For AP13: count `it(` blocks and `expect(` calls — if any `it` block has 0 expects → AP13. **RTL exception:** `getByRole`/`getByText`/`getByLabelText` are implicit assertions — a test with only `getBy*` queries is NOT AP13.
- For AP15: check if test calls methods with `__` or `_` prefix (private/internal methods)
- For AP16: count lines of fixture data vs lines containing `expect(` — ratio > 20:1 → AP16
- For AP17: search for `const .*= {` or `const .*= [` declarations that are never referenced in any `it()` block
- For AP18: check for duplicate `it(` descriptions or duplicate test numbering (e.g., two `#1.1`)
- NestJS specific: check for `spyOn(service, service.ownMethod)` self-mock pattern → likely AP10
- NestJS specific: count providers in TestingModule — 10+ is a red flag for quality
- SmartMock/Proxy pattern: if tests use `as Record<string, jest.Mock>` or Proxy-based mock factories, Q5=0 is correct (no type safety) but note this is a deliberate trade-off vs boilerplate. Recommend typed accessor helper (e.g., `mockMethod(service, 'findOne')`) rather than full typed mocks.
- N/A normalization math: if 3 Qs are N/A → applicable=14. If raw yes=12 → normalized = (12/14)*17 = 14.6/17. Use normalized for tier classification.
- SUITE-AWARE MODE: If you see sibling test files for same production file (e.g., `foo.test.ts`, `foo.errors.test.ts`, `foo.edge-cases.test.ts`), evaluate Q7/Q11 at suite level — error paths in `foo.errors.test.ts` satisfy Q7 for the suite group. Report as: "Suite group: [files] — Q7 covered by [file]".

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
| A (≥14) | [N] | [%] | No action needed |
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

## Tier D — Rewrite Queue (worst first)

| File | Score | Why rewrite |
|------|-------|-------------|

## Tier C — Major Fix Queue

| File | Score | Top 3 gaps |
|------|-------|------------|

## Tier B — Targeted Fix Queue

| File | Score | Gaps to fix |
|------|-------|-------------|

## Tier A — No Action

| File | Score |
|------|-------|
```

## Step 5: Save Report

Save to: `audits/test-quality-audit-[date].md`

If `--deep` mode: also save per-file reports to `audits/test-audit-details/[filename].md`

## Execution Notes

- Use Sonnet for `--quick` mode (binary checks — Haiku inflates scores on nuanced checks like Q11, Q15, AP10)
- Use Sonnet for `--deep` mode (evidence + fix recommendations)
- Max 6 parallel agents for batch evaluation
- Each agent gets 8-10 files per batch
- Total time estimate: ~2 min for quick (50 files), ~10 min for deep (50 files)
- Always run `npm run test:run` first to confirm baseline passes
