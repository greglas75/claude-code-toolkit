# Code Audit Orchestrator -- Multi-Agent Prompt

Use this prompt with Claude Code to audit all production files in parallel.

## Usage

```
Paste into Claude Code or run as: /code-audit all
```

## Orchestrator Instructions

You are the orchestrator for a production code quality audit. Your job:

1. **Read** project CLAUDE.md + `~/.codex/rules/code-quality.md` for CQ1-CQ20 checklist
2. **Discover** all production files (exclude tests, config, generated)
3. **Classify** each file by code type (SERVICE, CONTROLLER, etc.)
4. **Prioritize** by risk (services + controllers first, utilities last)
5. **Split** into batches of 6-8 files
6. **Spawn** parallel Task agents (one per batch)
7. **Aggregate** results into a tiered report
8. **Cross-file analysis** for project-wide patterns
9. **Save** to `audits/code-quality-audit-[date].md`

### Step 1: Read Project Rules

```
Read CLAUDE.md (if exists) -- look for Tech Stack, file limits, conventions
Read ~/.codex/rules/code-quality.md -- CQ1-CQ20 full checklist with evidence + N/A rules
```

### Step 2: Discovery

```bash
find . \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" \) \
  ! -name "*.test.*" ! -name "*.spec.*" ! -name "test_*" ! -name "*_test.*" \
  ! -path "*/node_modules/*" ! -path "*/.next/*" ! -path "*/dist/*" ! -path "*/build/*" \
  ! -path "*/__pycache__/*" ! -path "*/migrations/*" ! -path "*/.claude/*" \
  ! -name "*.config.*" ! -name "*.setup.*" ! -name "*.d.ts" | sort
```

Exclude: test files, generated code, config files, type declarations. Count total.

### Step 3: Classify + Prioritize

For each file, assign code type using SKILL.md Step 2 classification table.

Sort by priority:
1. **CRITICAL:** GUARD/AUTH, CONTROLLER (public attack surface)
2. **HIGH:** SERVICE, ORCHESTRATOR, API-CALL (business logic + data)
3. **MEDIUM:** ORM/DB, REACT components (data handling + UI)
4. **LOW:** PURE utilities, helpers (lowest risk)

If >80 files and `--quick` mode: audit priority 1+2 first. If time permits, continue to 3+4.

### Step 4: Batch + Spawn

Split files into batches of 6-8. Group by code type when possible (helps agent build context).

```
Task(
  model: "sonnet",  // Use "opus" for --deep mode
  prompt: [AGENT PROMPT from SKILL.md with file list + code types]
)
```

Run batches in parallel (max 6 concurrent agents). Send all Task calls in one message.

### Step 5: Collect + Score

Parse each agent's output. Extract per-file:
- Code type
- Line count
- Applicable questions (N/20)
- Raw score (yes-count / applicable)
- Normalized score (raw/applicable × 20)
- Static critical gate (PASS/FAIL)
- Conditional critical gate (which activated, PASS/FAIL)
- Evidence completeness (--deep mode)
- Anti-patterns found
- Tier (A/B/C/D)
- Top 3 issues

### Step 6: Cross-File Analysis

After per-file aggregation, check for project-wide patterns:

1. **Cross-file duplication:** Multiple Tier-C files in same directory with CQ14=0 -> likely shared duplication between files
2. **Validation chain gaps:** Controller CQ3=1 but service CQ3=N/A -> verify service isn't called from other entry points
3. **Money handling inconsistency:** Some files Decimal, others float -> project-wide CQ16 issue
4. **Error handling inconsistency:** Some services with CQ8=1, others CQ8=0 for same patterns -> project convention missing
5. **N+1 hotspots:** Multiple CQ17=0 -> candidate for batch query refactoring sprint

### Step 7: Build Report

Use the report template from SKILL.md Step 4. Sort files by score (worst first). Calculate:
- Total files per tier
- **Average score by code type** -- identifies which layer has worst quality
- **Top failed CQs** -- which CQ questions fail most often (project-wide weakness)
- **Critical gate failure rate** -- % of files failing gates
- **Conditional gate activation rate** -- how many files triggered CQ16/19/20
- Most common anti-patterns

### Step 8: Actionable Output

End with concrete action plan grouped by effort (S/M/L) and priority.

Include **project-wide recommendations** when patterns emerge:
- "15/30 services missing CQ8 -> add global exception filter + per-service infra error handling"
- "8/12 controllers missing CQ19 -> adopt response DTO pattern project-wide"
- "All money calculations use float -> adopt Decimal.js, start with [highest-risk file]"

### Important Rules

- **NEVER modify files during audit** -- read only
- Each agent MUST read the **full file** before scoring (no skimming headers)
- Files with only type declarations / interfaces -> skip (not production logic)
- Setup/bootstrap files (main.ts, app.module.ts) -> audit for CQ5 (secrets), CQ8 (startup errors) only
- **Evidence is required** for critical gate CQs in `--deep` mode
- For `--quick` mode: binary scores are sufficient, but critical gate FAILs still need a one-line explanation
- **Suite-aware:** If file A imports from file B and both are in the batch, note the dependency (helps CQ4/CQ14 analysis)
- **Respect N/A rules:** Agent must justify every N/A. "It's a helper" without checking callers = invalid N/A.
