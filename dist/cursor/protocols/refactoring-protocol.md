# Refactoring Protocol -- ETAP-1A -> 1B -> 2

> **Read `~/.cursor/skills/refactor/rules.md` for:** types table, iron rules, hard gates, scope fence, sub-agents.
> **Read `~/.cursor/refactoring-examples/{stack}.md` for:** test templates, assertion patterns, mock patterns, AST helpers.

---

# ETAP 1A: ANALYZE & SCOPE FREEZE

> **Role:** Senior Software Architect analyzing code for refactoring.
> **Mode:** READ-ONLY -- analysis, specs, scope freeze (NO CODE CHANGES)
> **Output:** Audit, extraction list, test specs, plan -> FROZEN SCOPE for ETAP 1B

---

## Stage 0: Backup

Create git-based backup before any analysis:

```bash
git branch --show-current
git stash -u -m "pre-refactor-$(date +%Y%m%d-%H%M%S)"
git checkout -b backup/refactor-[name]-$(date +%Y%m%d-%H%M%S)
git checkout -
```

**Status:** Record as VERIFIED (if agent ran commands) or NOT VERIFIED (user must confirm).

---

## Stage 0.5: Baseline Verification

After backup, before analysis -- collect baseline metrics for the detected REFACTORING_TYPE.

| Type | Baseline Action |
|------|----------------|
| BREAK_CIRCULAR | `npx madge --circular --extensions ts,js src/` -> record cycle count. **Fallback:** if madge fails or returns empty on complex TS paths (path aliases, monorepos), use `npx eslint --rule '{"import/no-cycle": "error"}' src/` or manual grep for bidirectional imports between target files. |
| MOVE, RENAME_MOVE | `npx tsc --noEmit` -> must PASS before changes |
| INTRODUCE_INTERFACE | `npx tsc --noEmit` -> record PASS/FAIL |
| FIX_ERROR_HANDLING | `npm run lint` -> record error/warning count |
| DELETE_DEAD | `npx tsc --noEmit` -> must PASS |
| EXTRACT_METHODS, SPLIT_FILE | No additional baseline needed |
| GOD_CLASS | Count public methods, list injected deps, record line count |
| SIMPLIFY | Record current complexity metrics if available |

### Backlog Check (all types)

Read `backlog.md` from project's auto memory directory. If target files have OPEN backlog items:
1. List them in the CONTRACT under `## KNOWN ISSUES IN SCOPE`
2. For items that the refactoring naturally fixes (e.g., extracting a function resolves "god class" debt) -> mark as "WILL_RESOLVE" in CONTRACT
3. For items that refactoring should address (e.g., missing tests, encoding issues) -> add as CONTRACT tasks
4. For items unrelated to this refactoring -> note as "OUT_OF_SCOPE" (do not fix)

This ensures known problems are not perpetuated through refactoring.

---

## Stage 1: Audit

### Full Audit Checklist

Read project CLAUDE.md for file/function limits. Fallback defaults in `~/.cursor/rules/file-limits.md`: 250 lines/file, 50 lines/function.

For EACH file/project, check ALL categories:

| Priority | Check | Method |
|----------|-------|--------|
| CRITICAL | God class (> file limit) | `wc -l` |
| CRITICAL | God methods (> function limit) | grep + count |
| CRITICAL | Circular dependencies | `madge --circular` (JS/TS) -- if madge fails, fallback to `eslint import/no-cycle` or manual bidirectional import grep |
| HIGH | Deprecated methods | `grep "@deprecated"` |
| HIGH | Unused code | grep + usage check |
| HIGH | Missing delegation | methods copied but not delegated |
| HIGH | Empty catch blocks | `grep "catch.*{}"` |
| MEDIUM | Large methods (near limit) | manual inspection |
| MEDIUM | Missing interfaces (DIP) | no IService pattern |
| MEDIUM | Code duplication | similar code blocks |
| LOW | TODO/FIXME comments | `grep "TODO\|FIXME"` |
| LOW | Inconsistent naming | manual inspection |

### Audit Rules

1. ALWAYS full audit -- never skip categories
2. Show ALL problems -- don't hide "minor" ones
3. Give options, don't decide for user
4. "Continue" ≠ "Skip audit" -- even on continuation, show current state

### Tech Stack Detection

```
| Category | Detected |
|----------|----------|
| Framework | [React/NestJS/etc.] |
| Language | TypeScript [strict?] |
| Testing | [Vitest/Jest] |
| State | [MST/MobX/Redux/etc.] |
```

### Existing Code Analysis (mandatory before planning)

```bash
# Find similar services
find . -name "*.service.ts" -o -name "*.util.ts" | head -20
grep -rn "[keyword]" --include="*.ts" src/ | head -15
```

Output: table of logic to extract vs existing services (MOVE to existing / CREATE new / EXTEND existing).

### Test Quality Audit (SPLIT_FILE / EXTRACT_METHODS only)

When splitting or extracting, you're rewriting tests from scratch (WRITE_NEW mode). This is the one chance to fix existing test gaps -- it costs nothing extra since tests are being rewritten anyway. **A split that only moves code without improving test quality is a wasted opportunity.**

**Step 1: Find existing tests**
```bash
# Find test files for the target source file
find . -name "*.test.ts" -o -name "*.spec.ts" | xargs grep -l "[FileName]"
```

**Step 2: Run Step 4 self-eval on EACH existing test file**

Read `~/.cursor/test-patterns.md`. For each existing test file, run the Step 4 self-eval checklist (17 binary questions). Score EACH question individually -- never group questions (e.g., "Q1-Q6: 5/6" is FORBIDDEN).

| Test File | Q1 | Q2 | Q3 | Q4 | Q5 | Q6 | Q7 | Q8 | Q9 | Q10 | Q11 | Q12 | Q13 | Q14 | Q15 | Q16 | Q17 | Total | Critical Gate | Verdict |
|-----------|----|----|----|----|----|----|----|----|----|----|-----|-----|-----|-----|-----|-----|-----|-------|--------------|---------|
| `helpers.test.ts` | 1 | 1 | 0 | 1 | 0 | 1 | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 0 | 8/17 | Q7=0 Q15=0 Q17=0 | FIX |
| `utils.test.ts` | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 15/17 | all pass | PASS |

Individual scores are required so the CONTRACT shows exactly which dimensions need fixing. Grouped scores (e.g., "Q1-Q6: 5/6") are forbidden -- they hide which specific question failed.

**Step 3: Identify specific gaps -- COUNT every instance**

For EACH question scoring 0, run a targeted grep/search to count ALL instances in the file -- not just a sample. A gap resolution that fixes 3 out of 40 instances is a cosmetic fix, not a real improvement.

| Q=0 | What to count | How |
|-----|---------------|-----|
| Q3 | Mocks missing CalledWith / not.toHaveBeenCalled | `grep -c "vi.fn\|jest.fn\|mock"` vs `grep -c "CalledWith\|not.toHaveBeenCalled"` |
| Q5 | `as any`, `: any`, untyped mocks | `grep -c "as any\|: any"` -- count EVERY occurrence |
| Q8 | Missing null/empty tests | Count functions with nullable params vs null-input tests |
| Q10 | Magic values (hardcoded numbers/strings in assertions) | `grep -cE "[0-9]{2,}\|'[a-z]{5,}'"` in test data |
| Q12 | Missing negative/symmetric tests | Count positive `it("should X when Y")` vs negative `it("should NOT X when not-Y")` |

**MANDATORY output format (in CONTRACT gap table):**

| # | Q | Gap | Instances | Fix Strategy | Scope |
|---|---|-----|-----------|-------------- |-------|
| 1 | Q5 | `as any` casts | 43 | Typed helper `callGET(url)` replacing `GET(req as any, ...)` | ALL 43 |
| 2 | Q3 | Missing negative mock assertions | 12 mocks, 0 negative | Add `not.toHaveBeenCalled` for side-effect mocks in PATCH/DELETE | 6 of 12 |
| 3 | Q10 | Magic numbers in pagination | 8 occurrences | Extract `PAGINATION_LIMIT`, `SEARCH_LIMIT` constants | ALL 8 |

**Rules:**
- **Instances column is MANDATORY** -- "some" or "a few" is FORBIDDEN
- **Fix Strategy must address ALL instances** or explicitly justify partial scope (e.g., "6 of 12 -- remaining 6 are in unmodified read-only mocks")
- If instances > 10 for a single Q: a point-fix won't work -- propose a systematic approach (helper function, factory, type wrapper)

For files scoring < 14 (FIX/BLOCK), also drill into each function being extracted. Classify code type, check against gap patterns (P-*):

| Check | Method | Score |
|-------|--------|-------|
| Coverage of branches | Count branches in source vs test cases | X/Y |
| Edge cases present? | Null, empty, boundary, special chars | YES/NO |
| Error paths tested? | try/catch, rejection, invalid input | YES/NO |
| Strong assertions? | toBe/toEqual vs toBeDefined/toBeTruthy | STRONG/WEAK |
| Assertion depth? | Verifies content/values, not just counts/shape | DEEP/SHALLOW |
| Gap patterns matched? | Which P-* patterns apply but are missing? | List |

**Step 4: Output test gap table**

| # | Function | Existing Tests | Self-eval | Gaps Found | Gap Patterns |
|---|----------|---------------|-----------|------------|--------------|
| 1 | `foo()` | 3 tests (weak) | 6/17 BLOCK | No edge cases, no error path, shallow asserts | P-3, P-18 |
| 2 | `bar()` | 0 tests | N/A | No coverage at all | -- |
| 3 | `baz()` | 5 tests | 15/17 PASS | Minor: no boundary test | P-7 |

This table goes into the CONTRACT alongside the extraction list. In ETAP-1B, new tests MUST cover both the extracted behavior AND ALL identified gaps -- regardless of the file's overall score. If gaps were identified, they MUST be fixed. A split that moves code without fixing identified gaps is a wasted opportunity -- tests are being rewritten from scratch, so fixing gaps costs zero extra effort.

---

## Stage 2: Extraction List + Test Specifications

### 2.1 Function Analysis (for each function)

For EACH function to extract, document:

- **Location:** file:start-end (N lines)
- **Target:** existing service or new file
- **Purpose, Inputs, Output, Side effects**
- **Branch count** (if/else, switch, ternary, ?., try/catch, early returns, ??)
  - +2 adjustment if touches external deps (DB, API, crypto, fs, env)
- **Complexity:** Low (<=3), Medium (4-7), High (8+)
- **Edge cases** and **Error cases** identified
- **Return type contract** -- actual return type as it exists today

### 2.2 Extraction List (CONTRACT)

| # | Function | Lines | Complexity | Target | Tests Needed | Testability |
|---|----------|-------|------------|--------|--------------|-------------|
| 1 | name() | 45-89 | Medium (5) | Service | 5-7 | YES |

**Testability:** YES = can write behavior tests with max 3 active mocks. NO = cannot test properly (+ reason). Testability = NO -> function NOT eligible for extraction.

**Line count rule (SPLIT_FILE):** For SPLIT_FILE type, the "Lines" column MUST show **counted source lines** -- not estimates. Count the actual line ranges being moved to each target file (shared setup/mocks + describe blocks + helpers). Use `wc -l` on line ranges or count describe block boundaries. "Est. ~110" is FORBIDDEN -- write "162 (lines 25-186)" instead. This prevents target files from accidentally exceeding the 250-line limit.

### 2.3 Test Specifications (NOT code)

For EACH function, write specs (not code -- code comes in ETAP-1B):

- **Happy Path** (2 required): ID, scenario, input, expected output
- **Edge Cases** (2 required): boundary values, null/empty, special chars
- **Error Cases** (1 required): invalid input, missing params
- **Format Breaker** (1 required): catches if param order/encoding/format changes
- **URL type** if applicable: [URL-DET] deterministic -> toBe, [URL-DYN] dynamic -> parse + canonical

Test quality rules:
- PREFER exact match (toBe/toEqual/==) as PRIMARY assertion
- FORBIDDEN as sole assertion: toBeDefined, toBeTruthy, toContain for URLs, toHaveBeenCalled without output check
- Mock budget: max 3 ACTIVE mocks per file (passive DI stubs unlimited)
- **LEGACY_MOCK_EXEMPTION:** When splitting legacy monolith test files and extracted functions inherit >3 mocks from the original module's DI tree, the mock budget is relaxed for that split. Use a MockFactory helper or `__test_utils__/` sidecar to centralize shared mocks. Document the exemption with `// LEGACY_MOCK_EXEMPTION: {reason}` in the test file.
- Breaker test: at least 1 per function

### 2.4 Legacy Test File Handling

If existing monolith test file covers extraction functions:
- **OPTION A (recommended):** MIGRATE -- split into per-function files in ETAP-1B
- **OPTION B (exception):** Keep monolith -- requires justification

---

## Stage 2.5: Parallelism Analysis

Analyze the extraction/task list for independent work that can be parallelized with a multi-agent team.

### Classification

For each task in the extraction list, determine:
- **Files it READS** (source analysis, context)
- **Files it WRITES** (creates or modifies)
- **Depends on** (which other tasks must complete first)

Two tasks are **independent** if their WRITE sets don't overlap (different target files).

### Dependency Graph

Build a graph and assign parallel groups:

```
| # | Task | Writes To | Depends On | Group |
|---|------|-----------|------------|-------|
| 1 | Sidebar.tsx rewrite | Sidebar.tsx | -- | A (parallel) |
| 2 | RightTabV2.tsx rewrite | RightTabV2.tsx | -- | A (parallel) |
| 3 | SaveIndicator inline | SaveIndicator.tsx | -- | A (parallel) |
| 4 | Update DesignerShell imports | DesignerShell.tsx | 1,2,3 | B (sequential) |
| 5 | Delete wrappers + verify | cleanup | 4 | C (sequential) |
```

### Mode Decision

Apply Team Mode activation/forbidden rules from `rules.md` -> Team Mode section.

Include `TEAM_MODE: true/false` and the dependency graph in the CONTRACT output.

---

## Stage 3: Refactoring Plan

### 3.1 Scope Context

```
This extraction addresses: [specific logic area]
Lines being extracted: [N] lines
Remaining file size: [M] lines (reduction: [X]%)
Phase [1] of [N] (if part of larger decomposition)
```

### 3.2 Allowed Files (Scope Fence)

| Type | File | Reason |
|------|------|--------|
| SOURCE | original.ts | File being refactored |
| SOURCE | target.service.ts | Extraction target |
| TEST | fn1.pre-extraction.spec.ts | Pre-extraction test |

**FORBIDDEN:** All other files. Touching any other file requires restarting ETAP-1A.

### 3.3 Plan Format

Per phase: Goal, Files changed, Functions moved, Tasks (numbered), Risk level.

---

## HARD STOP -- Scope Frozen

```
CONTRACT_ID: [TYPE]|[YYYY-MM-DD]|[item1]|[item2]|...

EXTRACTION LIST (FROZEN): [table]
TEST GAP TABLE (SPLIT_FILE/EXTRACT_METHODS): [table from Stage 1 Test Quality Audit]
KNOWN ISSUES IN SCOPE (from backlog): [table]
DEPENDENCY GRAPH: [table with Groups]
TEAM MODE: [true/false] -- [N parallel + M sequential tasks]
ALLOWED FILES (SCOPE FENCE): [list]
TEST SPECIFICATIONS: [total tests planned + gap fixes, mock budget, breaker count]
PLAN SUMMARY: [phases, tasks, risk]

Commands:
  "Approve"     -> Proceed to ETAP 1B
  "Modify [fn]" -> Change function in list
  "Remove [fn]" -> Remove from list
  "Add file"    -> Add to allowed list
  "Restart"     -> Start over
```

**Save CONTRACT.json NOW:** Write to `refactoring-session/contracts/CONTRACT.json` (schema at end of this file). This is required for `/refactor continue` to work. Do NOT wait until end of protocol -- save at HARD STOP so the contract persists even if the session is interrupted.

---

# ETAP 1B: TESTS

> **Role:** Senior Test Engineer writing pre-extraction behavior tests.
> **Mode:** TEST WRITING ONLY -- no production code changes
> **Input:** Approved plan from ETAP-1A (includes REFACTORING_TYPE)

---

## Mode Routing (from CONTRACT_ID)

```
Type from CONTRACT_ID -> Test Mode:

EXTRACT_METHODS, SPLIT_FILE     -> WRITE_NEW_TESTS (full test writing flow below)
GOD_CLASS                       -> WRITE_FUNCTIONAL_TESTS (read ~/.cursor/refactoring-god-class.md)
BREAK_CIRCULAR, MOVE, RENAME_MOVE,
INTRODUCE_INTERFACE, DELETE_DEAD -> VERIFY_COMPILATION (compiler is primary check)
FIX_ERROR_HANDLING              -> RUN_IF_EXISTS (tests if they exist, else lint + compile)
SIMPLIFY                        -> RUN_EXISTING + WRITE_NEW_EDGES
```

---

## VERIFY_COMPILATION Mode (MOVE, BREAK_CIRCULAR, etc.)

1. **Compilation check (REQUIRED):** `npx tsc --noEmit` / `npm run build` / `mypy`
2. **Find existing tests (optional):** search for spec files matching modified files
3. **Run existing tests (optional):** sanity check -- if PASS good, if FAIL check if preexisting
4. **Record results** -> READY FOR ETAP 2

If compilation FAILS: check if preexisting (`git stash && compile && git stash pop`).

---

## RUN_IF_EXISTS Mode (FIX_ERROR_HANDLING)

1. **Compilation check (REQUIRED)**
2. **Find existing tests** -> if found, MUST PASS
3. **Lint check (REQUIRED):** `npm run lint`
4. **Record results** -> READY FOR ETAP 2

---

## WRITE_NEW_TESTS Mode (EXTRACT_METHODS, SPLIT_FILE)

### Strict Rules

- OK: Read function code, write COMPLETE test files, run tests, ADD new edge cases
- FORBIDDEN: Production code changes, changes to extraction list, todo/skip tests, weakening specs

### Test Gap Resolution (SPLIT_FILE / EXTRACT_METHODS) -- MANDATORY

If the CONTRACT includes a TEST GAP TABLE (from Stage 1 Test Quality Audit), gaps are NOT optional suggestions -- they are CONTRACT requirements. A split that only moves tests without fixing identified gaps is a failed split.

**For each gap in the CONTRACT:**
- Cross-reference with `test-patterns.md` gap patterns (P-*) for specific test patterns to apply
- Write new tests or strengthen existing assertions to address the gap
- **Verify scope**: CONTRACT gap table includes an "Instances" count -- the resolution MUST address ALL counted instances (or justify partial scope)
- Track resolution in a gap checklist (output at end of ETAP-1B):

| # | Q | Gap | Instances | Pattern | Resolution | Fixed/Total | Status |
|---|---|-----|-----------|---------|------------|-------------|--------|
| 1 | Q5 | `as any` casts | 43 | P-4 | Created typed `callGET()`/`callPATCH()` helpers in setup | 43/43 | [x] FIXED |
| 2 | Q3 | Missing negative assertions | 12 | P-18 | Added `not.toHaveBeenCalled` for cache/DB mocks in PATCH/DELETE | 6/12 | [x] PARTIAL (6 read-only mocks excluded -- justified) |
| 3 | Q10 | Magic numbers | 8 | P-22 | Extracted `PAGINATION_LIMIT`, `SEARCH_LIMIT` constants | 8/8 | [x] FIXED |

**Scope verification rule:** If CONTRACT says "43 instances" but resolution only fixes 3, the gap is NOT resolved. The "Fixed/Total" column must show actual numbers. Partial fixes require justification and must fix at least 50% of instances.

**HARD GATE:** Every gap row must be [x] FIXED (or [x] PARTIAL with justification fixing >=50%). Unresolved gaps = ETAP-1B is INCOMPLETE -- cannot proceed to ETAP-2.

Since tests are being rewritten from scratch anyway, fixing gaps costs zero extra effort. The goal is: **after split, each new test file must score HIGHER than the original monolith's score on Step 4 self-eval.** If the original scored 14/17, split files must score >= 15/17. A split that produces the same score is a mechanical move, not an improvement.

**No "migrate as-is" exception:** If the CONTRACT identifies gaps (any Q=0), those gaps MUST be resolved -- even if the file scored >= 14. The whole point of splitting is to improve quality, not just reduce file size.

**Anti-patterns to catch during gap resolution:**
- Testing CSS classes (`toContain('bg-green-100')`) instead of behavior -- use `getByRole`, check disabled/enabled state, verify accessibility
- Shared mutable mock objects -- use `createDefaultProps()` factory pattern (G-4)
- Count-only assertions (`buttons.length === 8`) without content verification -- check actual button text/labels (Q15)
- `as any` -> `as never` rename -- both bypass type checking equally. Q5 requires REAL types (typed helper, generic wrapper, or proper interface). Replacing `any` with `never` does NOT fix Q5.
- Cosmetic-only gap resolution -- extracting constants but using them inconsistently, adding 1 assertion out of 6 identified gaps, renaming without behavioral change. If a gap fix doesn't change test BEHAVIOR or TYPE SAFETY, it's not a fix.

**Mechanical split detection (Stage 4C):**
After split, verify the split added REAL new test coverage -- not just file boundaries. Quick check: count new `it()` blocks and new assertions vs the original monolith. If the split adds < 3 new test cases addressing identified gaps, it's a mechanical move and FAILS the quality gate.

### Test Type Requirements (all three required)

| Type | % | Purpose | Minimum |
|------|---|---------|---------|
| Contract | 5% | Verify structure exists (importable, callable, signature) | 1-2 per function |
| Behavioral | 70% | Verify actual I/O with real data ← PRIMARY FOCUS | 3+ per function |
| Integration | 25% | Verify extraction didn't break call chain | 1 per function |

**Gate check:** Missing behavioral -> HARD FAIL. Missing integration -> HARD FAIL. Only contract tests -> HARD FAIL. Unaddressed test gap -> HARD FAIL.

### Behavioral Test Requirement (Golden Rule)

"If I change the function's logic, will this test fail?" If NO -> test is too weak.

Every function MUST have:
- 1+ test with VALID input -> verify OUTPUT VALUE
- 1+ test with EDGE input -> verify HANDLING
- 1+ test with INVALID input -> verify ERROR/FALLBACK
- 1+ test with NULL/UNDEFINED on required params

### Mock Call Assertions

- FORBIDDEN on business-critical arguments: `expect.anything()` / `mock.ANY`
- ALLOWED on non-critical: callback refs, timestamps, correlation IDs
- Rule: if changing the argument would change BEHAVIOR, assert it exactly

### Delegation Test Pattern

When function A delegates to function B, test BOTH:
1. Correct arguments passed to B
2. Return value from B is PASSED THROUGH (not dropped)

### Orchestration Test Pattern

When function orchestrates multiple sub-operations, verify:
1. Each sub-operation called with correct args
2. TOTAL call count matches expected number (catches silently dropped steps)

### Negative Tests (Post-Extraction)

Write these as skipped -- enable after ETAP-2:
- NEG-1: Function not duplicated (exists in helper, NOT in original)
- NEG-2: Original imports from new location
- NEG-3: Original calls the extracted function
- NEG-4: File size reduced

Use AST parsing for structure verification -- FORBIDDEN to use string matching.

### Spec Change Rules

- ALLOWED: Add new test cases, add more specific assertions, discover edge cases
- FORBIDDEN: Remove specs from 1A, weaken assertions, change expected values to match wrong behavior
- If spec ≠ reality: STOP -> report mismatch -> user decides (restart 1A / mark bug / remove function)

### Test Code Efficiency

- Module-level setup (beforeAll) for heavy operations
- Per-test reset (beforeEach) for mock clearing only
- Shared mock factories -- no inline Mock() / vi.fn() duplication
- Parameterized tests (it.each / @pytest.mark.parametrize)
- Cross-file: if 2+ spec files duplicate >3 mock configs, extract to shared test-utils

### Stack-Specific Patterns

**Read `~/.cursor/refactoring-examples/{detected_stack}.md` for:**
- Complete test template
- Test runner syntax reference
- Assertion patterns (strong/medium/weak)
- Mock patterns and factory examples
- AST helper code
- Flaky protection patterns
- Baseline management commands

### Test Writing Process (per function)

0. **Load test patterns** -- read `~/.cursor/test-patterns.md`. Classify the function's code type (Step 1), then load matching good/gap patterns from the lookup table (Step 2). Apply these patterns alongside the stack-specific template.
1. **Read function code** -- analyze branches, deps, side effects, return type
2. **Verify test specs** -- compare 1A specs with actual code, add discovered edge cases. Cross-check against loaded gap patterns (P-*) for commonly missed tests.
3. **Write complete test file** -- all 3 test types, following stack-specific template + loaded good patterns (G-*)
4. **Run tests** -- mark PASS / FAIL / NOT VERIFIED
5. **Handle failures** -- CONTRACT test failed -> STOP (1A mismatch). DISCOVERY test failed -> may adjust expectation

### Test Quality Checklist (per function)

- [ ] No todo/skip (except post-extraction)
- [ ] All 3 test types present (contract, behavioral, integration)
- [ ] Format breaker test present
- [ ] STRONG assertions as primary
- [ ] Function under test NOT mocked
- [ ] Max 3 ACTIVE mocks
- [ ] Mock factories used
- [ ] AST for structure (not string matching)
- [ ] No hardcoded baselines
- [ ] All tests PASS

### Post-Write Self-Eval (MANDATORY)

After writing/migrating ALL test files, run Step 4 self-eval on EACH new file. Score individually (Q1=1 Q2=0 ... format). This catches quality issues BEFORE ETAP-2 execution.

| New Test File | Q1-Q17 scores | Total | Critical Gate | Verdict |
|---------------|---------------|-------|--------------|---------|
| `context-button.test.tsx` | Q1=1 Q2=1 ... Q16=1 Q17=1 | 15/17 | all pass | PASS |
| `rendering-minimalistic.test.tsx` | Q1=1 Q2=1 ... Q16=1 Q17=0 | 11/17 | Q17=0 | FIX |

**HARD GATE:** Every new file must score >= 14/17 with critical gate passed (Q7, Q11, Q13, Q15, Q17). Files scoring < 14 -> fix before proceeding to ETAP-2. A split that produces 12 files all scoring 9/17 has failed -- you just moved bad tests into more files.

### Completion Output

```
ETAP 1B COMPLETE -- ALL TESTS WRITTEN

TEST FILES: [table with CT/BT/IT/FB/NEG counts and status]

GAP RESOLUTION:
  [table: # | Area | Gap | Resolution | Status]
  All gaps: X/Y resolved (must be Y/Y to proceed)

SELF-EVAL (per new file):
  [table: File | Q1-Q17 individual scores | Total | Verdict]
  All files >= 14/17: YES/NO (must be YES to proceed)

QUALITY VALIDATION:
  [OK] No todo/skip (except post-extraction)
  [OK] All functions have behavioral + integration tests
  [OK] Mock budget respected
  [OK] All tests passing
  [OK] All CONTRACT gaps resolved
  [OK] All new files score >= 14/17 on Step 4

NEXT: ETAP 2 with "Execute Phase 1"
RULES FOR ETAP 2:
  - NO modifying test assertions (import paths may change only)
  - If behavioral tests fail -> fix production code, not tests
  - Enable post-extraction tests (remove skip) after extraction
```

---

# ETAP 2: EXECUTE & VERIFY

> **Role:** Senior Software Architect executing approved refactoring plan.
> **Mode:** MECHANICAL EXECUTION of CONTRACT from ETAP-1A + 1B
> **Input:** Approved plan (1A) + Passing tests (1B) + REFACTORING_TYPE

---

## Strict Rules

**FORBIDDEN:**
- New functions outside CONTRACT
- API changes not in plan
- Scope expansion
- "While we're here" additions
- Skipping verification steps
- Modifying pre-extraction test assertions (import path updates only)
- Refactoring tests to make them pass (fix code instead)
- Deleting code without explicit CONTRACT task

**ALLOWED:**
- Execute tasks from CONTRACT
- Run tests after each change
- Fix import paths in tests (if file moved)
- Add new service to TestingModule providers in OTHER tests (cascading DI fix -- provider only, no logic/assertion changes)
- Fix issues that break CONTRACT tests
- Commit after each phase

If cascading changes exceed DI fix: STOP -> report -> user decides.

---

## Pre-Execution Checklist

- [ ] CONTRACT loaded (read `refactoring-session/contracts/CONTRACT.json`)
- [ ] Backup exists and verified
- [ ] Not on main/master branch
- [ ] Clean working directory (`git status`)
- [ ] Pre-extraction tests PASS on current code

If any missing -> STOP, fix first.

---

## Stage 4A: Verify Tests First

Run CONTRACT tests on current (unchanged) code. All must PASS before any changes.

If tests fail BEFORE changes:
- "Fix test" -> test expectation was wrong in ETAP-1A
- "Fix code" -> current code has bug (update CONTRACT)
- "Abort" -> return to ETAP-1A

---

## Stage 4B: Execute Phase

Route by TEAM_MODE from CONTRACT:

### Solo Execution (TEAM_MODE = false)

For each phase in CONTRACT:

1. **Show phase header:** goal, tasks, test files to verify
2. **Execute each task:** EXACTLY what CONTRACT specifies (from, to, action)
3. **Output format:** Small (<100 lines) -> complete. Medium (100-300) -> complete. Large (>300) -> diff + complete in chunks.

### Team Execution (TEAM_MODE = true)

#### Step 1: Create Team

```
TeamCreate("refactor-{contractId-short}")
```

#### Step 2: Create Task List from CONTRACT

For each task in the dependency graph, create a TaskCreate entry:

```
TaskCreate:
  subject: "[Task description from CONTRACT]"
  description: |
    CONTRACT: [contractId]
    Type: [REFACTORING_TYPE]

    YOUR TASK:
    [Full task description -- what to do, from where, to where]

    ALLOWED FILES (your scope):
    - [only files THIS task touches]

    CONTEXT:
    [Relevant code snippets, function signatures, test specs from ETAP-1A]

    RULES:
    1. ONLY modify files listed in YOUR allowed scope
    2. Run task-specific tests after completion: [test command]
    3. If you discover something outside CONTRACT -> message lead, don't fix
    4. If blocked or confused -> message lead, don't improvise
    5. Mark task completed ONLY when tests pass

    STACK: [detected stack] | RUNNER: [test runner]
  activeForm: "[Present continuous of task]"
```

Set up dependencies:
```
TaskUpdate(task4, addBlockedBy: [task1, task2, task3])
TaskUpdate(task5, addBlockedBy: [task4])
```

#### Step 3: Spawn Agents

Spawn up to 3 teammates (general-purpose) for Group A (parallel) tasks:

```
Task(subagent_type="general-purpose", team_name="refactor-{id}", name="worker-{n}"):
  "You are a refactoring agent on team refactor-{id}.
   Check TaskList for available tasks. Claim the lowest-ID unblocked task.
   Execute it following the task description exactly.
   After modifying any production file, run CQ1-CQ20 self-eval (read ~/.cursor/rules/code-quality.md).
   Report CQ score in your completion message. If any critical gate fails, flag it.
   When done, mark completed and check for next available task.
   If no tasks available, notify team lead and go idle."
```

Agent count = min(parallel_tasks, 3). More than 3 agents rarely helps -- coordination overhead grows.

#### Step 4: Lead Monitors

Team lead (main agent):
- Monitors progress via TaskList
- Handles sequential tasks (Group B, C) after parallel tasks complete
- Resolves blockers if agents report issues
- Does NOT duplicate work agents are doing

#### Step 5: Convergence

When all tasks complete:
1. Run full verification (Stage 4C) on combined result
2. If issues -> fix or assign back to agents
3. Dissolve team: send shutdown_request to all agents -> TeamDelete

#### Step 6: Continue to 4B.5+

Proceed with Delegation Verification, Stage 4C, 4D, 4E as normal (solo -- team is dissolved).

### Discovery During Execution (both modes)

If you find something NOT in CONTRACT: STOP, present options:
1. "Add to contract" (requires approval)
2. "Ignore" (continue without change)
3. "Abort phase" (reassess)

DO NOT make changes outside CONTRACT without approval.

---

## Stage 4B.5: Delegation Verification (EXTRACT_METHODS / SPLIT_FILE only)

After extraction, before Stage 4C -- verify delegation was applied:

**Delegation math** (evaluate in reasoning, NOT raw bash -- variables are CONTRACT values, not shell exports):
- `LINES_BEFORE` = original file line count from CONTRACT
- `LINES_AFTER` = `wc -l < [original_file]` (run this one command)
- `REDUCTION` = LINES_BEFORE - LINES_AFTER
- `EXPECTED_REDUCTION` = EXTRACTED_LINES × 0.8 (where EXTRACTED_LINES = total lines moved to new files)

| Condition | Status | Action |
|-----------|--------|--------|
| reduction >= expected | FULL DELEGATION | Proceed |
| 0 < reduction < expected * 0.5 | PARTIAL DELEGATION | List un-delegated methods |
| reduction <= 0 | NO DELEGATION | STOP -- code was copied, not delegated |

---

## Stage 4B.6: Code Quality Self-Eval (all types)

After extraction/refactoring, before Stage 4C -- run CQ1-CQ20 self-eval (from `~/.cursor/rules/code-quality.md`) on each NEW or MODIFIED production file.

- Score each CQ individually (1/0)
- Static critical gate: CQ3, CQ4, CQ5, CQ6, CQ8, CQ14 -- any = 0 -> fix before proceeding
- Conditional critical gate: CQ16 (if money code), CQ19 (if I/O boundary), CQ20 (if dual fields) -- any = 0 -> fix
- Score < 14 -> FAIL, 14-15 -> CONDITIONAL PASS (fix encouraged), >= 16 -> PASS
- Evidence required for each critical gate CQ scored as 1 (file:line or schema name)
- Check code-type patterns table for high-risk CQs specific to your code type

**Refactored code must meet CQ standards.** Extraction that preserves bad patterns is a missed opportunity.

---

## Stage 4C: Verify After Changes

### Standard Checks (all types)

| Check | Command | Required |
|-------|---------|----------|
| Tests | `npm test [spec-file]` | YES |
| TypeScript | `npx tsc --noEmit` | YES |
| Lint | `npm run lint` | YES |

### Type-Specific Verification

| Type | Additional Check |
|------|-----------------|
| BREAK_CIRCULAR | `madge --circular` -> fewer cycles than baseline. **Fallback:** if madge fails, verify with `eslint import/no-cycle` or grep that bidirectional imports between target files are removed. |
| MOVE, RENAME_MOVE | `grep old imports` -> 0 remaining |
| FIX_ERROR_HANDLING | `grep empty catches` -> 0 remaining; lint errors <= baseline |
| INTRODUCE_INTERFACE | `grep "implements I{Name}"` -> interface is used |
| DELETE_DEAD | `grep usage` -> 0 remaining references |
| EXTRACT_METHODS | Standard checks sufficient |
| SPLIT_FILE | Encoding check (see below) + shared setup dedup (see below) |
| SIMPLIFY | Complexity metrics improved |

If verification fails: CANNOT PROCEED -- must fix or rollback.

### SPLIT_FILE Additional Checks

**1. Encoding Preservation**
After splitting, verify all new files preserve the original encoding:
```bash
# Check for non-UTF-8 characters in split files
file [new_file_1] [new_file_2] ...   # all must show "UTF-8 Unicode text"
```
If source file contained non-ASCII characters (accented letters, Unicode symbols), spot-check them in the split output. String literals with special characters (e.g., Polish: ą, ę, ś, ź; German: ü, ö, ß) must survive the split unchanged. If garbled -> fix encoding before proceeding.

**2. Shared Test Setup Deduplication**
After splitting test files, check for duplicated `beforeEach` / `beforeAll` blocks:
```bash
# Count identical beforeEach blocks across split test files
grep -l "beforeEach" [test_file_1] [test_file_2] ...
```
If 2+ test files share identical or near-identical setup (>5 lines overlap):
- Extract to `__tests__/setup.ts` or `__tests__/helpers.ts`
- Import shared setup in each test file
- Each test file's `beforeEach` should only contain test-specific reset logic

**3. Backlog Resolution**
Cross-check CONTRACT's `KNOWN ISSUES IN SCOPE` (from Stage 0.5 Backlog Check):
- Items marked "WILL_RESOLVE" -> verify they are actually resolved
- Items marked as CONTRACT tasks -> verify they were completed
- If any remain unresolved -> report to user before committing

**4. Post-Split Quality Gate (test files)**
Re-run Step 4 self-eval on each NEW split test file. Compare scores with the pre-split audit from Stage 1:

| File | Pre-split score | Post-split score | Improved? |
|------|----------------|-----------------|-----------|
| `context-button.test.tsx` | 12/17 (from monolith) | 15/17 | [x] +3 |
| `rendering-minimalistic.test.tsx` | 10/17 (from monolith) | 10/17 | [ ] No improvement |

**HARD GATE:** Every split file MUST score at least `min(original_score + 1, 17)` -- i.e., improve by 1 point, capped at 17/17. Also must meet floor of 14/17. Formula: `max(min(original + 1, 17), 14)`. Examples: original 14 -> need >=15; original 12 -> need >=14 (floor); original 17 -> maintain 17. If any file scores below this -> fix gaps before committing.

### SIMPLIFY Additional Checks

**Goal:** Reduce complexity without changing behavior.

**Targets (verify ALL improved):**
- Cyclomatic complexity reduced (fewer branches/conditions)
- Max nesting <= 3 levels (extract early returns, guard clauses)
- All functions <= 50 lines (extract helpers if needed)
- No duplicated logic remaining (if simplification revealed hidden duplication)

**Techniques (in priority order):**
1. **Guard clauses** -- replace nested if/else with early returns
2. **Extract method** -- long functions -> smaller named functions
3. **Replace conditional with polymorphism** -- if type-switching detected
4. **Inline unnecessary abstractions** -- remove wrappers that add no value
5. **Simplify boolean expressions** -- `!(!a && !b)` -> `a || b`

**Post-simplification verification:**
- Run existing tests -- all must pass (no behavior change)
- File stays within 250-line limit
- Functions stay within 50-line limit
- Nesting <= 3 levels in all functions

---

## Stage 4D: Re-Audit

Quick check after each phase:

- [ ] All changed files are in CONTRACT allowlist
- [ ] No new files outside CONTRACT
- [ ] No functions added outside extraction list
- [ ] No new file > limit
- [ ] No new `any` types introduced
- [ ] All CONTRACT tests still pass
- [ ] Git diff matches expectations

---

## Stage 4E: Commit Checkpoint

```
refactor([scope]): [phase description]

- Task N.1: [description]
- Task N.2: [description]

Phase N of M. All tests passing.
CONTRACT: [reference]
```

One commit per phase. Never push mid-phases.

---

# GOD_CLASS Flow -- Lazy Loaded

> **LOAD ON DEMAND:** When detected type = GOD_CLASS, read `~/.cursor/refactoring-god-class.md` for the full iterative decomposition protocol (ETAP-1A -> 1B -> 2 -> 3).
> **Do NOT read this file for other refactoring types** -- it adds ~220 lines of context that only applies to GOD_CLASS.

---

## Final Phase: Full Test Suite

After LAST phase, before declaring complete:

Run FULL test suite (`npm test` / `npx turbo test --force`), not just extraction-related tests. Extraction may break other code that depends on extracted functions.

Required output: total suites passed, total tests passed, 0 failed. Or mark NOT VERIFIED with command to run.

---

## Final Completion Output

```
REFACTORING COMPLETE -- CONTRACT FULFILLED

SUMMARY:
| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Main file | N | M | -X% |
| Total files | 1 | 4 | +3 |
| Test coverage | 0% | 85% | +85% |

CONTRACT VERIFICATION:
  All phases executed: YES
  All tasks completed: YES
  All tests passing: YES
  No scope expansion: YES

COMMITS: N (one per phase)

Next steps:
  /review  -> Review the changes
  Push     -> git push origin [branch]
```

---

## Partial Failure Handling

If execution fails during phase N (tests fail, unexpected dependency, scope exceeded):

1. **Commit completed phases:** All phases 1..N-1 with passing tests are committed (one per phase, as normal)
2. **Revert current phase:** `git restore` files changed in the failing phase
3. **Update CONTRACT.json:** Set `status: "partial"`, mark completed phases, note the failing phase and reason
4. **Report to user:**

```
PARTIAL COMPLETION -- Phase [N] of [M] failed

COMPLETED (committed):
  Phase 1: [description] -- ✓
  Phase 2: [description] -- ✓

FAILED:
  Phase N: [description] -- [reason]

REMAINING:
  Phase N+1..M: [descriptions]

Options:
  /refactor continue -> Resume from Phase N after fixing
  git diff            -> Review completed work
  Rollback           -> git reset --hard [last-good-commit]
```

5. **DO NOT:** Auto-retry failed phases, weaken tests to pass, expand scope to work around failures

---

## Rollback Procedures

| Scope | Command |
|-------|---------|
| Current task (before commit) | `git restore [files]` |
| Current phase (after commit) | `git reset --hard HEAD~1` |
| Specific phase | `git reset --hard [commit-hash]` |
| Full rollback (to backup) | `git checkout backup/refactor-[name]-* -- [files]` |

---

## CONTRACT.json Schema

For machine-readable state tracking alongside markdown:

```json
{
  "contractId": "EXTRACT_METHODS|2026-02-13|fn1|fn2|fn3",
  "type": "EXTRACT_METHODS",
  "date": "2026-02-13",
  "status": "etap2_in_progress",  // etap1a | etap1b | etap2_in_progress | partial | completed
  "sourceFile": "src/original.service.ts",
  "linesBefore": 450,
  "phases": [
    {
      "id": 1,
      "name": "Extract URL helpers",
      "status": "completed",
      "commit": "abc123",
      "tasks": [
        { "id": "1.1", "description": "Move buildUrl()", "status": "completed" }
      ]
    }
  ],
  "teamMode": false,
  "dependencyGraph": [
    { "taskId": 1, "description": "Extract URL helpers", "writesTo": ["url-builder.service.ts"], "dependsOn": [], "group": "A" },
    { "taskId": 2, "description": "Extract auth helpers", "writesTo": ["auth-helper.service.ts"], "dependsOn": [], "group": "A" },
    { "taskId": 3, "description": "Update imports", "writesTo": ["original.service.ts"], "dependsOn": [1, 2], "group": "B" }
  ],
  "allowedFiles": ["src/original.service.ts", "src/url-builder.service.ts"],
  "testFiles": ["url-builder.pre-extraction.spec.ts"],
  "metrics": {
    "linesAfter": null,
    "testsWritten": 15,
    "testsPassing": 15,
    "agentsSpawned": 0,
    "parallelTasks": 0
  }
}
```

Save to `refactoring-session/contracts/CONTRACT.json` alongside the markdown contract.
