---
name: build
description: "Structured feature development with analysis sub-agents, quality gates, and backlog integration. Use for non-trivial new features (3+ files)."
user-invocable: true
---

# /build -- Structured Feature Development (Cursor)

Lightweight workflow for building new features with quality gates. Lighter than `/refactor` (no CONTRACT, no ETAP), heavier than raw coding (sub-agents, scope fence, backlog).

**When to use:** New features touching 3+ files, or any feature where blast radius matters.
**When NOT to use:** Simple fixes (<3 files), pure refactoring (`/refactor`), code review (`/review`).

### Argument Parsing

Parse $ARGUMENTS with these flags:
- `--auto` -- skip user approval at Phase 2 (plan auto-approved)
- `--auto-commit` -- commit without asking at Phase 5 (default: ask before committing)
- Everything else = the feature description

Example: `/build add offer export --auto` -> feature: "add offer export", auto-plan, ask before commit.

## Path Resolution

Resolve paths from both possible locations -- try `~/.cursor/` first, fall back to `_agent/` in project root:
- `~/.cursor/skills/` or `_agent/skills/`
- `~/.cursor/rules/` or `_agent/rules/`
- `~/.cursor/test-patterns.md` or `_agent/test-patterns.md`

---

## Mandatory File Reading (NON-NEGOTIABLE)

Before starting ANY work, read ALL files below. Confirm each with check or X:

```
1. check/X  ~/.cursor/rules/code-quality.md         -- CQ1-CQ20 production code checklist
2. check/X  ~/.cursor/rules/testing.md              -- Q1-Q17 test self-eval checklist
3. check/X  ~/.cursor/test-patterns.md              -- Q1-Q17 protocol, lookup table -> routes to catalog/domain files
4. check/X  ~/.cursor/rules/file-limits.md          -- 250-line file limit, 50-line function limit
```

### Degraded Mode (if mandatory files missing)

If ANY file cannot be read:
1. Log which file(s) are missing and why
2. **If 1-2 files missing:** proceed in DEGRADED MODE -- skip the rules from missing files, note "DEGRADED: [file] unavailable" in Phase 5 output. Apply remaining rules normally.
3. **If 3+ files missing:** STOP. Environment is misconfigured -- ask user to verify installation.

---

## Phase 0: Context

1. Read project `CLAUDE.md` and `.cursor/rules/` (or `_agent/rules/`) for conventions
2. Detect stack (check `package.json`, `tsconfig.json`, `pyproject.toml`, etc.)
3. Read `memory/backlog.md` if it exists -- check for related OPEN items

Output:
```
STACK: [language] | RUNNER: [test runner]
BACKLOG: [N open items in related files, or "none"]
```

---

## Phase 1: Analysis (parallel delegation)

Before planning, delegate to 2 agents for context gathering:

**Agent 1: Blast Radius Mapper** -- uses `~/.cursor/skills/build/agents/dependency-mapper.md`

Delegate to @dependency-mapper to trace blast radius:
- FEATURE: [description]
- TARGET FILES: [files the feature will likely touch]
- PROJECT ROOT: [cwd]
- INSTRUCTIONS: Read `~/.cursor/skills/build/agents/dependency-mapper.md` for full protocol. Trace all importers/callers of the target files. Identify what might break or need updates. Read project CLAUDE.md for import conventions.

**Agent 2: Existing Code Scanner** -- uses `~/.cursor/skills/build/agents/existing-code-scanner.md`

Delegate to @existing-code-scanner to find overlapping code:
- FEATURE: [description]
- PLANNED NEW CODE: [functions/components/services to create]
- PROJECT ROOT: [cwd]
- INSTRUCTIONS: Read `~/.cursor/skills/build/agents/existing-code-scanner.md` for full protocol. Search for existing services/helpers/components similar to what's planned. Prevent duplication. Read project CLAUDE.md for file organization conventions.

Don't wait for results -- start Phase 2 immediately. Incorporate results when ready.

---

## Phase 2: Plan

Present your plan to the user and wait for approval. If `--auto` flag is set, skip the approval wait.

Create a plan with ALL of these sections:

### Required Plan Sections

```
## 1. Feature Summary
[1-2 sentences: what and why]

## 2. Scope Fence
ALLOWED: [files to create/modify]
FORBIDDEN: files outside scope, unrelated improvements

## 3. Blast Radius
[From @dependency-mapper results -- who depends on files we're changing]
[If results not ready yet: list known dependents manually]

## 4. Duplication Check
[From @existing-code-scanner results -- existing code that overlaps]
[If results not ready yet: note "pending scan"]

## 5. Implementation Plan
[Ordered list of changes with file paths]

## 6. Test Strategy (MANDATORY)
- Code types being added (function/component/endpoint/hook)
- Test files to create/modify
- Critical scenarios (error paths, edge cases)
- Self-eval targets: CQ PASS (>=16 + critical gate) + Q >= 14/17 (tests)

## 7. File Size Check
[For each file to modify: current LOC + estimated after change]
[Read limits from ~/.cursor/rules/file-limits.md or project CLAUDE.md override]
[Flag any file that will exceed the production file limit -> plan split]

## 8. Questions for Author
[Only if genuine uncertainty about requirements or approach -- e.g. two valid architectures,
ambiguous business rules, conflicting patterns found in codebase. Leave empty if clear.]
```

**A plan missing any section is INCOMPLETE -- do not proceed.**

### Questions Gate (before proceeding)

If section 8 is non-empty:
1. Ask the user each question -- max 4 at a time
2. Wait for answers
3. Update the plan based on answers (revise approach, scope, implementation strategy)
4. Then proceed

If section 8 is empty, proceed directly.

**Wait for user approval before proceeding to Phase 3.**

---

## Phase 3: Implement

### 3.1: Pre-flight

Before coding, verify:
- [ ] @dependency-mapper + @existing-code-scanner results incorporated (if not in plan, add now)
- [ ] Scope fence defined
- [ ] No file will exceed production file limit from `file-limits.md` (plan splits if needed)

### 3.2: Code

Implement the feature following the plan. Rules:
- **Stay in scope** -- only touch ALLOWED files
- **Business logic in services** -- not in components or API routes
- **Follow project conventions** -- from CLAUDE.md and `.cursor/rules/`
- **Check file size after each file** -- if approaching the production file limit (from `file-limits.md`), split NOW
- **Scope Fence expansion** -- if a split or dependency requires touching a file outside the ALLOWED list:
  1. Log the expansion: `SCOPE EXPANDED: [file] -- reason: [justification]`
  2. Only structural splits (extracting helpers/sub-components to respect file limits) auto-expand
  3. Any other scope change -> ask user for approval before proceeding

### 3.3: Code Quality Self-Eval

Run CQ1-CQ20 self-eval (from `~/.cursor/rules/code-quality.md`) on each production file you wrote/modified.

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
- Follow patterns from `~/.cursor/test-patterns.md`
- Run tests: verify GREEN

### 3.5: Test Self-Eval (before Phase 4)

Run Q1-Q17 self-eval (from `~/.cursor/rules/testing.md`) on each test file you wrote.

- Score each Q individually (1/0)
- Critical gate: Q7, Q11, Q13, Q15, Q17 -- any = 0 -> fix before proceeding
- Score < 14 -> fix worst gaps, re-score
- **Q12 procedure:** list ALL public methods/endpoints under test -> for each repeated test pattern (auth guard, validation, error path), verify ALL methods have it. Missing = 0.

Only proceed to Phase 4 when both self-evals pass (CQ PASS or CONDITIONAL PASS with evidence + Q >= 14).

---

## Phase 4: Verify

### 4.1: Test Quality Auditor

Delegate to @test-quality-auditor to verify test quality:
- TEST FILES: [list of test files written/modified]
- CODE TYPE: [function/component/endpoint/hook]
- COMPLEXITY: [Low/Medium/High]
- INSTRUCTIONS: Read `~/.cursor/skills/build/agents/test-quality-auditor.md` for full protocol. Verify 11 hard gates and run 17-question self-eval (Q1-Q17) on each test file. Read project CLAUDE.md and `.cursor/rules/` for project-specific test conventions.

**If FAIL/BLOCK:** fix issues, re-run auditor. Do not proceed until PASS or FIX (with fixes applied).

### 4.2: Verification Commands

Run in parallel:
- Tests: project test command (`npm run test:run`, `pytest`, etc.)
- Types: `npx tsc --noEmit` or equivalent
- Lint: `npm run lint` or equivalent

**All must pass.** If any fails -> fix -> re-run.

### 4.3: Execute Verification Checklist (NON-NEGOTIABLE)

After all code is written and before committing, verify ALL of these. Print each with [x] or [ ]:

```
EXECUTE VERIFICATION
-------------------------------------
[x]/[ ]  SCOPE: All files match the approved plan (no unplanned files added)
[x]/[ ]  SCOPE: No extra features/refactoring beyond what the plan specifies
[x]/[ ]  TESTS PASS: Full test suite green (not just new files)
[x]/[ ]  TYPES: tsc --noEmit passes (no type errors)
[x]/[ ]  FILE LIMITS: All created/modified files within limits from file-limits.md (production + test)
[x]/[ ]  CQ1-CQ20: Self-eval on each new/modified PRODUCTION file (scores + evidence)
[x]/[ ]  Q1-Q17: Self-eval on each new/modified TEST file (individual scores + critical gate)
-------------------------------------
```

**If ANY is [ ], fix before committing.** Common failures:
- Scope creep: adding helpers or refactoring existing code not in the plan -> revert
- File limit: new files exceed production limit -> split into modules
- CQ/Q not run: every production file needs CQ1-CQ20, every test file needs Q1-Q17

---

## Phase 5: Completion

### 5.1: Backlog Persistence (MANDATORY)

Collect items from ALL sources:
1. **Test Quality Auditor** -- `BACKLOG ITEMS` section from Phase 4.1
2. **CQ Self-Eval** -- any CQ scored 0 that was not fixed (CONDITIONAL PASS items)
3. **Review warnings** -- warnings from `/review` (if run)

For each item -> persist to `memory/backlog.md`:
- Next available B-{N} ID
- Source: `build/{source}` (e.g., `build/test-quality-auditor`, `build/cq-self-eval`, `build/review`)
- Status: OPEN
- Date: today
- **Dedup:** before adding, check if `memory/backlog.md` already has an item with same file + same issue description. If found -> skip (do not create duplicate).

If any OPEN backlog items in related files were resolved -> mark FIXED.

**THIS IS REQUIRED.** Zero issues may be silently discarded.

### 5.2: Commit + Tag

**Commit policy:**
- **Default (no flag):** show staged file list + proposed commit message, ask user: _"Commit these changes? (y/n)"_. Wait for confirmation.
- **`--auto-commit` flag:** commit without asking -- the user pre-approved by passing the flag.

After approval (or with `--auto-commit`):

1. `git add [list of created/modified files -- specific names, not -A]`
2. `git commit -m "build: [feature description]"`
3. `git tag build-[YYYY-MM-DD]-[short-slug]` (e.g., `build-2026-02-22-offer-export`)

This creates a clean rollback point. User can `git reset --hard <tag>` if needed.

**Do NOT push.** Push is a separate user decision.

### 5.3: Output

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
  /review  -> Review the new code
  Push     -> git push origin [branch]
------------------------------------
```

---

## Flags Reference

| Flag | Effect |
|------|--------|
| `--auto` | Skip user approval at Phase 2 (plan auto-approved) |
| `--auto-commit` | Skip commit confirmation at Phase 5.2 |

Both flags can be combined: `/build add export --auto --auto-commit`

All agents and quality gates still run regardless of flags. Tests must still pass.
