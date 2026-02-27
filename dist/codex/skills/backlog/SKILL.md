---
name: backlog
description: "Manage tech debt backlog -- add, list, fix, wontfix, prioritize items. Use when managing or viewing the project's tech debt."
---

# /backlog -- Manage Tech Debt Backlog

Add, list, or manage backlog items manually.

**Backlog location:** `memory/backlog.md` in the project root (same level as `package.json`/`CLAUDE.md`). If `memory/` dir does not exist -> `mkdir -p memory`. If the file doesn't exist, create it from the embedded template below.

## Backlog Schema

Canonical column definition -- ALL interactions use these columns:

| Column | Description | Required |
|--------|-------------|----------|
| **ID** | `B-{N}` sequential | auto |
| **Fingerprint** | Dedup key (see format below) | auto |
| **File** | File path | yes |
| **Problem** | Short description of the issue | yes |
| **Severity** | CRITICAL \| HIGH \| MEDIUM \| LOW | yes |
| **Category** | Code \| Test \| Architecture \| Dependency \| Documentation \| Infrastructure | yes |
| **Source** | Which skill added it (`code-audit/2026-02-27`, `manual`, etc.) | auto |
| **Seen** | Occurrence count (deduplicated) | auto |
| **Added** | Date first added (YYYY-MM-DD) | auto |

**Fingerprint formats by source:**
- From `/code-audit`: `file|CQ{N}|signature` (e.g., `auth.service.ts|CQ8|missing-try-catch`)
- From `/test-audit`: `file|{pattern-id}|signature` (e.g., `auth.test.ts|P-41|loading-only`)
- From `/write-tests`: `file|Q{N}|signature` (e.g., `user.test.ts|Q7|no-error-path`)
- Manual add: `file|manual|first-3-words-slugified` (e.g., `auth.ts|manual|missing-rate-limiting`)

**Listing view** (compact subset): `ID | Severity | File | Problem | Seen`

## Parse $ARGUMENTS

| Input | Action |
|-------|--------|
| _(empty)_ or `list` | Show all OPEN items as a summary table |
| `list category:{x}` | Show OPEN items filtered by category (code/test/arch/dep/doc/infra) |
| `add` | Interactive: ask what to add, then append |
| `add {description}` | Add issue described in natural language |
| `fix B-{N}` | Delete item (confirmed fixed -- git has history) |
| `wontfix B-{N} {reason}` | Delete item with reason logged to console |
| `delete B-{N}` | Remove item entirely (no reason needed) |
| `stats` | Show counts by severity |
| `prioritize` | Rank individual items by urgency score (view-only ordering) |
| `suggest` | Group items by pattern and propose batch fix commands |

## Error Handling

| Situation | Response |
|-----------|----------|
| `fix B-99` but B-99 doesn't exist | "B-99 not found in backlog. Run `/backlog list` to see current items." |
| `list` but backlog.md is empty (header only) | "Backlog is empty. Use `/backlog add` to track issues." |
| `add` with vague description (no file path) | Ask for file path and specific problem before adding |
| `prioritize` with 0 or 1 items | "Only {N} item(s) -- no ranking needed." Show the item if 1. |
| `suggest` with 0 items | "Backlog is clear -- consider scheduling a periodic `/code-audit`." |

## Resolving Items

`fix` and `wontfix` both **delete** the item from the backlog. Fixed/won't-fix items are not kept -- git history preserves them. This matches `/review`'s model: no "resolved" section, no unbounded growth.

- `fix B-{N}` -> confirm item ID, delete it, report "B-{N} deleted (fixed)"
- `wontfix B-{N} {reason}` -> confirm item ID, log reason to console, delete it
- `delete B-{N}` -> silent delete (for cleanup, no reason needed)

## Adding Items

When adding (either interactive or from description):

1. Read the current `backlog.md`
2. Determine next `B-{N}` ID
3. If user gave natural language description, extract:
   - **File** (ask if not obvious from description)
   - **Problem** (short description from user input)
   - **Severity** (infer from description -- see batch add inference rules)
   - **Category** (infer from file path -- see batch add inference rules)
4. **Dedup check** -- compute fingerprint per schema format (see Backlog Schema). Search the `Fingerprint` column for an existing match. If found -> increment `Seen` count, keep highest severity, update date. Do NOT create duplicate.
5. Append as new table row (all schema columns)
6. Confirm what was added

### Batch Add

If user provides multiple issues (numbered list, bullet points, or comma-separated), add them all in one pass. Show a summary table of what was added.

**Auto-inference for missing fields** (do NOT ask per-item):
- **Severity**: infer from keywords -- `race condition`/`security`/`data loss` -> HIGH, `any type`/`missing test` -> MEDIUM, `typo`/`naming` -> LOW
- **Category**: infer from file path -- `*.test.*` -> Test, `*.service.*`/`*.controller.*` -> Code, `docker*`/`*.yml` -> Infrastructure, `types.*` -> Code
- **Source**: `manual`
- **Seen**: `1x`
- **Added**: today
- **Fingerprint**: `file|manual|first-3-words-slugified`

Infer all fields, then show summary table for confirmation before writing.

Example: `/backlog add` then user pastes:
```
1. apps/api/auth.ts - missing rate limiting on login endpoint
2. apps/web/Dashboard.tsx - N+1 query in useEffect
3. packages/shared/types.ts - 5 uses of `any` type
```

## Listing Items

Default view (no args or `list`):

```
TECH DEBT BACKLOG -- {project name}
---------------------------------------------
| ID   | Severity | File                    | Problem (short)          | Seen |
|------|----------|-------------------------|--------------------------|------|
| B-1  | MEDIUM   | auth.service.ts         | catch(err: any)          | 3x   |
| B-2  | HIGH     | payout.service.ts       | Race condition in claim  | 1x   |
----------------------------------------------
OPEN: X items (C: _, H: _, M: _, L: _)
```

## Stats

```
BACKLOG STATS
----------------------------
OPEN:      X items
  CRITICAL:  _
  HIGH:      _
  MEDIUM:    _
  LOW:       _

By category:
  Code: _  Test: _  Architecture: _
  Dependency: _  Documentation: _  Infrastructure: _

Top files (group by File column, sort by count descending, show top 5):
  1. services/payout.service.ts (3 items)
  2. handlers/webhook.ts (2 items)
----------------------------
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

Score range: 2 (low priority) -> 50 (do immediately).

Output as ranked table:
```
PRIORITIZED BACKLOG
------------------------------------------------
| Rank | ID   | Score | Impact | Risk | Effort | Problem               |
|------|------|-------|--------|------|--------|-----------------------|
| 1    | B-2  | 40    | 5      | 5    | 2      | Race condition payout |
| 2    | B-1  | 24    | 4      | 4    | 3      | catch(err: any)       |
------------------------------------------------
```

---

## Suggest (when `suggest` is called or user asks "what should we tackle?")

Analyze all OPEN items by pattern and propose batch actions:

| Condition | Suggested action |
|-----------|-----------------|
| 3+ items with same CQ (e.g., CQ8=0 in 5 files) | `/code-audit [files]` or direct fix batch |
| 3+ items from test-audit with same pattern ID | `/fix-tests --pattern [ID] [path]` |
| 3+ items pointing to same module | `/refactor [module]` or `/architecture review [module]` |
| 5+ Tier D items | `/code-audit --deep [path]` -- serious quality debt |
| No OPEN items | "Backlog is clear -- consider scheduling a periodic `/code-audit`" |

Output:
```
BACKLOG SUGGESTIONS
------------------------------
Pattern: CQ8=0 appears in 5 files -> /code-audit src/services/
Pattern: P-41 in 4 test files     -> /fix-tests --pattern P-41 src/
Hotspot: src/offer/offer.service.ts (6 items) -> /refactor src/offer/offer.service.ts
------------------------------
```

---

## Tech Debt Categories

Assign category when adding items. Enables `/backlog list category:test` filtered views.

| CLI alias | Category | Examples |
|-----------|----------|----------|
| `code` | Code | Duplicated logic, magic numbers, poor abstractions, any-types |
| `arch` | Architecture | Wrong data store, monolith boundaries, missing service split |
| `test` | Test | Low coverage, flaky tests, missing integration tests |
| `dep` | Dependency | Outdated libraries, CVEs, unmaintained packages |
| `doc` | Documentation | Missing runbooks, outdated READMEs, tribal knowledge |
| `infra` | Infrastructure | Manual deploys, no monitoring, missing IaC |

---

## Backlog Template (embedded -- no external dependency)

When `memory/backlog.md` doesn't exist, create it from this template:

```markdown
# Tech Debt Backlog

> Auto-maintained by `/review`, `/build`, `/code-audit`, `/test-audit`, `/write-tests`, `/fix-tests`, `/backlog`.
> Fixed items are deleted (git has history).

| ID | Fingerprint | File | Problem | Severity | Category | Source | Seen | Added |
|----|-------------|------|---------|----------|----------|--------|------|-------|
```

This is the same table format used by all producer skills. Columns match the **Backlog Schema** at the top of this file.
