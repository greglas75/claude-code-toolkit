---
name: refactor
description: "Smart refactoring runner with structured workflow (ETAP-1A/1B/2). Use when refactoring code, extracting methods, splitting files, or restructuring."
user-invocable: true
---

# /refactor -- Smart Refactoring Runner (Cursor)

You are a senior software architect executing a structured refactoring workflow.

## Mandatory File Reading (NON-NEGOTIABLE)

Before starting ANY work, read ALL files below. Confirm each with check or X:

```
1. check/X  ~/.cursor/skills/refactor/rules.md      -- types, iron rules, hard gates, scope fence, sub-agents
2. check/X  ~/.cursor/refactoring-protocol.md       -- full ETAP-1A -> 1B -> 2 protocol
3. check/X  ~/.cursor/rules/code-quality.md         -- CQ1-CQ20 production code checklist
4. check/X  ~/.cursor/rules/testing.md              -- Q1-Q17 test self-eval checklist
5. check/X  ~/.cursor/test-patterns.md              -- Q1-Q17 protocol, lookup table -> routes to catalog/domain files
```

**If ANY file cannot be read, STOP. Do not proceed with a partial rule set.**

Parse $ARGUMENTS to determine mode, then follow the protocol.

## Path Resolution

Resolve paths from both possible locations -- try `~/.cursor/` first, fall back to `_agent/` in project root:
- `~/.cursor/skills/` or `_agent/skills/`
- `~/.cursor/rules/` or `_agent/rules/`
- `~/.cursor/refactoring-protocol.md` or `_agent/refactoring-protocol.md`
- `~/.cursor/refactoring-god-class.md` or `_agent/refactoring-god-class.md`
- `~/.cursor/refactoring-examples/` or `_agent/refactoring-examples/`
- `~/.cursor/test-patterns.md` or `_agent/test-patterns.md`

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

Follow `~/.cursor/rules/stack-detection.md` to detect language and test runner.

Then load the appropriate example module:

| Stack + Runner | Read |
|----------------|------|
| Python + pytest | `~/.cursor/refactoring-examples/python-pytest.md` |
| Python + unittest | `~/.cursor/refactoring-examples/python-unittest.md` |
| TypeScript + Vitest | `~/.cursor/refactoring-examples/typescript-vitest.md` |
| TypeScript + Jest | `~/.cursor/refactoring-examples/typescript-jest.md` |
| React + RTL | `~/.cursor/refactoring-examples/react-rtl.md` |
| NestJS | `~/.cursor/refactoring-examples/nestjs-testing.md` |

Output: `STACK: [language] | RUNNER: [test runner] | EXAMPLE: [loaded file]`

---

## Phase 1: Type Detection

Analyze the task description to detect refactoring type:

| Keywords | Detected Type |
|----------|--------------|
| extract, split, service, helper | EXTRACT_METHODS |
| split file, god class, god object | SPLIT_FILE |
| circular, cycle, madge | BREAK_CIRCULAR |
| move, relocate | MOVE |
| rename | RENAME_MOVE |
| interface, IService, DIP, dependency inversion | INTRODUCE_INTERFACE |
| error handling, catch block, empty catch, error | FIX_ERROR_HANDLING |
| dead code, unused, remove unused | DELETE_DEAD |
| simplify, reduce complexity | SIMPLIFY |

Default (if no match): EXTRACT_METHODS

### GOD_CLASS Auto-Escalation

**After keyword-based detection, ALWAYS check the target file for GOD_CLASS thresholds** (defined in `rules.md` -- includes stack-specific dependency counting).

If thresholds met -> **override** to `GOD_CLASS`, show detection message from `rules.md`, offer force-override (user's risk).

### Standard Type Display

For non-GOD_CLASS types, display detected type and ask the user for confirmation:

```
Detected type: [TYPE]
This means:
  - ETAP 1A: Full audit + backup + baseline
  - ETAP 1B: [WRITE_NEW / RUN_EXISTING / VERIFY_COMPILATION]
  - ETAP 2: Execute + verify ([type-specific verification])

OK? (Yes / Change to [type])
```

Wait for user confirmation (unless AUTO mode).

### Questions Gate (in ETAP-1A plan, before HARD STOP)

After completing the ETAP-1A audit and before the HARD STOP for plan approval, if there is genuine uncertainty (ambiguous scope, two valid extraction strategies, unclear business rules):

1. Add a **Questions for Author** section at the end of the plan
2. Ask the user each question -- max 4 at a time
3. Wait for answers
4. Update the CONTRACT and plan based on answers
5. Then proceed to HARD STOP for plan approval

If no uncertainty -> skip questions, go directly to HARD STOP.

---

## Phase 2: Sub-Agent Delegation (parallel)

Delegate to 2 agents for context gathering:

**Agent 1: Dependency Mapper** -- uses `~/.cursor/skills/refactor/agents/dependency-mapper.md`

Delegate to @dependency-mapper to trace blast radius:
- TARGET FILES: [list from Phase 1]
- PROJECT ROOT: [cwd]
- INSTRUCTIONS: Read `~/.cursor/skills/refactor/agents/dependency-mapper.md` for full protocol. Trace all importers/callers of each target file. Build a dependency map showing blast radius. Read project CLAUDE.md for import conventions.

**Agent 2: Existing Code Scanner** -- uses `~/.cursor/skills/refactor/agents/existing-code-scanner.md`

Delegate to @existing-code-scanner to find overlapping code:
- PLANNED EXTRACTIONS: [list of functions/methods to extract]
- PROJECT ROOT: [cwd]
- INSTRUCTIONS: Read `~/.cursor/skills/refactor/agents/existing-code-scanner.md` for full protocol. Search for existing services/helpers similar to planned extraction targets. Read project CLAUDE.md for file organization conventions.

These run while ETAP-1A proceeds. Results feed into Stage 1 (audit) and Stage 2 (extraction list).

---

## Phase 3: Execute Protocol

Read and execute the full protocol:

```
Read ~/.cursor/refactoring-protocol.md

# ONLY if detected type = GOD_CLASS:
Read ~/.cursor/refactoring-god-class.md
```

Execute in order:
1. **ETAP-1A** (Analyze & Scope Freeze)
   - Stages 0 -> 0.5 -> 1 -> 2 -> **2.5 (Parallelism Analysis)** -> 3 -> HARD STOP
   - Incorporate @dependency-mapper + @existing-code-scanner results
   - Stage 2.5 determines whether tasks can be parallelized -- included in CONTRACT
   - **Present your plan. Wait for user approval before proceeding.** (all modes)

   If PLAN mode (`plan-only`): OUTPUT plan and STOP here.

2. **ETAP-1B** (Tests)
   - Mode routing based on type
   - If WRITE_NEW with parallelizable tasks: delegate test writing to available @agents or write tests sequentially. Each agent writes tests for their assigned functions -- separate spec files, no conflicts.
   - If WRITE_NEW solo: sequential test writing flow
   - If RUN_EXISTING/VERIFY_COMPILATION: compiler + optional tests (always solo)
   - **Present test results. Wait for user approval before proceeding.** (FULL mode only; AUTO mode continues)

3. **ETAP-2** (Execute & Verify)
   - If parallelizable: delegate independent tasks to available @agents, then handle sequential tasks as dependencies resolve
   - If solo: Stage 4A -> 4B -> 4B.5 -> 4C -> 4D -> 4E (per phase)
   - Parallel delegation is dissolved before 4B.5 (verification is always solo)
   - Final: full test suite

---

## Phase 4: Post-Execution Agents

After ETAP-1B completes, delegate:

**Agent 3: Test Quality Auditor** -- uses `~/.cursor/skills/refactor/agents/test-quality-auditor.md`

Delegate to @test-quality-auditor to verify test quality:
- TEST FILES WRITTEN/MODIFIED: [list from ETAP-1B]
- REFACTORING TYPE: [type]
- COMPLEXITY: [Low/Medium/High]
- INSTRUCTIONS: Read `~/.cursor/skills/refactor/agents/test-quality-auditor.md` for full protocol. Verify all 11 hard gates and run the 17-question self-eval on each test file. Read project CLAUDE.md and `.cursor/rules/` for project-specific test conventions.

- Output: PASS / FIX / BLOCK with details
- **If BACKLOG ITEMS section present in output -> persist to backlog** (see Phase 4.5)

### Execute Verification Checklist (NON-NEGOTIABLE)

After ETAP-2 execution and before spawning post-extraction verifier, verify ALL of these. Print each with [x] or [ ]:

```
EXECUTE VERIFICATION
-------------------------------------
[x]/[ ]  CONTRACT: All changes match the CONTRACT scope (no files outside contract modified)
[x]/[ ]  SCOPE: No extra refactoring beyond what the contract specifies
[x]/[ ]  TESTS PASS: Full test suite green (before = after)
[x]/[ ]  FILE LIMITS: All modified/created files <= 250 lines (production) / <= 400 lines (test)
[x]/[ ]  CQ1-CQ20: Self-eval on each modified PRODUCTION file (scores + evidence)
[x]/[ ]  Q1-Q17: Self-eval on each modified/created TEST file (individual scores + critical gate)
[x]/[ ]  NO BEHAVIOR CHANGE: Refactoring preserved existing behavior (same inputs -> same outputs)
-------------------------------------
```

**If ANY is [ ], fix before proceeding.** Common failures:
- Contract violation: touching files not listed in CONTRACT -> revert extra changes
- Behavior change: refactoring accidentally changed logic -> fix or add tests to prove equivalence
- Q1-Q17 not run: after splitting/rewriting test files, re-eval is mandatory

After ETAP-2 phases complete, delegate:

**Agent 4: Post-Extraction Verifier** -- uses `~/.cursor/skills/refactor/agents/post-extraction-verifier.md`

Delegate to @post-extraction-verifier to verify refactoring integrity:
- CONTRACT: [contract details -- extractions, file sizes, type]
- ORIGINAL FILE: [path] (was [N] lines)
- EXTRACTED FILES: [list with paths]
- REFACTORING TYPE: [type]
- INSTRUCTIONS: Read `~/.cursor/skills/refactor/agents/post-extraction-verifier.md` for full protocol. Verify delegation applied, imports updated, file sizes reduced, no orphaned code. Read project CLAUDE.md and `.cursor/rules/` for project-specific limits.

- Output: PASS / FAIL with details
- **If BACKLOG ITEMS section present in output -> persist to backlog** (see Phase 4.5)

---

## Phase 4.5: Backlog Persistence (MANDATORY)

After each agent (@test-quality-auditor and @post-extraction-verifier) completes, check their output for a `BACKLOG ITEMS` section. If present:

1. **Read** the project's `memory/backlog.md` (from the auto memory directory shown in system prompt)
2. **If file doesn't exist**: create it with the template from `~/.cursor/skills/review/rules.md`
3. **Dedup check (MANDATORY):** Before appending, check if an OPEN item with the same fingerprint already exists. Fingerprint = `file|rule|signature` (e.g., `src/order.service.ts|CQ8|missing try-catch`). If match found -> update `occurrence` count and date instead of creating a new B-{N} ID. This prevents duplicate backlog items from repeated runs.
4. **Append** new (non-duplicate) items with:
   - Next available B-{N} ID
   - Source: `refactor/{agent-name}`
   - Status: OPEN
   - Date: today
   - Confidence: N/A (these are verified observations, not scored)
5. **Items that ARE fixed during refactoring**: mark any matching OPEN backlog items as FIXED

**THIS IS REQUIRED, NOT OPTIONAL.** Every issue found by agents that isn't fixed in this session must be persisted. Zero issues may be silently discarded.

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
  "agentDelegations": ["dependency-mapper", "existing-code-scanner", "test-quality-auditor", "post-extraction-verifier"]
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
5. Ask the user to confirm, then resume protocol from that phase
