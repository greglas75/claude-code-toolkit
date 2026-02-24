# Task Routing (MANDATORY)

Before starting implementation, route the task to the correct workflow.

## Routing Table

| Task Type | Signal | Command | Why |
|-----------|--------|---------|-----|
| New feature (3+ files) | New endpoints, components, services | `/build` | Blast radius + existing code scan + quality gates |
| New feature (1-2 files) | Small addition, clear scope | Direct coding | Rules in .claude/rules/ sufficient |
| Refactoring | Extract, split, move, rename, simplify | `/refactor` | CONTRACT + ETAP workflow |
| Code review | After coding, before push | `/review` | Audit + confidence gate + backlog |
| Code quality audit | Mass audit of production files | `/code-audit` | CQ1-CQ20 + CAP1-CAP13, tiered report |
| Test quality audit | Mass audit of test files | `/test-audit` | Q1-Q17 + AP/P-* patterns, tiered report |
| API audit | Endpoint integrity check | `/api-audit` | 10 dimensions (D1-D10), cross-cutting analysis |
| Tech debt management | View/manage backlog items | `/backlog` | Add, list, fix, wontfix items |
| Simple bug fix | <3 files, clear cause | Direct coding | Follow testing + CQ rules |
| Complex bug fix | 3+ files, unclear cause | `/build` | Need blast radius analysis |

## Rule: No Direct EnterPlanMode for Features

**NEVER use `EnterPlanMode` directly for feature implementation that touches 3+ files.**

Use `/build` instead — it includes planning WITH analysis sub-agents (blast radius, duplication check, test quality audit). `EnterPlanMode` alone skips all quality gates.

When `EnterPlanMode` IS appropriate:
- Simple tasks (1-2 files, clear scope)
- User explicitly says "just plan it" without wanting full workflow
- Research/investigation tasks (not implementation)

## Rule: CQ Self-Eval for Direct Coding

When coding directly (1-2 files, no `/build` or `/refactor`), still run CQ1-CQ20 self-eval from `~/.claude/rules/code-quality.md` on each production file before writing tests. Critical gate (static + conditional), evidence requirement, and thresholds apply.

## Rule: /review Before Push

After any non-trivial implementation (feature or bug fix), run `/review` before pushing.
This catches issues that escaped during development.

## Rule: Periodic Audits

Run mass audits periodically or before releases:
- `/code-audit` — after adding >10 production files, or before major release
- `/test-audit` — after mass test writing, or when test quality is uncertain
- `/api-audit` — after adding new endpoints, or before API versioning changes
