---
name: code-audit
description: "Audit production code files against CQ1-CQ20 checklist + CAP1-CAP13 anti-patterns. Produces tiered report with scores, evidence gaps, and fix priorities. Use: /code-audit [path] or /code-audit all"
user-invocable: true
---

# /code-audit -- Production Code Quality Triage

Mass audit of production files against the CQ1-CQ20 binary checklist + CAP anti-patterns.
Produces a tiered report: which files are production-ready, which need fixes, which need rework.

## Mandatory File Reading (NON-NEGOTIABLE)

Before starting ANY work, read ALL files below. Confirm each with check or X:

```
1. [x]/[ ]  ~/.cursor/rules/code-quality.md         -- CQ1-CQ20 checklist, scoring, evidence, N/A rules, examples
2. [x]/[ ]  ~/.cursor/rules/security.md             -- SSRF, XSS, auth, path traversal patterns
3. [x]/[ ]  ~/.cursor/rules/file-limits.md          -- 250-line file limit, 50-line function limit
```

**If ANY file fails to load, STOP. Do not proceed with a partial rule set.**

## Path Resolution (non-Claude-Code environments)

If running in Antigravity, Cursor, or other IDEs where `~/.cursor/` is not accessible, resolve paths from `_agent/` in project root:
- `~/.cursor/rules/` -> `_agent/rules/`

## Step 0: Parse $ARGUMENTS

| Argument | Behavior |
|----------|----------|
| `all` | Audit ALL production files in the project |
| `[path]` | Audit production files in specific directory |
| `[file]` | Audit single file (deep mode with full evidence) |
| `--deep` | Include per-file evidence + fix recommendations (slower) |
| `--quick` | Binary checklist only, skip evidence (faster) |
| `--services` | Only audit service/business-logic files |
| `--controllers` | Only audit controller/route/handler files |

Default: `all --quick`

## Step 1: Discover Production Files

Find all production source files (exclude tests, config, generated):
```bash
find . \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" \) \
  ! -name "*.test.*" ! -name "*.spec.*" ! -name "test_*" ! -name "*_test.*" \
  ! -path "*/node_modules/*" ! -path "*/.next/*" ! -path "*/dist/*" ! -path "*/build/*" \
  ! -path "*/__pycache__/*" ! -path "*/migrations/*" ! -path "*/.claude/*" \
  ! -name "*.config.*" ! -name "*.setup.*" ! -name "*.d.ts" | sort
```

Count total. If >80 files **and no explicit `--deep` flag was provided**, switch to `--quick` mode automatically. An explicit `--deep` always takes precedence -- never auto-downgrade a user's explicit mode choice.

**Filter heuristic:** Prioritize files by risk. If >80 files, audit in this order:
1. Services / business logic (`*.service.*`, `*.repository.*`)
2. Controllers / handlers / routes (`*.controller.*`, `*.handler.*`, `route.*`)
3. Guards / middleware / auth (`*.guard.*`, `*.middleware.*`)
4. Components with logic (>100 lines `.tsx`)
5. Utilities / helpers (last -- lowest risk)

## Step 2: Classify Each File

For each file, auto-detect **code type** -- this determines which CQs are high-risk and which conditional gates activate.

| Signal | Code Type | High-Risk CQs | Conditional Gates |
|--------|-----------|---------------|-------------------|
| `*.service.*`, `*.repository.*` | SERVICE | CQ1,3,4,8,14,16,17,18,20 | CQ16 if money fields, CQ19 if API calls |
| `*.controller.*`, `*.handler.*`, `route.*` | CONTROLLER | CQ3,4,5,12,13,19 | CQ19 always (API boundary) |
| `*.guard.*`, `*.middleware.*`, auth in name | GUARD/AUTH | CQ4,5 | -- |
| `*.tsx`, `*.jsx` (>50 lines) | REACT | CQ6,10,11,13,15 | -- |
| `*.entity.*`, `*.model.*`, schema in name | ORM/DB | CQ6,7,9,10,17,20 | CQ20 if dual fields |
| orchestrat, workflow, pipeline in name | ORCHESTRATOR | CQ6,8,9,14,15,17,18 | CQ18 if multi-store |
| `*.utils.*`, `*.helpers.*`, lib/ | PURE | CQ1,2,10,12,16 | CQ16 if money functions |
| calls external API (fetch, axios, http) | API-CALL | CQ3,5,8,15,17,19 | CQ19 always |

If file matches multiple -> use the **most specific** type (SERVICE > PURE, CONTROLLER > API-CALL).

## Step 2.5: Global Infrastructure Detection

Before batch evaluation, detect project-wide error handling infrastructure. This prevents systematic overcounting of CQ8 failures in quick mode.

**Search for global error handler:**
- NestJS: `@Catch()` decorator, `AllExceptionsFilter`, `APP_FILTER` provider in `main.ts` or app module
- Express: `app.use((err, req, res, next)` error middleware
- Next.js: `error.tsx` / `global-error.tsx` boundary
- Fastify: `setErrorHandler`
- Python: `@app.exception_handler`, middleware with try/except

**If found**, note in report header:
```
Global error handler: [type] at [file:line] -- errors re-thrown from services propagate here.
CQ8 adjustment: services/controllers that let errors propagate to global handler = CQ8 PASS (unless they swallow errors internally with empty catch).
```

**Pass this context as `PROJECT_CONTEXT`** at the top of each batch evaluation.

## Step 3: Batch Evaluation

Split files into batches of 6-8. For each batch, evaluate against CQ1-CQ20 using the instructions below.

---

### EVALUATION INSTRUCTIONS (apply to each batch):

```
You are a production code quality auditor. For each file below, evaluate against the CQ1-CQ20 binary checklist.

PROJECT_CONTEXT (from Step 2.5 -- use for CQ8 evaluation):
[INSERT: global error handler info, or "No global error handler detected"]

STEP 0 -- RED FLAG PRE-SCAN (do this FIRST, before full checklist):
Scan the file for these. If any AUTO TIER-D trigger found -> use TIER-D SHORT FORMAT below and skip full CQ1-CQ20 checklist:
- Hardcoded secret (API key, password, token in source) -> AUTO TIER-D
- SQL string concatenation with user input -> AUTO TIER-D
- eval() / new Function() with non-literal input -> AUTO TIER-D
- dangerouslySetInnerHTML without DOMPurify -> AUTO TIER-D

TIER-D SHORT FORMAT (for files with red flags -- do NOT output full CQ1-CQ20):
```
### [filename]
Code type: [TYPE]
Lines: [count]
Red flags: [CAP5/CAP6/CAP7/CAP8] -> AUTO TIER-D
Details: [what was found, line number]
Tier: D
(Full CQ1-CQ20 checklist skipped -- fix red flag first, then re-audit)
```

QUICK HEURISTICS (not Tier-D triggers, but predict score):
- 5+ `as any` casts -> likely score <=10
- File > 400 lines -> likely CQ11=0
- 0 try/catch in file with DB/API calls -> likely CQ8=0
- `parseFloat` on price/cost/money field -> likely CQ16=0
- `await` inside for/forEach loop -> likely CQ17=0

CLASSIFY the file first (SERVICE / CONTROLLER / GUARD / REACT / ORM / ORCHESTRATOR / PURE / API-CALL).
This determines which conditional gates activate and which CQs are highest risk.

CHECKLIST (score 1=YES, 0=NO, N/A=not applicable with justification):
CQ1:  No string/number where union/enum/branded type appropriate?
CQ2:  All public function return types explicit? No implicit any?
CQ3:  CRITICAL -- Boundary validation complete? ALL: (a) required fields, (b) format/range/allowlist, (c) runtime schema at entry?
CQ4:  CRITICAL -- Guards reinforced by query-level filtering? Guard NOT sole defense?
CQ5:  CRITICAL -- No sensitive data in logs/errors/responses? Evidence: masking policy or proof no PII in logs.
CQ6:  CRITICAL -- No unbounded memory from external data? Pagination/streaming/batching?
CQ7:  DB queries bounded? LIMIT/cursor present? List endpoints return slim payload (select)?
CQ8:  CRITICAL -- Infra failures handled? Timeouts on outbound calls? No empty catch. Error logged with context OR propagated to global handler with correlation ID.
CQ9:  Multi-table mutations in transactions? FK order correct?
CQ10: Nullable values handled? No silent null propagation? No unsafe array[0]/.find()? No `as Type` on external data without validation?
CQ11: Functions <=50 lines? Single responsibility? No god methods?
CQ12: No magic strings/numbers? No index-based mapping (row[0])? No duplicate keys in config arrays?
CQ13: No dead code? (commented-out blocks, unreachable, unused imports)
CQ14: CRITICAL -- No duplicated logic? (>10 lines repeated). Procedure: list methods >20 lines + declarative structures -> check for repeated blocks.
CQ15: Every async awaited or fire-and-forget with .catch() + correlation ID? No dropped promises? No sleep-as-sync? NOTE: `return somePromise` inside `async function` is NOT a missing await -- async auto-flattens `Promise<Promise<T>>` -> `Promise<T>`. Only flag when promise is neither returned nor awaited (true fire-and-forget without .catch()).
CQ16: Money uses exact arithmetic (Decimal/integer-cents)? No float for money? No mixed money representations?
CQ17: No sequential await in loops where batch/parallel works? No N+1?
CQ18: Cross-system data consistency? Multi-store writes handle partial failures?
CQ19: API request AND response validated by runtime schema? No hope-based typing? CRITICAL on external boundary, optional on internal if caller validates.
CQ20: Each data point ONE canonical source? No dual fields (*_id + *_name)? Derived fields computed?

ANTI-PATTERNS (each found = noted, severity attached):
CAP1:  Empty catch block or .catch(() => null) -- HIGH
CAP2:  console.log/console.error in production (not structured logger) -- MEDIUM
CAP3:  `as any` / `as unknown as X` without validation -- MEDIUM (×5+ = HIGH)
CAP4:  @ts-ignore / @ts-expect-error without justification comment -- MEDIUM
CAP5:  Hardcoded secret (API key, password, token) -- AUTO TIER-D
CAP6:  dangerouslySetInnerHTML without DOMPurify -- AUTO TIER-D
CAP7:  eval() / new Function() with dynamic input -- AUTO TIER-D
CAP8:  SQL string concatenation/interpolation -- AUTO TIER-D
CAP9:  File > 500 lines (2× limit) -- HIGH
CAP10: Function > 100 lines (2× limit) -- HIGH
CAP11: parseFloat/Number() on money/price/cost field -- HIGH
CAP12: await inside for/for...of/while without batch alternative -- MEDIUM
CAP13: (REACT only) 5+ useState in one component, especially boolean toggles for mutually exclusive UI (dropdowns, menus) -- should be single `activePanel` union state or useReducer -- MEDIUM

N/A HANDLING: See ~/.cursor/rules/code-quality.md for strict N/A rules.
Key rule: N/A requires justification. "It's just a helper" is NOT automatic N/A for CQ19.
N/A is scored as 1 (per code-quality.md). Score is always /20. Do NOT normalize -- count N/A as 1 and score out of 20.

STATIC CRITICAL GATE: CQ3, CQ4, CQ5, CQ6, CQ8, CQ14 -- any = 0 -> capped at Tier C regardless of total.
CONDITIONAL CRITICAL GATE (per code type):
- CQ16 -> critical if file handles money (prices, costs, discounts, invoices, CPI)
- CQ19 -> critical if file is CONTROLLER or API-CALL type, or calls external API. **Thin controller exception:** if CONTROLLER only returns data constructed by typed service code (not forwarding external/unvalidated data), the conditional gate does NOT activate -- CQ19=0 counts as a normal score deduction (not a critical gate FAIL). Tier cap = B (not C).
- CQ20 -> critical if file defines entities with *_id + *_name pairs or mixed money formats

FOR EACH FILE, output this exact format:
```
### [filename]
Code type: [SERVICE/CONTROLLER/GUARD/REACT/ORM/ORCHESTRATOR/PURE/API-CALL]
Lines: [count]
Red flags: [CAP5/CAP6/CAP7/CAP8 = auto Tier-D; or "none"] -> [AUTO TIER-D or "continue"]
Score: CQ1=[0/1] CQ2=[0/1] CQ3=[0/1/N/A] CQ4=[0/1/N/A] CQ5=[0/1/N/A] CQ6=[0/1/N/A] CQ7=[0/1/N/A] CQ8=[0/1/N/A] CQ9=[0/1/N/A] CQ10=[0/1] CQ11=[0/1] CQ12=[0/1] CQ13=[0/1] CQ14=[0/1] CQ15=[0/1/N/A] CQ16=[0/1/N/A] CQ17=[0/1/N/A] CQ18=[0/1/N/A] CQ19=[0/1/N/A] CQ20=[0/1/N/A]
Anti-patterns: [CAP IDs found, or "none"]
Total: [score]/20 (N/A counted as 1, no normalization)
Static gate: CQ3=[0/1/N/A] CQ4=[0/1/N/A] CQ5=[0/1/N/A] CQ6=[0/1/N/A] CQ8=[0/1/N/A] CQ14=[0/1/N/A] -> [PASS/FAIL] (N/A gates are skipped, not converted to 1)
Conditional gate: [which activated] -> [PASS/FAIL/none]
Evidence (critical gates scored 1): [CQ=evidence pairs, file:line or schema name]
Tier: [A/B/C/D]
Top 3 issues: [brief description of worst 3 problems]
```

TIER CLASSIFICATION:
  A (>=16/20, all active gates PASS): Production-ready
  B (14-15, all active gates PASS): Conditional pass -- targeted fixes
  C (10-13, or any critical gate FAIL with score >=10): Significant rework needed
  D (<10 or AUTO TIER-D red flag): Critical -- immediate fix or rewrite

IMPORTANT:
- You MUST read the full file before scoring
- Do RED FLAG PRE-SCAN first. If any auto Tier-D trigger -> report and skip full checklist.
- For CQ3: check if there's a DTO/schema at the entry point. "Validation exists somewhere" = 0.
- For CQ4: look for ownership check followed by query WITHOUT that owner in WHERE clause. In --deep mode: for SERVICE files, ALWAYS read the associated controller to check if req.user/ownership is checked there but NOT passed to service query WHERE clause. A service with update(id)/remove(id) that doesn't filter by owner -> CQ4=0 even if controller has auth guard. N/A only for pure utilities with zero user-scoped data.
- For CQ8: check PROJECT_CONTEXT first. If project has global error handler, services/controllers that let errors propagate (no try/catch = errors bubble up) = CQ8 PASS. Only CQ8=0 when errors are SWALLOWED (empty catch, catch-and-return-null, catch-without-rethrow). No global handler = every file needs its own error handling.
- For CQ11: count lines per function. Use the project's limit from CLAUDE.md if available (default: 50).
- For CQ14: actually LIST methods >20 lines. Compare pairs for structural similarity.
- For CQ16: search for parseFloat, Number(), arithmetic operators on fields named price/cost/cpi/amount/total/discount/rate.
- For CQ17: search for `await` inside for/for...of/while/forEach. Check if batch alternative exists.
- For CQ19: CONTROLLER type = CQ19 critical unless thin controller exception applies (see conditional gate section). Check both request DTO AND response shape.
- For CQ20: search for patterns: field_id + field_name, field: number + field: "X currency_code".
- Evidence is REQUIRED for --deep mode (all CQs). For --quick mode: evidence is REQUIRED for critical gate CQs scored as 1 (per code-quality.md: "Without evidence -> score as 0"). Evidence is optional for non-critical CQs in quick mode.
- CQ15 TRAP: In async functions, `return somePromise` (without await) is NOT a bug. `async` wraps the return in Promise, and Promise<Promise<T>> auto-flattens to Promise<T>. Caller's `await` unwraps correctly. Only flag when a promise is neither returned nor awaited -- true dropped promise.
- CQ12 vs CQ20 BOUNDARY: CQ12 = representation inconsistency (same boolean as `false` literal AND `ACTION_STATUS.INACTIVE` constant). CQ20 = dual source of truth (two independent fields storing same data, e.g., `country_id` + `country_name` stored separately). If it's the same field expressed inconsistently -> CQ12. If it's two different fields duplicating the same data -> CQ20.
- GATE N/A REPORTING: When a CQ in the static/conditional gate is N/A, show it as N/A in the gate line -- do NOT convert to 1. N/A gates are skipped (not evaluated), only 0/1 gates determine PASS/FAIL. Example: `Static gate: CQ3=N/A CQ4=N/A CQ5=1 CQ6=1 CQ8=N/A CQ14=0 -> FAIL (CQ14)`.

Files to audit:
[LIST OF FILES FOR THIS BATCH]
```

---

## Step 4: Aggregate Results

Collect all batch results. Build summary table:

```markdown
# Code Quality Audit Report

Date: [date]
Project: [name]
Files audited: [N]
Mode: [quick/deep]

## Summary by Tier

| Tier | Count | % | Action |
|------|-------|---|--------|
| A (>=16) | [N] | [%] | Production-ready |
| B (14-15) | [N] | [%] | Targeted fixes before merge |
| C (10-13) | [N] | [%] | Significant rework |
| D (<10 or red flag) | [N] | [%] | Critical -- immediate fix |

## Summary by Code Type

| Type | Files | Avg Score | Worst CQ | Notes |
|------|-------|-----------|----------|-------|
| SERVICE | [N] | [avg] | [most failed CQ] | |
| CONTROLLER | [N] | [avg] | | |
| ... | | | | |

## Critical Gate Failures

Files where static critical gate FAILED (CQ3/4/5/6/8/14):

| File | Score | Failed CQs | Impact |
|------|-------|------------|--------|

## Conditional Gate Failures

Files where conditional critical gate FAILED (CQ16/19/20):

| File | Score | Failed CQs | Why Activated | Impact |
|------|-------|------------|---------------|--------|

## Red Flag Summary (Auto Tier-D)

| File | Red Flag | Details |
|------|----------|---------|

## Top Failed CQs (across all files)

| CQ | Category | Fail count | % of files | Pattern |
|----|----------|-----------|------------|---------|

## Anti-pattern Hot Spots

| Anti-pattern | Severity | Files affected | Total instances |
|-------------|----------|---------------|-----------------|

## Tier D -- Critical Fix Queue (worst first)

| File | Type | Score | Why critical |
|------|------|-------|-------------|

## Tier C -- Rework Queue

| File | Type | Score | Top 3 issues |
|------|------|-------|-------------|

## Tier B -- Targeted Fix Queue

| File | Type | Score | Gaps to fix |
|------|------|-------|-------------|

## Tier A -- Production Ready

| File | Type | Score |
|------|------|-------|
```

## Step 5: Cross-File Analysis

After per-file scoring, run cross-cutting checks:

1. **Duplication across files** -- if CQ14=0 in multiple files in same directory, check if they share duplicated logic between them (not just internal duplication)
2. **Inconsistent patterns** -- if some services use transactions (CQ9=1) and others don't for similar operations (CQ9=0), flag the inconsistency
3. **Missing validation chain** -- if controller has CQ3=1 (validates input) but its service has CQ3=N/A ("internal"), verify the service is truly never called from another entry point
4. **Money handling inconsistency** -- if some files use Decimal (CQ16=1) and others use float for same domain, flag project-wide inconsistency

Add findings to report under `## Cross-File Issues`.

## Step 6: Save Report

Save to: `audits/code-quality-audit-[date].md`

If `--deep` mode: also save per-file reports to `audits/code-audit-details/[filename].md`

## Step 7: Actionable Output

The report must end with a concrete action plan:

```markdown
## Recommended Action Plan

### Immediate (Tier D -- critical security/data issues)
1. [file] -- [CAP5: hardcoded secret at line X] -- effort: S

### High Priority (Critical gate failures)
1. [file] -- CQ8: no error handling on DB calls -- effort: M
2. [file] -- CQ3: no input validation on POST endpoint -- effort: S

### Medium Priority (Tier C -- rework)
1. [file] -- [top 3 issues] -- effort: L

### Low Priority (Tier B -- targeted fixes)
1. [file] -- [specific gap] -- effort: S

### Project-Wide Patterns
- [N] files missing input validation (CQ3) -- consider global validation pipe
- [N] files using float for money (CQ16) -- adopt Decimal.js project-wide
- [N] services with N+1 queries (CQ17) -- batch query refactoring sprint
```

## Step 7.5: Backlog Persistence (MANDATORY)

After generating the report, persist findings to `memory/backlog.md`:

1. **Read** the project's `memory/backlog.md` (from the auto memory directory shown in system prompt)
2. **If file doesn't exist**: create it with this template (or use the one in `~/.cursor/skills/review/rules.md` if available):
   ```markdown
   # Tech Debt Backlog
   | ID | Fingerprint | File | Issue | Severity | Category | Source | Seen | Dates |
   |----|-------------|------|-------|----------|----------|--------|------|-------|
   ```
3. **Which findings to persist** (tier-based -- no arbitrary score threshold):
   - **Tier D** (red flags, <10): ALL findings -- CRITICAL severity
   - **Tier C** (critical gate FAIL or 10-13): ALL critical gate failures -- HIGH severity
   - **Tier B** (14-15): only critical gate near-misses (CQ scored 1 with weak evidence) -- MEDIUM severity
   - **Tier A** (>=16): do NOT persist (production-ready)
4. For each finding to persist:
   - **Fingerprint:** `file|CQ-id|signature` (e.g., `order.service.ts|CQ8|missing-try-catch`). Search the `Fingerprint` column for an existing match.
   - **Duplicate**: increment `Seen` count, add date, keep highest severity
   - **New**: append with next `B-{N}` ID, category: Code, source: `code-audit/{date}`, date: today
5. **Tier A files**: if any OPEN backlog items exist for Tier A files, mark as FIXED

**THIS IS REQUIRED, NOT OPTIONAL.** Every finding from the audit must end up either fixed (Step 8) or in the backlog. Zero issues may be silently discarded.

## Step 8: Post-Audit Fix Workflow

After presenting the report, the user may request fixes. Follow this sequence:

1. **Fix** -- user says "napraw X" (specific CQs, specific files, or whole tier). Implement fixes using the audit report as context (lines, evidence, proposed fixes are already known -- no re-discovery needed).
2. **Test** -- run existing tests (`npx jest --no-coverage` or project test runner) to verify fixes don't break anything.
3. **Execute Verification Checklist** -- after tests pass, verify ALL of these. Print each with [x] or [ ]:

```
EXECUTE VERIFICATION
-------------------------------------
[x]/[ ]  SCOPE: Only files from the audit report modified (no "while we're here" additions)
[x]/[ ]  SCOPE: No new features/tests added beyond what the CQ fix requires
[x]/[ ]  TESTS PASS: Full test suite green (not just changed files)
[x]/[ ]  FILE LIMITS: All modified files <= 250 lines (production) / <= 400 lines (test)
[x]/[ ]  CQ1-CQ20: Re-eval on each modified PRODUCTION file (verify fixed CQs now score 1)
[x]/[ ]  Q1-Q17: Self-eval on any modified/created TEST file (individual scores + critical gate)
[x]/[ ]  NO SCOPE CREEP: Only CQ fixes from the audit applied, nothing extra
-------------------------------------
```

**If ANY is [ ], fix before committing.** Common failures:
- Scope creep: refactoring or adding features not in the audit -> revert extra changes
- CQ re-eval: after fixing CQ8, verify the fix actually scores CQ8=1 with evidence
- File limit: fix caused file to exceed 250 lines -> split

4. **Auto-Commit + Tag** -- after verification passes:
   - `git add [list of modified files -- specific names, not -A]`
   - `git commit -m "code-audit-fix: [brief description of CQs fixed]"`
   - `git tag audit-fix-[YYYY-MM-DD]-[short-slug]` (e.g., `audit-fix-2026-02-22-cq8-cq14`)
   - This creates a clean rollback point. User can `git reset --hard <tag>` if needed.
5. **Review** -- run `/review` on changed files to verify fixes are correct and didn't introduce new issues.

**User can request fixes at any granularity:**
- `"napraw wszystko z Tier D"` -- start from worst files
- `"napraw CQ8 we wszystkich plikach"` -- one issue type cross-file
- `"napraw offer.service.ts"` -- all issues in one file
- `"napraw top 3 issues"` -- by priority from action plan
