---
name: backlog
description: "Manage tech debt backlog -- add, list, fix, wontfix, delete items. Use when managing or viewing the project's tech debt."
---

# /backlog -- Manage Tech Debt Backlog

Add, list, or manage backlog items manually. Works independently of `/review`.

**Backlog location:** `memory/backlog.md` in the project's auto memory directory (path shown in system prompt). If the file doesn't exist, create it from the template in `~/.codex/skills/review/rules.md`.

## Parse $ARGUMENTS

| Input | Action |
|-------|--------|
| _(empty)_ | Show all OPEN items as a summary table |
| `add` | Interactive: ask what to add, then append |
| `add {description}` | Add issue described in natural language |
| `fix B-{N}` | Mark item as FIXED with today's date |
| `wontfix B-{N} {reason}` | Mark item as WONT_FIX |
| `delete B-{N}` | Remove item entirely |
| `stats` | Show counts by severity + status |

## Adding Items

When adding (either interactive or from description):

1. Read the current `backlog.md`
2. Determine next `B-{N}` ID
3. If user gave natural language description, extract:
   - **File + function** (ask if not obvious)
   - **Severity** (infer from description, confirm if unsure)
   - **Problem** (from user's description)
   - **Fix** (suggest one if obvious, otherwise "TBD")
4. Check for duplicates (same file + same function/location) -- if found, increment `Seen` count instead
5. Append under `## OPEN Issues`
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

RESOLVED:  Y items
WONT_FIX:  Z items

Top files:
  1. services/payout.service.ts (3 items)
  2. handlers/webhook.ts (2 items)
----------------------------
```

$ARGUMENTS
