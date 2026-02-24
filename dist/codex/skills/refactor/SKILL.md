---
name: refactor
description: "Smart refactoring runner with structured workflow (ETAP-1A/1B/2). Use when refactoring code, extracting methods, splitting files, or restructuring."
---

# /refactor -- Smart Refactoring Runner

You are a senior software architect executing a structured refactoring workflow.

## Mandatory File Reading (NON-NEGOTIABLE)

Before starting ANY work, read ALL files below. Confirm each with [x] or [ ]:

```
1. [x]/[ ]  ~/.codex/skills/refactor/rules.md      -- types, iron rules, hard gates, scope fence, sub-agents
2. [x]/[ ]  ~/.codex/refactoring-protocol.md       -- full ETAP-1A -> 1B -> 2 protocol
3. [x]/[ ]  ~/.codex/rules/code-quality.md         -- CQ1-CQ20 production code checklist
4. [x]/[ ]  ~/.codex/rules/testing.md              -- Q1-Q17 test self-eval checklist
5. [x]/[ ]  ~/.codex/test-patterns.md              -- Q1-Q17 protocol, lookup table -> routes to catalog/domain files
```

**If ANY file is [ ] -> STOP. Do not proceed with a partial rule set.**

Parse $ARGUMENTS to determine mode, then follow the protocol.

## Path Resolution (non-Claude-Code environments)

If running in Antigravity, Cursor, or other IDEs where `~/.codex/` is not accessible, resolve paths from `_agent/` in project root:
- `~/.codex/skills/` -> `_agent/skills/`
- `~/.codex/rules/` -> `_agent/rules/`
- `~/.codex/refactoring-protocol.md` -> `_agent/refactoring-protocol.md`
- `~/.codex/refactoring-god-class.md` -> `_agent/refactoring-god-class.md`
- `~/.codex/refactoring-examples/` -> `_agent/refactoring-examples/`
- `~/.codex/test-patterns.md` -> `_agent/test-patterns.md`

---

## Argument Parsing

```
$ARGUMENTS = empty     -> FULL mode (STOPs at plan approval + test approval)
$ARGUMENTS = "auto"    -> AUTO mode (only STOP at plan approval)
$ARGUMENTS = "plan-only" -> PLAN mode (ETAP-1A only -- analyze, no execution)
$ARGUMENTS = "continue"  -> RESUME mode (load existing CONTRACT.json)
$ARGUMENTS = other     -> treat as task description, FULL mode
```

---

## Phase 0: Stack Detection

Follow `~/.codex/rules/stack-detection.md` to detect language and test runner.

Then load the appropriate example module:

| Stack + Runner | Read |
|----------------|------|
| Python + pytest | `~/.codex/refactoring-examples/python-pytest.md` |
| Python + unittest | `~/.codex/refactoring-examples/python-unittest.md` |
| TypeScript + Vitest | `~/.codex/refactoring-examples/typescript-vitest.md` |
| TypeScript + Jest | `~/.codex/refactoring-examples/typescript-jest.md` |
| React + RTL | `~/.codex/refactoring-examples/react-rtl.md` |
| NestJS | `~/.codex/refactoring-examples/nestjs-testing.md` |

Output: `STACK: [language] | RUNNER: [test runner] | EXAMPLE: [loaded file]`

---

## Phase 1: Type Detection

### Test File Auto-Detection (before keyword matching)

If the target file is a test file (`.test.*`, `.spec.*`, `__tests__/*`):
-> Auto-set type = `IMPROVE_TESTS`
-> Skip keyword-based detection below
-> Stage 1 uses Q1-Q17 as primary audit (not production code checklist)
-> Read `~/.codex/test-patterns.md` for lookup table -> load matched patterns from catalog/domain files

Display:
```
TEST FILE DETECTED: [file] -> type = IMPROVE_TESTS
This means:
  - ETAP 1A: Q1-Q17 self-eval -> assertion gaps + structural issues
  - ETAP 1B: Structural cleanup (DRY, helpers, factories)
  - ETAP 2: Assertion strengthening (payload verification, validation, interactions)

Both phases required -- structural-only refactoring is INCOMPLETE.
OK? (Yes / Change to [type])
```

### Keyword-Based Detection (production files)

Analyze the task description to detect refactoring type:

| Keywords | Detected Type |
|----------|--------------|
| extract, split, wyciągnij, service, helper | EXTRACT_METHODS |
| split file, god class, god object, rozbij | SPLIT_FILE |
| circular, cykliczn, cycle, madge, -> | BREAK_CIRCULAR |
| move, przenieś, relocate | MOVE |
| rename, zmień nazw | RENAME_MOVE |
| interface, IService, DIP, dependency inversion | INTRODUCE_INTERFACE |
| error handling, catch block, empty catch, error | FIX_ERROR_HANDLING |
| dead code, unused, remove unused, martwy | DELETE_DEAD |
| simplify, uprość, reduce complexity | SIMPLIFY |

Default (if no match): EXTRACT_METHODS

### GOD_CLASS Auto-Escalation

**After keyword-based detection, ALWAYS check the target file for GOD_CLASS thresholds** (defined in `rules.md` -- includes stack-specific dependency counting).

If thresholds met -> **override** to `GOD_CLASS`, show detection message from `rules.md`, offer force-override (user's risk).

### Standard Type Display

For non-GOD_CLASS types, display detected type and wait for confirmation:

```
Detected type: [TYPE]
This means:
  - ETAP 1A: Full audit + backup + baseline
  - ETAP 1B: [WRITE_NEW / RUN_EXISTING / VERIFY_COMPILATION]
  - ETAP 2: Execute + verify ([type-specific verification])

OK? (Yes / Change to [type])
```

WAIT for user confirmation (unless AUTO mode).

### Questions Gate (in ETAP-1A plan, before HARD STOP)

After completing the ETAP-1A audit and before the HARD STOP for plan approval, if there is genuine uncertainty (ambiguous scope, two valid extraction strategies, unclear business rules):

1. Add a **Questions for Author** section at the end of the plan
2. Use ask the user to ask each question interactively -- max 4 at a time
3. Wait for answers
4. Update the CONTRACT and plan based on answers
5. Then proceed to HARD STOP for plan approval

If no uncertainty -> skip questions, go directly to HARD STOP.

---

---

## Phase 2: Sub-Agent Spawn (parallel, background)

**Skip this phase for IMPROVE_TESTS type** -- no production code analysis needed. Go directly to Phase 3.

Spawn two sub-agents in background using the inline analysis:

**Agent 1: Dependency Mapper** -- uses `references/dependency-mapper.md`
Read `references/dependency-mapper.md` and perform this analysis yourself.


**Agent 2: Existing Code Scanner** -- uses `references/existing-code-scanner.md`
Read `references/existing-code-scanner.md` and perform this analysis yourself.


These run in background while ETAP-1A proceeds. Results feed into Stage 1 (audit) and Stage 2 (extraction list).

---

## Phase 3: Execute Protocol

Read and execute the full protocol:

```
Read ~/.codex/refactoring-protocol.md

# ONLY if detected type = GOD_CLASS:
Read ~/.codex/refactoring-god-class.md
```

Execute in order:

**For IMPROVE_TESTS type** (test file refactoring):
1. **ETAP-1A** -- Q1-Q17 self-eval -> gap classification (STRUCTURAL vs ASSERTION) -> CONTRACT -> HARD STOP
2. **ETAP-1B** -- Structural cleanup (DRY, helpers, constants) -> commit
3. **ETAP-2** -- Assertion strengthening (payload verification, missing scenarios, interaction tests) -> re-score -> commit
4. **HARD GATE:** score must improve >= 2 points AND all ASSERTION gaps resolved

**For all other types** (production code refactoring):
1. **ETAP-1A** (Analyze & Scope Freeze)
   - Stages 0 -> 0.5 -> 1 -> 2 -> **2.5 (Parallelism Analysis)** -> 3 -> HARD STOP
   - Incorporate Dependency Mapper + Existing Code Scanner results
   - Stage 2.5 determines TEAM_MODE (true/false) -- included in CONTRACT
   - **STOP** for plan approval (all modes)

   If PLAN mode (`plan-only`): OUTPUT plan and STOP here.

2. **ETAP-1B** (Tests)
   - Mode routing based on type
   - If WRITE_NEW + TEAM_MODE: spawn team for parallel test writing (each agent writes tests for their assigned functions -- separate spec files, no conflicts)
   - If WRITE_NEW solo: sequential test writing flow
   - If RUN_EXISTING/VERIFY_COMPILATION: compiler + optional tests (always solo)
   - **STOP** for test approval (FULL mode only; AUTO mode continues)

3. **ETAP-2** (Execute & Verify)
   - If TEAM_MODE: Stage 4A -> **4B Team Execution** -> 4B.5 -> 4C -> 4D -> 4E
   - If solo: Stage 4A -> 4B -> 4B.5 -> 4C -> 4D -> 4E (per phase)
   - Team is dissolved before 4B.5 (verification is always solo)
   - Final: full test suite

---

## Phase 4: Post-Execution Sub-Agents

After ETAP-1B completes, spawn:

**Agent 3: Test Quality Auditor** -- uses `references/test-quality-auditor.md`
Read `references/test-quality-auditor.md` and perform this analysis yourself.

- Output: PASS / FIX / BLOCK with details
- **If BACKLOG ITEMS section present in output -> persist to backlog** (see Phase 4.5)

### Execute Verification Checklist (NON-NEGOTIABLE)

After ETAP-2 execution and before spawning post-extraction verifier, verify ALL of these. Print each with [x]/[ ]:

```
EXECUTE VERIFICATION
------------------------------------
[x]/[ ]  CONTRACT: All changes match the CONTRACT scope (no files outside contract modified)
[x]/[ ]  SCOPE: No extra refactoring beyond what the contract specifies
[x]/[ ]  TESTS PASS: Full test suite green (before = after)
[x]/[ ]  FILE LIMITS: All modified/created files <= 250 lines (production) / <= 400 lines (test)
[x]/[ ]  CQ1-CQ20: Self-eval on each modified PRODUCTION file (scores + evidence)
[x]/[ ]  Q1-Q17: Self-eval on each modified/created TEST file (individual scores + critical gate)
[x]/[ ]  NO BEHAVIOR CHANGE: Refactoring preserved existing behavior (same inputs -> same outputs)
------------------------------------
```

**If ANY is [ ] -> fix before proceeding.** Common failures:
- Contract violation: touching files not listed in CONTRACT -> revert extra changes
- Behavior change: refactoring accidentally changed logic -> fix or add tests to prove equivalence
- Q1-Q17 not run: after splitting/rewriting test files, re-eval is mandatory

After ETAP-2 phases complete, spawn:

**Agent 4: Post-Extraction Verifier** -- uses `references/post-extraction-verifier.md`
Read `references/post-extraction-verifier.md` and perform this analysis yourself.

- Output: PASS / FAIL with details
- **If BACKLOG ITEMS section present in output -> persist to backlog** (see Phase 4.5)

---

## Phase 4.5: Backlog Persistence (MANDATORY)

After each sub-agent (Agent 3 and Agent 4) completes, check their output for a `BACKLOG ITEMS` section. If present:

1. **Read** the project's `memory/backlog.md` (from the auto memory directory shown in system prompt)
2. **If file doesn't exist**: create it with the template from `~/.codex/skills/review/rules.md`
3. **Append** each backlog item with:
   - Next available B-{N} ID
   - Source: `refactor/{agent-name}`
   - Status: OPEN
   - Date: today
   - Confidence: N/A (these are verified observations, not scored)
4. **Items that ARE fixed during refactoring**: mark any matching OPEN backlog items as FIXED

**THIS IS REQUIRED, NOT OPTIONAL.** Every issue found by sub-agents that isn't fixed in this session must be persisted. Zero issues may be silently discarded.

After Phase 5 completion, verify: "Did I persist all backlog items from Agent 3 and Agent 4?" If not -> persist them now before showing completion output.

---

## Phase 5: Completion

### Metrics

Append to `refactoring-session/metrics.jsonl`:

```json
{
  "date": "2026-02-13T14:30:00Z",
  "contractId": "EXTRACT_METHODS|2026-02-13|fn1|fn2",
  "type": "EXTRACT_METHODS",
  "file": "src/original.service.ts",
  "linesBefore": 450,
  "linesAfter": 280,
  "reductionPercent": 38,
  "testsWritten": 15,
  "testsPassing": 15,
  "phases": 2,
  "commits": 2,
  "duration": "45min",
  "subAgents": ["dependency-mapper", "existing-code-scanner", "test-quality-auditor", "post-extraction-verifier"],
  "teamMode": false,
  "parallelTasks": 0,
  "sequentialTasks": 0,
  "agentsSpawned": 0
}
```

### Tag (commits already done per-phase in Stage 4E)

Stage 4E creates one commit per phase during ETAP-2. Phase 5 only adds a tag on the final commit:

1. `git tag refactor-[YYYY-MM-DD]-[short-slug]` (e.g., `refactor-2026-02-22-split-offer-service`)

If `refactoring-session/` files (metrics, contracts) need committing:
1. `git add refactoring-session/`
2. `git commit -m "refactor: session metadata for [contractId]"`
3. Then tag.

This creates a clean rollback point. User can `git reset --hard <tag>` if needed.

**Do NOT push.** Push is a separate user decision.

### Completion Output

```
REFACTORING COMPLETE

Type: [TYPE]
File: [path] -- [before] -> [after] lines (-[X]%)
Tests: [N] written, [N] passing
Commit: [hash] -- [message]
Tag: [tag name] (rollback: git reset --hard [tag])
Execution: [SOLO / TEAM (N agents, M parallel tasks)]

Next steps:
  /review   -> Review the refactored code
  Push      -> git push origin [branch]
  Continue  -> /refactor to start next task
```

---

## Resume Mode (`/refactor continue`)

1. Read `refactoring-session/contracts/CONTRACT.json` (fixed path per protocol schema)
   - If missing: check for `refactoring-session/contracts/*.md` as fallback
   - If both missing: STOP -- "No CONTRACT found. Run `/refactor` to start."
2. Load `contractId`, `type`, `status`, `sourceFile`, and `phases` from JSON
3. Find the first phase with `status != "completed"` -- that's where to resume
4. Display summary:
   ```
   RESUME: [contractId]
   Type: [type] | Source: [sourceFile]
   Completed: Phase 1..N-1 | Resume from: Phase N -- [name]
   ```
5. Ask user to confirm, then resume protocol from that phase
