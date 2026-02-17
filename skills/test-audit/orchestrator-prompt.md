# Test Audit Orchestrator — Multi-Agent Prompt

Use this prompt with Claude Code to audit all test files in parallel.

## Usage

```
Paste this into Claude Code or run as: /test-audit all
```

## Orchestrator Instructions

You are the orchestrator for a test quality audit. Your job:

1. **Discover** all test files in the project
2. **Pair** each with its production file
3. **Split** into batches of 8-10 files
4. **Spawn** parallel Task agents (one per batch)
5. **Aggregate** results into a tiered report
6. **Save** to `audits/test-quality-audit-[date].md`

### Step 1: Discovery

```bash
find . \( -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" -o -name "*.spec.tsx" \) \
  ! -path "*/node_modules/*" ! -path "*/.next/*" ! -path "*/e2e/*" | sort
```

Exclude E2E tests (different evaluation criteria). Count total.

### Step 2: Batch + Spawn

Split files into batches of 8-10. For each batch, spawn a Task agent:

```
Task(
  subagent_type: "general-purpose",
  model: "sonnet",  // Haiku inflates scores on Q11/Q15/AP10 — Sonnet required for reliable triage
  prompt: [AGENT PROMPT from SKILL.md with file list]
)
```

Run ALL batches in parallel (send all Task calls in one message).

### Step 3: Collect + Score

Parse each agent's output. Extract per-file:
- Score (N/15)
- Anti-pattern count
- Final score (N/15 - AP)
- Critical gate (PASS/FAIL)
- Tier (A/B/C/D)
- Top 3 gaps

### Step 4: Build Report

Sort files by score (worst first). Group by tier. Calculate:
- Total files per tier
- Most common gaps across all files
- Most common anti-patterns
- Critical gate failure rate

### Step 5: Actionable Output

The report must end with a concrete action plan:

```markdown
## Recommended Action Plan

### Immediate (Tier D — rewrite)
1. [file] — [reason] — estimated effort: [S/M/L]

### Short-term (Critical gate failures)
1. [file] — add error path test (Q7)
2. [file] — import production code (Q13)

### Medium-term (Tier C)
1. [file] — [top 3 fixes]

### Low priority (Tier B)
1. [file] — [targeted fix]
```

### Important Rules

- NEVER modify test files during audit — read only
- Each agent MUST read the production file too (for Q11, Q13, AP10 detection)
- If a test file has no identifiable production file → mark as ORPHAN
- Setup/helper files (*.setup.ts, *.fixtures.ts) are NOT test files — skip them
- Files with only `it.todo()` or `it.skip()` → auto Tier D
