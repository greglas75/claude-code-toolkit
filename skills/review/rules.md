ocen f# Code Review Rules (Always Active)

These rules govern all code reviews via `/review`.
Full protocol with detailed checklists, red-flag patterns, and report templates is at `~/.claude/review-protocol.md` — read it on-demand when `/review` starts.

---

## Change Intent (Set First)

| Intent | Focus | Required Tests |
|--------|-------|---------------|
| BUGFIX | Regression prevention, edge cases | 1 regression (reproduces bug) + 1 happy path |
| REFACTOR | Behavioral compatibility, no regressions | Contract tests (before=after) + 1 format/encoding breaker |
| FEATURE | Completeness, UX, observability | 1 e2e/integration + unit for edge + error cases |
| INFRA | Backward compat, rollback, config validation | Smoke test + config validation |

## Severity Definitions

| Level | Meaning | Examples |
|-------|---------|---------|
| CRITICAL | Data loss/corruption, security/PII, auth bypass, money, system outage | SQL injection, PII leak, payment bug |
| HIGH | User-visible bug, broken functionality | Race condition, missing validation, broken edge case |
| MEDIUM | Tech debt, maintainability | Code duplication >20 lines, missing types, poor naming |
| LOW | Style preference, minor improvement | Naming nitpick, minor optimization |

Don't inflate severity. Be honest. "I would do it differently" is not HIGH.

## False Positive Filter (Apply Before Reporting)

DO NOT report these as PR issues — but DO persist them to backlog (see Backlog Persistence below):
- **Pre-existing:** Issue existed before this change (check `git blame` — if line is old, skip from PR report but add to backlog)
- **Unmodified lines:** Real issue but on code the author didn't touch in this change (skip from PR report but add to backlog)

DO NOT report AND do NOT add to backlog:
- **Linter/compiler-catchable:** Import errors, type errors, formatting — CI catches these
- **Stylistic without CLAUDE.md rule:** Personal preference not backed by project conventions
- **Intentional changes:** Functionality changes directly related to the PR's purpose
- **Pedantic nitpicks:** Things a senior engineer would wave through
- **Speculative:** "This might cause issues" without concrete evidence or scenario

When in doubt: does this issue actually impact users or maintainability? If no → skip it.

## Confidence Re-Scoring

After audit, spawn a **Haiku sub-agent** to independently re-score each issue 0-100.
The sub-agent acts as a skeptic defending the code author. See `/review` for full agent prompt.

| Score | Meaning | Action |
|-------|---------|--------|
| 0-25 | Hallucination or 100% false positive — doesn't survive scrutiny | **DISCARD** (do not persist) |
| 26-50 | Minor nitpick, pre-existing debt, low impact | Backlog only |
| 51-74 | Valid, low-impact but real — worth fixing | **In report** |
| 75-89 | Important — verified real, affects functionality | **In report** |
| 90-100 | Critical — confirmed, will happen in production | **In report** |

**Threshold: 51+** goes into the report with fix code. 26-50 → backlog only. 0-25 → DISCARD (hallucinations and total false positives don't pollute backlog).
For each reported issue, show the confidence score: `Confidence: [X]/100`

Sub-agents used during review (tier-gated — see SKILL.md for full logic):

| Agent | Model | Spawned When |
|-------|-------|--------------|
| **Blast Radius Mapper** | Sonnet | TIER 2 (3+ files) or TIER 3. TIER 1 / TIER 2 (<3 files): lead does inline grep. |
| **Pre-Existing Checker** | Haiku | TIER 2+. TIER 1: lead does inline `git blame`. |
| **Structure Auditor** | Sonnet | Team audit only (TIER 2 with 5+ files OR TIER 3). |
| **Behavior Auditor** | Sonnet or Opus | Team audit only. Sonnet for TIER 2 team and small TIER 3. Opus only for TIER 3 with 15+ files OR security/money risk signals. |
| **Confidence Re-Scorer** | Haiku | TIER 2+. TIER 1: lead scores inline (max 2-3 issues). |

### Team Audit Mode (TIER 2 with 5+ files OR TIER 3)

For larger reviews, `/review` splits audit steps across 2 custom agents in parallel. Agents are defined in `~/.claude/skills/review/agents/` with enforced read-only tool access (no Write/Edit) and optimized model routing.

**Activation:** `(TIER 2 AND files_changed >= 5) OR TIER 3`

**Structure:**
| Role | Agent | Model | Steps | Focus |
|------|-------|-------|-------|-------|
| Lead | (orchestrator) | inherited | 0, 1 (sequential, first) | Context setting, change inventory |
| Structure Auditor | `structure-auditor` | Sonnet | 2, 4, 5 (+10, 11 for T3) | Types, imports, architecture, integration, performance |
| Behavior Auditor | `behavior-auditor` | Sonnet (default) / Opus (T3 large+risky) | 3, 6, 9 (+7, 8 for T3) | Logic, side effects, regressions, security, observability |

**Behavior Auditor model routing:** Opus only when `TIER 3 AND (files_changed >= 15 OR risk signals include Security/auth or Payment/money)`. All other team audits use Sonnet.

**Merge protocol:**
1. Wait for both auditors to complete
2. Collect issue lists (STRUCT-* + BEHAV-*)
3. Deduplicate — if both found same issue, keep more detailed one
4. Renumber: R-1, R-2, R-3...
5. Feed merged list to Confidence Re-Scorer (`confidence-rescorer` agent)

**When NOT to use team audit:**
- TIER 1 (too few steps)
- TIER 2 with < 5 files (overhead > benefit)
- User says "solo" or "no team" (explicit override)

### Code Quality on Execute

When applying fixes during Execute, run CQ1-CQ20 self-eval (`~/.claude/rules/code-quality.md`) on each modified production file. Static critical gate: CQ3, CQ4, CQ5, CQ6, CQ8, CQ14. Conditional gate: CQ16 (money), CQ19 (I/O), CQ20 (dual fields). Thresholds: ≥16 PASS, 14-15 CONDITIONAL PASS (fix before merge encouraged), <14 FAIL. Any active critical gate = 0 → FAIL regardless of score. Evidence required for each critical CQ scored as 1.

### Parallel Execute Mode (3+ fixes on different files)

During Execute (Phase B), if 3+ fixes target different files with no interaction, spawn parallel agents to apply fixes simultaneously. Each agent:
- Gets assigned issues + fix code from report
- Only modifies files in its scope
- Writes tests for its fixes (separate spec files)
- Reports back to lead for verification

**Dependency check before parallelizing:** Do NOT parallelize if ANY of these apply:
- Fixes target the same file
- File A imports from File B (or vice versa) — check with grep before splitting
- Fixes share a common type/interface/DTO that both modify
- Controller + Service pair for the same endpoint (execute sequentially: Service first → Controller second)

## Tier Selection

| Tier | When | Audit Steps | Mode 2 OK? |
|------|------|-------------|------------|
| TIER 1 (LIGHT) | <50 lines, no risk signals | 0 → 1 → 2.1 → 6.1 → Report | YES |
| TIER 2 (STANDARD) | 50-500 lines, max 1 risk signal | 0 → 1-6 → **7.0** → 9 → Report | YES (if no risky changes) |
| TIER 3 (DEEP) | >500 lines OR 2+ risk signals | ALL 0-11 → Report | NO |

## Mode 2 Blocker

`/review fix` is FORBIDDEN if ANY: TIER 3, DB/migration changes, security/auth changes, API contract changes, payment/money flow.
If blocked → run `/review` (report only) + `Execute BLOCKING` instead.

## 6 Iron Rules

### 1. EVIDENCE REQUIRED
- File path (required) + direct code quote (max 20 lines, minimal snippet proving the claim)
- Function name + unique anchor line (required)
- NO vague claims ("there might be a problem")
- "Code Executed Locally" = YES only if terminal output was provided; otherwise "NOT VERIFIED" + confidence downgrade

### 2. FIX CODE MANDATORY
- MEDIUM+ issues: complete, working replacement code — full replacement, not snippets

### 3. ZERO HALLUCINATION
- Don't invent imports/APIs. If unsure → prefix with "VERIFY:"

### 4. HOLISTIC THINKING
- View file as part of SYSTEM. What depends on this? What breaks if it changes?

### 5. SEVERITY HONESTY
- Don't inflate. CRITICAL = actual data loss / security / auth bypass / money risk
- "I would do it differently" ≠ "This is wrong"

### 6. TESTS ARE BLOCKING
- Missing tests for new/changed code = BLOCKING issue
- On Execute: write complete, runnable tests (NOT stubs/todos/skips)
- `it.todo` / `test.todo` / `describe.skip` / `it.skip` in required tests = BLOCKING
- No merge without test coverage
- Requirements depend on CHANGE INTENT (see table above)
- **Before writing tests:** read `~/.claude/test-patterns.md` (global, all projects). Apply all matching patterns (check WHEN triggers against code under test).
- **After writing tests:** run Q1-Q17 self-eval checklist (17 yes/no questions, per `~/.claude/rules/testing.md`). Score < 14 = fix before continuing. Critical gate: Q7, Q11, Q13, Q15, Q17.
- **When user gives feedback about test gaps:** append new pattern to `~/.claude/test-patterns.md` with WHEN trigger, required tests, and source.

## Scope Fence (Mandatory on Execute)

Before applying ANY fix, show:
- **ALLOWED FILES** from the report
- **FORBIDDEN:** files outside scope, new public APIs/DTOs, new dependencies, "while we're here" improvements, style/naming outside fix scope

If fix requires touching other file → STOP → ask: "Fix requires [file]. Add to allowed list?" → wait for approval.

**Auto-expanded scope:** CQ16 corrections (Float→Decimal) automatically expand Scope Fence to include dependent DTOs, Type Definitions, and ORM schemas that reference the corrected field — because changing a field's type without updating its consumers creates type errors. No approval needed for these cascading type changes.

## Flaky Test Detection

During "loop until green", if test fails:
1. Check if same test passed earlier in session
2. Check if failure is non-deterministic (timing, random, race)
3. Check if environment-related (network, disk)

If FLAKY SUSPECTED → STOP loop → mark "FLAKY SUSPECTED: [test]" → ask user → DO NOT "fix" code to make flaky test pass.

## Stack-Specific Awareness

Auto-detect stack from project files before reviewing:
- `next.config.*` → Next.js: check Server Components, Server Actions, `"use client"`, `NEXT_PUBLIC_*`
- `pyproject.toml` / `requirements.txt` / `manage.py` → Python: check type hints, mutable defaults, async pitfalls, pickle/eval
- `package.json` with `react` → React: check hooks, re-renders, state management
- Detailed checklists for each stack in `~/.claude/review-protocol.md`

Critical cross-stack checks (always apply):
- Env vars: validated at startup? Secrets not exposed to client?
- Auth: checked in every mutation endpoint / server action?
- Input validation: at system boundaries (API, forms, server actions)?

## Gate A — Insufficient Input

If no diff / no baseline / no context provided:
- Confidence = LOW, switch to TIER 1
- Review ONLY what is visible (local correctness, obvious bugs)
- Mark system-level claims as "INSUFFICIENT DATA"
- Output Context Request Block (max 3 bullets): diff/PR link, changed files, test output
- FORBIDDEN: regression risk claims, dead-code statements, broad refactors

## Issue Format (Required for Each Issue)

```
### [ID] Short Descriptive Title
Severity: CRITICAL / HIGH / MEDIUM / LOW
Confidence: [X]/100
Location: `file.ts` → `functionName()` → near `codeFragment`
Current Code: [exact quote, max 20 lines]
Problem: [why it's wrong]
Impact: [what breaks — specific user impact]
Pre-existing? [YES (skip) / NO — checked via git blame]
Complete Fix: [full replacement code — must compile and work]
Verification: [how to verify the fix]
```

## Backlog Persistence (Mandatory)

**Location:** `memory/backlog.md` in the project's auto memory directory.
To find it: look for the `auto memory directory` path in your system prompt (e.g., `~/.claude/projects/{project-slug}/memory/`). The backlog file is `backlog.md` inside that directory.
If `backlog.md` doesn't exist yet, create it using the template below.

### Size Management

1. **FIXED/WONT_FIX → DELETE** (not "move to resolved"). Git has history if needed.
2. **No RESOLVED section.** Fixed = gone. This prevents unbounded growth.

### Backlog file template (create if missing)

```markdown
# Tech Debt Backlog

> Auto-maintained by `/review`. Max 50 OPEN items. Fixed items are deleted.

## Format

### B-{N}: {Short Title}
- **Severity:** CRITICAL / HIGH / MEDIUM / LOW
- **Confidence:** {X}/100
- **File:** `{path}` → `{function}()`
- **Problem:** {description}
- **Fix:** {brief fix description}
- **Source:** review {date}
- **Seen:** {count}x

---

## OPEN Issues

_No issues yet._
```

### What goes to backlog

| Source | When | Example |
|--------|------|---------|
| Pre-existing issues | Found during review but pre-date this PR | `catch(err: any)` on unmodified line |
| Issues on unmodified lines | Real problem but not author's responsibility | Missing validation in adjacent function |
| Dropped issues (confidence 26-50) | Filtered from report but real enough to track | Missing tooltip, minor tech debt |
| Reported but not fixed | User chose `Execute BLOCKING` (skips MEDIUM/LOW) | Tech debt items from report |
| Deferred by user | User explicitly says "not now" / "later" | Any severity |

Issues with confidence 0-25 are DISCARDED — hallucinations don't go to backlog.

### When to persist

- **After confidence gate:** persist dropped issues with confidence 26+ (0-25 = DISCARD)
- **After `/review` (report only):** persist all reported issues + pre-existing issues
- **After `/review fix`:** persist any issues that couldn't be auto-fixed
- **After `/review blocking`:** persist MEDIUM + LOW issues (not fixed)
- **After `Execute` / `Execute BLOCKING`:** persist issues NOT applied
- **After `Execute [ID]`:** persist issues whose IDs were NOT in the execute list

### How to persist

1. Read current `backlog.md`
2. For each issue to persist, compute **fingerprint**: `file_path:rule_id:line_range`
   - `rule_id` = CQ number (e.g., CQ8), or issue category (e.g., "missing-test", "dead-code")
   - `line_range` = approximate hunk location (e.g., "L45-60"). Use ±10 line tolerance for matching.
   - Example fingerprint: `src/auth/auth.service.ts:CQ4:L45-60`
3. For each issue:
   - Search backlog for matching fingerprint (same file + same rule + overlapping line range)
   - If **duplicate**: increment `Seen` count, keep highest confidence score, update line range if shifted
   - If **new**: append under `## OPEN Issues` with next `B-{N}` ID
4. **Prune:** delete any FIXED/WONT_FIX items.
5. Write updated `backlog.md`

### When to delete items

- During any review, if a backlog item's file+function was modified and the problem no longer exists → **delete the item** (not "mark as resolved")
- User says "wontfix" or "ignore" → **delete the item**

### At review start

Read `backlog.md` at the beginning of every `/review`. If the current PR touches files with open backlog items, mention them in the report under a `## BACKLOG ITEMS IN SCOPE` section so the author can optionally fix them.

## Review Commands Quick Reference

| Command | What it does |
|---------|-------------|
| `/review` | Triage + full audit report. Wait for Execute. |
| `/review fix` | Triage + audit + auto-fix ALL + tests + loop (Mode 2 gate applies) |
| `/review blocking` | Triage + audit + fix CRITICAL/HIGH only + tests + loop |
| `Execute` | Apply ALL fixes from last report |
| `Execute BLOCKING` | Apply CRITICAL + HIGH only |
| `Execute [ID]` | Apply specific fix(es) |
| `Re-audit` | Run audit again after fixes |
| `Push` | Commit + push + tag `reviewed` |
