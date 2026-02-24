# Test Patterns — Catalog

> Pattern definitions referenced by ID from the lookup table in `~/.claude/test-patterns.md`.
> Agent: grep this file for matched pattern IDs only -- do NOT read the entire file.
> Domain-specific patterns are in separate files (see core for pointers).

---

## Good Patterns -- Replicate These

### G-1: State Machine Coverage
- **When:** Code implements a state machine, interceptor, middleware, or multi-step workflow
- **Do:** One dedicated test per state/transition. Name tests after the state: `it('replays cached response when duplicate key with same payload')`
- **Why:** Proves every path through the machine is exercised. Missing state = missing test.
- **Source:** review 2026-02-15, idempotency interceptor -- all 5 states + passthrough covered

### G-2: Assert Behavior, Not Structure
- **When:** Always
- **Do:**
  - `toEqual(exactValue)` over `toMatchObject(partial)` -- proves the full shape
  - `not.toHaveBeenCalled()` to prove something was prevented (e.g., handler NOT called on cache replay)
  - `toHaveBeenCalledTimes(1)` + `toHaveBeenCalledWith(...)` together -- proves both "did it happen" and "was it correct"
- **Anti-pattern:** `toMatchObject` when you know the full expected value -- hides unexpected extra fields
- **Source:** review 2026-02-15, idempotency interceptor -- `toEqual` with exact values, `not.toHaveBeenCalled` proving cache prevented execution

### G-3: Realistic Test Data -- Use Real Functions
- **When:** Code under test uses a helper function (hasher, serializer, formatter)
- **Do:** Import and use the real function in test setup instead of hardcoding its output. E.g., `computeSubmitPayloadHash(payload)` in test instead of `'abc123'`.
- **Why:** If the helper changes behavior, the test breaks -- which is what you want. Hardcoded values create a gap between test and reality.
- **Source:** review 2026-02-15, idempotency interceptor -- used real hash function in replay/conflict tests

### G-4: Clean Factory Helpers with Overrides
- **When:** Test file has 3+ tests that need similar setup objects
- **Do:** Create `createX(overrides?)` factories that return defaults merged with overrides. Fresh mocks per test (inline or in `beforeEach`).
- **Example:** `const config = createConfig({ ttl: 600 })` -- default TTL overridden for one test
- **Anti-pattern:** Copy-pasting setup objects across tests, or one shared mutable mock
- **Source:** review 2026-02-15, idempotency interceptor -- `createConfig`, `createContext`, `createHandler` -- clean, composable

### G-5: Pure Functions = Zero Mocks
- **When:** Function under test is a pure transformation (input -> output, no side effects)
- **Do:** Import real function, pass real data, assert on output with `toEqual`. No mocks at all.
- **Why:** Mocks on pure functions add complexity without value. Real input/output tests are deterministic, fast, and catch real bugs.
- **Example:** `buildAnswerMapFromResponses(responses, questionIds)` -> test null->undefined, empty->undefined, Decimal->number -- all with `toEqual`
- **Source:** review 2026-02-15, buildAnswerMapFromResponses -- 9/10, zero mocks, complete edge case coverage

### G-6: Security Boundary / Multi-Tenant Guard
- **When:** Function has authorization/ownership checks (orgId, userId, role)
- **Do:**
  - Test cross-org rejection: call with `organizationId: 'other-org'` -> throws Access Denied
  - Verify the guarded action was NOT executed: `mockService.dangerousAction.not.toHaveBeenCalled()`
  - Test that the check happens BEFORE the action (order matters)
- **Why:** Security regression = data leak. These tests are cheap to write and critical to have.
- **Source:** review 2026-02-15, cache invalidation -- cross-org Access Denied + verify invalidate NOT called

### G-7: Destructive Action Confirmation Flow
- **When:** UI has destructive actions (delete, archive, close) that require user confirmation
- **Do:**
  - Non-destructive action -> immediate call (no dialog)
  - Destructive action -> confirmation dialog opens
  - Confirm -> action executes
  - Cancel -> action NOT executed (`not.toHaveBeenCalled`)
  - Test dialog text matches severity (e.g., "cannot be undone" for irreversible)
- **Source:** review 2026-02-15, StatusManager -- 9/10, destructive vs non-destructive transitions, confirm + cancel paths

### G-8: Permission-Based Conditional Rendering
- **When:** UI shows/hides elements based on user permissions or roles
- **Do:**
  - Permission granted -> element visible + functional
  - Permission denied -> `queryByX` returns `null` (element absent, not just hidden/disabled)
  - Verify the data/content still renders (user can SEE but not ACT)
- **Source:** review 2026-02-15, StatusManager -- canEditSurveyStatus=false -> buttons null, status text visible

### G-9: ORM/Query Building Assertions
- **When:** Service builds database queries (Prisma, TypeORM, Sequelize, Django ORM)
- **Do:**
  - Assert exact `where` clause structure (not just `expect.any(Object)`)
  - Assert `orderBy`, `take`, `skip` for pagination
  - Assert `include`/`select` structure for at least one key method
  - Test search filter -> `{ contains: term, mode: 'insensitive' }`
  - Test default sorting vs explicit sorting
- **Source:** review 2026-02-15, TemplateService -- 8.5/10, exact Prisma where/orderBy verified per test

### G-10: Per-Test Mock Override via vi.fn()
- **When:** React component depends on a hook/context with multiple possible states
- **Do:** Mock the hook with `vi.fn()` at module level, then override per test with `mockReturnValue`. Never use static module-level mock with fixed return value.
- **Anti-pattern:** `vi.mock('./hooks', () => ({ useHook: () => fixedValue }))` -- locks you into one state, can't test other states without refactoring the test
- **Pattern:**
  ```typescript
  vi.mock('./hooks', () => ({ useHook: vi.fn() }));
  // per test:
  vi.mocked(useHook).mockReturnValue({ status: 'loading' });
  ```
- **Source:** review 2026-02-15, SaveIndicator 4/10 (static mock, 1/4 states) vs TemplateTab 8/10 (vi.fn, all states)

### G-11: Boundary/Limit Testing -- All Paths
- **When:** System enforces a limit (record count, file size, rate limit, quota)
- **Do:**
  - Test below limit -> allowed
  - Test exactly at limit -> allowed
  - Test above limit -> rejected with specific error message (include numbers)
  - Test across ALL code paths that enforce the limit (not just one)
- **Why:** Limits often have off-by-one bugs. Testing one format but not others misses format-specific bypass.
- **Example:** Export service 500k limit tested across CSV, JSON, XLSX, CSV stream, JSON stream -- all 5 formats
- **Source:** review 2026-02-15, ExportService -- 9.5/10, boundary tests on every format

### G-12: Format Compliance Testing
- **When:** Code generates output in a standard format (CSV, JSON, XLSX, XML)
- **Do:** Test the spec's edge cases, not just happy path:
  - **CSV (RFC 4180):** commas in values -> quoted, quotes in values -> doubled (`""World""`), newlines -> quoted, empty fields -> empty string
  - **XLSX:** binary signature (PK zip: `0x50, 0x4B`), worksheet name, header bold, frozen panes, data types
  - **JSON:** valid parse, nested structures, null handling, encoding
  - **Streaming:** header only on empty, chunk accumulation via `collectStream` helper, valid parse of accumulated output
- **Source:** review 2026-02-15, ExportService -- CSV RFC edge cases + XLSX binary/structural verification

### G-13: Cross-Format Consistency
- **When:** Same business logic applies across multiple output formats (CSV, JSON, XLSX, stream variants)
- **Do:** Test the shared logic (batching, filtering, column mapping) in EVERY format, not just one.
- **Anti-pattern:** Testing batching only in CSV and assuming XLSX works the same
- **Pattern:** Create a test matrix: `[format] x [behavior]` -- batch size, record limit, empty data, column ordering
- **Source:** review 2026-02-15, ExportService -- batching tested in CSV, JSON, XLSX, and both stream variants

### G-14: Fallback Chain Testing
- **When:** Function has sequential fallback logic (try A -> try B -> try C -> default)
- **Do:** Test each step with all previous values missing:
  - A present -> use A
  - A missing, B present -> use B
  - A+B missing, C present -> use C
  - All missing -> default/null/error
- **Why:** Each link in the chain is a potential bug. Fallback to wrong level = wrong data shown to user.
- **Source:** review 2026-02-15, getSurveyColumns -- text -> qid -> id -> null fallback chain, each step tested

### G-15: Legacy Format Transformation Assertions
- **When:** Code transforms between legacy and modern formats (PHP<->TS, v1<->v2 API, int<->UUID)
- **Do:**
  - Field renaming: `sort -> sortOrder`, `page_id -> pageId` (exact assertions)
  - Type conversion: `1 -> true`, `0 -> false`, `'3.14' -> 3.14` (PHP int booleans, string numbers)
  - Structure changes: flat -> nested, array -> map
  - Routing: batch vs single operation (with negative assertions -- batch called + single NOT called)
  - Verify BOTH directions if adapter is bidirectional
- **Source:** review 2026-02-15, TRPCAdapters -- 9/10, snake->camel, int->bool, entity_type->targetType, complex logic transform

### G-16: Stream Testing with Real Streams
- **When:** Code produces streaming output (Node.js ReadableStream, PassThrough, Response stream)
- **Do:**
  - Use real `PassThrough` stream, NOT mock stream -- collect chunks via helper: `const chunks: Buffer[] = []; stream.on('data', c => chunks.push(c)); await finished(stream); return Buffer.concat(chunks).toString();`
  - Parse accumulated output to verify it's valid (JSON.parse for JSON stream, split lines for CSV)
  - Test empty data -> header only (CSV) or empty array (JSON)
  - Test single item -> no trailing comma / correct structure
  - Test multi-item -> verify all items present
- **Anti-pattern:** Mocking the stream and just checking `.pipe()` was called -- proves nothing about actual output
- **Source:** review 2026-02-15, ExportService -- 9.5/10, collectStream helper, PassThrough -> parse -> verify

### G-17: Binary/Structural Output Verification
- **When:** Code generates binary format files (XLSX, PDF, ZIP, images)
- **Do:**
  - Verify binary signature (XLSX = PK zip: `0x50, 0x4B` first bytes)
  - Parse with real library (ExcelJS for XLSX, pdf-parse for PDF) -- not just "file exists"
  - Assert structural elements: worksheet name, header row values, data row values
  - Assert formatting: bold headers, frozen panes, column widths, cell types
- **Why:** "File was created" doesn't catch corrupt output. Users get broken downloads in production.
- **Source:** review 2026-02-15, ExportService -- XLSX PK signature + ExcelJS parse + worksheet name + bold + frozen panes

### G-18: Accessibility Assertions as First-Class Tests
- **When:** Interactive React component (table headers, form controls, navigation)
- **Do:**
  - Dedicated accessibility test section (not sprinkled in other tests)
  - `aria-sort="ascending"` on active sort column, `aria-sort="none"` on inactive
  - `tabIndex="0"` on focusable interactive elements
  - `role` attributes matching semantic purpose (columnheader, checkbox, button)
  - `aria-label` / `aria-checked` / `aria-expanded` for screen reader context
- **Why:** Accessibility bugs are invisible to sighted developers but break the app for screen reader users. Explicit assertions prevent regressions.
- **Source:** review 2026-02-15, OrderTableHeader -- 9/10, dedicated a11y section with aria-sort, tabIndex, role verification

### G-19: Keyboard Navigation Parity
- **When:** UI element responds to click AND keyboard (Enter/Space)
- **Do:**
  - Test click -> callback with correct args
  - Test Enter key -> same callback with same args
  - Test Space key -> same callback with same args (if applicable)
  - Use different elements per test to prove keyboard handling is universal, not hardcoded to one column/button
- **Why:** Keyboard-only users (accessibility, power users) need parity. Testing only click misses broken `onKeyDown` handlers.
- **Source:** review 2026-02-15, OrderTableHeader -- sort via click, Enter, Space on different columns

### G-20: Combinatorial Input Coverage (Truth Table)
- **When:** Function has N boolean/enum parameters that combine to produce different outputs (e.g., `buildJustification(hasChange, r1, r2, r3)`)
- **Do:**
  - List all meaningful input combinations as a truth table
  - Test each combination: all-false, each-one-true, all-true, mixed
  - Name tests after the combination: `it('returns R1+R3 justification when R2 is empty')`
  - For N booleans: test at least 2N+1 combinations (not full 2^N, but all single-true + all-true + all-false + key mixes)
- **Why:** Combinatorial bugs (wrong `&&`/`||`, missing case) hide when you only test happy path + one edge case.
- **Source:** review 2026-02-15, QC Pipeline -- buildJustification 8 tests covering all R1/R2/R3 combinations

### G-21: Crash-Resume Defensive Testing
- **When:** Pipeline/workflow can be interrupted and resumed from partial state (partial progress, checkpoint/resume, crash recovery)
- **Do:**
  - Test resume with null result (never started)
  - Test resume with null sub-fields (started but crashed mid-way: `final_report: null`)
  - Test resume with empty arrays (started, no entries yet)
  - Test resume with partial data (some entries filled, others null)
  - Verify each case returns sensible defaults, not crashes
- **Why:** Long-running pipelines crash. The resume path must handle every possible partial state, not just "completed" or "not started".
- **Source:** review 2026-02-15, QC Pipeline -- loadExistingResults tests null result, null final_report, empty entries, partial data

### G-22: Roundtrip/Inverse Testing
- **When:** Code has paired serialize/deserialize, encode/decode, compress/decompress, or map/unmap functions
- **Do:**
  - Test identity: `deserialize(serialize(input))` === `input` for each supported type
  - Test unicode preservation (polish, CJK, emoji, RTL)
  - Test empty values (empty string, empty collection, null values in map)
  - Test type boundaries (string<->number key conversion, BigInt, Date)
- **Why:** Roundtrip tests catch asymmetric bugs where one direction works but the other loses data. Single-direction tests miss encoding/decoding mismatches.
- **Source:** review 2026-02-15, Translation utils -- serializeTranslationMap -> deserializeTranslationMap inverse test, unicode preservation, key type conversion

### G-23: Modular Test Suite Architecture (for large test files)
- **When:** Test file would exceed 250 lines, OR component/module has 10+ distinct behaviors to test
- **Do:**
  - Create orchestrator file: `*.test.ts` with mock setup + `describe` + registered suites
  - Create suite files: `*.happy-path.test.ts`, `*.edge-cases.test.ts`, etc. -- each exports `registerXTests(ctx)`
  - Share typed context: `interface TestContext { mockDb: ..., mockApi: ..., mockLogger: ... }`
  - Keep vi.mock in orchestrator (Vitest hoisting requires it there)
  - `beforeEach(vi.clearAllMocks)` in orchestrator applies to all suites
- **Why:** 1000+ LOC test files are unnavigable. Modular suites with shared context keep tests organized without duplicating mock setup.
- **Source:** review 2026-02-15, Export generator orchestrator -- 12 registered suites, typed ExportGeneratorComprehensiveTestContext, clean separation

### G-24: Suite-Specific Minimal Setup
- **When:** Test file has 5+ describe blocks or uses modular suite architecture (G-23)
- **Do:**
  - Happy-path suite: full setup (project + entries + context + analysis + glossary)
  - Focused suites: ONLY what they test (filtering = project + entries, context=null, analysis=null)
  - Each suite's `beforeEach` is independent -- no shared mutable state across suites
- **Why:** Full setup in every suite creates false dependencies -- a test "passes" because analysis data happens to be present, not because the code handles null analysis. Minimal setup proves the code works with only the required data.
- **Anti-pattern:** Copy-pasting the happy-path setup into every suite and wondering why 40 tests break when one fixture changes.
- **Source:** review 2026-02-15, Export generator comprehensive -- happy-path uses full data, filtering/questionnaire/html use only project+entries

### G-25: Controlled Promise for Async Loading States
- **When:** Component shows loading/disabled state during async operation (save, delete, fetch)
- **Do:**
  - Create controlled promise: `let resolveSave!: Function; const savePromise = new Promise(r => { resolveSave = r; });`
  - Mock returns the unresolved promise: `onSave.mockReturnValue(savePromise)`
  - Trigger action -> assert button is disabled / spinner shows (DURING async)
  - Resolve: `resolveSave()` -> assert button re-enabled / spinner gone (AFTER async)
- **Why:** Testing only before/after misses the loading state entirely. Users see the loading state -- it must work. `await` in test skips over it instantly.
- **Source:** review 2026-02-15, DictionaryTab 9/10 -- controlled Promises test disabled state DURING save/delete/add

### G-26: Step Advancement Helpers for Multi-Step Flows
- **When:** UI has wizard/stepper (2+ steps) where later steps require completing earlier ones
- **Do:**
  - Create `advanceToStep2()`, `advanceToStep3()` helpers that perform all clicks/inputs to reach that step
  - Each step's tests call only the helper they need -- no repeated setup
  - Test each step independently: render, advance, assert
  - Test back navigation: advance to step 3 -> go back -> state preserved
- **Why:** Without helpers, each step-3 test repeats 20+ lines of step-1 and step-2 interactions. Helpers keep tests focused on what they actually test.
- **Source:** review 2026-02-15, HolisticReviewModal 9/10 -- advanceToReviewStep(), advanceToImportStep(), advanceToApplyStep()

### G-27: Dual Mode/Variant Testing
- **When:** Component has visual modes (standard/compact, desktop/mobile, text/icon-only) that show same functionality differently
- **Do:**
  - Test BOTH modes with same scenarios: buttons exist, callbacks fire, state changes reflected
  - Verify mode-specific rendering: standard -> text labels, minimalistic -> icons only
  - Verify mode-specific behavior if any (e.g., mobile -> hamburger menu, desktop -> sidebar)
- **Why:** Mode-specific bugs are common -- a button works in standard mode but is missing in compact mode because the conditional rendering is wrong.
- **Source:** review 2026-02-15, AgentReviewActions 9.5/10 -- standard (text buttons) vs minimalistic (icon-only), both modes tested with full state combinations

### G-28: it.each Parameterization for Same-Behavior Variants
- **When:** 3+ tests differ only in a single enum/status value but assert identical behavior (e.g., multiple HTTP statuses that all return 200)
- **Do:**
  - Extract into `it.each(['submitted', 'under_review', 'approved', 'paid'])('returns 200 when status is %s', ...)`
  - Keep unique-behavior tests separate (don't force-parameterize tests with different assertions)
  - Use descriptive `%s` / `%i` / `%j` placeholders so test names are readable in output
- **Why:** Copy-pasted tests with one value changed are hard to maintain and hide the intent ("all these behave the same"). `it.each` communicates that intent explicitly.
- **Source:** review 2026-02-16, proofreading public route -- 4 nearly identical status tests -> `it.each` reduces to 1

### G-29: Symmetric Positive/Negative Coverage
- **When:** Component/function has boolean conditions or feature flags that show/hide behavior
- **Do:**
  - For every "shows X when Y" test, add "does NOT show X when not-Y"
  - For every "calls handler when condition" test, add "does NOT call handler when no condition"
  - Name pairs symmetrically: `it('shows clear button when query is not empty')` + `it('does not show clear button when query is empty')`
- **Why:** Testing only the positive path misses regressions where the condition is accidentally removed (element always shows). The negative test catches that.
- **Source:** review 2026-02-16, SearchInput 9/10 -- exemplary symmetric coverage of all variants (loading/not, meta/no-meta, minimalistic/standard)

### G-30: Structural Pattern Assertions (regex/SQL/URL)
- **When:** Code generates dynamic patterns -- regex, SQL LIKE expressions, URL patterns, query strings
- **Do:**
  - Use `toMatch(/structural-regex/)` to verify the pattern has correct operators/delimiters without hardcoding the exact string
  - Import the real helper function (e.g., `escapeLikePattern`) in the test instead of hardcoding the expected output
  - Assert structure, not exact value: `expect(firstCall[2]).toMatch(/\[\^[>&]\]/)` verifies tag boundary regex without coupling to specific content
- **Why:** Exact string matching is fragile for generated patterns. Structural assertions catch real bugs (wrong operator, missing boundary) while tolerating legitimate content changes.
- **Source:** review 2026-02-16, project-search -- `escapeLikePattern` imported in test + `toMatch` for regex structure verification

### G-31: Call Order Verification
- **When:** Code executes operations in a required sequence (collect before delete, auth before action, init before process)
- **Do:**
  - Track order via array: `const callOrder: string[] = []; mockFn.mockImplementation(async () => { callOrder.push('name'); })`
  - Assert relative positions: `expect(callOrder.indexOf('collect')).toBeLessThan(callOrder.indexOf('delete'))`
- **Why:** Race conditions where operations execute out of order are invisible to CalledWith/CalledTimes checks. Only order verification catches them.
- **Source:** review 2026-02-21, risk-sync.service -- reindexAllRisks verified findMany BEFORE deleteAll via callOrder array

### G-32: Admin/Non-Admin Symmetry (Guard Pattern)
- **When:** Endpoint/method has authorization check (role, ownership, permission)
- **Do:** For EACH guarded operation, write 3 tests:
  1. Authorized user -> success + verify result
  2. Unauthorized user -> throws permission error (exact message)
  3. Unauthorized user -> service method `not.toHaveBeenCalled()` (proves guard is BEFORE logic)
- **Owner check variant** (when auth = ownership, not role):
  4. Non-owner user -> throws "You are not creator of this offer!" (or equivalent)
  5. Non-owner user -> mutation service `not.toHaveBeenCalled()`
- **Why:** Test #3/#5 is critical -- without it, someone could move the auth check after the mutation and tests 1-2 still pass. Verifies guard ordering.
- **Source:** review 2026-02-21, ProjectScopeController 8/10 -- every CRUD endpoint x 3; OfferController #4.4, #18.2 -- owner check variant

### G-35: Type Boundary Assertions (Framework Crossing)
- **When:** Code passes data between two frameworks/libraries (Polars<->Pandas, NumPy<->Torch, ORM<->raw SQL)
- **Do:**
  - Assert `isinstance(result, pl.DataFrame)` AND `not isinstance(result, pd.DataFrame)` at every boundary
  - Name tests after the boundary: `test_build_export_dataframe_returns_pandas`
  - Test BOTH directions: `to_pandas()` produces Pandas, `from_pandas()` produces Polars
  - Verify framework-specific attributes exist/don't exist: `.height` (Polars-only), `.loc` (Pandas-only)
- **Why:** Framework confusion is the #1 runtime error in dual-framework codebases. `df.fillna()` on Polars silently fails. `df.height` on Pandas -> AttributeError.
- **Source:** review 2026-02-21, Datalab Agent 2 -- systematic `isinstance` + `not isinstance` at every service boundary

### G-36: Contract Tests Tracing Client Crash Points
- **When:** Backend API serves frontend that accesses response with `.forEach()`, `Object.entries()`, `.map()`
- **Do:**
  - Create `assert_array_not_null(value, path)` and `assert_dict_not_none(value, path)` helpers
  - Document each client access pattern in docstring with file:line reference
  - Test that every collection field is NEVER null (always `[]` or `{}`)
  - Test JSON serializability of every response
  - **CRITICAL:** Call actual production function, not just build dict and assert
- **Anti-pattern:** Building a dict literal and asserting its fields are lists -- tests dict construction, not production code (see P-35).
- **Source:** review 2026-02-21, Datalab Agent 3 -- `assert_array_not_null` + JS line references

### G-37: Static Analysis as Tests (AST/Regex Scanning)
- **When:** Codebase has recurring bug patterns detectable by scanning source files
- **Do:**
  - `ast.parse()` all source files -> catch SyntaxError
  - Regex scan with context: check if match is in comment, string, or active code
  - Build safe-lists for known-good patterns (`PANDAS_SAFE_FILES`, parameterized SQL)
  - Backward trace to determine variable type (scan 50 lines back for assignment)
  - **Zero false positives** -- better to miss a bug than cry wolf
- **Categories:** Framework confusion (Polars/Pandas), SQL injection, security config, path traversal, dangerous imports
- **Source:** review 2026-02-21, Datalab Agent 5 -- Polars/Pandas confusion detector, SQL injection audit, security config

### G-38: Preserve Semantics Testing
- **When:** Operation conditionally modifies data -- should NOT clear existing values where condition is False
- **Do:**
  - First operation: set value A where condition X
  - Second operation: set value A where condition Y (disjoint from X)
  - Assert BOTH X and Y rows have value A after both operations
  - Name: `test_multiple_preserve_existing`
- **Why:** "Last write wins" bugs are silent -- second set_value clears first, test passes if you only check the second.
- **Source:** review 2026-02-21, Datalab RecodeService -- `TestSetValuePreserve` verified two set_value calls don't interfere

### G-39: Deprecated Method Regression Test
- **When:** Method is deprecated but still callable (backward compatibility)
- **Do:**
  - Call deprecated method -> assert it returns deprecation warning
  - Assert data is NOT modified (method is no-op)
  - Assert no errors produced (graceful degradation)
- **Source:** review 2026-02-21, Datalab RecodeService -- `recode()` deprecated, returns warning, doesn't modify data

### G-40: Author/Era Mapping Heuristic (Audit Pattern)
- **When:** Auditing a large module (50+ test files) across multiple directories
- **Do:**
  - Map test quality to directory/file naming convention, not to module complexity
  - Identify distinct "generations" by shared patterns:
    - **Generation A signs:** `makeX()` factories, `CalledWith`, error propagation, `not.toHaveBeenCalled()`
    - **Generation B signs:** `spyOn(self)`, `toBeTruthy()`, `__privateMethod()`, 200+ LOC inline fixture
  - Score generations separately -- averaging across them hides the bimodal distribution
  - Prioritize Generation B for rewrite, use Generation A as reference implementation
- **Why:** Module-level averages (e.g., "Offer module: 6/10") are misleading when the module has 42 files at 8.4/10 and 8 files at 2.6/10. The 8 bad files create false security.
- **Evidence:**
  ```
  offer/services/*.spec.ts      -> 4 files, avg 8.6/10  (modern)
  offer/unit-test/*.spec.ts     -> 5 files, avg 2.8/10  (legacy)
  Same module. Same domain. 3x quality difference.
  ```
- **Source:** review 2026-02-21, Offer Module 92-file audit -- clear two-author pattern

### G-51: Callback Prop Payload Shape Verification
- **When:** React component calls a callback prop (`onSave`, `onSubmit`, `onChange`) with a computed object
- **Do:** Assert the EXACT shape passed to the callback, especially computed/transformed fields:
  ```typescript
  it('onSave receives form data with computed total', async () => {
    const onSave = vi.fn();
    render(<OrderForm onSave={onSave} />);

    await userEvent.type(screen.getByLabelText(/quantity/i), '5');
    await userEvent.type(screen.getByLabelText(/unit price/i), '10.50');
    await userEvent.click(screen.getByRole('button', { name: /save/i }));

    expect(onSave).toHaveBeenCalledWith({
      quantity: 5,
      unitPrice: 10.50,
      total: 52.50,     // COMPUTED -- this is the regression risk
    });
  });
  ```
  - Test number/string coercion: form inputs are strings; component should parse to numbers before callback
  - Test that omitted optional fields are NOT included in the payload (not `undefined`-keyed)
  - Test empty/null cases: clear all fields -> callback called with `{}` or not called at all
- **Why:** Many bugs live in "component builds object from partial form state -> normalizes -> adds computed fields -> calls callback". Testing only "callback was called" misses all of that.
- **Related:** G-43 (dispatch payload) -- same principle for callbacks
- **Source:** Feedback from cross-project review -- computed callback payloads frequently untested

### G-53: Idempotency Testing
- **When:** Operation can be triggered multiple times (double submit, retry, deduplication, batchSave)
- **Do:**
  ```typescript
  // UI: double-click prevention
  it('double submit does not create duplicate (button disabled after first click)', async () => {
    await userEvent.click(submitBtn);
    expect(submitBtn).toBeDisabled();                    // disabled immediately
    expect(createOrder).toHaveBeenCalledTimes(1);        // not 2
  });

  // Thunk: idempotent API call
  it('dispatching fetchProfiles twice returns same state', async () => {
    await store.dispatch(fetchProfiles());
    const stateAfterFirst = store.getState().profiles.profiles;
    await store.dispatch(fetchProfiles());
    expect(store.getState().profiles.profiles).toEqual(stateAfterFirst);  // not doubled
  });
  ```
- **Particularly important for:** survey submissions, payment flows, batch operations, import jobs
- **Why:** Double-submit bugs are a class of production failures that are trivially testable but almost never covered.
- **Source:** Feedback -- "double-submit survey response is a real production bug"

### G-54: Regression Anchor Naming
- **When:** Test is written to prevent a specific production bug from recurring
- **Do:** Include the ticket/bug ID in the test name:
  ```typescript
  // Bug: survey with 0 questions crashed export -- ticket SURV-4521
  it('SURV-4521: export handles survey with zero questions', () => {
    const result = exportSurvey({ ...survey, questions: [] });
    expect(result.status).toBe('empty');
    expect(result.file).toBeNull();
  });

  // Or use describe grouping:
  describe('regression: SURV-4521 -- empty survey export', () => {
    it('returns empty status', () => { ... });
    it('does not throw', () => { ... });
  });
  ```
- **Why:** Named regression tests survive "cleanup" refactors -- developers see the ticket reference and know the test protects against a specific production failure. Without it, the test looks like an arbitrary edge case and gets deleted.
- **Source:** Feedback -- production bugs reappeared 6 months after "simple" edge case tests were deleted during cleanup

### G-55: Frontend--Backend Contract Boundary Tests
- **When:** Mixed stack (React frontend + PHP/Node backend) with no shared type schema
- **Do:** Write contract tests at both ends:
  ```typescript
  // Frontend: verify what shape is SENT
  it('survey create sends correct request shape', async () => {
    let sentBody: unknown;
    server.use(rest.post('/api/survey/create', async (req, res, ctx) => {
      sentBody = await req.json();
      return res(ctx.json({ id: 1 }));
    }));
    await submitSurvey(formData);
    expect(sentBody).toEqual({
      title: expect.any(String),
      questions: expect.arrayContaining([
        expect.objectContaining({ type: expect.any(String), text: expect.any(String) })
      ])
    });
  });
  ```
  ```php
  // Backend: verify what shape is ACCEPTED
  public function testCreateSurveyAcceptsCorrectPayload(FunctionalTester $I): void {
      $I->sendPOST('/api/survey/create', [
          'title' => 'Test Survey',
          'questions' => [['type' => 'text', 'text' => 'Q1']]
      ]);
      $I->seeResponseCodeIs(201);
      $I->seeResponseContainsJson(['id' => new IsType('integer')]);
  }
  ```
- **Why:** When frontend changes request shape but backend test stays unchanged, CI catches it. In mixed stacks without shared DTO/schema, this is the only automated contract check.
- **Related:** G-36 (client crash points), G-42 (MSW sentBody capture)
- **Source:** Feedback -- "in mixed stack React + Yii2 + NestJS, contract boundary is the only safety net"

---

## Gap Patterns -- Check These

### P-1: Input Boundaries -- Multi-field params
- **When:** Function accepts an object with 3+ fields, OR 3+ separate parameters
- **Tests:**
  - Each field/param as `null`
  - Each field/param as `undefined`
  - String params as empty string `""`
  - Entire params object as `null` / `undefined`
  - Document expected behavior (throw? return false? return default?)
- **Source:** review 2026-02-15, `paypal-signature.ts` -- 10-field params object had zero null tests

### P-2: Delegation to External API
- **When:** Function calls an external service and maps the response to a return value
- **Tests:**
  - Exact response mapping: what API returns -> what function returns (not just true/false, but WHY true/false)
  - Unexpected API response (unknown status, empty body, HTML instead of JSON)
  - API timeout / network error
  - API returns success with unexpected shape
- **Source:** review 2026-02-15, `paypal-signature.ts` -- no test for how `status === 'SUCCESS'` maps to boolean

### P-3: Boolean Return Functions
- **When:** Function returns `boolean`
- **Tests:**
  - At least 1 test for each path that returns `true`
  - At least 1 test for each path that returns `false`
  - If function has try/catch that returns `false` on error -> test that the catch path returns `false` (not `undefined`)
- **Source:** review 2026-02-15, `paypal-signature.ts` -- catch returns false but not explicitly tested

### P-4: Repeated Test Boilerplate
- **When:** Same setup/helper pattern appears 3+ times in a test file
- **Action:** Extract into a helper function (e.g., `async function runWithTimers(fn)`)
- **Source:** review 2026-02-15, `paypal-signature.test.ts` -- `vi.advanceTimersByTimeAsync(0)` repeated 8x

### P-5: Mock Argument Verification -- CalledWith, not just CalledTimes
- **When:** Test mocks an external store (Redis, DB, KV, queue) or external service call
- **Tests:**
  - `toHaveBeenCalledWith(expectedKey, expectedValue, ...)` -- not just `toHaveBeenCalledTimes(1)`
  - Verify the key format/pattern (e.g., `expect.stringContaining('session-1')`)
  - Verify TTL / expiration values match config
  - Verify serialized value shape (what exactly is stored?)
  - Verify cleanup calls (`.del`) target the correct key
- **Why:** `CalledTimes(1)` proves the call happened but not that it did the right thing. Key format change, TTL change, or wrong value serialization all pass `CalledTimes` silently.
- **Source:** review 2026-02-15, idempotency interceptor -- `redis.set` and `redis.setex` verified by count only, no key/TTL/value check

### P-6: Infrastructure Failure -- Fail-open vs Fail-closed
- **When:** Function depends on infrastructure (Redis, DB, queue, cache) that can be unavailable
- **Tests:**
  - Infrastructure throws error (connection refused, timeout) -> does function fail-open (proceed) or fail-closed (block)?
  - Infrastructure returns garbage (unparseable JSON, HTML error page, empty string)
  - Infrastructure returns null/undefined unexpectedly
  - Document the expected behavior explicitly in test name: `it('fails open when Redis is down')`
- **Why:** "Redis is down" is a real production scenario. If the test doesn't cover it, nobody knows if the system degrades gracefully or crashes.
- **Source:** review 2026-02-15, idempotency interceptor -- no test for Redis unavailable, unknown if fail-open or fail-closed

### P-7: Config Branch Coverage
- **When:** Function accepts a config/options object with boolean flags or mode switches
- **Tests:**
  - Test both `true` and `false` for each boolean flag
  - Test default behavior when flag is omitted
  - Test interaction between flags if multiple exist
- **Source:** review 2026-02-15, idempotency interceptor -- `requireKey: true` never tested, only `false` path exercised

### P-8: Hash/Serialization Stability
- **When:** Function produces a hash, digest, or serialized output from structured input
- **Tests:**
  - Same input -> same output (deterministic)
  - Input with reordered keys/arrays -> same output (order-independent, if expected)
  - Minimal change in input -> different output (sensitivity)
  - Test the function in isolation, not just as a helper in other tests
- **Source:** review 2026-02-15, idempotency interceptor -- `computeSubmitPayloadHash` used in tests but never tested for order stability

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
- **Source:** review 2026-02-15, transformPage -- 6.5/10, uuidToInt always 123 hid entity mapping bugs

### P-10: React Testing Weak Patterns (3 traps)
- **When:** Writing React component tests with Testing Library
- **Trap 1 -- toBeTruthy() on queries:** `expect(screen.getByText('X')).toBeTruthy()` is redundant -- `getByText` already throws if not found. Use `toBeInTheDocument()` or just call `screen.getByText('X')` alone.
- **Trap 2 -- Static module mock:** `vi.mock('./hook', () => ({ useHook: () => fixedValue }))` locks you into one state. Use `vi.fn()` + per-test `mockReturnValue` (see G-10).
- **Trap 3 -- Date.now() in mock data:** Without `vi.useFakeTimers()` + `vi.setSystemTime()`, time-relative displays ("2 min ago") are flaky.
- **Source:** review 2026-02-15, SaveIndicator 4/10 (all 3 traps), LogicRulePanel 7/10 (trap 1), TemplateTab 8/10 (trap 1 only)

### P-11: Partial Structure Assertions -- expect.any() Hiding Shape
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
- **Source:** review 2026-02-15, TemplateService -- 8x `expect.any(Object)` on includes

### P-12: Incomplete Interaction Flows
- **When:** Test opens a dialog/modal/form but doesn't test the submit action
- **Problem:** Proves the UI triggers but not that the action completes. "Dialog opens" is half a test.
- **Required flow:** trigger -> dialog opens -> fill/confirm -> action called with correct args -> success/error feedback
- **Check:** For every dialog/modal open assertion, there MUST be a corresponding submit test
- **Source:** review 2026-02-15, TemplateTab -- "Create Template" opens dialog but save submit untested; LogicRulePanel -- edit click untested

### P-13: Duplicate/Conflicting Input Data
- **When:** Function processes a collection (array of objects, map of records)
- **Tests:**
  - Two items with same key/ID -- which wins? (first? last? merge? error?)
  - Empty collection -> expected behavior
  - Single item -> no off-by-one
- **Why:** Databases can return duplicates from joins. APIs can send repeated items. The test should document the dedup behavior.
- **Source:** review 2026-02-15, buildAnswerMapFromResponses -- no test for duplicate questionId in responses

### P-14: Negative Side-Effect Verification
- **When:** Function conditionally calls a side effect (e.g., `expire` only on first hit, `invalidate` only on success)
- **Tests:**
  - Positive: side effect called in correct conditions (`expire` when count === 1)
  - **Negative: side effect NOT called in other conditions** (`expire` NOT called when count > 1)
- **Why:** Without the negative test, removing the conditional (always calling the side effect) doesn't break any test
- **Source:** review 2026-02-15, BurstGuard -- `expire` tested on first hit but no test proving it's skipped on subsequent hits

### P-15: Pagination Beyond Page 1
- **When:** Service implements pagination (skip/take, offset/limit, cursor)
- **Tests:**
  - Default page (page 1, default limit)
  - Page > 1 -- verify `skip` math: `(page - 1) * limit`
  - Limit cap -- verify max limit enforced
  - Return metadata: `{ page, totalPages, total }` with correct values
- **Source:** review 2026-02-15, TemplateService -- only page 1 tested, no test for `skip: 40` on page 3

### P-16: Unmapped/Unknown ID Handling
- **When:** System maps between ID formats (UUID<->int, slug<->id, legacy<->modern)
- **Tests:**
  - Known ID -> correct mapping
  - Unknown/unmapped ID -> what happens? (throw? return undefined? return 0?)
  - Stale ID (was mapped, then mapping cleared) -> behavior documented
- **Why:** Legacy systems pass stale IDs. APIs send unknown IDs. The mapping layer should have defined behavior, not silent corruption.
- **Source:** review 2026-02-15, TRPCAdapters -- no test for int ID that was never seeded via seedUuid()

### P-17: Loading State Scoping
- **When:** Component shows loading/disabled state for a specific entity (order, item, row)
- **Tests:**
  - `loadingId="order-1"` -> button for order-1 is disabled
  - `loadingId="order-1"` -> button for order-OTHER is **still enabled** (scoping test)
  - `loadingId=undefined` -> all buttons enabled (default state)
- **Why:** Global loading state breaks UX -- user can't interact with other items while one is processing. Test BOTH matching and non-matching entity.
- **Source:** review 2026-02-15, OrderTypeBadge -- resendingOrderId tested for matching order, but missing test for non-matching order staying enabled

### P-18: Incomplete Enum/Status Coverage
- **When:** Component/function handles a string/number enum (status, type, method)
- **Tests:**
  - Test EVERY known enum value (not just terminal states success/failed -- include intermediate: pending, processing, queued)
  - Test unknown/unexpected value: `reward_method: "unknown"`, `status: "new_value_from_api"` -> graceful fallback
  - Test null/undefined -> fallback or error
- **Why:** APIs evolve -- new enum values arrive. Missing intermediate state test = surprise blank UI in production. Unknown value test = crash prevention.
- **Source:** review 2026-02-15, OrderTypeBadge -- tested success/failed/returned/blocked but missing pending; no test for unknown reward_method

### P-19: Semantic Queries over CSS Class Selectors
- **When:** Test detects elements by CSS class (`.querySelector('.text-green-600')`, `.querySelector('.bg-red-500')`)
- **Problem:** Tailwind class changes (green-600 -> green-500), wrapper div changes, or class reorganization breaks tests for wrong reasons.
- **Fix:** Prefer in order:
  1. `getByRole('img', { name: /check/ })` -- semantic
  2. `getByLabelText('Email sent')` -- aria
  3. `getByTestId('status-icon-success')` -- explicit (add to component if needed)
  4. `.querySelector('.text-green-600')` -- last resort (add comment: "fragile, needs data-testid")
- **When CSS is OK:** Verifying Tailwind styling intentionally (badge color test, active state style) -- that's testing styling, not detecting elements.
- **Source:** review 2026-02-15, OrderTypeBadge -- icon detection via `.querySelector('.text-green-600')`, fragile to color changes

### P-20: Dead/Self-Referential Tests (red flag when functions)
- **When:** Test defines local constants, objects, OR functions and asserts against them -- not importing from production code
- **Severity levels:**
  - **Constants/objects:** `const X = { MAX: 600 }; expect(X.MAX).toBe(600)` -- test proves nothing but damage is limited
  - **Copied functions:** `function serialize(map) { return Object.fromEntries(map); }` with comment `// will be extracted from lines 122-144` -- test LOOKS comprehensive (roundtrip, unicode, edge cases) but verifies the COPY, not production code. Gives false sense of security. If production code changes, test still passes.
- **Detection:** If removing the test changes nothing about production code coverage -> it's dead.
- **Fix:** Replace local definitions with imports from production module. If module doesn't exist yet (pre-refactoring), mark tests as `// TODO: replace with import after extraction` and flag as NOT VERIFIED in review.
- **Source:** review 2026-02-15, QC Pipeline (constants) + Translation utils 6.5/10 (copied functions -- 11 tests on local serializeTranslationMap that don't verify production code)

### P-21: Mock Component Prop Drift
- **When:** React test mocks child components with inline JSX: `vi.mock('./Header', () => ({ Header: vi.fn(({ onCopy }) => <div>...</div>) }))`
- **Problem:** If real `Header` renames `onCopy` to `onCopyProject`, mock still destructures old prop name -- test passes but production breaks. Mock and reality drift apart silently.
- **Fix:** After rendering, verify the mock was called with expected props:
  ```typescript
  expect(Header).toHaveBeenCalledWith(
    expect.objectContaining({ onCopy: expect.any(Function) }),
    expect.anything() // ref
  );
  ```
  This catches prop renames because `objectContaining({ onCopy: ... })` fails when prop is now `onCopyProject`.
- **Source:** review 2026-02-15, Project Page orchestrator -- 20+ mock components, none verified via CalledWith

### P-22: Zero-Denominator Edge Case
- **When:** Function computes average, percentage, ratio, or any division where denominator comes from input (count, total, length)
- **Tests:**
  - Zero denominator -> verify result is 0 (not NaN or Infinity)
  - Empty collection -> verify aggregation returns sensible default
  - Assert the exact value: `expect(result.confidence).toBe(0)` -- not just "doesn't throw"
- **Why:** `Math.round(0/0 * 100)` = `NaN`. `100/0` = `Infinity`. Both propagate silently through JSON serialization and UI, showing "NaN%" to users.
- **Source:** review 2026-02-15, Translation utils -- mergeEvalResults([], 0) -> confidence = NaN, test didn't check the value

### P-23: Weak Assertions on Known Data
- **When:** Test has deterministic setup (known number of entries, known mock returns) but uses weak assertions
- **Problem patterns:**
  - `toBeGreaterThan(0)` when test creates exactly 3 entries -> should be `toBe(3)`
  - `toBeTruthy()` when exact value is known -> should be `toBe(expectedValue)`
  - `toHaveLength(expect.any(Number))` when array content is deterministic
- **When weak IS OK:** Smoke tests ("doesn't crash with 1000 entries"), non-deterministic data, testing existence not value
- **Fix:** In tests with known setup data, assert exact values. Reserve `toBeGreaterThan` for genuine lower-bound checks.
- **Source:** review 2026-02-15, Export generator -- happy-path creates 1 pattern but asserts `toBeGreaterThan(0)` instead of `toBe(1)`. Integration test does it right: `toBe(5)`.

### P-24: Contradictory Test Assertions Across Suites
- **When:** Multiple test files/suites cover the same function/feature
- **Problem:** Suite A says `reviewRound option is ignored`. Suite B says `reviewRound overrides history`. Both pass -- one is wrong.
- **Detection:** During review, search for the same feature tested in multiple places. Compare assertions -- if they claim opposite behavior, flag immediately.
- **Fix:** Run the production code to determine actual behavior. Delete the wrong test. Add comment to surviving test: `// verified: reviewRound DOES override history (not ignored)`
- **Source:** review 2026-02-15, Export generator -- original test vs comprehensive test contradicted on reviewRound behavior

### P-25: Hardcoded Mock Call Indices
- **When:** Test accesses specific mock call by index: `mockFetch.mock.calls[2][1].body`
- **Problem:** If call order changes (new call added before, conditional call removed), index shifts and test breaks for wrong reason -- or worse, silently asserts against wrong call.
- **Fix:** Find the call by characteristic, not position:
  ```typescript
  const importCall = mockFetch.mock.calls.find(
    ([url]) => url.includes('/import')
  );
  expect(JSON.parse(importCall![1].body)).toMatchObject({ reviewRound: 2 });
  ```
- **When index IS OK:** Sequential protocol tests where call order IS the thing being tested (e.g., "auth happens before data fetch")
- **Source:** review 2026-02-15, HolisticReviewModal 9/10 -- `mockFetch.mock.calls[2][1].body` fragile to call order changes

### P-26: Test Name Claims Unverified Behavior
- **When:** Test name describes specific behavior but body doesn't actually verify it
- **Variants:**
  - **Empty body:** `it('should handle delete on non-existent project', () => { /* comment only */ })` -- zero assertions
  - **Wrong assertions:** `it('should handle rapid filter changes')` but test doesn't verify debouncing, just makes 2 calls
  - **Smoke only:** `it('should handle 1000 entries', () => { ... expect(result).toBeGreaterThan(0) })` -- name implies performance/correctness, assertion only checks "didn't crash"
- **Fix:** Test name must match what assertions prove. If you can't write the assertion yet, use `it.todo('should handle rapid filter changes')` -- honest about the gap.
- **Source:** review 2026-02-15, ProjectsPage 8/10 -- "handle delete on non-existent project" (empty), "handle rapid filter changes" (no debounce verification)

### P-27: Silent False-Positive via try/catch in Assertions
- **When:** Test uses try/catch to verify that a function throws an error
- **Problem:** If the function does NOT throw, execution skips the catch block entirely -- test passes with zero assertions. Silent false-positive.
  ```typescript
  // WRONG -- passes silently if validateUpdate doesn't throw:
  try {
    await service.validateUpdate(1, { field: 'value' });
  } catch (e) {
    expect(e.message).toContain('1 translated segment');
  }
  ```
- **Fix:** Use `rejects.toThrow` or catch-then-assert with explicit fail:
  ```typescript
  // CORRECT -- fails if no error thrown:
  await expect(service.validateUpdate(1, { field: 'value' }))
    .rejects.toThrow('1 translated segment');

  // ALT -- explicit catch with fail guard:
  const error = await service.validateUpdate(1, { field: 'value' }).catch(e => e);
  expect(error).toBeInstanceOf(Error);
  expect(error.message).toContain('1 translated segment');
  ```
- **NestJS variant** (seen 3x in review):
  ```typescript
  // WRONG -- passes if controller does NOT throw:
  try {
    await controller.findOne(id, reqHeader);
  } catch (err) {
    expect(err.response.statusCode).toEqual(400);
  }

  // CORRECT:
  await expect(controller.findOne(id, reqHeader))
    .rejects.toThrow(BadRequestException);
  ```
- **Metric:** Tests using try/catch pattern averaged 3.5/10 (N=92).
- **Source:** review 2026-02-16, project-services + review 2026-02-21, LocalStrategy, OfferController #19

### P-28: Phantom Mocks (Untested Mock Setup)
- **When:** `beforeEach` sets up a mock (e.g., `mockDemoLink.findUnique.mockResolvedValue(null)`) but no test in the suite exercises that code path
- **Problem:** The mock signals that a code path exists (demo links, fallback behavior, optional feature) but the path is invisible -- zero coverage. If the real code breaks for that path, no test catches it.
- **Detection:** For each mock in `beforeEach`, search the test suite for at least one test that depends on it. If no test changes or asserts against it -> phantom mock.
- **Fix:** Either write a test that exercises the path, or remove the mock (dead setup = noise).
- **Source:** review 2026-02-16, proofreading public route -- `proofreadingDemoLink.findUnique` mocked to null in beforeEach, zero tests for demo link path

### P-29: Type Hack Proliferation in Mocks (`as never`/`as any`)
- **When:** Multiple tests use `as never` or `as any` to satisfy Prisma/DB/complex types when mocking
- **Problem:** Scattered `as never` casts are noisy, hide type mismatches, and make tests fragile. If the real type changes, the cast swallows the error.
- **Fix:** Centralize in a typed mock helper:
  ```typescript
  // Factory returns typed partial -- cast is in ONE place:
  function createSessionRecord(overrides?: Partial<ProofreadingSession>) {
    return { id: 'sess-1', status: 'pending', ...overrides } as ProofreadingSession;
  }

  // Or generic helper for any Prisma mock:
  function mockDBReturn<T>(mock: ReturnType<typeof vi.fn>, value: Partial<T>) {
    mock.mockResolvedValue(value as T);
  }
  ```
- **Source:** review 2026-02-16, proofreading public route -- `as never` in 6+ places, reduced to 1 via factory

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
- **Source:** review 2026-02-16, SearchInput 9/10 -- fireEvent works but misses potential debounce bugs

### P-31: Inconsistent Edge Case Coverage Across Sibling Methods
- **When:** Module has 3+ similar methods (e.g., `searchById`, `searchByText`, `searchByTags`) that share a common interface or pattern
- **Problem:** Some methods have edge case tests (empty input, null, boundary) while others don't. Creates a false sense of complete coverage.
- **Detection:** Create a matrix of `[method x edge case]`. If any cell is empty for a method that logically should handle that case -> gap.
- **Fix:** Fill the matrix. If `searchById` has an empty-query test, `searchByText` and `searchByTags` should too. Either test the behavior or document why it's intentionally different.
- **Source:** review 2026-02-16, project-search -- searchById and searchByTags have empty query tests, searchByText doesn't

### P-32: Untested Query Builder Variants (flag x SQL operator)
- **When:** Function builds different SQL/queries based on boolean flag combinations (e.g., `caseSensitive x wholeSegment` -> 4 variants with different operators: `~` vs `~*`, `LIKE` vs `ILIKE`)
- **Problem:** Each flag combination produces fundamentally different SQL. Testing only one combination leaves 3 others unverified -- a wrong operator in one branch silently corrupts results.
- **Tests:**
  - `caseSensitive=false, wholeSegment=false` -> `~*` (case-insensitive regex)
  - `caseSensitive=true, wholeSegment=false` -> `~` (case-sensitive regex)
  - `caseSensitive=false, wholeSegment=true` -> `ILIKE` (case-insensitive exact)
  - `caseSensitive=true, wholeSegment=true` -> `LIKE` (case-sensitive exact)
  - Use `it.each` (see G-28) to keep it DRY
- **Related:** G-20 (combinatorial coverage), P-7 (config branch coverage) -- this is the specific DB/query-builder variant
- **Source:** review 2026-02-16, project-search -- searchByText has 4 query variants, zero tested

### P-33: Input Echo Assertions (Asserting Input, Not Output)
- **When:** Test assertion checks a value that was directly passed as input, not computed by the function
- **Problem:**
  ```typescript
  const request = { from: 18, to: 65, gender: "both" };
  const [result] = await controller.GetAutoGenerateQuota(request);
  expect(result.from).toEqual(18);  // <- this is the INPUT, not computed
  ```
  Passes even if controller returns `{ from: request.from }` without any computation.
- **Fix:** Assert COMPUTED values: `expect(result.population).toBe(expectedPop)`, `expect(result.brackets[0].quota).toBe(calculatedQuota)`
- **Related:** Q17 (computed output check) -- this is the specific anti-pattern Q17 catches
- **Source:** review 2026-02-21, OfferQuotaController 2/10 -- 4 tests, all asserting `result.from === 18` (input echo)

### P-34: Fixture:Assertion Ratio Smell
- **When:** Test file has >5x more lines of fixture data than assertion lines
- **Problem:** 850 lines of inline data + 5 lines of assertions = the test is documentation, not verification. Massive data creates illusion of coverage.
- **Thresholds (calibrated on N=92):**
  - <3:1 -- healthy (avg 7.8/10)
  - 3:1 to 10:1 -- warning, consider factory extraction (avg 5.5/10)
  - 10:1 to 50:1 -- critical, almost certainly undertested (avg 2.5/10)
  - >50:1 -- Auto Tier-D (avg 2.0/10)
- **Fix:** Factory functions with overrides (G-4), programmatic generation, or JSON fixture files
- **Source:** review 2026-02-21, OfferQuota 850:5 ratio (2/10), OfferController 500:50 ratio (3/10)

### P-35: Self-Referential Contract Tests (Dict-in, Dict-out)
- **When:** Test builds a response dict/object manually and asserts its structure
- **Problem:**
  ```python
  response = {"status": "ok", "questions": []}
  assert isinstance(response["questions"], list)  # always True
  ```
  Tests dict construction, not production code. If real endpoint returns None, test still passes.
- **Fix:** Call actual production function: `question_list = build_question_list(real_meta)`
- **When hardcoded IS OK:** Documenting expected contract shape (but label it `TestContractShape`)
- **Source:** review 2026-02-21, Datalab Agent 3 -- ~60% tests build dicts and assert structure

### P-36: Overly Generous Performance Thresholds
- **When:** Performance test threshold is 100x actual expected time
- **Problem:** `assert t < 10000ms` for 50ms operation. 10x regression still passes.
- **Fix:** Benchmark actual P95, set threshold at 3-5x P95. Always print actual time.
- **Source:** review 2026-02-21, Datalab Agent 7 -- 10s threshold for ~200ms operation

### P-37: Module-Level Side Effects in Test Files
- **When:** Test file has `open()`, `json.load()`, `sys.modules` at module level
- **Problem:** Missing file -> entire module fails to import -> all tests skip with confusing error. Global mutable state leaks.
- **Fix:** Move to `conftest.py` fixtures with `scope="session"`. Use `pytest.skip()` for optional fixtures.
- **Source:** review 2026-02-21, Datalab Agent 2+7 -- module-level `_meta = json.load(open(...))` and `sys.modules` stubs

### P-38: Missing Public Method Coverage
- **When:** Production file has N public methods/exported functions, test file covers fewer than N
- **Problem:** Untested public methods have zero regression safety. Especially dangerous for CRUD endpoints where `create()` exists in production but test file only covers `update()` and `delete()`. Refactoring or adding validation to untested method breaks silently.
- **Required tests:** At least 1 `it()` block per public method (happy path minimum). For CONTROLLER/SERVICE: list all route handlers / exported methods, verify each has a test.
- **Detection:** Compare `export function`/`async method()` in production file vs `describe`/`it` blocks in test file. Any public method with zero matching test = P-38 gap.
- **Source:** code-audit feedback 2026-02-21, offer.controller -- `create()` endpoint had zero test coverage while `createVersion()` and `createOption()` were fully tested

### P-39: Rendering-Only Tests as Pre-Refactoring Safety Net (AI Agent Trap)
- **When:** Writing pre-refactoring tests for React components (ETAP-1B or any test-first workflow)
- **Problem:** AI agents (and developers) default to rendering/visibility tests: `getByText('Submit')`, `getByRole('button')`, `toBeInTheDocument()`. These prove the component renders but NOT that user flows work. A refactoring that breaks the submit handler, search logic, or calendar interaction passes all rendering tests. **Contract test that doesn't cover core user flows = false safety net.**
- **Detection (mechanical check):** Count `it()` blocks by type:
  - **Rendering tests:** assertions are `toBeInTheDocument`, `toBeVisible`, `getByText` without subsequent interaction
  - **Flow tests:** assertions follow a user interaction chain: click/type -> state change -> callback/API called with args -> success/error feedback
  - If rendering > 60% and flow < 30% -> P-39 triggered
- **Minimum User Flow Coverage by Component Type:**

  | Component Type | Minimum Flows to Test |
  |----------------|----------------------|
  | **Form** | submit with valid data -> callback args, submit with invalid -> error shown, clear/reset, field validation feedback |
  | **Search/Filter** | type query -> results filtered, clear query -> results reset, empty results state, debounce (if applicable) |
  | **Modal/Dialog** | open -> fill -> submit -> callback + close, open -> cancel -> no callback, validation errors inside modal |
  | **List/Table** | sort -> order changes, paginate -> correct page data, select item -> detail/callback, empty state |
  | **Date/Calendar** | select date -> callback with date value, range selection, invalid date handling, clear date |
  | **Rating/Slider** | select value -> callback with value, boundary values (min/max), change value -> UI reflects new state |
  | **Tabs/Navigation** | switch tab -> correct content shown, tab state persisted (if applicable), deep link to tab |
  | **CRUD** | create -> success + list updates, edit -> save + values persisted, delete -> confirm -> removed |
  | **Toast/Notification** | trigger action -> toast appears with correct message, toast auto-dismiss or manual close |
  | **Dropdown/Select** | open -> select option -> callback with value, search within dropdown (if applicable), multi-select |

- **Fix:** For each component being tested, identify its type(s) from the table above. Write at least 1 test per minimum flow. A rendering test (`getByText('Submit').toBeInTheDocument()`) does NOT count as a submit flow test.
- **Rule of thumb:** If removing the event handler wouldn't fail any test -> the test suite is rendering-only.
- **Source:** review 2026-02-22, Cursor refactoring -- 10 components tested, all had rendering coverage but 0 submit flows, 0 search flows, 0 calendar interaction. Tests scored 7/10 visually but provided zero regression safety for the actual refactoring.

### P-42: Non-Deterministic Element Selection in Tests
- **When:** Test needs to click/interact with one item from a rendered list (checkbox, table row, list item)
- **Problem:**
  ```typescript
  // WRONG -- random index fails non-reproducibly; different item each run
  const checkboxPos = faker.number.int({ min: 0, max: checkboxes.length - 1 });
  const checkbox = checkboxes[checkboxPos];
  ```
  When the test fails, you can't reproduce which checkbox caused it. CI failure != local failure.
- **Fix:** Deterministic selection + loud failure guard:
  ```typescript
  // CORRECT -- deterministic, loud, reproducible
  expect(checkboxes.length).toBeGreaterThan(0);  // fail loud if no checkboxes render
  const checkbox = checkboxes[1] ?? checkboxes[0];  // second row (avoids header checkbox)
  ```
- **When faker IS OK:** Generating test data values (names, emails, IDs) -- just not for selecting which element to interact with
- **Source:** audit 2026-02-24, ClientProfile.test.tsx -- random checkbox selection remained in v2 despite other fixes

### P-43: getByTestId Over Semantic Queries (Accessibility Gap)
- **When:** React component tests use `getByTestId` as primary query for interactive elements (buttons, inputs, links)
- **Problem:** `getByTestId` tests DOM structure, not semantics. Doesn't catch ARIA/role regressions. If a `<button>` becomes `<div onClick>`, test still passes. Ratio > 3:1 `getByTestId:getByRole` signals accessibility-blind test suite.
- **Empirical:** 6:1 `getByTestId:getByRole` ratio in 106-file Offer Module scan -- linked to accessibility gaps found in prod
- **Fix:** Prefer semantic queries in priority order:
  ```typescript
  // 1st choice -- role + accessible name
  getByRole('button', { name: /submit/i })
  getByRole('textbox', { name: /first name/i })
  // 2nd choice -- label (form inputs)
  getByLabelText(/email address/i)
  // 3rd choice -- placeholder (inputs without label)
  getByPlaceholderText(/search.../i)
  // Last resort -- testId (no semantic equivalent: custom canvas, widget)
  getByTestId('date-range-picker')
  ```
- **Exception:** `getByTestId` OK for complex custom components (date pickers, drag-drop) with no accessible role
- **Source:** audit 2026-02-24, Offer Module 106-file scan -- getByTestId:getByRole 6:1 vs target < 2:1

### P-45: Shallow Empty State (Text Absence Only)
- **When:** Component has an empty state (no results, no data loaded, filtered list has 0 items)
- **Problem:** 66/81 list/filter components in audit assert only that content is NOT present -- never verify what renders INSTEAD:
  ```typescript
  // INCOMPLETE -- proves items gone, not that empty state shows
  expect(screen.queryByText('John Doe')).not.toBeInTheDocument();
  // If empty state placeholder is also broken, this still passes
  ```
- **Fix:** Assert the empty state placeholder renders:
  ```typescript
  // COMPLETE -- proves both: data gone AND empty state shown
  expect(screen.queryByText('John Doe')).not.toBeInTheDocument();
  expect(screen.getByText('No profiles found')).toBeInTheDocument();
  // Or assert the empty state container:
  expect(screen.getByRole('status', { name: /no results/i })).toBeInTheDocument();
  ```
- **Minimum:** One test that explicitly triggers empty state + asserts the empty state element is shown
- **Source:** audit 2026-02-24, Offer Module 106-file scan -- 66/81 list files assert absence only, empty state UI unverified

### P-46: Validation Error Recovery Gap
- **When:** Form component shows inline validation errors after failed submit
- **Problem:** Only 8/32 form files in audit test that validation errors **clear** after user corrects the input. A common bug: error shown correctly on bad submit, but stays stuck even after fixing the field.
  ```typescript
  // INCOMPLETE -- tests error shown but not cleared
  await userEvent.click(submitBtn);
  expect(screen.getByText('Email is required')).toBeInTheDocument();
  // Missing: fix the field -> error should disappear
  ```
- **Full flow required:**
  ```typescript
  it('clears email error after user fixes the field', async () => {
    // 1. Submit empty -> error appears
    await userEvent.click(submitBtn);
    expect(screen.getByText('Email is required')).toBeInTheDocument();
    // 2. Fill the field -> error disappears
    await userEvent.type(screen.getByLabelText(/email/i), 'valid@test.com');
    expect(screen.queryByText('Email is required')).not.toBeInTheDocument();
    // 3. Submit now works
    expect(submitBtn).not.toBeDisabled();
  });
  ```
- **Source:** audit 2026-02-24, Offer Module 106-file scan -- 24/32 form files missing recovery flow; error-stuck bugs found in prod

### P-53: Snapshot Abuse
- **When:** Component tests use `toMatchSnapshot()` on full component trees
- **Problem:** Snapshots of 2000-line JSX give false 100% rendering coverage with zero regression safety. `--updateSnapshot` becomes a reflex -- nobody reviews 2000-line diffs. Snapshot files accumulate and rot.
  ```typescript
  // FORBIDDEN -- full JSX tree snapshot
  expect(container).toMatchSnapshot();  // 2000 lines, meaningless diff
  ```
- **When snapshots ARE OK:** Small, stable, non-JSX outputs -- serialized payload, generated SQL, error message string, formatted output
  ```typescript
  // FINE -- small deterministic output
  expect(formatCurrency(1234.56, 'USD')).toMatchInlineSnapshot(`"$1,234.56"`);
  expect(buildSQLWhere(filters)).toMatchSnapshot();  // 1 line of SQL
  ```
- **Gate:** If `toMatchSnapshot()` is the SOLE assertion on a JSX component -> counts as AP13 (zero real assertions)
- **Source:** Pattern from cross-project audit -- repos with 400+ snapshot files where `npm run fix-tests` = `jest -u`

### P-54: Timezone / Locale Sensitivity
- **When:** Test asserts date strings, formatted numbers, or locale-dependent output
- **Problem:** Test passes in UTC CI, fails for developer in UTC+2 -- or vice versa. Very hard to reproduce.
  ```typescript
  // FLAKY -- passes in UTC, fails in UTC-8
  expect(formatDate(new Date('2025-01-15'))).toBe('January 15, 2025');
  // Returns "January 14, 2025" in UTC-8 timezones
  ```
- **Fix:** Pin timezone explicitly:
  ```typescript
  // Vitest/Jest -- at top of file or in beforeAll
  const originalTZ = process.env.TZ;
  beforeAll(() => { process.env.TZ = 'UTC'; });
  afterAll(() => { process.env.TZ = originalTZ; });

  // Or use vi.setSystemTime() for date-specific tests:
  beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date('2025-01-15T12:00:00Z')); });
  afterEach(() => { vi.useRealTimers(); });
  ```
- **Detection:** Any test asserting formatted dates without explicit timezone setup = P-54 risk
- **Source:** Common cross-timezone CI failure pattern

### P-55: Flaky Async Ordering
- **When:** Test dispatches multiple async operations without controlling their resolution order
- **Problem:** Two thunks with different MSW response delays produce non-deterministic state:
  ```typescript
  // FLAKY -- order of resolution depends on MSW delay config
  await store.dispatch(fetchProfiles());
  await store.dispatch(fetchPermissions());
  expect(store.getState().profiles.loading).toBe(false);
  expect(store.getState().permissions.loading).toBe(false);
  // Sometimes passes, sometimes the second dispatch hasn't resolved
  ```
- **Fix:** Use `Promise.all` for parallel, or test each dispatch in isolation:
  ```typescript
  // CORRECT -- parallel, both awaited
  await Promise.all([
    store.dispatch(fetchProfiles()),
    store.dispatch(fetchPermissions()),
  ]);
  // OR -- test each independently
  await store.dispatch(fetchProfiles());
  expect(store.getState().profiles.loading).toBe(false);
  // separate test for permissions
  ```
- **Detection:** Multiple sequential `await store.dispatch()` calls followed by assertions on different slices
- **Source:** MSW-backed thunk tests with different `ctx.delay()` values

### P-56: Mock Drift -- Interface Divergence
- **When:** Production function/service adds a required parameter months after mock was written
- **Problem:** Mock has fewer parameters than real function. Tests pass. Production crashes.
  ```typescript
  // Production service (updated 3 months ago):
  // createOrder(data: OrderData, options: { validateStock: boolean })

  // Test mock (never updated):
  const mockService = { createOrder: vi.fn().mockResolvedValue({ id: 1 }) };
  // Test passes. Production call missing `options` crashes.
  ```
- **Fix:** Use TypeScript to enforce mock shape matches real interface:
  ```typescript
  import type { OrderService } from '../OrderService';
  // Partial mock but typed -- TS errors if service adds required method you forgot
  const mockService: Pick<OrderService, 'createOrder' | 'findById'> = {
    createOrder: vi.fn().mockResolvedValue({ id: 1 }),
    findById: vi.fn().mockResolvedValue(null),
  };
  ```
- **Detection:** Mocks typed as `as any`, `as never`, or plain object literal without interface reference
- **Source:** Common pattern in long-lived codebases with active refactoring

### P-57: Teardown Leak Detection
- **When:** Tests share global/module-level state (window properties, process.env, module-level variables)
- **Problem:** Test B passes only when run after Test A (relies on A's side effect). Impossible to run in isolation.
  ```typescript
  // Missing cleanup:
  afterEach(() => {
    // forgot: window.pageParams = originalPageParams;
    // forgot: process.env.API_URL = originalUrl;
  });
  ```
- **Fix + Detection:**
  ```typescript
  // Detect: run tests in random order
  // vitest --sequence.shuffle  OR  jest --randomize
  // If any test fails in shuffled mode -> state leak -> add cleanup

  // Standard pattern: save + restore
  let originalValue: string;
  beforeAll(() => { originalValue = window.someGlobal; });
  afterAll(() => { window.someGlobal = originalValue; });
  ```
- **CI rule:** Add `--sequence.shuffle` (Vitest) or `--randomize` (Jest) to CI test command -- fails fast on leaks
- **Source:** Cross-project audit -- "works locally, fails CI" often caused by test ordering assumptions

### P-62: Over-Mocking (Mass Unused Mock Declarations)
- **When:** Unit/integration test file with >15 `vi.mock()`/`vi.hoisted()` or `jest.mock()` calls
- **Problem:** Copy-paste mock setup from template. Many mocks declared but never asserted against (no `CalledWith`, no `mockReturnValue` consumed). Creates cognitive overhead, slows setup, masks actual dependencies.
  ```typescript
  // BAD: 46 mocks declared, only ~25 used in tests
  vi.mock('@/lib/auth', () => ({ getSession: vi.fn() }));
  vi.mock('@/lib/cache', () => ({ get: vi.fn(), set: vi.fn() }));
  vi.mock('@/lib/queue', () => ({ enqueue: vi.fn() }));  // never referenced in any test!
  vi.mock('@/lib/metrics', () => ({ track: vi.fn() }));   // never referenced in any test!
  // ... 42 more ...
  ```
- **Fix:** Audit mock list against actual test assertions. Remove mocks never verified or consumed. If file needs >15 mocks, it's testing a monolith -- split the module first.
- **Threshold:** >20 mock declarations with >30% unused = flag. Files with 20+ unused mocks averaged 3.5/10 quality.
- **Source:** audit 2026-02-24, PromptVault analyze/route.test.ts -- 46 mocks, ~20 never referenced

### P-63: E2E Silent Conditional (isVisible Guard)
- **When:** Playwright/Cypress E2E test with conditional assertion guard
- **Problem:** `if (await element.isVisible())` means test silently PASSES when element is missing. Feature can be broken and CI stays green.
  ```typescript
  // BAD: silent pass if button doesn't exist
  if (await page.locator('.submit-btn').isVisible()) {
    await page.locator('.submit-btn').click();
    await expect(page.locator('.success')).toBeVisible();
  }
  // If .submit-btn removed from page -> test passes -> zero regression safety

  // GOOD: test FAILS if element missing
  await expect(page.locator('.submit-btn')).toBeVisible();
  await page.locator('.submit-btn').click();
  await expect(page.locator('.success')).toBeVisible();
  ```
- **Relation:** Specialization of AP2 (conditional assertions) for E2E context where `isVisible()` returns boolean instead of throwing.
- **Source:** audit 2026-02-24, PromptVault e2e specs -- conditional isVisible() masked missing UI elements

### P-64: E2E Hardcoded Credentials
- **When:** E2E test fixtures or spec files with inline login credentials
- **Problem:** Credentials in source code = security risk. Also blocks running tests in different environments (staging, CI with different accounts).
  ```typescript
  // BAD: hardcoded in fixtures.ts
  const testUser = { email: 'admin@company.com', password: 'Test123!' };

  // GOOD: from env vars with validation
  const testUser = {
    email: process.env.E2E_USER_EMAIL ?? (() => { throw new Error('E2E_USER_EMAIL required') })(),
    password: process.env.E2E_USER_PASSWORD ?? (() => { throw new Error('E2E_USER_PASSWORD required') })(),
  };
  ```
- **Detection:** `grep -rn "password.*=.*['\"]" tests/ --include="*.ts"` -- any non-empty string literal = flag.
- **Source:** audit 2026-02-24, PromptVault fixtures.ts -- login/password hardcoded

### P-65: API Route Test Density
- **When:** API route/handler test file (Next.js App Router, Cloudflare Workers, serverless handlers)
- **Problem:** Too few test cases per endpoint. Missing edge cases that cause production incidents.
  ```
  Minimum per endpoint (6 tests):
    1. Happy path (200/201 + response body shape)
    2. Auth error (401/403 + service NOT called)
    3. Validation error (400 + specific field errors)
    4. Not found (404)
    5. Empty result (200 + empty array/null handling)
    6. Boundary value (max length, min value, unicode)

  Optional but recommended:
    7. Rate limit (429)
    8. Concurrent request handling
    9. Malformed input (broken JSON, wrong Content-Type)
  ```
- **Audit:** Count `it()`/`test()` per endpoint. If avg < 6 = flag. Empirical: files with <5 tests/endpoint averaged 5.5/10 quality.
- **Source:** audit 2026-02-24, PromptVault API routes -- avg 5.1 tests/endpoint, missing edge cases

---

## E2E Good Patterns

### G-56: Page Object Pattern for E2E Browser Tests
- **When:** Playwright/Cypress E2E tests with browser navigation
- **Do:** Extract page selectors and actions into page object classes. Each page = one file.
  ```typescript
  // pages/login.page.ts
  export class LoginPage {
    constructor(private page: Page) {}
    readonly emailInput = this.page.getByLabel('Email');
    readonly passwordInput = this.page.getByLabel('Password');
    readonly submitBtn = this.page.getByRole('button', { name: 'Sign in' });

    async goto() { await this.page.goto('/login'); }
    async login(email: string, password: string) {
      await this.emailInput.fill(email);
      await this.passwordInput.fill(password);
      await this.submitBtn.click();
    }
  }

  // specs/auth.spec.ts -- uses page object
  test('login with valid credentials', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await loginPage.login(testUser.email, testUser.password);
    await expect(page).toHaveURL('/dashboard');
  });
  ```
- **Why:** Selector changes = edit one file. Without PO, any UI change requires editing every spec. Maintenance cost drops ~70%.
- **Source:** audit 2026-02-24, PromptVault -- all selectors inline in 4 spec files

### G-57: E2E Data Cleanup (Test Isolation)
- **When:** E2E tests that create data (users, records, resources)
- **Do:** Clean up created data in `afterEach`/`afterAll`. Use API calls for cleanup, not UI.
  ```typescript
  let createdPromptId: string;

  test('create prompt', async ({ page }) => {
    // ... create via UI ...
    createdPromptId = await page.locator('[data-prompt-id]').getAttribute('data-prompt-id');
  });

  test.afterEach(async ({ request }) => {
    if (createdPromptId) {
      await request.delete(`/api/prompts/${createdPromptId}`);
      createdPromptId = '';
    }
  });
  ```
- **Why:** Without cleanup, tests affect each other. Order-dependent tests = flaky CI.
- **Source:** audit 2026-02-24, PromptVault -- tests create data without cleanup
