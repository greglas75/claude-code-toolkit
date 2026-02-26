---
name: backlog
description: "Manage tech debt backlog — add, list, fix, wontfix, prioritize items. Use when managing or viewing the project's tech debt."
user-invocable: true
---

# /backlog — Manage Tech Debt Backlog

Add, list, or manage backlog items manually.

**Backlog location:** `memory/backlog.md` in the project's auto memory directory (path shown in system prompt). If the file doesn't exist, create it from the embedded template below.

## Path Resolution (non-Claude-Code environments)

If running in Cursor, Codex, or other IDEs where `~/.claude/` is not accessible, resolve paths:
- `~/.claude/` → `~/.cursor/` (Cursor) or `~/.codex/` (Codex)
- If neither available → `_agent/` in project root

## Parse $ARGUMENTS

| Input | Action |
|-------|--------|
| _(empty)_ or `list` | Show all OPEN items as a summary table |
| `list category:{x}` | Show OPEN items filtered by category (code/test/arch/dep/doc/infra) |
| `add` | Interactive: ask what to add, then append |
| `add {description}` | Add issue described in natural language |
| `fix B-{N}` | Delete item (confirmed fixed — git has history) |
| `wontfix B-{N} {reason}` | Delete item with reason logged to console |
| `delete B-{N}` | Remove item entirely (no reason needed) |
| `stats` | Show counts by severity |
| `prioritize` | Score and rank all OPEN items by Impact/Risk/Effort |
| `suggest` | Analyze backlog content and recommend batch fix actions |

## Resolving Items

`fix` and `wontfix` both **delete** the item from the backlog. Fixed/won't-fix items are not kept — git history preserves them. This matches `/review`'s model: no "resolved" section, no unbounded growth.

- `fix B-{N}` → confirm item ID, delete it, report "B-{N} deleted (fixed)"
- `wontfix B-{N} {reason}` → confirm item ID, log reason to console, delete it
- `delete B-{N}` → silent delete (for cleanup, no reason needed)

## Adding Items

When adding (either interactive or from description):

1. Read the current `backlog.md`
2. Determine next `B-{N}` ID
3. If user gave natural language description, extract:
   - **File + function** (ask if not obvious)
   - **Severity** (infer from description, confirm if unsure)
   - **Category** (Code/Test/Architecture/Dependency/Documentation/Infrastructure)
   - **Problem** (from user's description)
   - **Fix** (suggest one if obvious, otherwise "TBD")
4. **Dedup check** — compute fingerprint `file|rule-id|signature` (e.g., `auth.service.ts|CQ8|missing-try-catch`). Search the `Fingerprint` column for an existing match. If found → increment `Seen` count, keep highest severity, update date. Do NOT create duplicate.
5. Append as new table row
6. Confirm what was added

### Batch Add

If user provides multiple issues (numbered list, bullet points, or comma-separated), add them all in one pass. Show a summary table of what was added.

Example: `/backlog add` then user pastes:
```
1. apps/api/auth.ts - missing rate limiting on login endpoint
2. apps/web/Dashboard.tsx - N+1 query in useEffect
3. packages/shared/types.ts - 5 uses of `any` type
```

## Listing Items

Default view (no args or `list`):

```
TECH DEBT BACKLOG — {project name}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
| ID   | Severity | File                    | Problem (short)          | Seen |
|------|----------|-------------------------|--------------------------|------|
| B-1  | MEDIUM   | auth.service.ts         | catch(err: any)          | 3x   |
| B-2  | HIGH     | payout.service.ts       | Race condition in claim  | 1x   |
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OPEN: X items (C: _, H: _, M: _, L: _)
```

## Stats

```
BACKLOG STATS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OPEN:      X items
  CRITICAL:  _
  HIGH:      _
  MEDIUM:    _
  LOW:       _

By category:
  Code: _  Test: _  Architecture: _
  Dependency: _  Documentation: _  Infrastructure: _

Top files:
  1. services/payout.service.ts (3 items)
  2. handlers/webhook.ts (2 items)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Prioritization (when asked to rank or plan)

When user asks "what should we fix first?" or `/backlog prioritize`, score each OPEN item:

```
Priority Score = (Impact + Risk) × (6 - Effort)
```

| Dimension | 1 | 3 | 5 |
|-----------|---|---|---|
| **Impact** | Rarely slows us down | Sometimes blocks dev | Slows team every day |
| **Risk** | Nice-to-have | Regressions possible | Security/data loss risk |
| **Effort** | Days | Week | Month+ |

Score range: 2 (low priority) → 50 (do immediately).

Output as ranked table:
```
PRIORITIZED BACKLOG
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
| Rank | ID   | Score | Impact | Risk | Effort | Problem               |
|------|------|-------|--------|------|--------|-----------------------|
| 1    | B-2  | 40    | 5      | 5    | 2      | Race condition payout |
| 2    | B-1  | 24    | 4      | 4    | 3      | catch(err: any)       |
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Suggest (when `suggest` is called or user asks "what should we tackle?")

Analyze all OPEN items by pattern and propose batch actions:

| Condition | Suggested action |
|-----------|-----------------|
| 3+ items with same CQ (e.g., CQ8=0 in 5 files) | `/code-audit [files]` or direct fix batch |
| 3+ items from test-audit with same pattern ID | `/fix-tests --pattern [ID] [path]` |
| 3+ items pointing to same module | `/refactor [module]` or `/architecture review [module]` |
| 5+ Tier D items | `/code-audit --deep [path]` — serious quality debt |
| No OPEN items | "Backlog is clear — consider scheduling a periodic `/code-audit`" |

Output:
```
BACKLOG SUGGESTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Pattern: CQ8=0 appears in 5 files → /code-audit src/services/
Pattern: P-41 in 4 test files     → /fix-tests --pattern P-41 src/
Hotspot: src/offer/offer.service.ts (6 items) → /refactor src/offer/offer.service.ts
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Tech Debt Categories

When classifying new items (for filtering/planning):

| Category | Examples |
|----------|----------|
| **Code** | Duplicated logic, magic numbers, poor abstractions, any-types |
| **Architecture** | Wrong data store, monolith boundaries, missing service split |
| **Test** | Low coverage, flaky tests, missing integration tests |
| **Dependency** | Outdated libraries, CVEs, unmaintained packages |
| **Documentation** | Missing runbooks, outdated READMEs, tribal knowledge |
| **Infrastructure** | Manual deploys, no monitoring, missing IaC |

Assign category when adding items. Enables `/backlog list category:test` filtered views.

### CLI Alias → Column Value

| CLI shortcut | Category column value |
|-------------|----------------------|
| `code` | Code |
| `test` | Test |
| `arch` | Architecture |
| `dep` | Dependency |
| `doc` | Documentation |
| `infra` | Infrastructure |

---

## Backlog Template (embedded — no external dependency)

When `memory/backlog.md` doesn't exist, create it from this template:

```markdown
# Tech Debt Backlog

> Auto-maintained by `/review`, `/build`, `/code-audit`, `/test-audit`, `/write-tests`, `/fix-tests`, `/backlog`.
> Fixed items are deleted (git has history).

| ID | Fingerprint | File | Issue | Severity | Category | Source | Seen | Dates |
|----|-------------|------|-------|----------|----------|--------|------|-------|
```

This is the same table format used by all producer skills (build, test-audit, fix-tests, write-tests, code-audit). Each row = one backlog item. Fingerprint format: `file|rule-id|signature`.
