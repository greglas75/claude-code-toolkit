---
name: test-audit
description: "Audit all test files against Q1-Q15 checklist + anti-patterns. Produces tiered report with scores, gaps, and fix recommendations. Use: /test-audit [path] or /test-audit all"
disable-model-invocation: true
---

# /test-audit — Test Quality Triage

Mass audit of test files against the Q1-Q15 binary checklist + AP anti-patterns.
Produces a tiered report: which files are fine, which need fixes, which need rewrites.

**IMPORTANT:** Before starting, read:
```
Read ~/.claude/test-patterns.md    — Q1-Q15 checklist, anti-patterns AP1-AP12, stack adjustments
```

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
find . -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" -o -name "*.spec.tsx" | grep -v node_modules | grep -v .next | sort
```

Count total. If >50 files, use `--quick` mode automatically (skip evidence gathering).

## Step 2: Pair with Production Files

For each test file, identify the production file it tests:
- `__tests__/api/projects/[id]/route.test.ts` → `app/api/projects/[id]/route.ts`
- `__tests__/components/Foo.test.tsx` → `components/Foo.tsx`
- `tests/unit/services/bar.test.ts` → `lib/services/bar.ts` (or similar)

If production file not found → flag as ORPHAN (test without source).

## Step 3: Parallel Evaluation

Split files into batches of 8-10. For each batch, spawn a Task agent (subagent_type: "general-purpose") with this prompt:

---

### AGENT PROMPT (copy this for each batch):

```
You are a test quality auditor. For each test file below, evaluate against the Q1-Q15 binary checklist.

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

CRITICAL GATE: Q7, Q11, Q13, Q15 — any = 0 → capped at FIX regardless of total.

FOR EACH FILE, output this exact format:
```
### [filename]
Production file: [path or ORPHAN]
Score: Q1=[0/1] Q2=[0/1] Q3=[0/1] Q4=[0/1] Q5=[0/1] Q6=[0/1] Q7=[0/1] Q8=[0/1] Q9=[0/1] Q10=[0/1] Q11=[0/1] Q12=[0/1] Q13=[0/1] Q14=[0/1] Q15=[0/1]
Anti-patterns: [AP IDs found, or "none"]
Total: [N]/15 - [AP count] = [final]
Critical gate: Q7=[0/1] Q11=[0/1] Q13=[0/1] Q15=[0/1] → [PASS/FAIL]
Tier: [A/B/C/D]
Top 3 gaps: [brief description of worst 3 issues]
```

TIER CLASSIFICATION:
  A (≥12, critical gate PASS): Leave alone — good ROI on other files
  B (8-11, or critical gate FAIL with score ≥8): Fix gaps — 2-5 targeted fixes
  C (5-7): Major rewrite needed — significant gaps
  D (<5 or tautological): Delete and rewrite from scratch

IMPORTANT:
- You MUST read both the test file AND its production file
- For Q11 (branches): scan production file for if/else/switch/ternary, check if test covers both sides
- For Q13: verify import actually points to production code, not a local mock/copy
- For Q10: look for hardcoded numbers (100, 50, "test-id") without named constants
- For AP10: if test only calls mocks and verifies mocks without any production function in between → tautological

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
| A (≥12) | [N] | [%] | No action needed |
| B (8-11) | [N] | [%] | Fix targeted gaps |
| C (5-7) | [N] | [%] | Major rewrite |
| D (<5) | [N] | [%] | Delete + rewrite |
| ORPHAN | [N] | [%] | Verify or delete |

## Critical Gate Failures

Files where Q7/Q11/Q13/Q15 = 0 (highest priority):

| File | Score | Failed Qs | Top Gap |
|------|-------|-----------|---------|

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
