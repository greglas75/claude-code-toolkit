# Agent Instructions

You have access to a quality toolkit in the `_agent/` directory. **Use it instead of improvising.**

## Rules (always active)

Read these before writing or auditing code:

| File | Contains |
|------|----------|
| `_agent/rules/code-quality.md` | CQ1-CQ20 checklist with scoring, critical gates, evidence requirements |
| `_agent/rules/testing.md` | Q1-Q17 test self-eval checklist with critical gates |
| `_agent/rules/security.md` | OWASP patterns: XSS, SSRF, SQL injection, auth, path traversal |
| `_agent/rules/file-limits.md` | 250 lines per file, 50 lines per function |
| `_agent/rules/task-routing.md` | Routes tasks to the correct workflow (see below) |

## Available Skills (slash commands)

Each skill has a detailed workflow in `_agent/workflows/`. **Read the workflow file before starting.**

| Command | Workflow file | When to use |
|---------|--------------|-------------|
| `/build` | `_agent/workflows/build.md` | New features (3+ files) |
| `/review` | `_agent/workflows/review.md` | Code review before push |
| `/refactor` | `_agent/workflows/refactor.md` | Extract, split, move, rename |
| `/code-audit` | `_agent/workflows/code-audit.md` | Mass audit of production files against CQ1-CQ20 |
| `/test-audit` | `_agent/workflows/test-audit.md` | Mass audit of test files against Q1-Q17 |
| `/api-audit` | `_agent/workflows/api-audit.md` | Endpoint integrity check |
| `/backlog` | `_agent/workflows/backlog.md` | View/manage tech debt backlog |

## Critical: Use Existing Definitions

- **CQ1-CQ20** are defined in `_agent/rules/code-quality.md`. Do NOT invent your own numbering.
- **Q1-Q17** are defined in `_agent/rules/testing.md`. Do NOT invent your own test quality metrics.
- **Severity levels** (CRITICAL/HIGH/MEDIUM/LOW) are defined in `_agent/skills/review/rules.md`.

When recommending new rules, first verify the issue isn't already covered by an existing CQ or Q rule.

## Path Resolution

All `_agent/` paths are symlinks. If a skill references `~/.claude/`, resolve as:
- `~/.claude/rules/` -> `_agent/rules/`
- `~/.claude/skills/` -> `_agent/skills/`
- `~/.claude/review-protocol.md` -> `_agent/review-protocol.md`
- `~/.claude/test-patterns.md` -> `_agent/test-patterns.md`
- `~/.claude/test-patterns-catalog.md` -> `_agent/test-patterns-catalog.md`
- `~/.claude/test-patterns-redux.md` -> `_agent/test-patterns-redux.md`
- `~/.claude/test-patterns-nestjs.md` -> `_agent/test-patterns-nestjs.md`
- `~/.claude/test-patterns-yii2.md` -> `_agent/test-patterns-yii2.md`

## Backlog

Tech debt backlog is at `memory/backlog.md` (if it exists). Read it before audits to check for known issues.
