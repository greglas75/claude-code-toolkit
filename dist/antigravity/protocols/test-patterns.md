# Test Patterns -- Learned from Reviews

> Global file -- applies to ALL projects.
> Agent reads this BEFORE writing tests during Execute phase.
> Each pattern has a WHEN trigger -- only apply matching patterns.
> **Step 4 (Self-Evaluate) is MANDATORY after writing tests. Now Q1-Q17 (was Q1-Q15).**
> New patterns are added when user gives feedback about test gaps.

---

## How to use

### Step 1: Classify the code under test

Look at the function/component and pick ALL matching types:

| Code Type | How to recognize |
|-----------|-----------------|
| **PURE** | No side effects, no mocks needed, input -> output |
| **REACT** | React component, uses hooks, renders UI |
| **SERVICE** | Class/module with injected dependencies, business logic |
| **REDIS/CACHE** | Uses Redis, KV, or in-memory cache |
| **ORM/DB** | Builds database queries (Prisma, TypeORM, etc.) |
| **API-CALL** | Calls external HTTP API, maps response |
| **GUARD/AUTH** | Checks permissions, roles, ownership, rate limits |
| **STATE-MACHINE** | Multiple states/transitions (interceptor, workflow, status) |
| **ORCHESTRATOR** | Calls multiple sub-methods in sequence |
| **EXPORT/FORMAT** | Generates output in standard format (CSV, JSON, XLSX, XML, PDF) |
| **ADAPTER/TRANSFORM** | Maps between two formats/APIs (legacy<->modern, UUID<->int, snake<->camel) |
| **CONTROLLER** | NestJS/Express controller with DI, route handlers, auth guards |
| **STATIC-ANALYSIS** | Tests scanning source code without executing it (AST, regex, security) |
| **INTEGRATION-PIPELINE** | End-to-end tests crossing multiple services with real data |
| **REDUX-SLICE** | Redux Toolkit slice -- reducer + `createAsyncThunk` thunks, MSW-backed integration tests |
| **API-ROUTE** | Serverless/function-based handler (Next.js App Router, Cloudflare Workers, Express router) -- no DI, middleware chain |
| **E2E-BROWSER** | Playwright/Cypress browser tests with page navigation, selectors, auth flows |

### Step 2: Load patterns from lookup table

| Code Type | Good patterns (replicate) | Gap patterns (check) |
|-----------|--------------------------|----------------------|
| **PURE** | G-2, G-3, G-5, G-20, G-22, G-30, G-54 | P-1, P-8, P-13, P-20, P-22, P-27 |
| **REACT** | G-1, G-7, G-8, G-10, G-18, G-19, G-25, G-26, G-27, G-29, G-43, G-44, G-45, G-51, G-53, G-54, G-55, G-58 | P-1, P-9, P-10, P-12, P-17, P-18, P-19, P-21, P-25, P-28, P-30, P-39, P-43, P-45, P-46, P-53, P-54, P-55, P-57, P-66 |
| **SERVICE** | G-2, G-4, G-9, G-11, G-23, G-24, G-25, G-28, G-30, G-31, G-38, G-39, G-53, G-54, G-58 | P-1, P-4, P-5, P-11, P-22, P-23, P-25, P-27, P-28, P-29, P-31, P-32, P-37, P-56, P-57 |
| **REDIS/CACHE** | G-2, G-4 | P-1, P-5, P-6, P-14, P-29 |
| **ORM/DB** | G-9, G-28, G-30 | P-5, P-11, P-15, P-29, P-32 |
| **API-CALL** | G-3, G-15, G-28, G-29, G-36, G-55 | P-1, P-2, P-6, P-16, P-25, P-27, P-28, P-31, P-35, P-56, P-67 |
| **GUARD/AUTH** | G-6, G-8, G-11, G-20, G-28, G-29, G-32 | P-1, P-6, P-7, P-14, P-28 |
| **STATE-MACHINE** | G-1, G-7, G-21, G-28 | P-7, P-13, P-18 |
| **ORCHESTRATOR** | G-2, G-20, G-21, G-23, G-24, G-25, G-31 | P-5, P-14, P-20, P-21, P-22, P-23, P-24, P-25, P-28 |
| **EXPORT/FORMAT** | G-2, G-4, G-11, G-12, G-13, G-16, G-17, G-23, G-24, G-28, G-35 | P-1, P-4, P-22, P-23 |
| **ADAPTER/TRANSFORM** | G-2, G-14, G-15, G-22, G-30, G-35 | P-1, P-9, P-16, P-66 |
| **CONTROLLER** | G-2, G-4, G-6, G-9, G-28, G-32, G-33†, G-34†, NestJS-G1†, NestJS-G2† | P-1, P-5, P-28, P-33, P-34, P-38, P-62, AP15, AP16, NestJS-AP1†, NestJS-P1†, NestJS-P2†, NestJS-P3† |
| **STATIC-ANALYSIS** | G-37, G-28, G-30 | P-26, P-35 |
| **INTEGRATION-PIPELINE** | G-35, G-36, G-38, G-22, G-13 | P-35, P-36, P-37 |
| **REDUX-SLICE** | G-4, G-28, G-41, G-42, G-44, G-45, G-53 | P-40, P-41, P-42, P-44, P-55 |
| **API-ROUTE** | G-2, G-4, G-6, G-11, G-28, G-29, G-32, G-55 | P-1, P-5, P-6, P-28, P-38, P-62, P-65 |
| **E2E-BROWSER** | G-56, G-57 | P-63, P-64, P-57 |

**†** = domain-specific pattern, lives in domain file (not catalog). Loaded only when domain file is active.

**Always apply:** G-2 (behavior assertions), G-4 (factories), P-1 (null/undefined), P-3 (boolean returns if applicable), P-4 (DRY boilerplate), P-26 (test name = test behavior), P-28 (phantom mocks), G-31 (call order when sequence matters), G-32 (admin/non-admin symmetry for guarded endpoints), G-54 (regression anchor naming)

**Pattern files (load on demand by matched IDs):**

| File | Contains | When to load |
|------|----------|--------------|
| `~/.antigravity/test-patterns-catalog.md` | G-1 -- G-40, G-51 -- G-58, P-1 -- P-46, P-53 -- P-57, P-62 -- P-67 (general + E2E) | Always -- grep matched pattern IDs |
| `~/.antigravity/test-patterns-redux.md` | G-41 -- G-45, P-40, P-41, P-44 | Code type includes REDUX-SLICE |
| `~/.antigravity/test-patterns-nestjs.md` | G-33, G-34, NestJS-G1, NestJS-G2, NestJS-AP1, NestJS-P1-P3, security S1-S7, templates | Code type includes CONTROLLER + NestJS stack |

**Efficient loading:** Don't read entire catalog. Grep for `### G-4:` or `### P-28:` to jump to matched patterns only.

### Step 3: Write tests applying ONLY loaded patterns

Don't scan all ~77 patterns. Only read the details of patterns from your lookup result.

### Step 4: Self-Evaluate (MANDATORY after writing tests)

Run this checklist IMMEDIATELY after writing tests. You already have full context -- no files to read, just answer honestly.

**17 binary questions (1 point each):**

| # | Dimension | Question | 1 = YES, 0 = NO |
|---|-----------|----------|-----------------|
| Q1 | Structure | Every test name describes the expected behavior (not "should work", "handles data")? | |
| Q2 | Structure | Tests grouped in logical describe blocks (by feature/method, not flat list)? | |
| Q3 | Assertions | Every mock has `CalledWith` for positive AND `not.toHaveBeenCalled` for negative side-effects? (**N/A** if no mocks -- score as 1) | |
| Q4 | Assertions | All assertions on known data are exact (`toEqual`/`toBe`, not `toBeTruthy`/`toBeGreaterThan(0)`)? | |
| Q5 | Mocks | Mocks are typed (factory pattern or proper types, not `as any`/`as never` scattered)? (**N/A** if no mocks -- score as 1) | |
| Q6 | Mocks | Mock state is fresh per test (no shared mutable `let` at module scope, proper `beforeEach`)? (**N/A** if no mocks -- score as 1) | |
| Q7 | Edges | At least one error path test (function throws / returns error / rejects)? **CRITICAL** | |
| Q8 | Edges | Null/undefined/empty inputs tested where applicable? | |
| Q9 | Readability | Repeated setup (3+ tests) extracted to helper/factory? | |
| Q10 | Readability | No magic values -- test data is self-documenting or uses named constants? | |
| Q11 | Completeness | All code branches exercised (every if/else, switch case, early return)? **CRITICAL** -- In deep mode: cite 2-3 specific branches and the tests covering them as evidence. | |
| Q12 | Completeness | Symmetric coverage: every "does X when Y" has a "does NOT do X when not-Y"? **Procedure: list ALL methods -> for each repeated pattern (auth guard, validation, error), verify EVERY method has it. One missing = 0.** | |
| Q13 | Behavioral | Tests import and call actual production function (not a local copy/reimplementation)? **CRITICAL** | |
| Q14 | Behavioral | Assertions verify output/behavior, not just that a mock was called? | |
| Q15 | Depth | Assertions verify content/values, not just counts or shape? (`options[0].text === '18-24'` not just `options.length === 2`) **CRITICAL** | |
| Q16 | Isolation | Cross-cutting isolation verified? When changing A, assert B is NOT affected? (**N/A** if single-entity tests -- score as 1) | |
| Q17 | Computed | Assertions verify COMPUTED output, not input echo? **CRITICAL** -- BAD: `expect(result.from).toEqual(18)` (18 was the input); BAD: `expect(result.id).toEqual(1)` (mock returns `{id:1}`); GOOD: `expect(result.cpi_after_discount).toBe(2.25)` (2.5 x 0.9 computed) | |

**Q14/Q15/Q17 Disambiguation:**
- **Q14** (behavior): Does the test verify a meaningful outcome, not just "mock was called"? Fail if ALL assertions are `toHaveBeenCalled` with zero output/state checks.
- **Q15** (depth): Does the test check specific values, not just shape/count? Fail if `expect(result.length).toBe(2)` but never checks what the 2 items contain.
- **Q17** (computed): Does the assertion verify a value the code CALCULATED, not one it received unchanged? Fail if `expect(result.name).toBe('test')` and `'test'` was the input/mock value.
- A test can pass Q14 (checks behavior) but fail Q17 (the "behavior" is just echoing input back).
- A test can pass Q17 (checks computed value) but fail Q15 (only checks one value, ignores others).

**Anti-pattern deductions (each = -1 point):**

| AP | Pattern | Fix |
|----|---------|-----|
| AP1 | Any `describe.skip` or `it.skip` in new tests? | Remove skip or delete test. **Note:** per `testing.md`, `it.skip` in *required* tests (coverage mandated by code type) = BLOCKING, not just -1. |
| AP2 | Any `if (element) { expect... }` conditional assertion? | Use `getByX` (throws if missing) or assert existence first |
| AP3 | Function defined in test that mirrors production logic? | Import from production module |
| AP4 | 3+ identical mock object literals (not using factory)? | Extract `createX()` factory |
| AP5 | `as any` -> `as never` rename counted as Q5 fix? | Both bypass types equally. Use typed helper/factory/interface instead. |
| AP6 | Testing CSS classes (`className.includes('bg-purple')`)? | Test behavior: `aria-disabled`, `toBeDisabled()`, `getByRole` |
| AP7 | `.catch(() => {})` swallowing assertion errors? Test never fails. | Remove catch, or assert the specific error. A test that can't fail is not a test. |
| AP8 | `document.querySelector` bypassing Testing Library (React)? | Use `screen.getByRole`, `getByText`, `getByTestId`. querySelector tests DOM structure, not behavior. |
| AP9 | Always-true assertion (`document.body.toBeTruthy()`, `expect(true).toBe(true)`, `expect(screen).toBeDefined()`)? `screen` from Testing Library is ALWAYS defined -- checking it proves nothing. | Assert specific content/state that would change if component breaks. |
| AP10 | Tautological mock test -- three sub-types, all score 0 for Q17: **(1)** Call mock -> verify mock called, zero production code: `service.method(); expect(service.method).toHaveBeenCalled()`. **(2)** UI echo: `await userEvent.type(input, 'x'); expect(input).toHaveValue('x')` -- tests React's input binding, not your component logic. **(3)** MSW echo: mock server configured to return `{ id }`, test asserts `payload.id === id` -- verifies mock setup, not transformation. | Fix: verify COMPUTED output or CalledWith on downstream action. |
| AP11 | `vi.mocked(vi.fn())` -- mock targeting a fresh fn instead of imported module? | Mock the actual import: `vi.mocked(useParams).mockReturnValue(...)`. Fresh fn mock does nothing. |
| AP12 | `waitForTimeout(N)` hardcoded delay in async/E2E tests? | Use event-based waits: `waitForRequest`, `waitForSelector`, `waitFor(() => expect(...))`. |
| AP13 | Test body has zero `expect()` calls -- just calls code and exits | Add assertions or delete the test. A test without expect is not a test. **AUTO TIER-D.** **Exception:** In RTL, `getByRole`/`getByText`/`getByLabelText` are implicit assertions (throw if not found). A test with only `getBy*` queries and no `expect()` is NOT AP13. AP13 targets tests that call production code with zero verification. |
| AP14 | `toBeTruthy()`/`toBeDefined()` as SOLE assertion on complex object/response | Replace with `toEqual`/`toMatchObject` verifying actual structure/values. **Exception:** RTL `getByRole`/`getByText` + `toBeInTheDocument()` is NOT AP14 -- the query itself is the assertion. AP14 targets `expect(result).toBeTruthy()` on data objects. |
| AP15 | Testing private/internal methods directly (`controller.__method()`, `service._internal()`) | Test through public API. Private methods are implementation details -- tests coupled to them break on refactor. Metric: tests calling `__methods` averaged 3.0/10 (N=92). If you NEED to test a private method, extract it to a service. |
| AP16 | Fixture:assertion ratio > 20:1 (e.g., 850 lines data, 5 lines assertions) | Extract fixtures to factory functions or JSON files. Add assertions proportional to data complexity. |
| AP17 | Unused test data -- `const updateRequest = {...}` declared but never used in any test | Write the test or delete the declaration. Signals incomplete coverage -- someone planned a test and forgot. |
| AP18 | Duplicate test numbers/names -- two tests with `#1.1` or identical `it` descriptions | Indicates copy-paste without review. Renumber/rename to reflect distinct scenarios. |

**Stack adjustments (each missed = -1 from total):**

| Stack | Check | Trigger |
|-------|-------|---------|
| React | Uses `userEvent` not `fireEvent` for inputs? | Any `<input>` / `<textarea>` interaction |
| React | Tests loading + error + empty states? | Component with async data fetching |
| React | Semantic queries (`getByRole`, `getByLabelText`), not CSS selectors? | Component rendering assertions |
| Backend | Tests 4xx/5xx status codes, not just 200? | API endpoint handler |
| Backend | CalledWith on DB mock verifies WHERE clause? | Prisma/DB query mock |
| Backend/Service | Tests infrastructure failure (DB/API throws -> fail-open or fail-closed)? | Code with try/catch around DB/API calls |
| NestJS | No `spyOn(service, service.ownMethod)` self-mock? | Any NestJS service test |
| NestJS | Uses `makeX()` factory, not inline 100+ LOC fixture? | 3+ tests with similar setup |
| NestJS | Tests public controller methods, not `__private`? | Any controller test |
| Python | Uses `conftest.py` fixtures, not copy-paste? | 3+ test files in same directory |
| E2E | No vacuous conditionals? | Any `if` inside test body |
| Any | Parameter combinations tested (`it.each` or explicit)? | Function with 2+ boolean flags or mode enum |

**Modular suite adjustment (G-23):**

When scoring a file that's part of a modular test suite (orchestrator + suite files), score Q7 (error path) and Q11 (branch coverage) at the **suite level**, not per file. A `happy-path.test.ts` with Q7=0 is correct if `error-handling.test.ts` exists in the same suite. Check the orchestrator to verify all paths are covered across the suite.

**Critical gate:**

If ANY of Q7, Q11, Q13, Q15, Q17 = 0 -> result is **capped at FIX** regardless of total score. These dimensions cannot be compensated by high scores elsewhere. A test with perfect names and factories but zero error coverage or input-echo-only assertions is not PASS-worthy.

**Auto Tier-D triggers** (bypass scoring entirely):
- AP13 found (test without assertions) -> file is Tier D
- AP16 found (fixture:assertion ratio > 20:1) -> file is Tier D
- 50%+ of tests have AP14 (toBeTruthy as sole assertion) -> file is Tier D

**Q17 audit rule:** If >=50% of assertions check values that are direct copies of input/request/mock-return without transformation -> Q17=0. In deep mode, cite 1-2 examples: "assertion X is echo of input Y".

**N/A normalization:** Questions marked N/A (Q3/Q5/Q6/Q16 when not applicable) score as 1 -- don't penalize tests for not having mocks when no mocks are needed. This prevents PURE function tests from being unfairly scored lower than mock-heavy service tests.

**Scoring:**

```
Total = (Q1-Q17 yes count, with N/A=1) - (AP deductions)

>= 14  PASS -- continue (unless critical gate triggers -> FIX)
9-13  FIX -- identify worst dimension, improve it, re-score
< 9   BLOCK -- major gaps, rewrite before continuing
```

Stack-specific patterns (Redux P-40/P-41, NestJS NestJS-P1/P2/P3) are counted as AP deductions -- not a separate category. They apply only when auditing that code type.

**Output format (append to your response after tests):**

Score EACH question individually -- never group (e.g., "Q1-Q6: 5/6" is FORBIDDEN). Use this exact format:

```
Self-eval: Q1=1 Q2=1 Q3=0 Q4=1 Q5=1 Q6=1 Q7=1 Q8=0 Q9=1 Q10=1 Q11=1 Q12=0 Q13=1 Q14=1 Q15=1 Q16=1 Q17=1
  Score: 14/17 - 0 deductions = 14 -> PASS
  Critical gate: Q7=1 Q11=1 Q13=1 Q15=1 Q17=1 -> PASS
```

The individual scores are required so you (and the user) can see exactly which dimensions failed. Grouped scores hide the specific gaps and make fixes harder to target.

Example: `Q1=1 Q2=1 Q3=1 Q4=1 Q5=0 Q6=1 Q7=1 Q8=1 Q9=1 Q10=1 Q11=1 Q12=1 Q13=1 Q14=1 Q15=1 Q16=0 Q17=0 = 14/17 -> FIX [CRITICAL: Q17=0]`

If FIX or BLOCK: fix the issues, then re-run the checklist.

**Remember:** this checklist is the minimum gate, not the ceiling. Passing Step 4 means tests meet baseline quality -- but context-specific issues (does the test catch real regressions? will it survive a refactor?) require judgment beyond the checklist.

---

### Step 5: When user gives feedback -> append new patterns and update the lookup table

---

## Red Flags -- Quick Heuristics (for audit/review)

Empirical correlations from 92-file cross-project analysis (N=20 initial, N=92 confirmed). Use as fast pre-screening before full Q1-Q17 evaluation.

| Indicator | Avg Score (N=92) | Action |
|-----------|-----------------|--------|
| 0 CalledWith in entire file | 2.6/10 | Almost certainly Tier C/D -- prioritize for review |
| 4+ CalledWith assertions | 8.4/10 | Likely Tier A/B -- lower priority |
| 10+ DI providers in setup | 2.8/10 | Signals monolithic controller -- test quality suffers |
| 1-2 DI providers in setup | 7.8/10 | Focused test -- likely good quality |
| >200 lines of inline fixture data | 2.0/10 | Needs factory extraction -- Tier C/D |
| <50 lines of fixture data | 8.0/10 | Proportional setup -- likely good |
| Tests calling `__privateMethod()` | 3.0/10 | Coupled to implementation -- Tier C/D |
| Factory functions with overrides (`makeX()`) | 8.4/10 | **Strongest single quality predictor** |
| `spyOn(service, service.ownMethod)` -- self-mock | 3.0/10 | Test proves mock works, not code. AP10 |
| `toBeTruthy()` as sole assertion | 2.5/10 | No real verification -- Tier D |
| Fixture:assertion ratio > 20:1 | 2.3/10 | Auto Tier-D confirmed at scale (AP16) |
| Assertions only on `.id` or input values | 2.8/10 | Input echo -- see Q17 |
| `try/catch` wrapping expect (not `rejects.toThrow`) | 3.5/10 | Silent false-positive -- P-27 |
| `isinstance` + `not isinstance` at boundaries (Python) | 8.7/10 | Strong dual-framework testing |
| Real data fixtures (>50 rows, Python) | 8.5/10 | Strong integration quality |
| Test builds dict literal and asserts structure (Python) | 7.0/10 | Self-referential -- check P-35 |
| `reducer({ initialState: {} }, action)` -- wrong initial state | 3.0/10 | P-40: loading=false is default, not transition |
| `expect(state.loading).toEqual(false)` as only assertion | 3.5/10 | P-41: data never verified -- check state content |
| `faker.number.int` for selecting DOM element index | 4.0/10 | P-42: non-deterministic selection |
| `typeof dispatchSpy.mock.calls[0][0] === 'function'` | 4.5/10 | Use vi.mock thunk (G-43) for exact payload |
| `expect(screen).toBeDefined()` | 1.0/10 | AP9: screen always defined -- tests nothing |
| `getByTestId:getByRole` ratio > 3:1 | 4.2/10 | P-43: accessibility-blind -- replace testId with semantic queries |
| 0 `.rejected` tests in slice file | 4.5/10 | P-44: error paths unverified -- add at least 1 rejected test per thunk |
| Empty state: only `not.toBeInTheDocument()` | 5.0/10 | P-45: shallow empty state -- assert placeholder renders too |
| Form tests: 0 error-recovery tests | 4.8/10 | P-46: validation error stuck -- test error clears after fix |
| `vi.mock(module)` without `importActual` | 4.2/10 | Breaks selectors/reducers -- use G-44 selective mock instead |
| `preloadedState` used in setup | 8.1/10 | G-45: deterministic store seeding -- strong quality predictor |
| `toMatchSnapshot()` on full JSX container | 2.5/10 | P-53: likely false coverage -- snapshot of 2000-line tree, zero regression safety |
| Multiple `await dispatch()` sequential without isolation | 3.5/10 | P-55: potential flaky ordering -- resolution order depends on MSW delay |
| Mock typed as `as any` / plain object literal without interface | 3.2/10 | P-56: drift risk -- service signature change won't surface as test error |
| No `afterEach` cleanup for `process.env` / `window` globals | 3.8/10 | P-57: ordering leak risk -- test B passes only after test A ran first |
| Regression tests without ticket reference in name | 4.5/10 | G-54 missing: high deletion risk in cleanup -- looks like arbitrary edge case |
| `*.api.test.ts` with zero `mockRejectedValue` | 4.0/10 | P-67: error resilience never tested -- consumer try/catch has no regression safety |
| `if (condition) { expect(...) }` in test body | 2.5/10 | AP2: conditional assertion silently skips when condition is false -- test always passes |
| >20 `vi.mock()`/`jest.mock()` in single file | 3.5/10 | P-62: over-mocking -- likely copy-paste setup, many mocks unused |
| `if (await *.isVisible())` in E2E test | 3.0/10 | P-63: silent conditional -- test passes when feature broken |
| <6 `it()`/`test()` per API endpoint | 5.5/10 | P-65: under-tested -- missing edge cases (auth, validation, empty, boundary) |
| Inline selectors in Playwright spec (no page object) | 4.0/10 | G-56 missing: any UI change = multi-file edit |
| Hardcoded password/email string in test file | N/A | P-64: security -- move to env vars |

**Fixture:Assertion Ratio thresholds (calibrated on N=92):**

| Ratio | Avg Score | Example |
|-------|-----------|---------|
| < 3:1 | 7.8/10 | offer-clone.service (makeOffer factory, 8.5/10) |
| 3:1 -- 10:1 | 5.5/10 | offer-client-brief.controller (4/10) |
| 10:1 -- 50:1 | 2.5/10 | offer-public.controller (748 LOC, ~15 assertions) |
| > 50:1 | 2.0/10 | offer-quota.controller (1634 LOC, 5 assertions) -- Auto Tier-D |

These are HEURISTICS, not rules. A file with 0 CalledWith could still be Tier A if testing pure functions. Always run full Q1-Q17 for definitive scoring.

---

## Adding New Patterns (instructions for agent)

When user gives feedback about test quality (e.g., "test was missing X", "this pattern was good"), do ALL 3 steps:

### 1. Create the pattern entry

- Good pattern -> `G-{next}`, gap pattern -> `P-{next}`
- Include: When, Do/Tests, Why (1 sentence), Source (date + file + what happened)
- Keep it concise -- 5-8 lines max
- **File placement:** general patterns -> `test-patterns-catalog.md`, domain-specific -> `test-patterns-{domain}.md`

### 2. Update the lookup table (Step 2 in this file)

Decide which code types the new pattern applies to and add its ID to the table.
If it applies to ALL types -> add to the "Always apply" line instead.

### 3. Check if a new code type is needed

If the pattern applies to a code category not yet in the table (e.g., WEBSOCKET, CRON, CLI), add a new row to both the classification table (Step 1) and the lookup table (Step 2).
