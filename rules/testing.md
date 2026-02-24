# Testing Rules (All Projects)

Mandatory testing requirements. Applies regardless of stack — Jest, Vitest, pytest, Playwright.

---

## Iron Rule: Every New Code Must Have Tests

No exceptions. No "I'll add tests later." No commits without test coverage for new code.

## Plan Mode — Test Strategy Required

When using EnterPlanMode / ExitPlanMode, the plan MUST include a **Test Strategy** section:

1. **Code types** being added/changed (Step 1 classification)
2. **Key patterns** to apply (G-/P- IDs from Step 2 lookup)
3. **Test files** to create/modify (paths + scope)
4. **Critical scenarios** (error paths, edge cases, infra failures)
5. **Self-eval target**: minimum 14/17

A plan without Test Strategy is incomplete — do not approve it.

## Test Requirements by Code Type

### New Function/Utility
- Unit test: happy path
- Unit test: error cases
- Unit test: edge cases (null, undefined, empty, boundary values)

### New React Component
- Render test (mounts without error)
- **User flow tests (NOT just rendering)** — for each interactive element, test the FULL flow: user action → state change → callback/API called with correct args → success/error feedback. "Button visible" is NOT a flow test. See P-39 in `~/.claude/test-patterns-catalog.md` for per-component-type minimum flows (form submit, search filter, modal confirm, etc.)
- Props/state variation tests
- Error state test
- Accessibility: interactive elements have ARIA labels, keyboard navigation works (see `react-nextjs.md` WCAG 2.1 AA)
- **Gate: flow tests must be ≥ 30% of total tests.** If all tests are `toBeInTheDocument()` checks → FAIL. A rendering-only test suite provides zero regression safety.

### New API Endpoint/Handler
- Success response (200/201)
- Error responses (400, 401, 403, 404, 500)
- Input validation (invalid/missing fields)
- Auth/authorization check

### New Hook
- Behavior test (returns expected values)
- State change test (updates correctly)
- Side effect test (API calls, timers)

### New API Endpoint — Mandatory Security Tests

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
     /\       E2E Tests (5-10%) — critical user flows only
    /  \
   /____\     Integration Tests (30%) — component interactions
  /      \
 /________\   Unit Tests (60%) — utils, hooks, business logic
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

## Quick-Fail Forbidden Patterns (auto-fail Q17 critical gate)

Before submitting any test, scan for these specific patterns. Each one = Q17=0 = critical gate FAIL.

**1. Always-true assertions (AP9)**
```typescript
// FORBIDDEN — screen is always defined, this tests nothing
expect(screen).toBeDefined();
// FIX: assert actual content
expect(screen.getByText('Industry Name')).toBeInTheDocument();
```

**2. UI input echo (AP10 sub-type)**
```typescript
// FORBIDDEN — you typed 'moon', you check 'moon' — tests React, not your code
await userEvent.type(input, 'moon');
expect(input).toHaveValue('moon');
// FIX: assert what HAPPENED after submit
expect(fetchProfiles).toHaveBeenCalledWith({ searchParams: { first_name: 'moon' } });
```

**3. MSW mock echo (AP10 sub-type)**
```typescript
// FORBIDDEN — MSW was set up to return { id: 29 }, you check id === 29
expect(payload.id).toEqual(id);  // id comes from mock setup
// FIX: assert transformed data — fields the code computed
expect(payload.industry_name).toBe('Finance');
expect(state.industries).toEqual(INDUSTRY_FIXTURES);
```

**4. Opaque dispatch verification**
```typescript
// FORBIDDEN — proves "a thunk was dispatched" not "the correct one with correct payload"
expect(typeof dispatchedAction).toBe('function');
// FIX: vi.mock the thunk slice, use CalledWith
expect(fetchProfiles).toHaveBeenCalledWith({ searchParams: expect.objectContaining({ first_name: 'moon' }) });
```

**5. Silent test skip (AP2)**
```typescript
// FORBIDDEN — test PASSES when it skips, gives false confidence
if (checkboxes.length === 0) return;
// FIX: fail loud
expect(checkboxes.length).toBeGreaterThan(0);
```

**6. Redux wrong initial state (P-40)**
```typescript
// FORBIDDEN — { initialState: {} } is not the real slice state
const state = reducer({ initialState: {} }, action);
expect(state.loading).toEqual(false);  // always false — not a real transition
// FIX: use createInitialState() with real shape (see test-patterns-redux.md G-41)
const state = reduceFrom({ type: addProfile.fulfilled.type, payload });
expect(state.profiles).toContainEqual(expect.objectContaining({ id: 29 }));
```

**7. Loading-only Redux assertions (P-41)**
```typescript
// FORBIDDEN — loading flipped but data never verified
expect(state.loading).toEqual(false);  // that's it
// FIX: verify data actually landed in the store
expect(state.loading).toBe(false);
expect(state.profiles).toEqual(PROFILE_FIXTURES);
expect(state.filters).toEqual({ name: 'Moon' });
```

## Batch Diagnosis — Grep Before You Fix

Before deciding what to fix, scan the codebase to quantify what's actually broken.
Run these in order — highest signal first based on empirical data across real projects.

```bash
# P-41: Loading-only Redux assertions — most prevalent pattern in agent-written slice tests
# Hits here = slice tests that pass but never verify data in store
grep -rn "expect(state.loading).toBe(false)\|expect(state.loading).toEqual(false)" src/ --include="*.test.*" | grep -v "#"

# G-43 needed: Opaque dispatch — form tests that prove "something was dispatched" not "which thunk + payload"
grep -rn "expect(typeof dispatchedAction).toBe('function')" src/ --include="*.test.*"

# AP9/AP10: Always-true + weak assertions
grep -rn "toBeDefined()\|toBeTruthy()" src/ --include="*.test.*"

# P-42: Non-deterministic faker selection
grep -rn "faker.number.int.*min.*max.*length" src/ --include="*.test.*"

# AP2: Silent test skip
grep -rn "if.*length.*=== 0.*return\|if.*\.length === 0) return" src/ --include="*.test.*"

# P-40: Wrong Redux initial state
grep -rn "reducer({ initialState: {}" src/ --include="*.test.*"

# MSW echo: payload.id check where id comes from fixture setup (check output manually)
grep -rn "expect(payload\.id)\.toEqual\|expect(lastAction\.payload\.id)\.toEqual" src/ --include="*.test.*"

# P-43: getByTestId dominance — count ratio vs getByRole (accessibility gap)
grep -rn "getByTestId\|queryByTestId" src/ --include="*.test.*" | wc -l
grep -rn "getByRole\|queryByRole" src/ --include="*.test.*" | wc -l
# If testId:role > 3:1 → accessibility-blind suite — replace with semantic queries (P-43)

# P-44: Missing rejected state coverage in slice tests
grep -rn "\.rejected\.type\|\.rejected," src/ --include="*.test.*" | wc -l
# Low count (< 1 per thunk) → add rejected tests for each async thunk

# P-45: Shallow empty state — only absence check, no placeholder assertion
grep -rn "not\.toBeInTheDocument\|queryByText.*null" src/ --include="*.test.*" | wc -l
grep -rn "No.*found\|empty.*state\|no results" src/ --include="*.test.*" -i | wc -l
# If first >> second → empty state UI never verified (P-45)

# P-46: Validation error recovery gap — forms test error shown but not cleared
grep -rn "is required\|is invalid\|Please enter" src/ --include="*.test.*" | wc -l
grep -rn "not\.toBeInTheDocument.*required\|queryByText.*required" src/ --include="*.test.*" | wc -l
# If first >> second → validation recovery missing (P-46)
```

**Interpret results:**

| Pattern | Count | Action |
|---------|-------|--------|
| `state.loading` loading-only | >10 | Batch-fix all `*Slice.test.*` in one agent run — identical template error |
| `typeof dispatchedAction` | >3 | Batch-fix all `*Form.test.*` in one agent run — apply vi.mock thunk pattern (G-43) |
| `toBeDefined/toBeTruthy` | >10 | Likely AP14 territory — check if SOLE assertion or just supplemental |
| `faker.number.int` on DOM elements | Any | Replace with `checkboxes[1] ?? checkboxes[0]` + expect.length > 0 |
| `initialState: {}` | Any | Replace with `createInitialState()` factory (G-41) |
| `getByTestId:getByRole` > 3:1 | Any | Batch-replace testId queries with semantic queries (P-43) |
| rejected coverage < 1 per thunk | Any | Add rejected test per thunk to each slice file (P-44) |
| empty-state absence >> placeholder | >5 gap | Add placeholder assertion to each empty-state test (P-45) |
| error-shown >> error-cleared | >5 gap | Add recovery flow to each form test (P-46) |

**Grouping for batch fix:** Collect all files with same pattern → one agent per group.
E.g. 22 slice tests with loading-only → one agent, one prompt, one fix template.

## Refactoring & Tests

1. **Before:** run existing tests (baseline must pass)
2. **During:** update tests with each code change
3. **After:** full suite must pass, coverage must not drop
4. If tests fail after refactoring: fix the code OR update tests — never delete tests without replacement

## Self-Evaluation (MANDATORY after writing tests)

Run this checklist IMMEDIATELY after writing tests. Score EACH question individually — never group.

**17 binary questions (1 = YES, 0 = NO):**

| # | Question |
|---|----------|
| Q1 | Every test name describes expected behavior (not "should work")? |
| Q2 | Tests grouped in logical describe blocks? |
| Q3 | Every mock has `CalledWith` (positive) AND `not.toHaveBeenCalled` (negative side-effects)? |
| Q4 | Assertions on known data are exact (`toEqual`/`toBe`, not `toBeTruthy`)? |
| Q5 | Mocks are typed (not `as any`/`as never`)? |
| Q6 | Mock state fresh per test (proper `beforeEach`, no shared mutable)? |
| Q7 | **CRITICAL** — At least one error path test (throws/rejects/returns error)? |
| Q8 | Null/undefined/empty inputs tested where applicable? |
| Q9 | Repeated setup (3+ tests) extracted to helper/factory? |
| Q10 | No magic values — test data is self-documenting? |
| Q11 | **CRITICAL** — All code branches exercised (if/else, switch, early return)? |
| Q12 | Symmetric: every "does X when Y" has "does NOT do X when not-Y"? **Procedure: list ALL methods → for each repeated pattern (auth guard, validation, error), verify EVERY method has it. One missing = 0.** |
| Q13 | **CRITICAL** — Tests import actual production function (not local copy)? |
| Q14 | Assertions verify behavior, not just that a mock was called? |
| Q15 | **CRITICAL** — Assertions verify content/values, not just counts/shape? |
| Q16 | Cross-cutting isolation: change to A verified not to affect B? |
| Q17 | **CRITICAL** — Assertions verify COMPUTED output, not input echo? |

**N/A handling:** Q3/Q5/Q6 score as 1 (N/A) for pure functions with zero mocks. Q16 = 1 (N/A) for simple single-responsibility units.

**Critical gate:** Q7, Q11, Q13, Q15, Q17 — any = 0 → auto-capped at FIX regardless of total.

**Scoring:** Total = Q1-Q17 yes count (N/A=1) minus AP deductions (see `~/.claude/test-patterns.md`). ≥ 14 PASS, 9-13 FIX (fix worst dimension, re-score), < 9 BLOCK (rewrite).

**Output format (individual scores required):**
```
Self-eval: Q1=1 Q2=1 Q3=0 Q4=1 Q5=1 Q6=1 Q7=1 Q8=0 Q9=1 Q10=1 Q11=1 Q12=0 Q13=1 Q14=1 Q15=1 Q16=1 Q17=1
  Score: 14/17 → PASS | Critical gate: Q7=1 Q11=1 Q13=1 Q15=1 Q17=1 → PASS
```

Full patterns: `~/.claude/test-patterns.md` (core protocol + lookup table → routes to `test-patterns-catalog.md`, `test-patterns-redux.md`, `test-patterns-nestjs.md`)

## Before Finishing Any Task

- [ ] New code has tests
- [ ] Tests pass locally
- [ ] Self-eval score ≥ 14/17 (all Q scored individually, critical gate Q7+Q11+Q13+Q15+Q17 passed)
- [ ] Coverage didn't drop
- [ ] No skipped/todo tests for new code
