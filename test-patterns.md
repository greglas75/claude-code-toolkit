# Test Patterns — Learned from Reviews

> Global file — applies to ALL projects.
> Agent reads this BEFORE writing tests during Execute phase.
> Each pattern has a WHEN trigger — only apply matching patterns.
> **Step 4 (Self-Evaluate) is MANDATORY after writing tests.**
> New patterns are added when user gives feedback about test gaps.

---

## How to use

### Step 1: Classify the code under test

Look at the function/component and pick ALL matching types:

| Code Type | How to recognize |
|-----------|-----------------|
| **PURE** | No side effects, no mocks needed, input → output |
| **REACT** | React component, uses hooks, renders UI |
| **SERVICE** | Class/module with injected dependencies, business logic |
| **REDIS/CACHE** | Uses Redis, KV, or in-memory cache |
| **ORM/DB** | Builds database queries (Prisma, TypeORM, etc.) |
| **API-CALL** | Calls external HTTP API, maps response |
| **GUARD/AUTH** | Checks permissions, roles, ownership, rate limits |
| **STATE-MACHINE** | Multiple states/transitions (interceptor, workflow, status) |
| **ORCHESTRATOR** | Calls multiple sub-methods in sequence |
| **EXPORT/FORMAT** | Generates output in standard format (CSV, JSON, XLSX, XML, PDF) |
| **ADAPTER/TRANSFORM** | Maps between two formats/APIs (legacy↔modern, UUID↔int, snake↔camel) |

### Step 2: Load patterns from lookup table

| Code Type | Good patterns (replicate) | Gap patterns (check) |
|-----------|--------------------------|----------------------|
| **PURE** | G-2, G-3, G-5, G-20, G-22, G-30 | P-1, P-8, P-13, P-20, P-22, P-27 |
| **REACT** | G-1, G-7, G-8, G-10, G-18, G-19, G-25, G-26, G-27, G-29 | P-1, P-9, P-10, P-12, P-17, P-18, P-19, P-21, P-25, P-28, P-30 |
| **SERVICE** | G-2, G-4, G-9, G-11, G-23, G-24, G-25, G-28, G-30 | P-1, P-4, P-5, P-11, P-22, P-23, P-25, P-27, P-28, P-29, P-31, P-32 |
| **REDIS/CACHE** | G-2, G-4 | P-1, P-5, P-6, P-14, P-29 |
| **ORM/DB** | G-9, G-28, G-30 | P-5, P-11, P-15, P-29, P-32 |
| **API-CALL** | G-3, G-15, G-28, G-29 | P-1, P-2, P-6, P-16, P-25, P-27, P-28, P-31 |
| **GUARD/AUTH** | G-6, G-8, G-11, G-20, G-28, G-29 | P-1, P-6, P-7, P-14, P-28 |
| **STATE-MACHINE** | G-1, G-7, G-21, G-28 | P-7, P-13, P-18 |
| **ORCHESTRATOR** | G-2, G-20, G-21, G-23, G-24, G-25 | P-5, P-14, P-20, P-21, P-22, P-23, P-24, P-25, P-28 |
| **EXPORT/FORMAT** | G-2, G-4, G-11, G-12, G-13, G-16, G-17, G-23, G-24, G-28 | P-1, P-4, P-22, P-23 |
| **ADAPTER/TRANSFORM** | G-2, G-14, G-15, G-22, G-30 | P-1, P-9, P-16 |

**Always apply:** G-2 (behavior assertions), G-4 (factories), P-1 (null/undefined), P-3 (boolean returns if applicable), P-4 (DRY boilerplate), P-26 (test name = test behavior), P-28 (phantom mocks)

### Step 3: Write tests applying ONLY loaded patterns

Don't scan all 62 patterns. Only read the details of patterns from your lookup result.

### Step 4: Self-Evaluate (MANDATORY after writing tests)

Run this checklist IMMEDIATELY after writing tests. You already have full context — no files to read, just answer honestly.

**15 binary questions (1 point each):**

| # | Dimension | Question | 1 = YES, 0 = NO |
|---|-----------|----------|-----------------|
| Q1 | Structure | Every test name describes the expected behavior (not "should work", "handles data")? | |
| Q2 | Structure | Tests grouped in logical describe blocks (by feature/method, not flat list)? | |
| Q3 | Assertions | Every mock has `CalledWith` for positive AND `not.toHaveBeenCalled` for negative side-effects? | |
| Q4 | Assertions | All assertions on known data are exact (`toEqual`/`toBe`, not `toBeTruthy`/`toBeGreaterThan(0)`)? | |
| Q5 | Mocks | Mocks are typed (factory pattern or proper types, not `as any`/`as never` scattered)? | |
| Q6 | Mocks | Mock state is fresh per test (no shared mutable `let` at module scope, proper `beforeEach`)? | |
| Q7 | Edges | At least one error path test (function throws / returns error / rejects)? **CRITICAL** | |
| Q8 | Edges | Null/undefined/empty inputs tested where applicable? | |
| Q9 | Readability | Repeated setup (3+ tests) extracted to helper/factory? | |
| Q10 | Readability | No magic values — test data is self-documenting or uses named constants? | |
| Q11 | Completeness | All code branches exercised (every if/else, switch case, early return)? **CRITICAL** | |
| Q12 | Completeness | Symmetric coverage: every "does X when Y" has a "does NOT do X when not-Y"? | |
| Q13 | Behavioral | Tests import and call actual production function (not a local copy/reimplementation)? **CRITICAL** | |
| Q14 | Behavioral | Assertions verify output/behavior, not just that a mock was called? | |
| Q15 | Depth | Assertions verify content/values, not just counts or shape? (`options[0].text === '18-24'` not just `options.length === 2`) **CRITICAL** | |

**Anti-pattern deductions (each = -1 point):**

| AP | Pattern | Fix |
|----|---------|-----|
| AP1 | Any `describe.skip` or `it.skip` in new tests? | Remove skip or delete test |
| AP2 | Any `if (element) { expect... }` conditional assertion? | Use `getByX` (throws if missing) or assert existence first |
| AP3 | Function defined in test that mirrors production logic? | Import from production module |
| AP4 | 3+ identical mock object literals (not using factory)? | Extract `createX()` factory |
| AP5 | `as any` → `as never` rename counted as Q5 fix? | Both bypass types equally. Use typed helper/factory/interface instead. |
| AP6 | Testing CSS classes (`className.includes('bg-purple')`)? | Test behavior: `aria-disabled`, `toBeDisabled()`, `getByRole` |
| AP7 | `.catch(() => {})` swallowing assertion errors? Test never fails. | Remove catch, or assert the specific error. A test that can't fail is not a test. |
| AP8 | `document.querySelector` bypassing Testing Library (React)? | Use `screen.getByRole`, `getByText`, `getByTestId`. querySelector tests DOM structure, not behavior. |
| AP9 | Always-true assertion (`document.body.toBeTruthy()`, `expect(true).toBe(true)`)? | Assert specific content/state that would change if component breaks. |
| AP10 | Tautological mock test: call mock directly → verify mock called, zero production code in between? | Import and call production function. Test proves vi.fn() works, not your code. Overlaps Q13 but more specific. |
| AP11 | `vi.mocked(vi.fn())` — mock targeting a fresh fn instead of imported module? | Mock the actual import: `vi.mocked(useParams).mockReturnValue(...)`. Fresh fn mock does nothing. |
| AP12 | `waitForTimeout(N)` hardcoded delay in async/E2E tests? | Use event-based waits: `waitForRequest`, `waitForSelector`, `waitFor(() => expect(...))`. |

**Stack adjustments (each missed = -1 from total):**

| Stack | Check | Trigger |
|-------|-------|---------|
| React | Uses `userEvent` not `fireEvent` for inputs? | Any `<input>` / `<textarea>` interaction |
| React | Tests loading + error + empty states? | Component with async data fetching |
| React | Semantic queries (`getByRole`, `getByLabelText`), not CSS selectors? | Component rendering assertions |
| Backend | Tests 4xx/5xx status codes, not just 200? | API endpoint handler |
| Backend | CalledWith on DB mock verifies WHERE clause? | Prisma/DB query mock |
| Backend/Service | Tests infrastructure failure (DB/API throws → fail-open or fail-closed)? | Code with try/catch around DB/API calls |
| Python | Uses `conftest.py` fixtures, not copy-paste? | 3+ test files in same directory |
| E2E | No vacuous conditionals? | Any `if` inside test body |
| Any | Parameter combinations tested (`it.each` or explicit)? | Function with 2+ boolean flags or mode enum |

**Modular suite adjustment (G-23):**

When scoring a file that's part of a modular test suite (orchestrator + suite files), score Q7 (error path) and Q11 (branch coverage) at the **suite level**, not per file. A `happy-path.test.ts` with Q7=0 is correct if `error-handling.test.ts` exists in the same suite. Check the orchestrator to verify all paths are covered across the suite.

**Critical gate:**

If ANY of Q7, Q11, Q13, Q15 = 0 → result is **capped at FIX** regardless of total score. These dimensions cannot be compensated by high scores elsewhere. A test with perfect names and factories but zero error coverage is not PASS-worthy.

**Scoring:**

```
Total = (Q1-Q15 yes count) - (AP deductions) - (stack deductions)

≥ 12  PASS — continue (unless critical gate triggers → FIX)
8-11  FIX — identify worst dimension, improve it, re-score
< 8   BLOCK — major gaps, rewrite before continuing
```

**Output format (append to your response after tests):**

Score EACH question individually — never group (e.g., "Q1-Q6: 5/6" is FORBIDDEN). Use this exact format:

```
Self-eval: Q1=1 Q2=1 Q3=0 Q4=1 Q5=1 Q6=1 Q7=1 Q8=0 Q9=1 Q10=1 Q11=1 Q12=0 Q13=1 Q14=1 Q15=1
  Score: 12/15 - 0 deductions = 12 → PASS
  Critical gate: Q7=1 Q11=1 Q13=1 Q15=1 → PASS
```

The individual scores are required so you (and the user) can see exactly which dimensions failed. Grouped scores hide the specific gaps and make fixes harder to target.

Example: `Q1=1 Q2=1 Q3=1 Q4=1 Q5=0 Q6=1 Q7=1 Q8=1 Q9=1 Q10=1 Q11=1 Q12=1 Q13=1 Q14=1 Q15=0 = 13/15 → FIX [CRITICAL: Q15=0]`

If FIX or BLOCK: fix the issues, then re-run the checklist.

**Remember:** this checklist is the minimum gate, not the ceiling. Passing Step 4 means tests meet baseline quality — but context-specific issues (does the test catch real regressions? will it survive a refactor?) require judgment beyond the checklist.

---

### Step 5: When user gives feedback → append new patterns and update the lookup table

---

## Good Patterns — Replicate These

### G-1: State Machine Coverage
- **When:** Code implements a state machine, interceptor, middleware, or multi-step workflow
- **Do:** One dedicated test per state/transition. Name tests after the state: `it('replays cached response when duplicate key with same payload')`
- **Why:** Proves every path through the machine is exercised. Missing state = missing test.
- **Source:** review 2026-02-15, idempotency interceptor — all 5 states + passthrough covered

### G-2: Assert Behavior, Not Structure
- **When:** Always
- **Do:**
  - `toEqual(exactValue)` over `toMatchObject(partial)` — proves the full shape
  - `not.toHaveBeenCalled()` to prove something was prevented (e.g., handler NOT called on cache replay)
  - `toHaveBeenCalledTimes(1)` + `toHaveBeenCalledWith(...)` together — proves both "did it happen" and "was it correct"
- **Anti-pattern:** `toMatchObject` when you know the full expected value — hides unexpected extra fields
- **Source:** review 2026-02-15, idempotency interceptor — `toEqual` with exact values, `not.toHaveBeenCalled` proving cache prevented execution

### G-3: Realistic Test Data — Use Real Functions
- **When:** Code under test uses a helper function (hasher, serializer, formatter)
- **Do:** Import and use the real function in test setup instead of hardcoding its output. E.g., `computeSubmitPayloadHash(payload)` in test instead of `'abc123'`.
- **Why:** If the helper changes behavior, the test breaks — which is what you want. Hardcoded values create a gap between test and reality.
- **Source:** review 2026-02-15, idempotency interceptor — used real hash function in replay/conflict tests

### G-4: Clean Factory Helpers with Overrides
- **When:** Test file has 3+ tests that need similar setup objects
- **Do:** Create `createX(overrides?)` factories that return defaults merged with overrides. Fresh mocks per test (inline or in `beforeEach`).
- **Example:** `const config = createConfig({ ttl: 600 })` — default TTL overridden for one test
- **Anti-pattern:** Copy-pasting setup objects across tests, or one shared mutable mock
- **Source:** review 2026-02-15, idempotency interceptor — `createConfig`, `createContext`, `createHandler` — clean, composable

### G-5: Pure Functions = Zero Mocks
- **When:** Function under test is a pure transformation (input → output, no side effects)
- **Do:** Import real function, pass real data, assert on output with `toEqual`. No mocks at all.
- **Why:** Mocks on pure functions add complexity without value. Real input/output tests are deterministic, fast, and catch real bugs.
- **Example:** `buildAnswerMapFromResponses(responses, questionIds)` → test null→undefined, empty→undefined, Decimal→number — all with `toEqual`
- **Source:** review 2026-02-15, buildAnswerMapFromResponses — 9/10, zero mocks, complete edge case coverage

### G-6: Security Boundary / Multi-Tenant Guard
- **When:** Function has authorization/ownership checks (orgId, userId, role)
- **Do:**
  - Test cross-org rejection: call with `organizationId: 'other-org'` → throws Access Denied
  - Verify the guarded action was NOT executed: `mockService.dangerousAction.not.toHaveBeenCalled()`
  - Test that the check happens BEFORE the action (order matters)
- **Why:** Security regression = data leak. These tests are cheap to write and critical to have.
- **Source:** review 2026-02-15, cache invalidation — cross-org Access Denied + verify invalidate NOT called

### G-7: Destructive Action Confirmation Flow
- **When:** UI has destructive actions (delete, archive, close) that require user confirmation
- **Do:**
  - Non-destructive action → immediate call (no dialog)
  - Destructive action → confirmation dialog opens
  - Confirm → action executes
  - Cancel → action NOT executed (`not.toHaveBeenCalled`)
  - Test dialog text matches severity (e.g., "cannot be undone" for irreversible)
- **Source:** review 2026-02-15, StatusManager — 9/10, destructive vs non-destructive transitions, confirm + cancel paths

### G-8: Permission-Based Conditional Rendering
- **When:** UI shows/hides elements based on user permissions or roles
- **Do:**
  - Permission granted → element visible + functional
  - Permission denied → `queryByX` returns `null` (element absent, not just hidden/disabled)
  - Verify the data/content still renders (user can SEE but not ACT)
- **Source:** review 2026-02-15, StatusManager — canEditSurveyStatus=false → buttons null, status text visible

### G-9: ORM/Query Building Assertions
- **When:** Service builds database queries (Prisma, TypeORM, Sequelize, Django ORM)
- **Do:**
  - Assert exact `where` clause structure (not just `expect.any(Object)`)
  - Assert `orderBy`, `take`, `skip` for pagination
  - Assert `include`/`select` structure for at least one key method
  - Test search filter → `{ contains: term, mode: 'insensitive' }`
  - Test default sorting vs explicit sorting
- **Source:** review 2026-02-15, TemplateService — 8.5/10, exact Prisma where/orderBy verified per test

### G-10: Per-Test Mock Override via vi.fn()
- **When:** React component depends on a hook/context with multiple possible states
- **Do:** Mock the hook with `vi.fn()` at module level, then override per test with `mockReturnValue`. Never use static module-level mock with fixed return value.
- **Anti-pattern:** `vi.mock('./hooks', () => ({ useHook: () => fixedValue }))` — locks you into one state, can't test other states without refactoring the test
- **Pattern:**
  ```typescript
  vi.mock('./hooks', () => ({ useHook: vi.fn() }));
  // per test:
  vi.mocked(useHook).mockReturnValue({ status: 'loading' });
  ```
- **Source:** review 2026-02-15, SaveIndicator 4/10 (static mock, 1/4 states) vs TemplateTab 8/10 (vi.fn, all states)

### G-11: Boundary/Limit Testing — All Paths
- **When:** System enforces a limit (record count, file size, rate limit, quota)
- **Do:**
  - Test below limit → allowed
  - Test exactly at limit → allowed
  - Test above limit → rejected with specific error message (include numbers)
  - Test across ALL code paths that enforce the limit (not just one)
- **Why:** Limits often have off-by-one bugs. Testing one format but not others misses format-specific bypass.
- **Example:** Export service 500k limit tested across CSV, JSON, XLSX, CSV stream, JSON stream — all 5 formats
- **Source:** review 2026-02-15, ExportService — 9.5/10, boundary tests on every format

### G-12: Format Compliance Testing
- **When:** Code generates output in a standard format (CSV, JSON, XLSX, XML)
- **Do:** Test the spec's edge cases, not just happy path:
  - **CSV (RFC 4180):** commas in values → quoted, quotes in values → doubled (`""World""`), newlines → quoted, empty fields → empty string
  - **XLSX:** binary signature (PK zip: `0x50, 0x4B`), worksheet name, header bold, frozen panes, data types
  - **JSON:** valid parse, nested structures, null handling, encoding
  - **Streaming:** header only on empty, chunk accumulation via `collectStream` helper, valid parse of accumulated output
- **Source:** review 2026-02-15, ExportService — CSV RFC edge cases + XLSX binary/structural verification

### G-13: Cross-Format Consistency
- **When:** Same business logic applies across multiple output formats (CSV, JSON, XLSX, stream variants)
- **Do:** Test the shared logic (batching, filtering, column mapping) in EVERY format, not just one.
- **Anti-pattern:** Testing batching only in CSV and assuming XLSX works the same
- **Pattern:** Create a test matrix: `[format] × [behavior]` — batch size, record limit, empty data, column ordering
- **Source:** review 2026-02-15, ExportService — batching tested in CSV, JSON, XLSX, and both stream variants

### G-14: Fallback Chain Testing
- **When:** Function has sequential fallback logic (try A → try B → try C → default)
- **Do:** Test each step with all previous values missing:
  - A present → use A
  - A missing, B present → use B
  - A+B missing, C present → use C
  - All missing → default/null/error
- **Why:** Each link in the chain is a potential bug. Fallback to wrong level = wrong data shown to user.
- **Source:** review 2026-02-15, getSurveyColumns — text → qid → id → null fallback chain, each step tested

### G-15: Legacy Format Transformation Assertions
- **When:** Code transforms between legacy and modern formats (PHP↔TS, v1↔v2 API, int↔UUID)
- **Do:**
  - Field renaming: `sort → sortOrder`, `page_id → pageId` (exact assertions)
  - Type conversion: `1 → true`, `0 → false`, `'3.14' → 3.14` (PHP int booleans, string numbers)
  - Structure changes: flat → nested, array → map
  - Routing: batch vs single operation (with negative assertions — batch called + single NOT called)
  - Verify BOTH directions if adapter is bidirectional
- **Source:** review 2026-02-15, TRPCAdapters — 9/10, snake→camel, int→bool, entity_type→targetType, complex logic transform

### G-16: Stream Testing with Real Streams
- **When:** Code produces streaming output (Node.js ReadableStream, PassThrough, Response stream)
- **Do:**
  - Use real `PassThrough` stream, NOT mock stream — collect chunks via helper: `const chunks: Buffer[] = []; stream.on('data', c => chunks.push(c)); await finished(stream); return Buffer.concat(chunks).toString();`
  - Parse accumulated output to verify it's valid (JSON.parse for JSON stream, split lines for CSV)
  - Test empty data → header only (CSV) or empty array (JSON)
  - Test single item → no trailing comma / correct structure
  - Test multi-item → verify all items present
- **Anti-pattern:** Mocking the stream and just checking `.pipe()` was called — proves nothing about actual output
- **Source:** review 2026-02-15, ExportService — 9.5/10, collectStream helper, PassThrough → parse → verify

### G-17: Binary/Structural Output Verification
- **When:** Code generates binary format files (XLSX, PDF, ZIP, images)
- **Do:**
  - Verify binary signature (XLSX = PK zip: `0x50, 0x4B` first bytes)
  - Parse with real library (ExcelJS for XLSX, pdf-parse for PDF) — not just "file exists"
  - Assert structural elements: worksheet name, header row values, data row values
  - Assert formatting: bold headers, frozen panes, column widths, cell types
- **Why:** "File was created" doesn't catch corrupt output. Users get broken downloads in production.
- **Source:** review 2026-02-15, ExportService — XLSX PK signature + ExcelJS parse + worksheet name + bold + frozen panes

### G-18: Accessibility Assertions as First-Class Tests
- **When:** Interactive React component (table headers, form controls, navigation)
- **Do:**
  - Dedicated accessibility test section (not sprinkled in other tests)
  - `aria-sort="ascending"` on active sort column, `aria-sort="none"` on inactive
  - `tabIndex="0"` on focusable interactive elements
  - `role` attributes matching semantic purpose (columnheader, checkbox, button)
  - `aria-label` / `aria-checked` / `aria-expanded` for screen reader context
- **Why:** Accessibility bugs are invisible to sighted developers but break the app for screen reader users. Explicit assertions prevent regressions.
- **Source:** review 2026-02-15, OrderTableHeader — 9/10, dedicated a11y section with aria-sort, tabIndex, role verification

### G-19: Keyboard Navigation Parity
- **When:** UI element responds to click AND keyboard (Enter/Space)
- **Do:**
  - Test click → callback with correct args
  - Test Enter key → same callback with same args
  - Test Space key → same callback with same args (if applicable)
  - Use different elements per test to prove keyboard handling is universal, not hardcoded to one column/button
- **Why:** Keyboard-only users (accessibility, power users) need parity. Testing only click misses broken `onKeyDown` handlers.
- **Source:** review 2026-02-15, OrderTableHeader — sort via click, Enter, Space on different columns

### G-20: Combinatorial Input Coverage (Truth Table)
- **When:** Function has N boolean/enum parameters that combine to produce different outputs (e.g., `buildJustification(hasChange, r1, r2, r3)`)
- **Do:**
  - List all meaningful input combinations as a truth table
  - Test each combination: all-false, each-one-true, all-true, mixed
  - Name tests after the combination: `it('returns R1+R3 justification when R2 is empty')`
  - For N booleans: test at least 2N+1 combinations (not full 2^N, but all single-true + all-true + all-false + key mixes)
- **Why:** Combinatorial bugs (wrong `&&`/`||`, missing case) hide when you only test happy path + one edge case.
- **Source:** review 2026-02-15, QC Pipeline — buildJustification 8 tests covering all R1/R2/R3 combinations, wyczerpujące

### G-22: Roundtrip/Inverse Testing
- **When:** Code has paired serialize/deserialize, encode/decode, compress/decompress, or map/unmap functions
- **Do:**
  - Test identity: `deserialize(serialize(input))` === `input` for each supported type
  - Test unicode preservation (polish, CJK, emoji, RTL)
  - Test empty values (empty string, empty collection, null values in map)
  - Test type boundaries (string↔number key conversion, BigInt, Date)
- **Why:** Roundtrip tests catch asymmetric bugs where one direction works but the other loses data. Single-direction tests miss encoding/decoding mismatches.
- **Source:** review 2026-02-15, Translation utils — serializeTranslationMap → deserializeTranslationMap inverse test, unicode preservation, key type conversion

### G-23: Modular Test Suite Architecture (for large test files)
- **When:** Test file would exceed 250 lines, OR component/module has 10+ distinct behaviors to test
- **Do:**
  - Create orchestrator file: `*.test.ts` with mock setup + `describe` + registered suites
  - Create suite files: `*.happy-path.test.ts`, `*.edge-cases.test.ts`, etc. — each exports `registerXTests(ctx)`
  - Share typed context: `interface TestContext { mockDb: ..., mockApi: ..., mockLogger: ... }`
  - Keep vi.mock in orchestrator (Vitest hoisting requires it there)
  - `beforeEach(vi.clearAllMocks)` in orchestrator applies to all suites
- **Why:** 1000+ LOC test files are unnavigable. Modular suites with shared context keep tests organized without duplicating mock setup.
- **Source:** review 2026-02-15, Export generator orchestrator — 12 registered suites, typed ExportGeneratorComprehensiveTestContext, clean separation

### G-24: Suite-Specific Minimal Setup
- **When:** Test file has 5+ describe blocks or uses modular suite architecture (G-23)
- **Do:**
  - Happy-path suite: full setup (project + entries + context + analysis + glossary)
  - Focused suites: ONLY what they test (filtering = project + entries, context=null, analysis=null)
  - Each suite's `beforeEach` is independent — no shared mutable state across suites
- **Why:** Full setup in every suite creates false dependencies — a test "passes" because analysis data happens to be present, not because the code handles null analysis. Minimal setup proves the code works with only the required data.
- **Anti-pattern:** Copy-pasting the happy-path setup into every suite and wondering why 40 tests break when one fixture changes.
- **Source:** review 2026-02-15, Export generator comprehensive — happy-path uses full data, filtering/questionnaire/html use only project+entries

### G-25: Controlled Promise for Async Loading States
- **When:** Component shows loading/disabled state during async operation (save, delete, fetch)
- **Do:**
  - Create controlled promise: `let resolveSave!: Function; const savePromise = new Promise(r => { resolveSave = r; });`
  - Mock returns the unresolved promise: `onSave.mockReturnValue(savePromise)`
  - Trigger action → assert button is disabled / spinner shows (DURING async)
  - Resolve: `resolveSave()` → assert button re-enabled / spinner gone (AFTER async)
- **Why:** Testing only before/after misses the loading state entirely. Users see the loading state — it must work. `await` in test skips over it instantly.
- **Source:** review 2026-02-15, DictionaryTab 9/10 — controlled Promises test disabled state DURING save/delete/add

### G-26: Step Advancement Helpers for Multi-Step Flows
- **When:** UI has wizard/stepper (2+ steps) where later steps require completing earlier ones
- **Do:**
  - Create `advanceToStep2()`, `advanceToStep3()` helpers that perform all clicks/inputs to reach that step
  - Each step's tests call only the helper they need — no repeated setup
  - Test each step independently: render, advance, assert
  - Test back navigation: advance to step 3 → go back → state preserved
- **Why:** Without helpers, each step-3 test repeats 20+ lines of step-1 and step-2 interactions. Helpers keep tests focused on what they actually test.
- **Source:** review 2026-02-15, HolisticReviewModal 9/10 — advanceToReviewStep(), advanceToImportStep(), advanceToApplyStep()

### G-27: Dual Mode/Variant Testing
- **When:** Component has visual modes (standard/compact, desktop/mobile, text/icon-only) that show same functionality differently
- **Do:**
  - Test BOTH modes with same scenarios: buttons exist, callbacks fire, state changes reflected
  - Verify mode-specific rendering: standard → text labels, minimalistic → icons only
  - Verify mode-specific behavior if any (e.g., mobile → hamburger menu, desktop → sidebar)
- **Why:** Mode-specific bugs are common — a button works in standard mode but is missing in compact mode because the conditional rendering is wrong.
- **Source:** review 2026-02-15, AgentReviewActions 9.5/10 — standard (text buttons) vs minimalistic (icon-only), both modes tested with full state combinations

### G-28: it.each Parameterization for Same-Behavior Variants
- **When:** 3+ tests differ only in a single enum/status value but assert identical behavior (e.g., multiple HTTP statuses that all return 200)
- **Do:**
  - Extract into `it.each(['submitted', 'under_review', 'approved', 'paid'])('returns 200 when status is %s', ...)`
  - Keep unique-behavior tests separate (don't force-parameterize tests with different assertions)
  - Use descriptive `%s` / `%i` / `%j` placeholders so test names are readable in output
- **Why:** Copy-pasted tests with one value changed are hard to maintain and hide the intent ("all these behave the same"). `it.each` communicates that intent explicitly.
- **Source:** review 2026-02-16, proofreading public route — 4 nearly identical status tests → `it.each` reduces to 1

### G-30: Structural Pattern Assertions (regex/SQL/URL)
- **When:** Code generates dynamic patterns — regex, SQL LIKE expressions, URL patterns, query strings
- **Do:**
  - Use `toMatch(/structural-regex/)` to verify the pattern has correct operators/delimiters without hardcoding the exact string
  - Import the real helper function (e.g., `escapeLikePattern`) in the test instead of hardcoding the expected output
  - Assert structure, not exact value: `expect(firstCall[2]).toMatch(/\[\^[>&]\]/)` verifies tag boundary regex without coupling to specific content
- **Why:** Exact string matching is fragile for generated patterns. Structural assertions catch real bugs (wrong operator, missing boundary) while tolerating legitimate content changes.
- **Source:** review 2026-02-16, project-search — `escapeLikePattern` imported in test + `toMatch` for regex structure verification

### G-29: Symmetric Positive/Negative Coverage
- **When:** Component/function has boolean conditions or feature flags that show/hide behavior
- **Do:**
  - For every "shows X when Y" test, add "does NOT show X when not-Y"
  - For every "calls handler when condition" test, add "does NOT call handler when no condition"
  - Name pairs symmetrically: `it('shows clear button when query is not empty')` + `it('does not show clear button when query is empty')`
- **Why:** Testing only the positive path misses regressions where the condition is accidentally removed (element always shows). The negative test catches that.
- **Source:** review 2026-02-16, SearchInput 9/10 — exemplary symmetric coverage of all variants (loading/not, meta/no-meta, minimalistic/standard)

### G-21: Crash-Resume Defensive Testing
- **When:** Pipeline/workflow can be interrupted and resumed from partial state (partial progress, checkpoint/resume, crash recovery)
- **Do:**
  - Test resume with null result (never started)
  - Test resume with null sub-fields (started but crashed mid-way: `final_report: null`)
  - Test resume with empty arrays (started, no entries yet)
  - Test resume with partial data (some entries filled, others null)
  - Verify each case returns sensible defaults, not crashes
- **Why:** Long-running pipelines crash. The resume path must handle every possible partial state, not just "completed" or "not started".
- **Source:** review 2026-02-15, QC Pipeline — loadExistingResults tests null result, null final_report, empty entries, partial data

---

## Gap Patterns — Check These

### P-1: Input Boundaries — Multi-field params
- **When:** Function accepts an object with 3+ fields, OR 3+ separate parameters
- **Tests:**
  - Each field/param as `null`
  - Each field/param as `undefined`
  - String params as empty string `""`
  - Entire params object as `null` / `undefined`
  - Document expected behavior (throw? return false? return default?)
- **Source:** review 2026-02-15, `paypal-signature.ts` — 10-field params object had zero null tests

### P-2: Delegation to External API
- **When:** Function calls an external service and maps the response to a return value
- **Tests:**
  - Exact response mapping: what API returns → what function returns (not just true/false, but WHY true/false)
  - Unexpected API response (unknown status, empty body, HTML instead of JSON)
  - API timeout / network error
  - API returns success with unexpected shape
- **Source:** review 2026-02-15, `paypal-signature.ts` — no test for how `status === 'SUCCESS'` maps to boolean

### P-3: Boolean Return Functions
- **When:** Function returns `boolean`
- **Tests:**
  - At least 1 test for each path that returns `true`
  - At least 1 test for each path that returns `false`
  - If function has try/catch that returns `false` on error → test that the catch path returns `false` (not `undefined`)
- **Source:** review 2026-02-15, `paypal-signature.ts` — catch returns false but not explicitly tested

### P-4: Repeated Test Boilerplate
- **When:** Same setup/helper pattern appears 3+ times in a test file
- **Action:** Extract into a helper function (e.g., `async function runWithTimers(fn)`)
- **Source:** review 2026-02-15, `paypal-signature.test.ts` — `vi.advanceTimersByTimeAsync(0)` repeated 8x

### P-5: Mock Argument Verification — CalledWith, not just CalledTimes
- **When:** Test mocks an external store (Redis, DB, KV, queue) or external service call
- **Tests:**
  - `toHaveBeenCalledWith(expectedKey, expectedValue, ...)` — not just `toHaveBeenCalledTimes(1)`
  - Verify the key format/pattern (e.g., `expect.stringContaining('session-1')`)
  - Verify TTL / expiration values match config
  - Verify serialized value shape (what exactly is stored?)
  - Verify cleanup calls (`.del`) target the correct key
- **Why:** `CalledTimes(1)` proves the call happened but not that it did the right thing. Key format change, TTL change, or wrong value serialization all pass `CalledTimes` silently.
- **Source:** review 2026-02-15, idempotency interceptor — `redis.set` and `redis.setex` verified by count only, no key/TTL/value check

### P-6: Infrastructure Failure — Fail-open vs Fail-closed
- **When:** Function depends on infrastructure (Redis, DB, queue, cache) that can be unavailable
- **Tests:**
  - Infrastructure throws error (connection refused, timeout) → does function fail-open (proceed) or fail-closed (block)?
  - Infrastructure returns garbage (unparseable JSON, HTML error page, empty string)
  - Infrastructure returns null/undefined unexpectedly
  - Document the expected behavior explicitly in test name: `it('fails open when Redis is down')`
- **Why:** "Redis is down" is a real production scenario. If the test doesn't cover it, nobody knows if the system degrades gracefully or crashes.
- **Source:** review 2026-02-15, idempotency interceptor — no test for Redis unavailable, unknown if fail-open or fail-closed

### P-7: Config Branch Coverage
- **When:** Function accepts a config/options object with boolean flags or mode switches
- **Tests:**
  - Test both `true` and `false` for each boolean flag
  - Test default behavior when flag is omitted
  - Test interaction between flags if multiple exist
- **Source:** review 2026-02-15, idempotency interceptor — `requireKey: true` never tested, only `false` path exercised

### P-8: Hash/Serialization Stability
- **When:** Function produces a hash, digest, or serialized output from structured input
- **Tests:**
  - Same input → same output (deterministic)
  - Input with reordered keys/arrays → same output (order-independent, if expected)
  - Minimal change in input → different output (sensitivity)
  - Test the function in isolation, not just as a helper in other tests
- **Source:** review 2026-02-15, idempotency interceptor — `computeSubmitPayloadHash` used in tests but never tested for order stability

### P-9: Discriminating Mock Return Values
- **When:** Mock maps multiple different inputs to the same output (e.g., `uuidToInt` always returns `123`)
- **Problem:** If every entity gets id `123`, test can't distinguish page from question from rule. Wrong entity used = test still passes.
- **Fix:** Make mock return different values per input:
  ```typescript
  uuidToInt: vi.fn((uuid: string) => {
    const map: Record<string, number> = { 'p-1': 10, 'q-1': 20, 'r-1': 30 };
    return map[uuid] ?? 0;
  })
  ```
- **Test:** Then assert `expect(result.id).toBe(10)` (page), `expect(result.questions[0].id).toBe(20)` (question)
- **Source:** review 2026-02-15, transformPage — 6.5/10, uuidToInt always 123 hid entity mapping bugs

### P-10: React Testing Weak Patterns (3 traps)
- **When:** Writing React component tests with Testing Library
- **Trap 1 — toBeTruthy() on queries:** `expect(screen.getByText('X')).toBeTruthy()` is redundant — `getByText` already throws if not found. Use `toBeInTheDocument()` or just call `screen.getByText('X')` alone.
- **Trap 2 — Static module mock:** `vi.mock('./hook', () => ({ useHook: () => fixedValue }))` locks you into one state. Use `vi.fn()` + per-test `mockReturnValue` (see G-10).
- **Trap 3 — Date.now() in mock data:** Without `vi.useFakeTimers()` + `vi.setSystemTime()`, time-relative displays ("2 min ago") are flaky.
- **Source:** review 2026-02-15, SaveIndicator 4/10 (all 3 traps), LogicRulePanel 7/10 (trap 1), TemplateTab 8/10 (trap 1 only)

### P-11: Partial Structure Assertions — expect.any() Hiding Shape
- **When:** Test uses `expect.any(Object)` or `expect.objectContaining` on important nested structures (includes, select, where clauses)
- **Problem:** `include: expect.any(Object)` passes even if include is completely wrong. Critical for ORM queries where include determines what data is loaded.
- **Fix:** At least one test per method should assert the FULL structure:
  ```typescript
  expect(prisma.findFirst).toHaveBeenCalledWith({
    where: { id: 'x', organizationId: 'org-1' },
    include: { createdBy: { select: { id: true, name: true } }, _count: { select: { surveys: true } } },
  });
  ```
- **Acceptable:** `expect.any(Object)` on non-critical includes AFTER one test already verifies the full shape
- **Source:** review 2026-02-15, TemplateService — 8× `expect.any(Object)` on includes

### P-12: Incomplete Interaction Flows
- **When:** Test opens a dialog/modal/form but doesn't test the submit action
- **Problem:** Proves the UI triggers but not that the action completes. "Dialog opens" is half a test.
- **Required flow:** trigger → dialog opens → fill/confirm → action called with correct args → success/error feedback
- **Check:** For every dialog/modal open assertion, there MUST be a corresponding submit test
- **Source:** review 2026-02-15, TemplateTab — "Create Template" opens dialog but save submit untested; LogicRulePanel — edit click untested

### P-13: Duplicate/Conflicting Input Data
- **When:** Function processes a collection (array of objects, map of records)
- **Tests:**
  - Two items with same key/ID — which wins? (first? last? merge? error?)
  - Empty collection → expected behavior
  - Single item → no off-by-one
- **Why:** Databases can return duplicates from joins. APIs can send repeated items. The test should document the dedup behavior.
- **Source:** review 2026-02-15, buildAnswerMapFromResponses — no test for duplicate questionId in responses

### P-14: Negative Side-Effect Verification
- **When:** Function conditionally calls a side effect (e.g., `expire` only on first hit, `invalidate` only on success)
- **Tests:**
  - Positive: side effect called in correct conditions (`expire` when count === 1)
  - **Negative: side effect NOT called in other conditions** (`expire` NOT called when count > 1)
- **Why:** Without the negative test, removing the conditional (always calling the side effect) doesn't break any test
- **Source:** review 2026-02-15, BurstGuard — `expire` tested on first hit but no test proving it's skipped on subsequent hits

### P-15: Pagination Beyond Page 1
- **When:** Service implements pagination (skip/take, offset/limit, cursor)
- **Tests:**
  - Default page (page 1, default limit)
  - Page > 1 — verify `skip` math: `(page - 1) * limit`
  - Limit cap — verify max limit enforced
  - Return metadata: `{ page, totalPages, total }` with correct values
- **Source:** review 2026-02-15, TemplateService — only page 1 tested, no test for `skip: 40` on page 3

### P-16: Unmapped/Unknown ID Handling
- **When:** System maps between ID formats (UUID↔int, slug↔id, legacy↔modern)
- **Tests:**
  - Known ID → correct mapping
  - Unknown/unmapped ID → what happens? (throw? return undefined? return 0?)
  - Stale ID (was mapped, then mapping cleared) → behavior documented
- **Why:** Legacy systems pass stale IDs. APIs send unknown IDs. The mapping layer should have defined behavior, not silent corruption.
- **Source:** review 2026-02-15, TRPCAdapters — no test for int ID that was never seeded via seedUuid()

### P-17: Loading State Scoping
- **When:** Component shows loading/disabled state for a specific entity (order, item, row)
- **Tests:**
  - `loadingId="order-1"` → button for order-1 is disabled
  - `loadingId="order-1"` → button for order-OTHER is **still enabled** (scoping test)
  - `loadingId=undefined` → all buttons enabled (default state)
- **Why:** Global loading state breaks UX — user can't interact with other items while one is processing. Test BOTH matching and non-matching entity.
- **Source:** review 2026-02-15, OrderTypeBadge — resendingOrderId tested for matching order, but missing test for non-matching order staying enabled

### P-18: Incomplete Enum/Status Coverage
- **When:** Component/function handles a string/number enum (status, type, method)
- **Tests:**
  - Test EVERY known enum value (not just terminal states success/failed — include intermediate: pending, processing, queued)
  - Test unknown/unexpected value: `reward_method: "unknown"`, `status: "new_value_from_api"` → graceful fallback
  - Test null/undefined → fallback or error
- **Why:** APIs evolve — new enum values arrive. Missing intermediate state test = surprise blank UI in production. Unknown value test = crash prevention.
- **Source:** review 2026-02-15, OrderTypeBadge — tested success/failed/returned/blocked but missing pending; no test for unknown reward_method

### P-19: Semantic Queries over CSS Class Selectors
- **When:** Test detects elements by CSS class (`.querySelector('.text-green-600')`, `.querySelector('.bg-red-500')`)
- **Problem:** Tailwind class changes (green-600 → green-500), wrapper div changes, or class reorganization breaks tests for wrong reasons.
- **Fix:** Prefer in order:
  1. `getByRole('img', { name: /check/ })` — semantic
  2. `getByLabelText('Email sent')` — aria
  3. `getByTestId('status-icon-success')` — explicit (add to component if needed)
  4. `.querySelector('.text-green-600')` — last resort (add comment: "fragile, needs data-testid")
- **When CSS is OK:** Verifying Tailwind styling intentionally (badge color test, active state style) — that's testing styling, not detecting elements.
- **Source:** review 2026-02-15, OrderTypeBadge — icon detection via `.querySelector('.text-green-600')`, fragile to color changes

### P-20: Dead/Self-Referential Tests (🔴 when functions)
- **When:** Test defines local constants, objects, OR functions and asserts against them — not importing from production code
- **Severity levels:**
  - 🟡 **Constants/objects:** `const X = { MAX: 600 }; expect(X.MAX).toBe(600)` — test proves nothing but damage is limited
  - 🔴 **Copied functions:** `function serialize(map) { return Object.fromEntries(map); }` with comment `// will be extracted from lines 122-144` — test LOOKS comprehensive (roundtrip, unicode, edge cases) but verifies the COPY, not production code. Gives false sense of security. If production code changes, test still passes.
- **Detection:** If removing the test changes nothing about production code coverage → it's dead.
- **Fix:** Replace local definitions with imports from production module. If module doesn't exist yet (pre-refactoring), mark tests as `// TODO: replace with import after extraction` and flag as NOT VERIFIED in review.
- **Source:** review 2026-02-15, QC Pipeline (constants, 🟡) + Translation utils 6.5/10 (copied functions, 🔴 — 11 tests on local serializeTranslationMap that don't verify production code)

### P-21: Mock Component Prop Drift
- **When:** React test mocks child components with inline JSX: `vi.mock('./Header', () => ({ Header: vi.fn(({ onCopy }) => <div>...</div>) }))`
- **Problem:** If real `Header` renames `onCopy` to `onCopyProject`, mock still destructures old prop name — test passes but production breaks. Mock and reality drift apart silently.
- **Fix:** After rendering, verify the mock was called with expected props:
  ```typescript
  expect(Header).toHaveBeenCalledWith(
    expect.objectContaining({ onCopy: expect.any(Function) }),
    expect.anything() // ref
  );
  ```
  This catches prop renames because `objectContaining({ onCopy: ... })` fails when prop is now `onCopyProject`.
- **Source:** review 2026-02-15, Project Page orchestrator — 20+ mock components, none verified via CalledWith

### P-23: Weak Assertions on Known Data
- **When:** Test has deterministic setup (known number of entries, known mock returns) but uses weak assertions
- **Problem patterns:**
  - `toBeGreaterThan(0)` when test creates exactly 3 entries → should be `toBe(3)`
  - `toBeTruthy()` when exact value is known → should be `toBe(expectedValue)`
  - `toHaveLength(expect.any(Number))` when array content is deterministic
- **When weak IS OK:** Smoke tests ("doesn't crash with 1000 entries"), non-deterministic data, testing existence not value
- **Fix:** In tests with known setup data, assert exact values. Reserve `toBeGreaterThan` for genuine lower-bound checks.
- **Source:** review 2026-02-15, Export generator — happy-path creates 1 pattern but asserts `toBeGreaterThan(0)` instead of `toBe(1)`. Integration test does it right: `toBe(5)`.

### P-24: Contradictory Test Assertions Across Suites
- **When:** Multiple test files/suites cover the same function/feature
- **Problem:** Suite A says `reviewRound option is ignored`. Suite B says `reviewRound overrides history`. Both pass — one is wrong.
- **Detection:** During review, search for the same feature tested in multiple places. Compare assertions — if they claim opposite behavior, flag immediately.
- **Fix:** Run the production code to determine actual behavior. Delete the wrong test. Add comment to surviving test: `// verified: reviewRound DOES override history (not ignored)`
- **Source:** review 2026-02-15, Export generator — original test vs comprehensive test contradicted on reviewRound behavior

### P-25: Hardcoded Mock Call Indices
- **When:** Test accesses specific mock call by index: `mockFetch.mock.calls[2][1].body`
- **Problem:** If call order changes (new call added before, conditional call removed), index shifts and test breaks for wrong reason — or worse, silently asserts against wrong call.
- **Fix:** Find the call by characteristic, not position:
  ```typescript
  const importCall = mockFetch.mock.calls.find(
    ([url]) => url.includes('/import')
  );
  expect(JSON.parse(importCall![1].body)).toMatchObject({ reviewRound: 2 });
  ```
- **When index IS OK:** Sequential protocol tests where call order IS the thing being tested (e.g., "auth happens before data fetch")
- **Source:** review 2026-02-15, HolisticReviewModal 9/10 — `mockFetch.mock.calls[2][1].body` fragile to call order changes

### P-26: Test Name Claims Unverified Behavior
- **When:** Test name describes specific behavior but body doesn't actually verify it
- **Variants:**
  - **Empty body:** `it('should handle delete on non-existent project', () => { /* comment only */ })` — zero assertions
  - **Wrong assertions:** `it('should handle rapid filter changes')` but test doesn't verify debouncing, just makes 2 calls
  - **Smoke only:** `it('should handle 1000 entries', () => { ... expect(result).toBeGreaterThan(0) })` — name implies performance/correctness, assertion only checks "didn't crash"
- **Fix:** Test name must match what assertions prove. If you can't write the assertion yet, use `it.todo('should handle rapid filter changes')` — honest about the gap.
- **Source:** review 2026-02-15, ProjectsPage 8/10 — "handle delete on non-existent project" (empty), "handle rapid filter changes" (no debounce verification)

### P-27: Silent False-Positive via try/catch in Assertions
- **When:** Test uses try/catch to verify that a function throws an error
- **Problem:** If the function does NOT throw, execution skips the catch block entirely — test passes with zero assertions. Silent false-positive.
  ```typescript
  // WRONG — passes silently if validateUpdate doesn't throw:
  try {
    await service.validateUpdate(1, { field: 'value' });
  } catch (e) {
    expect(e.message).toContain('1 translated segment');
  }
  ```
- **Fix:** Use `rejects.toThrow` or catch-then-assert with explicit fail:
  ```typescript
  // CORRECT — fails if no error thrown:
  await expect(service.validateUpdate(1, { field: 'value' }))
    .rejects.toThrow('1 translated segment');

  // ALT — explicit catch with fail guard:
  const error = await service.validateUpdate(1, { field: 'value' }).catch(e => e);
  expect(error).toBeInstanceOf(Error);
  expect(error.message).toContain('1 translated segment');
  ```
- **Source:** review 2026-02-16, project-services — try/catch assertions for singular/plural validation messages

### P-28: Phantom Mocks (Untested Mock Setup)
- **When:** `beforeEach` sets up a mock (e.g., `mockDemoLink.findUnique.mockResolvedValue(null)`) but no test in the suite exercises that code path
- **Problem:** The mock signals that a code path exists (demo links, fallback behavior, optional feature) but the path is invisible — zero coverage. If the real code breaks for that path, no test catches it.
- **Detection:** For each mock in `beforeEach`, search the test suite for at least one test that depends on it. If no test changes or asserts against it → phantom mock.
- **Fix:** Either write a test that exercises the path, or remove the mock (dead setup = noise).
- **Source:** review 2026-02-16, proofreading public route — `proofreadingDemoLink.findUnique` mocked to null in beforeEach, zero tests for demo link path

### P-29: Type Hack Proliferation in Mocks (`as never`/`as any`)
- **When:** Multiple tests use `as never` or `as any` to satisfy Prisma/DB/complex types when mocking
- **Problem:** Scattered `as never` casts are noisy, hide type mismatches, and make tests fragile. If the real type changes, the cast swallows the error.
- **Fix:** Centralize in a typed mock helper:
  ```typescript
  // Factory returns typed partial — cast is in ONE place:
  function createSessionRecord(overrides?: Partial<ProofreadingSession>) {
    return { id: 'sess-1', status: 'pending', ...overrides } as ProofreadingSession;
  }

  // Or generic helper for any Prisma mock:
  function mockDBReturn<T>(mock: ReturnType<typeof vi.fn>, value: Partial<T>) {
    mock.mockResolvedValue(value as T);
  }
  ```
- **Source:** review 2026-02-16, proofreading public route — `as never` in 6+ places, reduced to 1 via factory

### P-31: Inconsistent Edge Case Coverage Across Sibling Methods
- **When:** Module has 3+ similar methods (e.g., `searchById`, `searchByText`, `searchByTags`) that share a common interface or pattern
- **Problem:** Some methods have edge case tests (empty input, null, boundary) while others don't. Creates a false sense of complete coverage.
- **Detection:** Create a matrix of `[method × edge case]`. If any cell is empty for a method that logically should handle that case → gap.
- **Fix:** Fill the matrix. If `searchById` has an empty-query test, `searchByText` and `searchByTags` should too. Either test the behavior or document why it's intentionally different.
- **Source:** review 2026-02-16, project-search — searchById and searchByTags have empty query tests, searchByText doesn't

### P-32: Untested Query Builder Variants (flag × SQL operator)
- **When:** Function builds different SQL/queries based on boolean flag combinations (e.g., `caseSensitive × wholeSegment` → 4 variants with different operators: `~` vs `~*`, `LIKE` vs `ILIKE`)
- **Problem:** Each flag combination produces fundamentally different SQL. Testing only one combination leaves 3 others unverified — a wrong operator in one branch silently corrupts results.
- **Tests:**
  - `caseSensitive=false, wholeSegment=false` → `~*` (case-insensitive regex)
  - `caseSensitive=true, wholeSegment=false` → `~` (case-sensitive regex)
  - `caseSensitive=false, wholeSegment=true` → `ILIKE` (case-insensitive exact)
  - `caseSensitive=true, wholeSegment=true` → `LIKE` (case-sensitive exact)
  - Use `it.each` (see G-28) to keep it DRY
- **Related:** G-20 (combinatorial coverage), P-7 (config branch coverage) — this is the specific DB/query-builder variant
- **Source:** review 2026-02-16, project-search — searchByText has 4 query variants, zero tested

### P-30: fireEvent vs userEvent for Input Components
- **When:** Testing input components (text fields, search, forms) with `@testing-library/react`
- **Problem:** `fireEvent.change(input, { target: { value: 'x' } })` sets the value in one shot. It skips keystroke-by-keystroke simulation, so it misses bugs in: debounced inputs, controlled components with per-keystroke validation, `onChange` handlers that depend on previous value.
- **Fix:** Use `@testing-library/user-event` for realistic input:
  ```typescript
  import userEvent from '@testing-library/user-event';
  const user = userEvent.setup();
  await user.type(input, 'new value');  // fires keyDown, keyPress, input, keyUp per char
  await user.clear(input);              // realistic clear
  ```
- **When fireEvent IS OK:** Testing a single change event (dropdown select, checkbox toggle) where keystroke simulation is irrelevant.
- **Source:** review 2026-02-16, SearchInput 9/10 — fireEvent works but misses potential debounce bugs

### P-22: Zero-Denominator Edge Case
- **When:** Function computes average, percentage, ratio, or any division where denominator comes from input (count, total, length)
- **Tests:**
  - Zero denominator → verify result is 0 (not NaN or Infinity)
  - Empty collection → verify aggregation returns sensible default
  - Assert the exact value: `expect(result.confidence).toBe(0)` — not just "doesn't throw"
- **Why:** `Math.round(0/0 * 100)` = `NaN`. `100/0` = `Infinity`. Both propagate silently through JSON serialization and UI, showing "NaN%" to users.
- **Source:** review 2026-02-15, Translation utils — mergeEvalResults([], 0) → confidence = NaN, test didn't check the value

---

## Adding New Patterns (instructions for agent)

When user gives feedback about test quality (e.g., "test was missing X", "this pattern was good"), do ALL 3 steps:

### 1. Create the pattern entry

- Good pattern → `G-{next}`, gap pattern → `P-{next}`
- Include: When, Do/Tests, Why (1 sentence), Source (date + file + what happened)
- Keep it concise — 5-8 lines max

### 2. Update the lookup table (Step 2 in "How to use")

Decide which code types the new pattern applies to and add its ID to the table.
If it applies to ALL types → add to the "Always apply" line instead.

### 3. Check if a new code type is needed

If the pattern applies to a code category not yet in the table (e.g., WEBSOCKET, CRON, CLI), add a new row to both the classification table (Step 1) and the lookup table (Step 2).
