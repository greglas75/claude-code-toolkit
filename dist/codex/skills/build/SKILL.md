---
name: build
description: "Structured feature development with analysis sub-agents, quality gates, and backlog integration. Use for non-trivial new features (3+ files). NOT for bug fixes (use /debug) or pure refactoring (use /refactor)."
---

# /build -- Structured Feature Development

Lightweight workflow for building new features with quality gates. Lighter than `/refactor` (no CONTRACT, no ETAP), heavier than raw coding (sub-agents, scope fence, backlog).

**When to use:** New features touching 3+ files, or any feature where blast radius matters.
**When NOT to use:** Simple fixes (<3 files), pure refactoring (`/refactor`), code review (`/review`).

### Argument Parsing

Parse $ARGUMENTS with these flags:
- `--auto` -- skip user approval at Phase 2 (plan auto-approved)
- `--auto-commit` -- commit without asking at Phase 5 (default: ask before committing)
- Everything else = the feature description

Example: `/build add offer export --auto` -> feature: "add offer export", auto-plan, ask before commit.

---

---

## Mandatory File Reading (required; degraded mode if missing)

Before starting ANY work, read ALL files below. Confirm each with [x] or [ ]:

```
1. [x]/[ ]  ~/.codex/rules/code-quality.md         -- CQ1-CQ20 production code checklist
2. [x]/[ ]  ~/.codex/rules/testing.md              -- Q1-Q17 test self-eval checklist
3. [x]/[ ]  ~/.codex/test-patterns.md              -- Q1-Q17 protocol, lookup table -> routes to catalog/domain files
4. [x]/[ ]  ~/.codex/rules/file-limits.md          -- file/function line limits
```

### Degraded Mode (if mandatory files missing)

If ANY file is [ ]:
1. Log which file(s) are missing and why
2. **If 1-2 files missing:** proceed in DEGRADED MODE -- skip the rules from missing files, note "DEGRADED: [file] unavailable" in Phase 5 output. Apply remaining rules normally.
3. **If 3+ files missing:** STOP. Environment is misconfigured -- ask user to verify installation.

---

## Phase 0: Context

1. Read project `CLAUDE.md` and `.claude/rules/` (or `_agent/rules/`) for conventions
2. Detect stack (check `package.json`, `tsconfig.json`, `pyproject.toml`, etc.)
3. Read `memory/backlog.md` if it exists -- check for related OPEN items

Output:
```
STACK: [language] | RUNNER: [test runner]
BACKLOG: [N open items in related files, or "none"]
```

---

## Phase 1: Analysis (background -- runs during Phase 2)

Spawn 2 sub-agents to gather context. Both run in background while you proceed to Phase 2 planning. Incorporate their results into the plan when they complete -- do not block on them.

**Agent 1: Blast Radius Mapper** -- uses `references/dependency-mapper.md`
Read `references/dependency-mapper.md` and perform this analysis yourself.


**Agent 2: Existing Code Scanner** -- uses `references/existing-code-scanner.md`
Read `references/existing-code-scanner.md` and perform this analysis yourself.


Both agents run in background (``). Proceed to Phase 2 immediately.

---

## Phase 2: Plan

### Plan Mode Fallback

If plan mode is available -> use it.
If NOT available (no plan mode in this environment):
1. Present the plan as a markdown block in your response
2. End with: **"Approve this plan to proceed, or request changes."**
3. Wait for explicit user approval before Phase 3
4. `--auto` flag skips this wait (same as with enter plan mode)

Create a plan with ALL of these sections:

### Required Plan Sections

```
## 1. Feature Summary
[1-2 sentences: what and why]

## 2. Scope Fence
ALLOWED: [files to create/modify]
FORBIDDEN: files outside scope, unrelated improvements

## 3. Blast Radius
[From Agent 1 results -- who depends on files we're changing]
[If Agent 1 not ready yet: list known dependents manually]

## 4. Duplication Check
[From Agent 2 results -- existing code that overlaps]
[If Agent 2 not ready yet: note "pending scan"]

## 5. Implementation Plan
[Ordered list of changes with file paths]

## 6. Test Strategy (MANDATORY)
- Code types being added (function/component/endpoint/hook)
- Test files to create/modify
- Critical scenarios (error paths, edge cases)
- Self-eval targets: CQ PASS (>=16 + critical gate) + Q >= 14/17 (tests)

## 7. File Size Check
[For each file to modify: current LOC + estimated after change]
[Read limits from ~/.codex/rules/file-limits.md or project CLAUDE.md override]
[Flag any file that will exceed the production file limit -> plan split]

## 8. Questions for Author
[Only if genuine uncertainty about requirements or approach -- e.g. two valid architectures,
ambiguous business rules, conflicting patterns found in codebase. Leave empty if clear.]
```

**A plan missing any section is INCOMPLETE -- do not finalize the plan.**

### Questions Gate (before finalize the plan)

If section 8 is non-empty:
1. Use ask the user (if available) or ask inline to get answers -- max 4 at a time
2. Wait for answers
3. Update the plan based on answers (revise approach, scope, implementation strategy)
4. Then exit plan mode / proceed

If section 8 is empty -> exit plan mode / proceed directly.

Wait for user approval (via exit plan mode or inline confirmation).

---

## Phase 3: Implement

### 3.1: Pre-flight

Before coding, verify:
- [ ] Agent 1 + Agent 2 results incorporated (if not in plan, add now)
- [ ] Scope fence defined
- [ ] No file will exceed production file limit from `file-limits.md` (plan splits if needed)

### 3.2: Code

Implement the feature following the plan. Rules:
- **Stay in scope** -- only touch ALLOWED files
- **Business logic in services** -- not in components or API routes
- **Follow project conventions** -- from CLAUDE.md and `.claude/rules/`
- **Check file size after each file** -- if approaching the production file limit (from `file-limits.md`), split NOW
- **Scope Fence expansion** -- if a split or dependency requires touching a file outside the ALLOWED list:
  1. Log the expansion: `SCOPE EXPANDED: [file] -- reason: [justification]`
  2. Only structural splits (extracting helpers/sub-components to respect file limits) auto-expand
  3. Any other scope change -> ask user for approval before proceeding

### 3.3: Code Quality Self-Eval

Run CQ1-CQ20 self-eval (from `~/.codex/rules/code-quality.md`) on each production file you wrote/modified.

- Score each CQ individually (1/0)
- Static critical gate: CQ3, CQ4, CQ5, CQ6, CQ8, CQ14 -- any = 0 -> fix before writing tests
- Conditional critical gate: CQ16 (if money code), CQ19 (if I/O boundary), CQ20 (if dual fields) -- any = 0 -> fix
- Score < 14 -> FAIL, 14-15 -> CONDITIONAL PASS, >= 16 -> PASS
- Evidence required for each critical gate CQ scored as 1
- Check code-type patterns table for high-risk CQs specific to your code type

**Fix code quality issues BEFORE writing tests.** Tests should cover correct patterns, not broken ones.

### 3.4: Tests

Write tests per the Test Strategy from Phase 2. Requirements:
- Every new function/component/endpoint/hook must have tests
- Follow patterns from `~/.codex/test-patterns.md`
- Run tests: verify GREEN

### 3.5: Test Self-Eval (before Phase 4)

Run Q1-Q17 self-eval (from `~/.codex/rules/testing.md`) on each test file you wrote or modified.

- Score each Q individually (1/0)
- Critical gate: Q7, Q11, Q13, Q15, Q17 -- any = 0 -> fix before proceeding
- Score < 14 -> fix worst gaps, re-score
- **Q12 procedure:** list ALL public methods/endpoints under test -> for each repeated test pattern (auth guard, validation, error path), verify ALL methods have it. Missing = 0.

Only proceed to Phase 4 when both self-evals pass (CQ PASS or CONDITIONAL PASS with evidence + Q >= 14).

---

## Phase 4: Verify

### 4.1: Test Quality Auditor

Spawn the auditor:

Read `references/test-quality-auditor.md` and perform this analysis yourself.


**If FAIL/BLOCK:** fix issues, re-run auditor. Do not proceed until PASS or FIX (with fixes applied).

### 4.2: Verification Commands

Run in parallel (use stack-appropriate commands from Phase 0):
- Tests: project test command (`npm run test:run`, `pytest`, `go test ./...`, etc.)
- Types: stack-dependent type checker:
  - TypeScript: `npx tsc --noEmit`
  - Python (mypy): `mypy [changed-files]`
  - Python (pyright): `pyright [changed-files]`
  - Go: `go vet ./...`
  - PHP (phpstan): `vendor/bin/phpstan analyse [changed-files]`
  - No type checker configured -> skip with note "TYPES: skipped (no type checker detected)"
- Lint: `npm run lint`, `ruff check`, `golangci-lint run`, or project equivalent

**All must pass.** If any fails -> fix -> re-run.

### 4.3: Execute Verification Checklist (NON-NEGOTIABLE)

After all code is written and before committing, verify ALL of these. Print each with [x]/[ ]:

```
EXECUTE VERIFICATION
------------------------------------
[x]/[ ]  SCOPE: All files match the approved plan (no unplanned files added)
[x]/[ ]  SCOPE: No extra features/refactoring beyond what the plan specifies
[x]/[ ]  TESTS PASS: Full test suite green (not just new files)
[x]/[ ]  TYPES: type checker passes -- `tsc --noEmit` (TS), `mypy`/`pyright` (Python), `go vet` (Go), or skipped if none configured
[x]/[ ]  FILE LIMITS: All created/modified files within limits from file-limits.md (production + test)
[x]/[ ]  CQ1-CQ20: Self-eval on each new/modified PRODUCTION file (scores + evidence)
[x]/[ ]  Q1-Q17: Self-eval on each new/modified TEST file (individual scores + critical gate)
------------------------------------
```

**If ANY is [ ] -> fix before committing.** Common failures:
- Scope creep: adding helpers or refactoring existing code not in the plan -> revert
- File limit: new files exceed production limit -> split into modules
- CQ/Q not run: every production file needs CQ1-CQ20, every test file needs Q1-Q17

---

## Phase 5: Completion

### 5.1: Backlog Persistence (MANDATORY)

Collect items from ALL sources:
1. **Test Quality Auditor** -- `BACKLOG ITEMS` section from Phase 4.1
2. **CQ Self-Eval** -- any CQ scored 0 that was not fixed (CONDITIONAL PASS items)
3. **Review warnings** -- warnings from Phase 5.2 `/review` (if run)

For each item -> persist to `memory/backlog.md`:

1. **Read** the project's `memory/backlog.md` (from the auto memory directory shown in system prompt)
2. **If file doesn't exist**: create it with this template:
   ```markdown
   # Tech Debt Backlog
   | ID | Fingerprint | File | Issue | Severity | Category | Source | Seen | Dates |
   |----|-------------|------|-------|----------|----------|--------|------|-------|
   ```
3. For each finding:
   - **Fingerprint:** `file|rule-id|signature` (e.g., `order.service.ts|CQ8|missing-try-catch`). Search the `Fingerprint` column for an existing match. If found -> increment `Seen`, update date, keep highest severity
   - **New:** append with next `B-{N}` ID, category: Code/Test (infer from source), source: `build/{source}` (e.g., `build/test-quality-auditor`, `build/cq-self-eval`, `build/review`), date: today

If any OPEN backlog items in related files were resolved -> delete them (fixed = deleted; git has history).

**THIS IS REQUIRED.** Zero issues may be silently discarded.

### 5.2: Stage + Pre-Commit Review

Stage exactly the files created/modified in this build (no more, no less):

```
git add [explicit list of created/modified files -- never -A or .]
```

Then run `/review` scoped to staged changes only:

```
/review staged
```

This reviews ONLY the staged files -- not the whole codebase.

**If review finds BLOCKING issues:** unstage (`git reset HEAD [file]`), fix, re-stage, re-run review.
**If review finds warnings only:** proceed to commit. Add warnings to backlog.

### 5.3: Commit + Tag

**Commit policy:**
- **Default (no flag):** show staged file list + proposed commit message, ask user: _"Commit these changes? (y/n)"_. Wait for confirmation.
- **`--auto-commit` flag:** commit without asking -- the user pre-approved by passing the flag.

After approval (or with `--auto-commit`):

```
git commit -m "build: [feature description]"
git tag build-[YYYY-MM-DD]-[short-slug]
```

(e.g. tag: `build-2026-02-22-offer-export`)

This creates a clean rollback point. User can `git reset --hard <tag>` if needed.

**Do NOT push.** Push is a separate user decision.

### 5.4: Output

```
BUILD COMPLETE
------------------------------------
Feature: [description]
Files created: [N]
Files modified: [N]
Tests written: [N], all passing
Verification: tests PASS | types PASS | lint PASS
Review: PASS | [N warnings -> added to backlog]
Backlog: [N items persisted | "none"]
Commit: [hash] -- [message]
Tag: [tag name] (rollback: git reset --hard [tag])

Next steps:
  /docs readme [path] -> Write README for the new module (if new service/module created)
  /docs api [path]    -> Document the new endpoints (if new endpoints added)
  Push                -> git push origin [branch]
------------------------------------
```

---

## Flags Reference

| Flag | Effect |
|------|--------|
| `--auto` | Skip user approval at Phase 2 (plan auto-approved) |
| `--auto-commit` | Skip commit confirmation at Phase 5.3 |

Both flags can be combined: `/build add export --auto --auto-commit`

All agents and quality gates still run regardless of flags. Tests must still pass.
