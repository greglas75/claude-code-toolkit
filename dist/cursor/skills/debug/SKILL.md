---
name: debug
description: "Structured debugging session -- find and fix issues systematically. Use when investigating a bug, error, or unexpected behavior. Works with error messages, stack traces, code snippets, or descriptions. NOT for code quality issues (use /code-audit or /review)."
user-invocable: true
---

# /debug -- Structured Debugging

Turns a bug report or error into a root cause + fix using a four-phase framework.

## Parse $ARGUMENTS

| Input | Action |
|-------|--------|
| _(empty)_ | Ask: "What's the issue? Share the error, stack trace, or describe what's happening." |
| error message / stack trace | Start at Phase 1.5 (Minimal Repro) -- verify reproducibility before narrowing |
| code snippet | Start at Phase 3 (Diagnose) -- read the code, trace the path |
| "why does X…" / "X is broken" | Start at Phase 1 (Reproduce) -- gather more context |

---

## Framework: 5 Phases

```
Phase 1:   REPRODUCE    -> understand expected vs. actual behavior
Phase 1.5: MINIMAL REPRO -> verify stack trace is reproducible (skip if from Phase 1)
Phase 2:   NARROW       -> baseline check + find exact failure point
Phase 3:   DIAGNOSE     -> trace the code path, form + test hypotheses
Phase 4:   FIX + VERIFY -> implement fix, run tests, write regression test, confirm green
```

---

## Phase 1: Reproduce

Establish a clear, reproducible failure description. Ask if not provided:

- **Expected behavior:** what should happen?
- **Actual behavior:** what happens instead?
- **Steps to reproduce:** exact sequence
- **Scope:** always or intermittent? all users or some? all environments or specific?
- **When it started:** recent deploy, config change, dependency update?

If reproduction is inconsistent (flaky) -> flag as potential race condition, environment-specific config, or test order dependency.

## Phase 1.5: Minimal Repro (when starting from stack trace)

A stack trace proves an error occurred -- it does NOT prove you can reproduce it now. Before narrowing:

1. **Run the failing test/endpoint** -- can you trigger the same error?
2. **If YES** -> proceed to Phase 2 with confirmed reproduction
3. **If NO** -> the trace may be from a different state (stale data, config, deploy). Treat as Phase 1: gather expected vs actual, steps, scope.
4. **If INTERMITTENT** -> run 3× to confirm flakiness, then proceed with flaky flag

Skip this phase only when the reproduction is self-evident (e.g., type error visible in code, compilation failure).

## Phase 2: Narrow

### 2.0: Baseline Check (pre-existing vs introduced)

Before diving in, establish whether this is a new regression or a pre-existing issue:

1. **Run existing tests** for the affected area -> were they already failing?
2. **Check recent commits** -- `git log --oneline -10 -- [affected-files]`
3. **If regression suspected** -- `git log --oneline --since="[when it broke]"` to narrow the introducing commit
4. **Tag baseline state** -- note which tests pass/fail NOW, before you change anything

Output:
```
BASELINE: [N] tests passing, [M] failing in affected area
REGRESSION: YES (commit [hash]) / NO (pre-existing) / UNKNOWN
```

### 2.1: Reduce the search space

Work through in order:

1. **Error message / stack trace** -- read the full trace, not just the last line. The root error is usually earlier in the chain.
2. **Logs around the time of failure** -- what happened just before the error?
3. **Recent changes** -- commits, deploys, dependency updates, config changes in the relevant timeframe
4. **Environment comparison** -- works in dev, fails in prod? Works for some users? -> find the diff
5. **Binary search** -- if the code path is long, identify the midpoint and test if the bug is before or after it

## Phase 3: Diagnose

Trace the code path from input to failure:

1. **Entry point** -- where does the triggering action enter the system?
2. **Trace forward** -- follow the data through each function/service until the point of failure
3. **Form hypotheses** -- list 2-3 possible root causes, ordered by likelihood
4. **Test hypotheses** -- for each: what evidence would confirm or rule it out?
5. **Root cause** -- identify the specific line/condition/assumption that fails. Distinguish root cause from symptoms.

Common root causes by error type:

| Error Type | Most Likely Causes |
|------------|-------------------|
| `undefined` / `null` | Missing null guard, wrong key, async timing |
| Wrong value | Off-by-one, unit mismatch, stale cache |
| Permission denied | Auth context not set, RBAC misconfigured |
| Timeout | N+1 query, missing index, unbounded loop |
| Flaky failure | Race condition, global state, test order dep |
| Works in dev, fails in prod | Env var missing, prod data edge case, timezone |

### Debug Profiles (stack-specific playbooks)

Choose the profile matching the bug area -- each has a focused diagnostic sequence:

**API / Backend:**
1. Reproduce with `curl` / test runner against the endpoint
2. Check request validation -- does the schema reject it or let bad data through?
3. Check auth context -- is the user/token/session correct at point of failure?
4. Check DB query -- does the query return expected data? Add `EXPLAIN` for slow queries
5. Check error handling -- does the catch block swallow, transform, or propagate correctly?

**Frontend / UI:**
1. Open browser DevTools -> Console (errors), Network (failed requests), React DevTools (component state)
2. Check if the data from API is correct -- if yes, bug is in rendering/state management
3. Check component props flow -- is the data reaching the failing component?
4. Check event handlers -- is the user action triggering the expected dispatch/callback?
5. Check hydration -- does the server-rendered HTML match client expectations? (SSR bugs)

**DB / Performance:**
1. Identify the slow/failing query -- check query logs or ORM debug mode
2. Run `EXPLAIN ANALYZE` on the query -- missing index? full table scan? cartesian join?
3. Check for N+1 -- is the same query executed in a loop?
4. Check connection pool -- are connections exhausted? timeouts?
5. Check data volume -- did the dataset grow beyond what the query handles efficiently?

**Async / Flaky:**
1. Run the failing test 5× -- consistent or intermittent?
2. Check for shared mutable state -- global variables, singletons, DB state between tests
3. Check timing assumptions -- `setTimeout`, `sleep`, `waitFor` with inadequate duration
4. Check execution order -- does the test depend on another test running first?
5. Check resource cleanup -- are ports, connections, file handles properly released?

## Phase 4: Fix + Verify

### 4.1: Implement the fix

1. **Apply the fix** -- edit the specific file(s). Be minimal: fix the root cause only.
2. **Explain why** -- connect the fix to the root cause (comment in code if non-obvious)
3. **Check side effects** -- does the fix break other paths? does it change behavior for other callers?
4. **Edge cases** -- does the fix hold for null, empty, concurrent, high-load scenarios?

### 4.2: Run targeted tests

Run only the tests for the affected area:
```bash
[test-runner] [affected-test-files]
```
- If failing -> fix is incomplete or introduced a new issue. Iterate.
- If passing -> proceed.

### 4.3: Run full suite

```bash
[test-runner]
```
- Compare with Phase 2.0 baseline: no NEW failures should appear.
- If new failures -> the fix has side effects. Investigate before proceeding.

### 4.4: Confirm original reproduction is resolved

Re-run the exact reproduction from Phase 1 / Phase 1.5:
- If the bug still occurs -> root cause was wrong. Return to Phase 3.
- If fixed -> proceed.

### 4.5: Write regression test

Write a test that:
1. Reproduces the exact bug condition
2. Asserts it no longer occurs
3. Would have caught this bug if it existed before

Run Q1-Q17 self-eval (from `~/.cursor/rules/testing.md`) on the regression test. Critical gates must pass.

### 4.6: CQ self-eval (if production code changed)

Run CQ1-CQ20 (from `~/.cursor/rules/code-quality.md`) on each modified production file. Critical gates must pass.

---

## Output Format

```markdown
## Debug Report: [issue summary]

### Reproduction
- **Expected:** [what should happen]
- **Actual:** [what happens instead]
- **Steps:** [how to reproduce]
- **Scope:** [always / intermittent / specific conditions]
- **Baseline:** [N] tests passing, [M] failing before fix

### Diagnosis (Hypothesis -> Evidence -> Verdict)

| # | Hypothesis | Evidence | Verdict |
|---|-----------|----------|---------|
| 1 | [most likely cause] | [what you found: file:line, log output, test result] | CONFIRMED / RULED OUT |
| 2 | [alternative cause] | [evidence] | CONFIRMED / RULED OUT |

**Confidence:** HIGH / MEDIUM / LOW -- [why]

### Root Cause
[1-3 sentences explaining WHY the bug occurs -- not just where]
File: [file:line]

### Fix Applied
```[language]
// Before:
[broken code]

// After:
[fixed code]
```

### Verification
- Targeted tests: [x] PASS ([N] tests)
- Full suite: [x] PASS (no new failures vs baseline)
- Original reproduction: [x] RESOLVED
- CQ self-eval: [score]/20 -> [PASS/CONDITIONAL PASS]
- Regression test: Q self-eval [score]/17 -> [PASS]

### Side Effects
[Any other paths affected, or "None -- change is isolated to X"]

### Regression Test
```[language]
it('should [describe the bug scenario] -- [ticket ref if known]', () => {
  // Reproduce the bug condition
  // Assert it no longer occurs
});
```
```

---

## Prioritization When Multiple Issues Found

If debugging reveals multiple problems, surface them all but focus the fix on the root cause:

1. **Root cause** -- fix this first
2. **Contributing factors** -- note these but don't fix speculatively
3. **Unrelated issues spotted** -- MANDATORY: add to `memory/backlog.md`, don't fix now

---

## Completion

After Phase 4 verification passes:

```
DEBUG COMPLETE
------------------------------
Issue: [summary]
Root cause: [1-line explanation]
Files fixed: [list]
Regression test: [test-file]
Verification: targeted PASS | full suite PASS | repro RESOLVED
Confidence: HIGH / MEDIUM / LOW
Backlog: [N items added | "none"]

Next steps:
  /review [fixed-files]  -> verify fix quality
  git commit -m "fix: [issue summary]"
------------------------------
```

---

## Tips for Better Input

- **Share the full stack trace**, not just the last line -- the root error is usually deeper
- **"This used to work"** -> what changed? deploy, config, data, dependency?
- **"Only in prod"** -> likely env var, data edge case, or scale-dependent issue
- **"Random/flaky"** -> likely race condition, shared state, or test order dependency
