# Testing Rules (All Projects)

Mandatory testing requirements. Applies regardless of stack -- Jest, Vitest, pytest, Playwright.

---

## Iron Rule: Every New Code Must Have Tests

No exceptions. No "I'll add tests later." No commits without test coverage for new code.

## Plan Mode -- Test Strategy Required

When using EnterPlanMode / ExitPlanMode, the plan MUST include a **Test Strategy** section:

1. **Code types** being added/changed (Step 1 classification)
2. **Key patterns** to apply (G-/P- IDs from Step 2 lookup)
3. **Test files** to create/modify (paths + scope)
4. **Critical scenarios** (error paths, edge cases, infra failures)
5. **Self-eval target**: minimum 14/17

A plan without Test Strategy is incomplete -- do not approve it.

## Test Requirements by Code Type

### New Function/Utility
- Unit test: happy path
- Unit test: error cases
- Unit test: edge cases (null, undefined, empty, boundary values)

### New React Component
- Render test (mounts without error)
- **User flow tests (NOT just rendering)** -- for each interactive element, test the FULL flow: user action -> state change -> callback/API called with correct args -> success/error feedback. "Button visible" is NOT a flow test. See P-39 in `~/.cursor/test-patterns.md` for per-component-type minimum flows (form submit, search filter, modal confirm, etc.)
- Props/state variation tests
- Error state test
- Accessibility: interactive elements have ARIA labels, keyboard navigation works (see `react-nextjs.md` WCAG 2.1 AA)
- **Gate: flow tests must be >= 30% of total tests.** If all tests are `toBeInTheDocument()` checks -> FAIL. A rendering-only test suite provides zero regression safety.

### New API Endpoint/Handler
- Success response (200/201)
- Error responses (400, 401, 403, 404, 500)
- Input validation (invalid/missing fields)
- Auth/authorization check

### New Hook
- Behavior test (returns expected values)
- State change test (updates correctly)
- Side effect test (API calls, timers)

### New API Endpoint -- Mandatory Security Tests

Every backend endpoint MUST include these tests (in addition to functional tests above):

| # | Test | Expected |
|---|------|----------|
| S1 | Invalid schema (missing/bad fields) | 400 + Zod/validation error |
| S2 | Auth missing (no token/cookie) | 401 |
| S3 | Auth forbidden (wrong role) | 403 + `service.not.toHaveBeenCalled()` |
| S4 | Tenant isolation (different orgId/ownerId) | 403 + `service.not.toHaveBeenCalled()` + no data leak |
| S5 | Rate limit on auth endpoints | 429 after threshold |
| S6 | XSS in HTML render paths (if applicable) | Sanitized output |
| S7 | Path/ID traversal (if file/resource access) | 400 or 403 |

Skip S5-S7 if not applicable to the endpoint. S1-S4 are always required.

## Test Requirements by Change Intent

| Intent | Required Tests |
|--------|---------------|
| BUGFIX | 1 regression test (reproduces bug) + 1 happy path |
| FEATURE | Unit for edges + error cases, 1 integration |
| REFACTOR | Existing tests must still pass (before = after) |
| INFRA | Smoke test + config validation |

## Testing Trophy (Coverage Targets)

```
     /\       E2E Tests (5-10%) -- critical user flows only
    /  \
   /____\     Integration Tests (30%) -- component interactions
  /      \
 /________\   Unit Tests (60%) -- utils, hooks, business logic
```

## Test File Rules

### Naming
```
ComponentName.test.tsx         # React components (Jest/Vitest)
function-name.test.ts          # TypeScript functions
test_function_name.py          # Python functions (pytest)
feature-name.spec.ts           # Playwright E2E
```

### Placement
- Co-located: `Component.tsx` + `Component.test.tsx` (preferred)
- Or in `__tests__/` folder next to source

### Structure
- One describe block per function/component
- Clear test names: `it("should return empty array when no results found")`
- Arrange-Act-Assert pattern
- No test logic in describe blocks (only in it/test)

## What NOT to Do

- `it.todo()` / `it.skip()` / `describe.skip()` in required tests = BLOCKING
- Tests without assertions (just calling code = not a test)
- Mocking the unit under test (mock dependencies, not the thing being tested)
- Snapshot tests as the ONLY test for a component
- `jest -u` / blind snapshot updates without reviewing diffs
- Tests that depend on execution order

## Refactoring & Tests

1. **Before:** run existing tests (baseline must pass)
2. **During:** update tests with each code change
3. **After:** full suite must pass, coverage must not drop
4. If tests fail after refactoring: fix the code OR update tests -- never delete tests without replacement

## Self-Evaluation (MANDATORY after writing tests)

Run this checklist IMMEDIATELY after writing tests. Score EACH question individually -- never group.

**17 binary questions (1 = YES, 0 = NO):**

| # | Question |
|---|----------|
| Q1 | Every test name describes expected behavior (not "should work")? |
| Q2 | Tests grouped in logical describe blocks? |
| Q3 | Every mock has `CalledWith` (positive) AND `not.toHaveBeenCalled` (negative side-effects)? |
| Q4 | Assertions on known data are exact (`toEqual`/`toBe`, not `toBeTruthy`)? |
| Q5 | Mocks are typed (not `as any`/`as never`)? |
| Q6 | Mock state fresh per test (proper `beforeEach`, no shared mutable)? |
| Q7 | **CRITICAL** -- At least one error path test (throws/rejects/returns error)? |
| Q8 | Null/undefined/empty inputs tested where applicable? |
| Q9 | Repeated setup (3+ tests) extracted to helper/factory? |
| Q10 | No magic values -- test data is self-documenting? |
| Q11 | **CRITICAL** -- All code branches exercised (if/else, switch, early return)? |
| Q12 | Symmetric: every "does X when Y" has "does NOT do X when not-Y"? **Procedure: list ALL methods -> for each repeated pattern (auth guard, validation, error), verify EVERY method has it. One missing = 0.** |
| Q13 | **CRITICAL** -- Tests import actual production function (not local copy)? |
| Q14 | Assertions verify behavior, not just that a mock was called? |
| Q15 | **CRITICAL** -- Assertions verify content/values, not just counts/shape? |
| Q16 | Cross-cutting isolation: change to A verified not to affect B? |
| Q17 | **CRITICAL** -- Assertions verify COMPUTED output, not input echo? |

**N/A handling:** Q3/Q5/Q6 score as 1 (N/A) for pure functions with zero mocks. Q16 = 1 (N/A) for simple single-responsibility units.

**Critical gate:** Q7, Q11, Q13, Q15, Q17 -- any = 0 -> auto-capped at FIX regardless of total.

**Scoring:** Total = Q1-Q17 yes count (N/A=1) minus AP deductions (see `~/.cursor/test-patterns.md`). >= 14 PASS, 9-13 FIX (fix worst dimension, re-score), < 9 BLOCK (rewrite).

**Output format (individual scores required):**
```
Self-eval: Q1=1 Q2=1 Q3=0 Q4=1 Q5=1 Q6=1 Q7=1 Q8=0 Q9=1 Q10=1 Q11=1 Q12=0 Q13=1 Q14=1 Q15=1 Q16=1 Q17=1
  Score: 14/17 -> PASS | Critical gate: Q7=1 Q11=1 Q13=1 Q15=1 Q17=1 -> PASS
```

Full patterns (good patterns G-*, gap patterns P-*, stack adjustments): `~/.cursor/test-patterns.md`

## Before Finishing Any Task

- [ ] New code has tests
- [ ] Tests pass locally
- [ ] Self-eval score >= 14/17 (all Q scored individually, critical gate Q7+Q11+Q13+Q15+Q17 passed)
- [ ] Coverage didn't drop
- [ ] No skipped/todo tests for new code
