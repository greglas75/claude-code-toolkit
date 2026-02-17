---
name: refactor
description: "Smart refactoring runner with structured workflow (ETAP-1A/1B/2). Use when refactoring code, extracting methods, splitting files, or restructuring."
disable-model-invocation: true
---

# /refactor — Smart Refactoring Runner

You are a senior software architect executing a structured refactoring workflow.

**IMPORTANT:** Before starting, read BOTH files:
```
Read ~/.claude/skills/refactor/rules.md      — types, iron rules, hard gates, scope fence, sub-agents
Read ~/.claude/refactoring-protocol.md       — full ETAP-1A → 1B → 2 protocol
```

Parse $ARGUMENTS to determine mode, then follow the protocol.

---

## Argument Parsing

```
$ARGUMENTS = empty     → FULL mode (STOPs at plan approval + test approval)
$ARGUMENTS = "auto"    → AUTO mode (only STOP at plan approval)
$ARGUMENTS = "plan-only" → PLAN mode (ETAP-1A only — analyze, no execution)
$ARGUMENTS = "continue"  → RESUME mode (load existing CONTRACT.json)
$ARGUMENTS = other     → treat as task description, FULL mode
```

---

## Phase 0: Stack Detection

Detect language and test runner from project files:

1. Check for config files:
   - `pyproject.toml` / `requirements.txt` → Python
   - `package.json` → Node/TypeScript
   - `vitest.config.*` → Vitest
   - `jest.config.*` → Jest
   - `next.config.*` → Next.js / React
   - `vite.config.*` → Vite / React

2. Check package.json dependencies:
   - `vitest` in devDeps → Vitest
   - `jest` in devDeps → Jest
   - `@testing-library/react` → React Testing Library
   - `@nestjs/core` → NestJS
   - `react` → React

3. Check existing test files for import patterns

4. Load the appropriate example module:
   - Python + pytest → Read `~/.claude/refactoring-examples/python-pytest.md`
   - Python + unittest → Read `~/.claude/refactoring-examples/python-unittest.md`
   - TypeScript + Vitest → Read `~/.claude/refactoring-examples/typescript-vitest.md`
   - TypeScript + Jest → Read `~/.claude/refactoring-examples/typescript-jest.md`
   - React + RTL → Read `~/.claude/refactoring-examples/react-rtl.md`
   - NestJS → Read `~/.claude/refactoring-examples/nestjs-testing.md`

Output: `STACK: [language] | RUNNER: [test runner] | EXAMPLE: [loaded file]`

---

## Phase 1: Type Detection

Analyze the task description to detect refactoring type:

| Keywords | Detected Type |
|----------|--------------|
| extract, split, wyciągnij, service, helper | EXTRACT_METHODS |
| split file, god class, god object, rozbij | SPLIT_FILE |
| circular, cykliczn, cycle, madge, → | BREAK_CIRCULAR |
| move, przenieś, relocate | MOVE |
| rename, zmień nazw | RENAME_MOVE |
| interface, IService, DIP, dependency inversion | INTRODUCE_INTERFACE |
| error handling, catch block, empty catch, error | FIX_ERROR_HANDLING |
| dead code, unused, remove unused, martwy | DELETE_DEAD |
| simplify, uprość, reduce complexity | SIMPLIFY |

Default (if no match): EXTRACT_METHODS

Display detected type and wait for confirmation:

```
Detected type: [TYPE]
This means:
  - ETAP 1A: Full audit + backup + baseline
  - ETAP 1B: [WRITE_NEW / RUN_EXISTING / VERIFY_COMPILATION]
  - ETAP 2: Execute + verify ([type-specific verification])

OK? (Yes / Change to [type])
```

WAIT for user confirmation (unless AUTO mode).

---

## Phase 2: Sub-Agent Spawn (parallel, background)

Spawn two Haiku sub-agents in background:

**Agent 1: Dependency Mapper**
- Trace all importers/callers of the target file(s)
- Build dependency graph (who depends on what we're changing)
- Output: list of files that may need import updates

**Agent 2: Existing Code Scanner**
- Search for existing services/helpers similar to planned extraction targets
- Check if functions already exist elsewhere (avoid duplication)
- Output: table of existing vs planned services

These run in background while ETAP-1A proceeds. Results feed into Stage 1 (audit) and Stage 2 (extraction list).

---

## Phase 3: Execute Protocol

Read and execute the full protocol:

```
Read ~/.claude/refactoring-protocol.md
```

Execute in order:
1. **ETAP-1A** (Analyze & Scope Freeze)
   - Stages 0 → 0.5 → 1 → 2 → **2.5 (Parallelism Analysis)** → 3 → HARD STOP
   - Incorporate Dependency Mapper + Existing Code Scanner results
   - Stage 2.5 determines TEAM_MODE (true/false) — included in CONTRACT
   - **STOP** for plan approval (all modes)

   If PLAN mode (`plan-only`): OUTPUT plan and STOP here.

2. **ETAP-1B** (Tests)
   - Mode routing based on type
   - If WRITE_NEW + TEAM_MODE: spawn team for parallel test writing (each agent writes tests for their assigned functions — separate spec files, no conflicts)
   - If WRITE_NEW solo: sequential test writing flow
   - If RUN_EXISTING/VERIFY_COMPILATION: compiler + optional tests (always solo)
   - **STOP** for test approval (FULL mode only; AUTO mode continues)

3. **ETAP-2** (Execute & Verify)
   - If TEAM_MODE: Stage 4A → **4B Team Execution** → 4B.5 → 4C → 4D → 4E
   - If solo: Stage 4A → 4B → 4B.5 → 4C → 4D → 4E (per phase)
   - Team is dissolved before 4B.5 (verification is always solo)
   - Final: full test suite

---

## Phase 4: Post-Execution Sub-Agents

After ETAP-1B completes, spawn:

**Agent 3: Test Quality Auditor** (Haiku)
- Verify all 11 hard gates from rules.md
- Check test type distribution (contract/behavioral/integration)
- Check mock budget compliance
- Check assertion strength
- If TEAM_MODE was used: verify no spec file conflicts across agents
- Output: PASS / FAIL with details

After ETAP-2 phases complete, spawn:

**Agent 4: Post-Extraction Verifier** (Haiku)
- Verify delegation applied (no duplicated code)
- Verify imports updated (no old paths remaining)
- Verify file size reduced as expected
- Check for orphaned exports
- If TEAM_MODE was used: verify all tasks from dependency graph are completed, no leftover tasks
- Output: PASS / FAIL with details

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

### Completion Output

```
REFACTORING COMPLETE

Type: [TYPE]
File: [path] — [before] → [after] lines (-[X]%)
Tests: [N] written, [N] passing
Commits: [N]
Execution: [SOLO / TEAM (N agents, M parallel tasks)]

Next steps:
  /review   → Review the refactored code
  Push      → git push origin [branch]
  Continue  → /refactor to start next task
```

---

## Resume Mode (`/refactor continue`)

1. Find existing CONTRACT: `find refactoring-session/contracts -name "CONTRACT.json" -o -name "*CONTRACT*.md"`
2. Load CONTRACT_ID and type from file
3. Determine current phase from status
4. Display summary and ask to continue
5. Resume protocol from last incomplete phase
