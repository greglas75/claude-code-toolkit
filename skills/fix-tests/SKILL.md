---
name: fix-tests
description: "Batch repair of systematic test quality issues. Runs Batch Diagnosis greps, identifies affected files, spawns parallel fixer agents per pattern. Use: /fix-tests --pattern P-41 [path] or /fix-tests --triage. NOT when tests need full rewrite (use /refactor or /test-audit first)."
user-invocable: true
---

# /fix-tests — Batch Test Repair

Fixes systematic test quality issues in batches. One pattern at a time — no shotgun edits.

**Designed for:** post-agent test suites where 100+ tests were written without quality gates, producing predictable systemic patterns (loading-only assertions, opaque dispatch, shallow empty states, etc.)

---

## Mandatory File Reading

Before starting ANY work, read the applicable files:

**Core (always required):**
```
1. ✅/❌  ~/.claude/test-patterns.md         — Q1-Q17 protocol, lookup table, scoring
2. ✅/❌  ~/.claude/test-patterns-catalog.md  — G-*/P-* pattern definitions (grep matched IDs)
3. ✅/❌  ~/.claude/rules/testing.md         — quality gates, Batch Diagnosis greps
```

**Conditional (load only when pattern matches):**
```
4. ✅/❌/SKIP  ~/.claude/test-patterns-redux.md    — LOAD when pattern is P-40, P-41, P-44, G-41–G-45
5. ✅/❌/SKIP  ~/.claude/test-patterns-nestjs.md   — LOAD when pattern is NestJS-AP1, NestJS-P1–P3, G-33, G-34
```

**If any CORE file (1-3) is ❌ → STOP.** Conditional files: SKIP with note if not needed for current pattern.

## Path Resolution (non-Claude-Code environments)

If `~/.claude/` is not accessible, resolve from `_agent/` in project root:
- `~/.claude/test-patterns.md` → `_agent/test-patterns.md`
- `~/.claude/test-patterns-catalog.md` → `_agent/test-patterns-catalog.md`
- `~/.claude/test-patterns-redux.md` → `_agent/test-patterns-redux.md`
- `~/.claude/test-patterns-nestjs.md` → `_agent/test-patterns-nestjs.md`
- `~/.claude/rules/testing.md` → `_agent/rules/testing.md`

## Progress Tracking

Use `TaskCreate` at the start for multi-step visibility. Update status as you progress.

---

## Step 0: Parse $ARGUMENTS

| Argument | Behavior |
|----------|----------|
| `--pattern P-41` | Fix loading-only Redux assertions |
| `--pattern G-43` | Fix opaque dispatch → vi.mock thunk |
| `--pattern P-43` | Fix getByTestId → semantic queries |
| `--pattern P-44` | Add missing rejected state tests |
| `--pattern P-45` | Add empty state placeholder assertions |
| `--pattern P-46` | Add validation error recovery tests |
| `--pattern P-40` | Fix wrong Redux initial state |
| `--pattern P-62` | Remove unused mock declarations |
| `--pattern P-63` | Replace E2E silent conditionals with assertions |
| `--pattern P-64` | Move hardcoded credentials to env vars |
| `--pattern P-65` | Add missing test cases to under-tested API routes |
| `--pattern AP10` | Upgrade tautological delegation (toHaveBeenCalled-only) to CalledWith + return value |
| `--pattern NestJS-P3` | Remove self-mock spyOn on own service, test computed output instead |
| `--pattern AP14` | Replace `toBeDefined()`/`toBeTruthy()` sole assertions with content assertions |
| `--pattern AP2` | Replace conditional assertions `if (x) { expect }` with hard assertions |
| `--pattern Q7-API` | Add `mockRejectedValue` error tests to API wrapper files with zero error coverage |
| `--pattern AP5` | Replace `as any`/`as never` mock casts with typed factories |
| `--pattern Q3-CalledWith` | Upgrade `toHaveBeenCalled()` to `toHaveBeenCalledWith(expectedArgs)` |
| `--triage` | Run Batch Diagnosis greps, report counts, ask user which to fix |
| `[path]` | Limit scope to specific directory (default: auto-detect, see Scope Discovery) |
| `--dry-run` | Show what would be changed, don't write files |
| `--bundle-gates` | When fixing a pattern, also apply adjacent quality gates (Q7 error tests, Q12 symmetry) |

Default with no args: `--triage`

### Scope Discovery

If no `[path]` specified, auto-detect test locations:
1. Check project `CLAUDE.md` or config for test directories
2. Search for test files: `find . -name "*.test.*" -o -name "*.spec.*" | head -5` — infer root directory
3. Common locations to check: `src/`, `tests/`, `test/`, `packages/`, `apps/`
4. If multiple directories found → list them and ask user which to scan

---

## Step 1: Triage

**Mode depends on invocation:**
- `--triage` (or no args): Run ALL Batch Diagnosis greps. Report full triage table. Ask user which patterns to fix.
- `--pattern P-41`: Run ONLY the grep relevant to P-41. Report count. Proceed directly to Step 2.

Run from `~/.claude/rules/testing.md` to quantify scope. Report counts BEFORE fixing.

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
find [path] -name "*.test.*" -type f -print0 | while IFS= read -r -d '' f; do
  count=$(grep -c "vi\.mock\|vi\.hoisted\|jest\.mock" "$f" 2>/dev/null || echo 0)
  [ "$count" -gt 15 ] && echo "$f: $count mocks"
done

# P-63: E2E silent conditionals
grep -rn "if.*isVisible\(\)\|if.*\.\$(" [path] --include="*.spec.*" | wc -l

# P-64: Hardcoded credentials in test files
grep -rn "password.*=.*['\"][^'\"]\+['\"]" [path] --include="*.test.*" --include="*.spec.*" --include="fixtures.*" -i | wc -l

# P-65: API route test density (count tests per file)
find [path] -name "route.test.*" -type f -print0 | while IFS= read -r -d '' f; do
  count=$(grep -c "it(\|test(" "$f" 2>/dev/null || echo 0)
  echo "$f: $count tests"
done

# AP10: Tautological delegation (toHaveBeenCalled as sole assertion — no CalledWith, no return value)
# Step 1: files with toHaveBeenCalled but no CalledWith (raw indicator)
grep -rln "\.toHaveBeenCalled\(\)\|\.toHaveBeenCalledTimes(1)" [path] --include="*.test.*" | \
  xargs -I{} sh -c 'grep -l "toHaveBeenCalledWith\|toHaveBeenLastCalledWith" {} >/dev/null 2>&1 || echo {}'
# Step 2: verify manually — if ALL assertions in file are toHaveBeenCalled → AP10

# NestJS-P3: Self-mock (spyOn on own service/controller)
grep -rn "spyOn(service\|spyOn(controller\|jest\.spyOn.*service\|jest\.spyOn.*controller" [path] --include="*.test.*" --include="*.spec.*" | grep -v "node_modules"

# AP14: toBeDefined/toBeTruthy as SOLE assertion (files where it's the majority pattern)
# Step 1: count files with high density
find [path] \( -name "*.test.*" -o -name "*.spec.*" \) -not -path "*/node_modules/*" -print0 | while IFS= read -r -d '' f; do
  total=$(grep -c "expect(" "$f" 2>/dev/null || echo 0)
  weak=$(grep -c "\.toBeDefined()\|\.toBeTruthy()" "$f" 2>/dev/null || echo 0)
  [ "$total" -gt 0 ] && ratio=$((weak * 100 / total)) || ratio=0
  [ "$ratio" -gt 40 ] && echo "$f: $weak/$total assertions are toBeDefined/toBeTruthy ($ratio%)"
done

# AP2: Conditional assertions (if-guarded expect — silent skip when condition false)
# Multiline: find if-blocks containing expect within 3 lines (catches multi-line patterns)
grep -rn -A3 "if (" [path] --include="*.test.*" --include="*.spec.*" | grep -B1 "expect\|assert" | grep "if (" | grep -v "node_modules"
# Single-line fallback:
grep -rn "if (.*) .*expect\|if (.*) return" [path] --include="*.test.*" --include="*.spec.*" | grep -v "node_modules"
# Python variant:
grep -rn -A2 "^    if " [path] --include="test_*.py" | grep -B1 "assert " | grep "if " | grep -v "node_modules"

# Q7-API: API wrapper files with zero error tests
find [path] \( -name "*.api.test.*" -o -name "*.api.spec.*" -o -name "*.client.test.*" \) -not -path "*/node_modules/*" -print0 | while IFS= read -r -d '' f; do
  rejected=$(grep -c "mockRejectedValue\|rejects\|\.reject\b" "$f" 2>/dev/null || echo 0)
  [ "$rejected" -eq 0 ] && echo "$f: 0 error tests"
done

# AP5: as any / as never in test mocks (files with high density)
find [path] \( -name "*.test.*" -o -name "*.spec.*" \) -not -path "*/node_modules/*" -print0 | while IFS= read -r -d '' f; do
  count=$(grep -c "as any\|as never" "$f" 2>/dev/null || echo 0)
  [ "$count" -gt 5 ] && echo "$f: $count as-any casts"
done

# Q3-CalledWith: toHaveBeenCalled() without any CalledWith in same file
grep -rln "\.toHaveBeenCalled()\|\.toHaveBeenCalledTimes(" [path] --include="*.test.*" --include="*.spec.*" | grep -v node_modules | while IFS= read -r f; do
  has_with=$(grep -c "toHaveBeenCalledWith\|toHaveBeenLastCalledWith\|toHaveBeenNthCalledWith" "$f" 2>/dev/null || echo 0)
  called=$(grep -c "\.toHaveBeenCalled()\|\.toHaveBeenCalledTimes(" "$f" 2>/dev/null || echo 0)
  [ "$has_with" -eq 0 ] && [ "$called" -gt 0 ] && echo "$f: $called bare .toHaveBeenCalled(), 0 CalledWith"
done
```

Report format:
```
Triage results:
  AP10 (delegation-only): [N] files (no CalledWith) → [ACTION: Fix / Skip]
  NestJS-P3 (self-mock):  [N] hits in [M] files → [ACTION: Fix / Skip]
  AP14 (toBeDefined sole): [N] files with >50% AP14 → [ACTION: Fix / Skip]
  AP2 (conditional assert):  [N] hits → [ACTION: Fix / Skip]
  Q7-API (no rejection):  [N] api wrapper files with 0 mockRejectedValue → [ACTION: Fix / Skip]
  AP5 (as-any mocks):    [N] files with >5 as-any casts → [ACTION: Fix / Skip]
  Q3-CalledWith (bare):  [N] files with 0 CalledWith → [ACTION: Fix / Skip]
  P-41 (loading-only):   [N] hits in [M] files → [ACTION: Fix / Skip]
  G-43 (opaque dispatch): [N] hits in [M] files → [ACTION: Fix / Skip]
  P-40 (wrong init state): [N] hits in [M] files → [ACTION: Fix / Skip]
  P-43 (getByTestId):    testId:[X] / byRole:[Y] = [ratio]:1 → [ACTION: Fix if >3:1 / Skip]
  P-44 (no rejected):    [N] thunks, [M] rejected tests → [ACTION: Fix if <1 per thunk / Skip]
  P-45 (shallow empty):  [N] absence-only hits → [ACTION: Fix / Skip]
  P-46 (no recovery):    [N] error-shown hits → [ACTION: Fix / Skip]
  P-62 (over-mocking):   [N] files with >15 mocks → [ACTION: Fix / Skip]
  P-63 (silent cond):    [N] isVisible guards in e2e → [ACTION: Fix / Skip]
  P-64 (hardcoded creds): [N] password literals → [ACTION: Fix / Skip]
  P-65 (route density):  [N] routes with <6 tests → [ACTION: Fix / Skip]
```

**`--triage` mode:** show full triage report, ask user "Which patterns to fix? (all / list IDs)"
**`--pattern` mode:** report only the relevant grep count, proceed to Step 2 immediately.

---

## Step 2: Identify Affected Files

For the chosen pattern(s), get the specific files (not just counts):

```bash
# Example for P-41:
grep -rln "expect(state.loading).toBe(false)\|expect(state.loading).toEqual(false)" [path] --include="*.test.*" | grep -v "#"
```

For each affected test file, find its production counterpart:
- `profileSlice.test.ts` → `profileSlice.ts` (same directory)
- `__tests__/MyComponent.test.tsx` → `MyComponent.tsx`
- If production file not found → flag as ORPHAN, skip that file

---

## Step 3: Read Production Context (before spawning fixers)

For EACH pair of (test file, production file), extract:

| Pattern | What to read in production file |
|---------|----------------------------------|
| **P-41** | Slice state interface — what fields does the state have? What does each action.payload contain? |
| **G-43** | Component file — which thunks does it dispatch? With what args? |
| **P-40** | Slice `initialState` — what is the real shape? |
| **P-43** | Component JSX — what roles/labels do interactive elements have? |
| **P-44** | Slice thunks — what does each `createAsyncThunk` return/reject? |
| **P-45** | Component — what renders in empty state (text, role, testId)? |
| **P-46** | Form component — what validation errors can appear? What clears them? |
| **P-62** | Test file mock list — which mocks are referenced in assertions? (no production file needed) |
| **P-63** | E2E spec — which elements use conditional isVisible() guards? |
| **P-64** | Fixtures/config — which credentials are hardcoded? (no production file needed) |
| **P-65** | Route handler — what auth, validation, error paths does the endpoint have? |
| **AP10** | Production service/controller — what does each public method return? What args does it pass downstream? |
| **NestJS-P3** | Production service — which injected dependencies does the method call? What does the external dep return? What does the service compute from it? |
| **AP2** | No production file needed — fix is always mechanical (remove if-guard, add direct assertion) |
| **Q7-API** | Production wrapper — which HTTP methods used? Does wrapper transform errors? Per-status handling? |
| **AP5** | Production interfaces/types — what is the real shape of the mocked object? Which fields does the test actually use? |
| **Q3-CalledWith** | Production service/handler — what args does each mocked dependency receive? What computed transformations happen before the call? |

Attach this context to each fixer agent's prompt. Without it, the agent writes generic assertions that don't match the real state shape.

---

## Step 4: Spawn Fixer Agents (batches of 5 files)

Split file pairs into batches of 5. For each batch, spawn a Task agent (`subagent_type: "general-purpose"`, `model: "sonnet"`).

**Send all batch spawns in a single message for parallel execution.**

### FIXER AGENT PROMPT (copy this for each batch):

```
You are a test repair specialist. Fix the test files below for the pattern: [PATTERN_ID].

QUALITY GATES — read [RESOLVED_RULES_PATH]/testing.md before writing. Forbidden patterns (auto-fail Q17):
- expect(screen).toBeDefined()  → tests nothing; assert actual content
- await userEvent.type(x, 'v'); expect(x).toHaveValue('v')  → UI echo; assert CalledWith on dispatch/callback instead
- expect(payload.id).toEqual(id) where id comes from mock setup  → MSW echo; assert computed fields
- expect(typeof action).toBe('function')  → opaque; vi.mock the thunk + CalledWith({ searchParams: {...} })
- if (condition) return  in test body  → silent skip; use expect(condition).toBeTruthy() to fail loud
- reducer({ initialState: {} }, action)  → wrong state; use createInitialState() factory with real shape
- expect(state.loading).toEqual(false) as ONLY assertion  → loading-only; also check data in store

- if (await el.isVisible()) { ... }  → silent pass; use await expect(el).toBeVisible() to fail loud
- >15 vi.mock() with many unused  → over-mocking; audit + remove unreferenced mocks

RESOLVED PATHS (use these, not hardcoded):
  Rules: [RESOLVED_RULES_PATH]       — resolved from ~/.claude/rules/ or _agent/rules/
  Patterns: [RESOLVED_PATTERNS_PATH] — resolved from ~/.claude/ or _agent/

PATTERN TO FIX: [PATTERN_ID]
[PASTE FULL PATTERN DESCRIPTION from the correct file:
  - Redux patterns (P-40, P-41, P-44, G-41–G-45): read [RESOLVED_PATTERNS_PATH]/test-patterns-redux.md
  - General patterns (G-1–G-40, P-1–P-46): read [RESOLVED_PATTERNS_PATH]/test-patterns-catalog.md
  Grep for the ### [PATTERN_ID] header to find the exact section.]

PRODUCTION CONTEXT (extracted from source files):
[PASTE STATE SHAPE / THUNK SIGNATURES / COMPONENT ROLES per file]

FILES TO FIX:
[LIST OF (test_file, production_file) PAIRS]

FOR EACH FILE:
1. Read the test file
2. Read the production file (already provided as context above, but re-read if needed)
3. Apply ONLY the fix for [PATTERN_ID] — do not refactor unrelated code
4. Write the fixed file
5. Self-eval Q1-Q17 (score each individually)
6. Report: filename | before-score | after-score | changes made

RULES:
- Fix ONLY the target pattern — leave unrelated issues for other runs
- Do NOT introduce new patterns or restructure existing tests
- If a test would need major rewrite to fix (not a mechanical change) → mark as SKIP + reason
- After fixing each file: run Q1-Q17 self-eval. Target ≥ 14/17, all critical gates (Q7/Q11/Q13/Q15/Q17) PASS
- If self-eval fails after fix → attempt one more iteration. If still fails → mark NEEDS_REVIEW

OUTPUT FORMAT per file:
### [filename]
Changes: [list of specific changes made]
Self-eval: Q1=_ Q2=_ Q3=_ Q4=_ Q5=_ Q6=_ Q7=_ Q8=_ Q9=_ Q10=_ Q11=_ Q12=_ Q13=_ Q14=_ Q15=_ Q16=_ Q17=_
Score: [N]/17 → [PASS/FIX/BLOCK] | Critical gate: Q7=_ Q11=_ Q13=_ Q15=_ Q17=_ → [PASS/FAIL]
Status: FIXED / SKIP ([reason]) / NEEDS_REVIEW
```

---

## Step 5: Validate Results

Collect all fixer agent outputs. Build summary:

```markdown
## Fix Results

| File | Pattern | Before | After | Status |
|------|---------|--------|-------|--------|
| profileSlice.test.ts | P-41 | 6/17 | 14/17 | FIXED ✅ |
| clientProfileFilter.test.tsx | G-43 | 8/17 | 15/17 | FIXED ✅ |
| industrySlice.test.ts | P-41 | 5/17 | 13/17 | NEEDS_REVIEW ⚠️ |
```

For any NEEDS_REVIEW: read the file yourself and add targeted fixes.

---

## Step 6: Report

Final report structure:

```markdown
## /fix-tests Report — [date]

### Summary
- Files processed: [N]
- Fixed (≥14/17): [N]
- Needs review: [N]
- Skipped: [N]

### Pattern Coverage
- P-41 (loading-only): [N] files fixed, [N] assertions upgraded
- G-43 (opaque dispatch): [N] files fixed, [N] dispatch verifications upgraded

### Remaining Issues
[Files that need manual review — specific gaps]

### Patterns NOT fixed in this run
[Patterns found in triage but not selected — with file counts for future runs]
```

### Backlog Persistence (MANDATORY)

After report, persist SKIP and NEEDS_REVIEW items to `memory/backlog.md`:
1. Read existing backlog — skip if already tracked
2. For each SKIP file: add item with reason
3. For each NEEDS_REVIEW file: add item with pattern ID + what failed
4. Print: `Backlog updated: {N} new items`

Item format:
```
| B-{N} | MEDIUM | src/profiles/profileSlice.test.ts | fix-tests SKIP: P-41 — state shape too complex for mechanical fix | fix-tests/2026-02-25 | OPEN |
```

### Next Steps

After the report:

```
NEXT STEPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run tests to verify fixes:  [detected-test-command] [fixed-files]
Review fixed files:         /review [space-separated list of FIXED files]
Manual fixes needed:        [N] NEEDS_REVIEW files in backlog (B-{X}–B-{Y})
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

`/review` on fixed test files confirms no regressions and validates self-eval improvements.

---

## Pattern-Specific Fix Notes

### P-41: Loading-only Redux Assertions

Context needed: slice state interface, what each action stores.

Fix template per action type:
```typescript
// ADD after every loading assertion:
// add.fulfilled → data appended
expect(state.profiles).toContainEqual(expect.objectContaining({ id: expect.any(Number) }));
// fetch.fulfilled → data replaced
expect(state.profiles).toEqual(FIXTURES);
// edit.fulfilled → specific record updated
expect(state.profiles.find(p => p.id === UPDATED_ID)).toMatchObject({ name: 'new name' });
// delete.fulfilled → record removed
expect(state.profiles.find(p => p.id === DELETED_ID)).toBeUndefined();
// rejected → error message set
expect(state.error).toBe('specific error message for THIS action');
```

### G-43: Opaque Dispatch → vi.mock Thunk

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

### P-43: getByTestId → Semantic Queries

Fix priority:
1. `getByTestId('submit-button')` → `getByRole('button', { name: /submit/i })`
2. `getByTestId('email-input')` → `getByLabelText(/email/i)` or `getByPlaceholderText(/email/i)`
3. `getByTestId('search-input')` → `getByRole('searchbox')` or `getByPlaceholderText(/search/i)`
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
3. If mock has zero references in any test → DELETE the declaration
4. If file still has >15 mocks after cleanup → flag as NEEDS_SPLIT (monolithic test)

### P-63: E2E Silent Conditional → Direct Assertion

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

Also check for: `if (await page.$('.selector'))` — same pattern, different API.

### P-64: Hardcoded Credentials → Env Vars

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

### AP2: Conditional Assertion → Hard Assertion

Context needed: none (mechanical — the fix is always the same pattern).

**Trigger:** `if (condition) { expect(...) }` or `if (x) return` inside test body. When `condition` is false, the test body is skipped and the test **passes silently** — with zero assertions verified.

**Python variant:** `if results: assert ...` — skips when results is empty.

**Fix:** Remove the conditional. Assert the condition directly, then assert the content:

```typescript
// BEFORE — silent skip when results is empty:
if (results.length > 0) {
  expect(results[0].name).toBe('Alice');
}

// AFTER — fails loud when results is empty:
expect(results.length).toBeGreaterThan(0);  // explicit: we expect data here
expect(results[0].name).toBe('Alice');
```

```python
# BEFORE — silent skip when results is empty:
if results:
    assert results[0]["name"] == "Alice"

# AFTER — fails loud:
assert len(results) > 0, "Expected at least one result"
assert results[0]["name"] == "Alice"
```

**`if (element)` pattern in RTL:**
```typescript
// BEFORE:
const btn = screen.queryByRole('button');
if (btn) { expect(btn).toBeDisabled(); }

// AFTER:
const btn = screen.getByRole('button');  // throws if missing — no silent skip
expect(btn).toBeDisabled();
```

**SKIP when:** the condition is genuinely optional behavior (`if (feature flag enabled) ...`) — but then add a comment explaining why the conditional is intentional, not a test gap.

### Q7-API: API Wrapper Error Tests — Add mockRejectedValue

Context needed: production API wrapper file — which HTTP methods does each function call? Does the wrapper transform errors?

**Trigger:** `*.api.test.ts` / `*.api.spec.ts` / `*.client.test.ts` file has success tests but zero `mockRejectedValue` / `rejects` / `catch` tests.

**Fix — add one rejection test per exported async function:**

```typescript
// For each function that has a success test, add:
it('rejects when [functionName] request fails', async () => {
  mockHttp.get.mockRejectedValue(new Error('Network error'));
  await expect(getUsers()).rejects.toThrow('Network error');
});

// If wrapper transforms errors (catches + re-throws):
it('wraps 401 response as UnauthorizedError', async () => {
  mockHttp.get.mockRejectedValue({ response: { status: 401 } });
  await expect(getUsers()).rejects.toBeInstanceOf(UnauthorizedError);
  // OR if it converts to a message:
  await expect(getUsers()).rejects.toThrow('Unauthorized');
});

// If wrapper has specific error handling (e.g., returns null on 404):
it('returns null when resource not found (404)', async () => {
  mockHttp.get.mockRejectedValue({ response: { status: 404 } });
  const result = await getUser('unknown-id');
  expect(result).toBeNull();
});
```

**Read the wrapper first** to know:
1. Does it catch errors and transform them? → test the transformation
2. Does it let errors propagate? → test with generic `rejects.toThrow`
3. Does it have per-status-code handling? → test each status code path

**Batch note:** In `*.api.test.ts` files, all functions follow the same pattern. One agent can process all 5-8 files in a directory with the same template.

### AP14: toBeDefined/toBeTruthy Sole Assertion → Content Check

Context needed: the production code/registration to know what the actual value is.

**Trigger:** `expect(x).toBeDefined()` or `expect(x).toBeTruthy()` is the ONLY assertion for a test. The value could be anything truthy and the test still passes.

**Fix — determine what the actual value should be, then assert it:**
```typescript
// BEFORE — proves something exists, not what it is:
expect(registry.getComponent('text')).toBeDefined();
expect(result.items).toBeTruthy();

// AFTER — asserts the actual identity/content:
expect(registry.getComponent('text')).toBe(TextQuestionComponent);
expect(result.items).toEqual([ITEM_1, ITEM_2]);
// OR if exact value unknown but shape is verifiable:
expect(registry.getComponent('text')).toMatchObject({ type: 'text', render: expect.any(Function) });
expect(result.items).toHaveLength(2);
expect(result.items[0]).toHaveProperty('id');
```

**Priority order for replacement:**
1. `toBe(ExactValue)` — when value is a specific constant/component/enum
2. `toEqual(fixture)` — when value is a data structure you can reproduce
3. `toMatchObject({...})` — when verifying shape with key fields
4. `toHaveLength(N)` + `toContainEqual(...)` — when verifying collections

**SKIP when:** `toBeDefined()` is SUPPLEMENTAL alongside a more specific assertion in the same test — don't remove it, just note it's already covered.

**Batch note:** In registry/factory patterns (settingsRegistry, componentRegistry), each `getComponent('type')` call should assert the specific registered component class, not just existence. Read the registry to find what's registered.

### AP10: Tautological Delegation — Upgrade to CalledWith + Return Value

Context needed: production service/controller to know what each method returns and what args it passes to its dependencies.

**Trigger:** Test only asserts `toHaveBeenCalled()` or `toHaveBeenCalledTimes(1)` — never checks argument content or return value. Every test follows the pattern: "call method → verify mock called once → done."

**Critical distinction from G-43:** G-43 is Redux dispatch opaque type check. AP10 is SERVICE/CONTROLLER delegation where return value and argument content are never verified.

Fix — for each tautological test, add both:
1. `toHaveBeenCalledWith(expect.objectContaining({...}))` — verify WHAT was passed downstream
2. Assertion on return value — verify WHAT was returned to the caller

```typescript
// BEFORE — tautological delegation:
it('should call dataService.process', async () => {
  mockDataService.process.mockResolvedValue(RESULT);
  await service.run(INPUT);
  expect(mockDataService.process).toHaveBeenCalled();  // sole assertion
});

// AFTER — verify content + result:
it('processes input with correct args and returns transformed result', async () => {
  mockDataService.process.mockResolvedValue(RAW_RESULT);
  const result = await service.run(INPUT);
  // What was passed downstream?
  expect(mockDataService.process).toHaveBeenCalledWith(
    expect.objectContaining({ field: INPUT.field, normalized: true })
  );
  // What was returned (computed from RAW_RESULT)?
  expect(result.status).toBe('processed');  // NOT equal to RAW_RESULT.status — it was transformed
});
```

**Watch for Q17:** the return value assertion must verify a COMPUTED value, not an echo of RAW_RESULT. If service just passes through the dep's return unchanged, assert it's the correct passthrough with `toEqual(RAW_RESULT)` AND add a separate test for error propagation.

**Optional Adjacent Fix (`--bundle-gates` only):** also add one error-path test per public method (Q7) — `mockRejectedValue` + `rejects.toThrow`. Without `--bundle-gates`, leave Q7 gaps for a separate `/fix-tests --pattern Q7-API` run.

**SKIP when:** the method genuinely is a pure delegation (adapter) with no transformation — then `toEqual(RAW_RESULT)` is correct and the test should add `toHaveBeenCalledWith` but is not AP10.

### NestJS-P3: Self-Mock → Test External Dep + Computed Output

Context needed: production service to identify which injected external dependency the mocked-own-method delegates to, and what the service computes from the external dep's return value.

**Trigger:** `jest.spyOn(service, 'ownMethod').mockResolvedValue(X)` in a test for the same service class.

Fix — 3 steps per file:

**Step 1:** Identify what `ownMethod` internally calls (read production file):
```typescript
// In production: service.getDataChanged() calls this.googleService.fetchData() and diffService.compare()
```

**Step 2:** Replace spyOn with mock on the EXTERNAL injected dep:
```typescript
// REMOVE:
jest.spyOn(service, 'getDataChanged').mockResolvedValue(MOCK_DIFF);

// ADD (mock the real external deps):
mockGoogleService.fetchData.mockResolvedValue(GOOGLE_DATA);
mockDiffService.compare.mockResolvedValue(MOCK_DIFF);
```

**Step 3:** Add assertion on COMPUTED output (not just that the external mock was called):
```typescript
// BEFORE (tautological):
expect(mockSpyGetDataChanged).toHaveBeenCalledWith(req);

// AFTER (computed):
const result = await service.importData(req);
expect(mockGoogleService.fetchData).toHaveBeenCalledWith(req.sheetId);
expect(result.newRecords).toBe(MOCK_DIFF.filter(d => d.isNew).length);  // computed from diff
expect(result.updatedRecords).toBe(MOCK_DIFF.filter(d => !d.isNew).length);
```

**Optional Adjacent Fix (`--bundle-gates` only):** also add one `.rejects.toThrow()` test per public method (Q7 gap that always appears with NestJS-P3). Without `--bundle-gates`, leave Q7 gaps for a separate run.

**Batch note (from 2026-02-24 audit):** task-schedule services all follow the same 6-method structure (import/sheet/diff/add/update/logError). Same fix template applies to all. Each file also needs:
- Direct test for the `getDataChanged`/diff method with real inputs (null req, empty req, new records, unchanged records)
- `logError` method test (untested in all files)

### P-65: API Route Test Density — Add Missing Cases

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

Read the route handler to identify which cases are missing. Don't generate generic tests — match assertions to actual response shapes.

### AP5: `as any` / `as never` Mock Casts → Typed Factories

Context needed: production interface/type that the mock should satisfy. Read imports in test file to find the type, then read the production type definition.

**Trigger:** `as any` or `as never` used to silence TypeScript when creating mock objects or casting mock return values. High density (>5 per file) indicates the test was written without proper type support.

**Fix strategy — 3 tiers based on scope:**

**Tier 1: Inline cast on mock return value (most common)**
```typescript
// BEFORE:
mockService.getUser.mockResolvedValue({ id: 1, name: 'Alice' } as any);

// AFTER — satisfy the interface:
const mockUser: User = { id: 1, name: 'Alice', email: 'a@b.com', role: 'user', createdAt: new Date() };
mockService.getUser.mockResolvedValue(mockUser);
```

**Tier 2: Mock object creation with `as any`**
```typescript
// BEFORE:
const mockCtx = { req: { headers: {} }, res: {} } as any;

// AFTER — create typed factory:
function createMockContext(overrides: Partial<RequestContext> = {}): RequestContext {
  return {
    req: { headers: {}, method: 'GET', url: '/', ...overrides.req },
    res: { status: vi.fn().mockReturnThis(), json: vi.fn(), ...overrides.res },
    ...overrides,
  };
}
const mockCtx = createMockContext();
```

**Tier 3: Shared factory for repeated patterns (Q9 fix bundled)**
When the same `as any` pattern repeats across 3+ test files (e.g., `RequestContext`, `Repository`, `Service`):
1. Create `__tests__/factories/` directory (or `test/helpers/`)
2. Move factory to shared file
3. Import in all affected test files

```typescript
// __tests__/factories/context.factory.ts
import type { RequestContext } from '../../types';
export function createMockContext(overrides: Partial<RequestContext> = {}): RequestContext {
  return { /* full typed shape */ ...overrides };
}
```

**Priority order:**
1. Fix Tier 2 first (object creation) — biggest type safety win
2. Then Tier 1 (return values) — most numerous
3. Tier 3 only if same factory pattern appears 3+ times across files

**SKIP when:** `as any` is on a genuinely untyped third-party library with no `@types/*` available — add `// eslint-disable-next-line @typescript-eslint/no-explicit-any` comment instead.

**Batch note:** In NestJS projects, `RequestContext` and repository mocks are the #1 source of `as any`. One shared factory eliminates 50%+ of casts across the entire test suite. Read the repository interface first, then build the factory once.

### Q3-CalledWith: Bare `toHaveBeenCalled()` → `toHaveBeenCalledWith(args)`

Context needed: production code for each mocked dependency — what args does the method receive? Are args transformed before the call?

**Trigger:** File has `toHaveBeenCalled()` or `toHaveBeenCalledTimes(N)` assertions but zero `toHaveBeenCalledWith` anywhere. The test proves "something was called" but not "the right thing was called with the right data."

**Critical distinction from AP10:** AP10 = delegation-only tests (CalledWith is the ONLY assertion). Q3-CalledWith = tests that may have other assertions (return values, state changes) but the mock call verification is bare.

**Fix — for each bare `toHaveBeenCalled()`:**

1. Read production code to find what args the dependency receives
2. Replace with `toHaveBeenCalledWith`:

```typescript
// BEFORE:
expect(mockEmailService.send).toHaveBeenCalled();

// AFTER — verify WHAT was sent:
expect(mockEmailService.send).toHaveBeenCalledWith(
  expect.objectContaining({
    to: user.email,
    subject: expect.stringContaining('Welcome'),
    template: 'welcome',
  })
);
```

**For `toHaveBeenCalledTimes(N)`:** keep the count check AND add CalledWith:
```typescript
// BEFORE:
expect(mockRepo.save).toHaveBeenCalledTimes(2);

// AFTER — keep count + add content:
expect(mockRepo.save).toHaveBeenCalledTimes(2);
expect(mockRepo.save).toHaveBeenNthCalledWith(1, expect.objectContaining({ type: 'create' }));
expect(mockRepo.save).toHaveBeenNthCalledWith(2, expect.objectContaining({ type: 'update' }));
```

**Also add negative verification (Q12 symmetry):**
```typescript
// After verifying the call was made with correct args:
expect(mockEmailService.send).toHaveBeenCalledWith(expect.objectContaining({ to: user.email }));
// Add negative: service that should NOT be called in this path
expect(mockNotificationService.push).not.toHaveBeenCalled();
```

**Watch for Q17:** The CalledWith args must include COMPUTED values, not just echo of input. If production code transforms the input before calling the dep, assert the transformed value:
```typescript
// Production code: this.repo.save({ ...input, slug: slugify(input.name), createdAt: expect.any(Date) })
expect(mockRepo.save).toHaveBeenCalledWith(
  expect.objectContaining({
    name: INPUT.name,
    slug: 'my-project-name',  // COMPUTED via slugify, not echo of INPUT.slug
    createdAt: expect.any(Date),  // COMPUTED, not from input
  })
);
```

**SKIP when:** the mock is a logger or metrics collector where argument content is not behaviorally significant — bare `toHaveBeenCalled()` is acceptable for fire-and-forget observability calls.

**Batch note:** Handler/controller test files are the #1 source of bare CalledWith — they verify "service was called" after request but never check what args the service received. Process all handler tests in one batch since they follow identical patterns.
