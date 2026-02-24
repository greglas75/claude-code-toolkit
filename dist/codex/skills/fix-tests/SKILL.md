---
name: fix-tests
description: "Batch repair of systematic test quality issues. Runs Batch Diagnosis greps, identifies affected files, spawns parallel fixer agents per pattern. Use: /fix-tests --pattern P-41 [path] or /fix-tests --triage"
---

# /fix-tests -- Batch Test Repair

Fixes systematic test quality issues in batches. One pattern at a time -- no shotgun edits.

**Designed for:** post-agent test suites where 100+ tests were written without quality gates, producing predictable systemic patterns (loading-only assertions, opaque dispatch, shallow empty states, etc.)

---

## Mandatory File Reading (NON-NEGOTIABLE)

Before starting ANY work, read ALL files below:

```
1. [x]/[ ]  ~/.codex/test-patterns.md         -- Q1-Q17 protocol, lookup table, scoring
2. [x]/[ ]  ~/.codex/test-patterns-catalog.md  -- G-*/P-* pattern definitions (grep matched IDs)
3. [x]/[ ]  ~/.codex/test-patterns-redux.md    -- Redux patterns: G-41–G-45, P-40, P-41, P-44
4. [x]/[ ]  ~/.codex/rules/testing.md         -- quality gates, Batch Diagnosis greps
5. [x]/[ ]  ~/.codex/test-patterns-nestjs.md   -- NestJS patterns: G-33–G-34, NestJS-G1–G2, NestJS-AP1, NestJS-P1–P3, S1–S7
```

**If ANY file is [ ] -> STOP. Do not proceed.**
File 3 only needed when fixing Redux patterns (P-40, P-41, P-44, G-41–G-45).
File 5 only needed when fixing NestJS controller patterns (NestJS-AP1, NestJS-P1–P3, G-33, G-34).

## Path Resolution (non-Claude-Code environments)

If `~/.codex/` is not accessible, resolve from `_agent/` in project root:
- `~/.codex/test-patterns.md` -> `_agent/test-patterns.md`
- `~/.codex/test-patterns-catalog.md` -> `_agent/test-patterns-catalog.md`
- `~/.codex/test-patterns-redux.md` -> `_agent/test-patterns-redux.md`
- `~/.codex/test-patterns-nestjs.md` -> `_agent/test-patterns-nestjs.md`
- `~/.codex/rules/testing.md` -> `_agent/rules/testing.md`

---

## Step 0: Parse $ARGUMENTS

| Argument | Behavior |
|----------|----------|
| `--pattern P-41` | Fix loading-only Redux assertions |
| `--pattern G-43` | Fix opaque dispatch -> vi.mock thunk |
| `--pattern P-43` | Fix getByTestId -> semantic queries |
| `--pattern P-44` | Add missing rejected state tests |
| `--pattern P-45` | Add empty state placeholder assertions |
| `--pattern P-46` | Add validation error recovery tests |
| `--pattern P-40` | Fix wrong Redux initial state |
| `--pattern P-62` | Remove unused mock declarations |
| `--pattern P-63` | Replace E2E silent conditionals with assertions |
| `--pattern P-64` | Move hardcoded credentials to env vars |
| `--pattern P-65` | Add missing test cases to under-tested API routes |
| `--triage` | Run Batch Diagnosis greps, report counts, ask user which to fix |
| `[path]` | Limit scope to specific directory (default: `src/`) |
| `--dry-run` | Show what would be changed, don't write files |

Default with no args: `--triage`

---

## Step 1: Triage (ALWAYS -- even if pattern specified)

Run Batch Diagnosis greps from `~/.codex/rules/testing.md` to quantify scope. Report counts BEFORE fixing.

```bash
# P-41: Loading-only assertions
grep -rn "expect(state.loading).toBe(false)\|expect(state.loading).toEqual(false)" [path] --include="*.test.*" | grep -v "#" | wc -l

# G-43 needed: Opaque dispatch
grep -rn "expect(typeof dispatchedAction).toBe('function')\|typeof.*dispatch.*calls.*\[0\].*\[0\].*function" [path] --include="*.test.*" | wc -l

# P-40: Wrong initial state
grep -rn "reducer({ initialState: {}" [path] --include="*.test.*" | wc -l

# P-43: getByTestId vs getByRole ratio
echo "testId: $(grep -rn "getByTestId\|queryByTestId" [path] --include="*.test.*" | wc -l)"
echo "byRole: $(grep -rn "getByRole\|queryByRole" [path] --include="*.test.*" | wc -l)"

# P-44: Missing rejected state coverage
grep -rn "\.rejected\.type\|\.rejected," [path] --include="*.test.*" | wc -l

# P-45: Empty state absence-only
grep -rn "not\.toBeInTheDocument\(\)" [path] --include="*.test.*" | wc -l

# P-46: Validation error recovery
grep -rn "is required\|is invalid\|Please enter\|Field required" [path] --include="*.test.*" -i | wc -l

# P-62: Over-mocking (files with >15 mock declarations)
for f in $(find [path] -name "*.test.*" -type f); do
  count=$(grep -c "vi\.mock\|vi\.hoisted\|jest\.mock" "$f" 2>/dev/null || echo 0)
  [ "$count" -gt 15 ] && echo "$f: $count mocks"
done

# P-63: E2E silent conditionals
grep -rn "if.*isVisible\(\)\|if.*\.\$(" [path] --include="*.spec.*" | wc -l

# P-64: Hardcoded credentials in test files
grep -rn "password.*=.*['\"][^'\"]\+['\"]" [path] --include="*.test.*" --include="*.spec.*" --include="fixtures.*" -i | wc -l

# P-65: API route test density (count tests per file)
for f in $(find [path] -name "route.test.*" -type f); do
  count=$(grep -c "it(\|test(" "$f" 2>/dev/null || echo 0)
  echo "$f: $count tests"
done
```

Report format:
```
Triage results:
  P-41 (loading-only):   [N] hits in [M] files -> [ACTION: Fix / Skip]
  G-43 (opaque dispatch): [N] hits in [M] files -> [ACTION: Fix / Skip]
  P-40 (wrong init state): [N] hits in [M] files -> [ACTION: Fix / Skip]
  P-43 (getByTestId):    testId:[X] / byRole:[Y] = [ratio]:1 -> [ACTION: Fix if >3:1 / Skip]
  P-44 (no rejected):    [N] thunks, [M] rejected tests -> [ACTION: Fix if <1 per thunk / Skip]
  P-45 (shallow empty):  [N] absence-only hits -> [ACTION: Fix / Skip]
  P-46 (no recovery):    [N] error-shown hits -> [ACTION: Fix / Skip]
  P-62 (over-mocking):   [N] files with >15 mocks -> [ACTION: Fix / Skip]
  P-63 (silent cond):    [N] isVisible guards in e2e -> [ACTION: Fix / Skip]
  P-64 (hardcoded creds): [N] password literals -> [ACTION: Fix / Skip]
  P-65 (route density):  [N] routes with <6 tests -> [ACTION: Fix / Skip]
```

If `--pattern` specified: only run the relevant grep, proceed to Step 2 immediately.
Otherwise: show triage report, ask user "Which patterns to fix? (all / list IDs)"

---

## Step 2: Identify Affected Files

For the chosen pattern(s), get the specific files (not just counts):

```bash
# Example for P-41:
grep -rln "expect(state.loading).toBe(false)\|expect(state.loading).toEqual(false)" [path] --include="*.test.*" | grep -v "#"
```

For each affected test file, find its production counterpart:
- `profileSlice.test.ts` -> `profileSlice.ts` (same directory)
- `__tests__/MyComponent.test.tsx` -> `MyComponent.tsx`
- If production file not found -> flag as ORPHAN, skip that file

---

## Step 3: Read Production Context (before spawning fixers)

For EACH pair of (test file, production file), extract:

| Pattern | What to read in production file |
|---------|----------------------------------|
| **P-41** | Slice state interface -- what fields does the state have? What does each action.payload contain? |
| **G-43** | Component file -- which thunks does it dispatch? With what args? |
| **P-40** | Slice `initialState` -- what is the real shape? |
| **P-43** | Component JSX -- what roles/labels do interactive elements have? |
| **P-44** | Slice thunks -- what does each `createAsyncThunk` return/reject? |
| **P-45** | Component -- what renders in empty state (text, role, testId)? |
| **P-46** | Form component -- what validation errors can appear? What clears them? |
| **P-62** | Test file mock list -- which mocks are referenced in assertions? (no production file needed) |
| **P-63** | E2E spec -- which elements use conditional isVisible() guards? |
| **P-64** | Fixtures/config -- which credentials are hardcoded? (no production file needed) |
| **P-65** | Route handler -- what auth, validation, error paths does the endpoint have? |

Attach this context to each fixer agent's prompt. Without it, the agent writes generic assertions that don't match the real state shape.

---

## Step 4: Spawn Fixer Agents (batches of 5 files)

Split file pairs into batches of 5. For each batch, evaluate each batch inline.

**Send all batch spawns in a single message for parallel execution.**

### FIXER AGENT PROMPT (copy this for each batch):

```
You are a test repair specialist. Fix the test files below for the pattern: [PATTERN_ID].

QUALITY GATES -- read _agent/rules/testing.md before writing. Forbidden patterns (auto-fail Q17):
- expect(screen).toBeDefined()  -> tests nothing; assert actual content
- await userEvent.type(x, 'v'); expect(x).toHaveValue('v')  -> UI echo; assert CalledWith on dispatch/callback instead
- expect(payload.id).toEqual(id) where id comes from mock setup  -> MSW echo; assert computed fields
- expect(typeof action).toBe('function')  -> opaque; vi.mock the thunk + CalledWith({ searchParams: {...} })
- if (condition) return  in test body  -> silent skip; use expect(condition).toBeTruthy() to fail loud
- reducer({ initialState: {} }, action)  -> wrong state; use createInitialState() factory with real shape
- expect(state.loading).toEqual(false) as ONLY assertion  -> loading-only; also check data in store

- if (await el.isVisible()) { ... }  -> silent pass; use await expect(el).toBeVisible() to fail loud
- >15 vi.mock() with many unused  -> over-mocking; audit + remove unreferenced mocks

PATTERN TO FIX: [PATTERN_ID]
[PASTE FULL PATTERN DESCRIPTION from the correct file:
  - Redux patterns (P-40, P-41, P-44, G-41–G-45): read _agent/test-patterns-redux.md
  - General patterns (G-1–G-40, P-1–P-46): read _agent/test-patterns-catalog.md
  Grep for the ### [PATTERN_ID] header to find the exact section.]

PRODUCTION CONTEXT (extracted from source files):
[PASTE STATE SHAPE / THUNK SIGNATURES / COMPONENT ROLES per file]

FILES TO FIX:
[LIST OF (test_file, production_file) PAIRS]

FOR EACH FILE:
1. Read the test file
2. Read the production file (already provided as context above, but re-read if needed)
3. Apply ONLY the fix for [PATTERN_ID] -- do not refactor unrelated code
4. Write the fixed file
5. Self-eval Q1-Q17 (score each individually)
6. Report: filename | before-score | after-score | changes made

RULES:
- Fix ONLY the target pattern -- leave unrelated issues for other runs
- Do NOT introduce new patterns or restructure existing tests
- If a test would need major rewrite to fix (not a mechanical change) -> mark as SKIP + reason
- After fixing each file: run Q1-Q17 self-eval. Target >= 14/17, all critical gates (Q7/Q11/Q13/Q15/Q17) PASS
- If self-eval fails after fix -> attempt one more iteration. If still fails -> mark NEEDS_REVIEW

OUTPUT FORMAT per file:
### [filename]
Changes: [list of specific changes made]
Self-eval: Q1=_ Q2=_ Q3=_ Q4=_ Q5=_ Q6=_ Q7=_ Q8=_ Q9=_ Q10=_ Q11=_ Q12=_ Q13=_ Q14=_ Q15=_ Q16=_ Q17=_
Score: [N]/17 -> [PASS/FIX/BLOCK] | Critical gate: Q7=_ Q11=_ Q13=_ Q15=_ Q17=_ -> [PASS/FAIL]
Status: FIXED / SKIP ([reason]) / NEEDS_REVIEW
```

---

## Step 5: Validate Results

Collect all fixer agent outputs. Build summary:

```markdown
## Fix Results

| File | Pattern | Before | After | Status |
|------|---------|--------|-------|--------|
| profileSlice.test.ts | P-41 | 6/17 | 14/17 | FIXED [x] |
| clientProfileFilter.test.tsx | G-43 | 8/17 | 15/17 | FIXED [x] |
| industrySlice.test.ts | P-41 | 5/17 | 13/17 | NEEDS_REVIEW ⚠️ |
```

For any NEEDS_REVIEW: read the file yourself and add targeted fixes.

---

## Step 6: Report

Final report structure:

```markdown
## /fix-tests Report -- [date]

### Summary
- Files processed: [N]
- Fixed (>=14/17): [N]
- Needs review: [N]
- Skipped: [N]

### Pattern Coverage
- P-41 (loading-only): [N] files fixed, [N] assertions upgraded
- G-43 (opaque dispatch): [N] files fixed, [N] dispatch verifications upgraded

### Remaining Issues
[Files that need manual review -- specific gaps]

### Patterns NOT fixed in this run
[Patterns found in triage but not selected -- with file counts for future runs]
```

---

## Pattern-Specific Fix Notes

### P-41: Loading-only Redux Assertions

Context needed: slice state interface, what each action stores.

Fix template per action type:
```typescript
// ADD after every loading assertion:
// add.fulfilled -> data appended
expect(state.profiles).toContainEqual(expect.objectContaining({ id: expect.any(Number) }));
// fetch.fulfilled -> data replaced
expect(state.profiles).toEqual(FIXTURES);
// edit.fulfilled -> specific record updated
expect(state.profiles.find(p => p.id === UPDATED_ID)).toMatchObject({ name: 'new name' });
// delete.fulfilled -> record removed
expect(state.profiles.find(p => p.id === DELETED_ID)).toBeUndefined();
// rejected -> error message set
expect(state.error).toBe('specific error message for THIS action');
```

### G-43: Opaque Dispatch -> vi.mock Thunk

Fix template:
```typescript
// REPLACE dispatchSpy pattern with:
vi.mock('../sliceName', async () => {
  const actual = await vi.importActual('../sliceName');
  return { ...actual, fetchItems: vi.fn(args => () => ({ type: 'mock', payload: args })) };
});
// REPLACE typeof assertion with:
expect(fetchItems).toHaveBeenCalledWith(expect.objectContaining({ key: 'value' }));
```

### P-40: Wrong Initial State

Fix template:
```typescript
// REPLACE:
const state = reducer({ initialState: {} }, action);
// WITH:
const createInitialState = (overrides = {}) => ({ ...sliceInitialState, ...overrides });
const state = reducer(createInitialState({ loading: true }), action);
```

### P-43: getByTestId -> Semantic Queries

Fix priority:
1. `getByTestId('submit-button')` -> `getByRole('button', { name: /submit/i })`
2. `getByTestId('email-input')` -> `getByLabelText(/email/i)` or `getByPlaceholderText(/email/i)`
3. `getByTestId('search-input')` -> `getByRole('searchbox')` or `getByPlaceholderText(/search/i)`
4. Keep `getByTestId` only if no semantic equivalent exists (date pickers, canvas, custom widgets)

### P-44: Missing Rejected State Tests

Add per thunk:
```typescript
it('[thunkName].rejected sets error message', () => {
  const state = reduceFrom({ type: thunkName.rejected.type, error: { message: 'Network error' } });
  expect(state.error).toBe('Network error');
  expect(state.loading).toBe(false);
  // Data should be unchanged:
  expect(state.items).toEqual([]);
});
```

### P-45: Shallow Empty State

Add after existing absence assertions:
```typescript
// AFTER:
expect(screen.queryByText('John Doe')).not.toBeInTheDocument();
// ADD:
expect(screen.getByText('No profiles found')).toBeInTheDocument();
// OR use role if component has aria-live:
expect(screen.getByRole('status')).toHaveTextContent('No results');
```

### P-46: Validation Error Recovery

Add full recovery flow:
```typescript
it('clears [field] error after user fixes input', async () => {
  await userEvent.click(submitBtn);
  expect(screen.getByText('[error message]')).toBeInTheDocument();
  await userEvent.type(screen.getByLabelText(/[field]/i), 'valid value');
  expect(screen.queryByText('[error message]')).not.toBeInTheDocument();
});
```

### P-62: Over-Mocking (Remove Unused Mocks)

Context needed: list of all `vi.mock()`/`vi.hoisted()` declarations + which ones are actually used in tests.

Fix strategy per file:
1. List all mock declarations (top-level `vi.mock()`, `vi.hoisted()`)
2. For each mock: search test body for references (CalledWith, mockReturnValue, mockResolvedValue)
3. If mock has zero references in any test -> DELETE the declaration
4. If file still has >15 mocks after cleanup -> flag as NEEDS_SPLIT (monolithic test)

### P-63: E2E Silent Conditional -> Direct Assertion

Fix template:
```typescript
// REPLACE:
if (await page.locator('.submit-btn').isVisible()) {
  await page.locator('.submit-btn').click();
}

// WITH:
const submitBtn = page.locator('.submit-btn');
await expect(submitBtn).toBeVisible();
await submitBtn.click();
```

Also check for: `if (await page.$('.selector'))` -- same pattern, different API.

### P-64: Hardcoded Credentials -> Env Vars

Fix template:
```typescript
// REPLACE:
const testUser = { email: 'admin@company.com', password: 'Test123!' };

// WITH:
const testUser = {
  email: process.env.E2E_USER_EMAIL!,
  password: process.env.E2E_USER_PASSWORD!,
};
```

Also add `.env.test` or `.env.e2e` to the project with the values, and add the env var names to `.env.example`.

### P-65: API Route Test Density -- Add Missing Cases

Context needed: the route handler code (what validations, auth checks, error paths exist).

Per endpoint, ensure these test cases exist (add missing ones):
```typescript
describe('POST /api/[resource]', () => {
  it('returns 200 with valid data', ...);       // happy path
  it('returns 401 without auth', ...);           // auth error
  it('returns 400 with invalid [field]', ...);   // validation
  it('returns 404 for non-existent [id]', ...);  // not found
  it('returns 200 with empty result set', ...);  // empty
  it('handles boundary values', ...);            // edge case
});
```

Read the route handler to identify which cases are missing. Don't generate generic tests -- match assertions to actual response shapes.
