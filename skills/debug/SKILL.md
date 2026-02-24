---
name: debug
description: "Structured debugging session — find and fix issues systematically. Use when investigating a bug, error, or unexpected behavior. Works with error messages, stack traces, code snippets, or descriptions."
user-invocable: true
---

# /debug — Structured Debugging

Turns a bug report or error into a root cause + fix using a four-phase framework.

## Parse $ARGUMENTS

| Input | Action |
|-------|--------|
| _(empty)_ | Ask: "What's the issue? Share the error, stack trace, or describe what's happening." |
| error message / stack trace | Start at Phase 2 (Narrow) — reproduction already known |
| code snippet | Start at Phase 3 (Diagnose) — read the code, trace the path |
| "why does X…" / "X is broken" | Start at Phase 1 (Reproduce) — gather more context |

---

## Framework: 4 Phases

```
Phase 1: REPRODUCE   → understand expected vs. actual behavior
Phase 2: NARROW      → find exact failure point (logs, scope, recent changes)
Phase 3: DIAGNOSE    → trace the code path, form + test hypotheses
Phase 4: FIX         → propose fix, check side effects, add regression test
```

---

## Phase 1: Reproduce

Establish a clear, reproducible failure description. Ask if not provided:

- **Expected behavior:** what should happen?
- **Actual behavior:** what happens instead?
- **Steps to reproduce:** exact sequence
- **Scope:** always or intermittent? all users or some? all environments or specific?
- **When it started:** recent deploy, config change, dependency update?

If reproduction is inconsistent (flaky) → flag as potential race condition, environment-specific config, or test order dependency.

## Phase 2: Narrow

Reduce the search space. Work through in order:

1. **Error message / stack trace** — read the full trace, not just the last line. The root error is usually earlier in the chain.
2. **Logs around the time of failure** — what happened just before the error?
3. **Recent changes** — commits, deploys, dependency updates, config changes in the relevant timeframe
4. **Environment comparison** — works in dev, fails in prod? Works for some users? → find the diff
5. **Binary search** — if the code path is long, identify the midpoint and test if the bug is before or after it

## Phase 3: Diagnose

Trace the code path from input to failure:

1. **Entry point** — where does the triggering action enter the system?
2. **Trace forward** — follow the data through each function/service until the point of failure
3. **Form hypotheses** — list 2-3 possible root causes, ordered by likelihood
4. **Test hypotheses** — for each: what evidence would confirm or rule it out?
5. **Root cause** — identify the specific line/condition/assumption that fails. Distinguish root cause from symptoms.

Common root causes by error type:

| Error Type | Most Likely Causes |
|------------|-------------------|
| `undefined` / `null` | Missing null guard, wrong key, async timing |
| Wrong value | Off-by-one, unit mismatch, stale cache |
| Permission denied | Auth context not set, RBAC misconfigured |
| Timeout | N+1 query, missing index, unbounded loop |
| Flaky failure | Race condition, global state, test order dep |
| Works in dev, fails in prod | Env var missing, prod data edge case, timezone |

## Phase 4: Fix

1. **Propose the fix** — be specific: which file, which line, what change
2. **Explain why** — connect the fix to the root cause
3. **Check side effects** — does the fix break other paths? does it change behavior for other callers?
4. **Edge cases** — does the fix hold for null, empty, concurrent, high-load scenarios?
5. **Regression test** — suggest a specific test that would have caught this bug (and will prevent recurrence)

---

## Output Format

```markdown
## Debug Report: [issue summary]

### Reproduction
- **Expected:** [what should happen]
- **Actual:** [what happens instead]
- **Steps:** [how to reproduce]
- **Scope:** [always / intermittent / specific conditions]

### Root Cause
[1-3 sentences explaining WHY the bug occurs — not just where]

### Fix
[Specific code change with file + line reference]

```[language]
// Before:
[broken code]

// After:
[fixed code]
```

### Side Effects
[Any other paths affected, or "None — change is isolated to X"]

### Regression Test
```[language]
it('should [describe the bug scenario] — [ticket ref if known]', () => {
  // Reproduce the bug condition
  // Assert it no longer occurs
});
```
```

---

## Prioritization When Multiple Issues Found

If debugging reveals multiple problems, surface them all but focus the fix on the root cause:

1. **Root cause** — fix this first
2. **Contributing factors** — note these but don't fix speculatively
3. **Unrelated issues spotted** — add to `/backlog` with `/backlog add`, don't fix now

---

## Tips for Better Input

- **Share the full stack trace**, not just the last line — the root error is usually deeper
- **"This used to work"** → what changed? deploy, config, data, dependency?
- **"Only in prod"** → likely env var, data edge case, or scale-dependent issue
- **"Random/flaky"** → likely race condition, shared state, or test order dependency
