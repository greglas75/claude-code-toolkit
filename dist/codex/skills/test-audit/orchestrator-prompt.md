# Test Audit Orchestrator -- Multi-Agent Prompt

Use this prompt with Claude Code to audit all test files in parallel.

## Usage

```
Paste this into Claude Code or run as: /test-audit all
```

## Orchestrator Instructions

You are the orchestrator for a test quality audit. Your job:

1. **Discover** all test files in the project
2. **Pair** each with its production file
3. **Calibrate** (first audit only) -- run 2-3 golden files to verify agent scoring consistency
4. **Split** into batches of 8-10 files
5. **Spawn** parallel Task agents (one per batch)
6. **Aggregate** results into a tiered report
7. **Save** to `audits/test-quality-audit-[date].md`

### Step 1: Discovery

```bash
find . \( -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" -o -name "*.spec.tsx" -o -name "test_*.py" -o -name "*_test.py" \) \
  ! -path "*/node_modules/*" ! -path "*/.next/*" ! -path "*/__pycache__/*" ! -path "*/e2e/*" | sort
```

Exclude E2E tests (different evaluation criteria). Count total.

### Step 2: Pair with Production Files

For each test file, identify the production file. If not found -> flag as ORPHAN.

### Step 3: Calibrate (first audit only)

See SKILL.md Step 2.5 -- run 2-3 golden files to verify agent scoring consistency before full batch.

### Step 4: Batch + Spawn

**Pre-batch grouping:** Group test files by production file first. If multiple test files target the same production file (e.g., `foo.test.ts` + `foo.errors.test.ts`), they MUST go into the same batch so suite-aware Q7/Q11 evaluation works correctly.

After grouping, split into batches of 8-10 files. For each batch, spawn a Task agent:

```
Task(
  model: "sonnet",  // Haiku inflates scores on Q11/Q15/Q17/AP10 -- Sonnet required for reliable triage
  prompt: [AGENT PROMPT from SKILL.md with file list]
)
```

Run batches in parallel (max 6 concurrent agents). Send all Task calls in one message.

### Step 5: Collect + Score

Parse each agent's output. Extract per-file:
- Score: yes-count + N/A-count (out of 17)
- Anti-pattern count
- Final score: (yes + N/A) - AP deductions
- Critical gate (PASS/FAIL)
- Tier (A/B/C/D)
- Top 3 gaps

### Step 6: Build Report

Sort files by score (worst first). Group by tier. Calculate:
- Total files per tier
- **Top failed Qs** -- which Q questions fail most often across all files
- **Top critical gate failures** -- Q7/Q11/Q13/Q15/Q17 failure counts with file lists
- Most common anti-patterns
- Critical gate failure rate

### Step 7: Actionable Output

The report must end with a concrete action plan:

```markdown
## Recommended Action Plan

### Immediate (Tier D -- rewrite)
1. [file] -- [reason] -- estimated effort: [S/M/L]

### Short-term (Critical gate failures)
1. [file] -- add error path test (Q7)
2. [file] -- import production code (Q13)

### Medium-term (Tier C)
1. [file] -- [top 3 fixes]

### Low priority (Tier B)
1. [file] -- [targeted fix]
```

### Important Rules

- NEVER modify test files during audit -- read only
- Each agent MUST read the production file too (for Q11, Q13, AP10 detection)
- If a test file has no identifiable production file -> mark as ORPHAN
- Setup/helper files (*.setup.ts, *.fixtures.ts) are NOT test files -- skip them
- Files with only `it.todo()` or `it.skip()` -> auto Tier D
- **Suite-aware grouping**: if multiple test files target the same production file (e.g., `foo.test.ts` + `foo.errors.test.ts`), batch them together and evaluate Q7/Q11 at suite level
