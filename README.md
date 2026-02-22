# Claude Code Toolkit

Opinionated rules, skills, and protocols for [Claude Code](https://claude.ai/code) and [Google Antigravity](https://antigravity.google).

Enforces code quality (CQ1-CQ20), test quality (Q1-Q17), file size limits, security practices, and provides multi-agent workflows for code review, refactoring, auditing, and feature development.

## Quick Install

```bash
git clone https://github.com/YOUR_USERNAME/claude-code-toolkit.git ~/claude-code-toolkit
bash ~/claude-code-toolkit/install.sh
```

This symlinks everything to `~/.claude/` — updates automatically on `git pull`.

To copy instead (no dependency on this repo):
```bash
bash ~/claude-code-toolkit/install.sh --copy
```

## What's Included

### Rules (`rules/`)

Always-on rules loaded into every Claude Code session:

| File | What it enforces |
|------|-----------------|
| `code-quality.md` | CQ1-CQ20 production code checklist, critical gates, evidence requirement |
| `testing.md` | Mandatory tests, Q1-Q17 self-eval checklist, coverage targets |
| `file-limits.md` | Max 250 lines/file, 50 lines/function, splitting patterns |
| `security.md` | OWASP top 10, input validation, SSRF/XSS/SQLi prevention, secret management |
| `task-routing.md` | Routes tasks to `/build`, `/refactor`, `/review` based on complexity |
| `typescript.md` | Zero `any` policy, Zod-first types, strict error handling (conditional) |
| `react-nextjs.md` | Server components, hooks rules, accessibility, performance (conditional) |
| `stack-detection.md` | Auto-detects project stack, loads conditional rules |

### Skills (`skills/`)

Slash commands for Claude Code:

| Command | What it does |
|---------|-------------|
| `/build` | Structured feature development — blast radius analysis, sub-agents, CQ quality gates, auto-commit + tag |
| `/review` | Code review with parallel audit agents, confidence rescoring, auto-fix, backlog integration |
| `/refactor` | Guided refactoring with CONTRACT system — ETAP stages, team mode, quality gates, auto-commit + tag |
| `/code-audit` | Mass audit production files against CQ1-CQ20 + CAP1-CAP13 anti-patterns. Tiered report (A/B/C/D), fix workflow |
| `/test-audit` | Mass audit test files against Q1-Q17 + AP1-AP18 anti-patterns. Coverage completeness check |
| `/api-audit` | API endpoint integrity audit — 10 dimensions (D1-D10), safety gates, GET-only probing, cross-cutting analysis |
| `/backlog` | Tech debt backlog management — add, list, fix, wontfix items |

### Protocols (root `.md` files)

Deep reference documents loaded on demand by skills:

| File | Lines | Used by |
|------|-------|---------|
| `test-patterns.md` | ~1000 | `/test-audit`, testing rules — 27 Good Patterns + 38 Gap Patterns |
| `refactoring-protocol.md` | ~700 | `/refactor` — CONTRACT format, ETAP stages, quality gates |
| `review-protocol.md` | ~400 | `/review` — severity classification, fix tracking |

### Conditional Rules (`conditional-rules/`)

Loaded only when stack matches:

| File | When |
|------|------|
| `python.md` | Python project detected |
| `skill-management.md` | Creating/editing skills |

## Code Quality System (CQ1-CQ20)

Production code quality enforcement with evidence-based scoring:

1. **CQ1-CQ20 binary checklist** — 20 yes/no questions per production file
2. **Static critical gate** — CQ3, CQ4, CQ5, CQ6, CQ8, CQ14 — any = 0 means FAIL
3. **Conditional critical gate** — CQ16 (money), CQ19 (API boundary), CQ20 (dual fields) — activated by code context
4. **Evidence requirement** — critical gate CQs scored as 1 must provide proof (file:line, schema name)
5. **3-tier scoring** — PASS (>=16), CONDITIONAL PASS (14-15), FAIL (<14 or critical gate = 0)
6. **CAP1-CAP13 anti-patterns** — from empty catch blocks to float arithmetic on money
7. **Code type detection** — SERVICE, CONTROLLER, GUARD, REACT, ORM, ORCHESTRATOR, PURE, API-CALL

## Test Quality System (Q1-Q17)

Test quality enforcement with critical gate:

1. **Q1-Q17 binary checklist** — 17 yes/no questions per test file
2. **Critical gate** — Q7 (error paths), Q11 (branches), Q13 (imports), Q15 (assertion depth), Q17 (computed output)
3. **AP1-AP18 anti-patterns** — common test smells
4. **Tiers** — A (>=14, production-ready), B (9-13, fix), C (<9, rewrite)
5. **Self-eval** — mandatory after writing any test

## Auto-Commit + Tag

All code-modifying skills (`/build`, `/refactor`, `/review`, `/code-audit`) auto-commit after successful verification:
- `git add [specific files]` — never `-A`
- `git commit -m "[skill]: [description]"`
- `git tag [skill]-[YYYY-MM-DD]-[slug]`

Creates clean rollback points. Never auto-pushes (push is a separate user decision).

## File Structure

```
claude-code-toolkit/
├── rules/                      # Always-on global rules
│   ├── code-quality.md         # CQ1-CQ20 checklist + evidence + detailed examples
│   ├── testing.md              # Q1-Q17 checklist + self-eval
│   ├── file-limits.md          # 250 lines/file, 50 lines/function
│   ├── security.md             # OWASP, XSS, SSRF, SQLi, path traversal
│   ├── task-routing.md         # Routes tasks to correct skill
│   ├── typescript.md           # Zero any, Zod-first (conditional)
│   ├── react-nextjs.md         # Server components, hooks (conditional)
│   └── stack-detection.md      # Auto-detect stack
├── skills/                     # Slash commands
│   ├── build/
│   │   └── SKILL.md
│   ├── review/
│   │   ├── SKILL.md
│   │   ├── rules.md
│   │   └── agents/             # Parallel audit agents
│   │       ├── behavior-auditor.md
│   │       ├── structure-auditor.md
│   │       └── confidence-rescorer.md
│   ├── refactor/
│   │   ├── SKILL.md
│   │   ├── rules.md
│   │   └── agents/             # Sub-agents
│   │       ├── dependency-mapper.md
│   │       ├── existing-code-scanner.md
│   │       ├── test-quality-auditor.md
│   │       └── post-extraction-verifier.md
│   ├── code-audit/
│   │   ├── SKILL.md
│   │   └── orchestrator-prompt.md
│   ├── test-audit/
│   │   ├── SKILL.md
│   │   └── orchestrator-prompt.md
│   ├── api-audit/
│   │   ├── SKILL.md
│   │   ├── dimensions.md       # D1-D10 scoring criteria
│   │   └── agent-prompt.md
│   └── backlog/
│       └── SKILL.md
├── scripts/
│   └── setup-antigravity-all.sh
├── conditional-rules/
│   ├── python.md
│   └── skill-management.md
├── test-patterns.md            # Full pattern library (G-*/P-*)
├── refactoring-protocol.md     # CONTRACT + ETAP protocol
├── review-protocol.md          # Review protocol
├── install.sh                  # Installer (symlink or copy)
└── README.md
```

## Google Antigravity Integration

### What is Google Antigravity?

[Google Antigravity](https://antigravity.google) is an agent-first AI coding IDE announced November 2025 alongside Gemini 3. Key features:

- **Dual interface** — Editor View (traditional IDE with AI tab completions) + Manager View (spawn and orchestrate multiple autonomous agents)
- **Multi-agent orchestration** — dispatch 5+ agents working on different tasks simultaneously
- **Verifiable Artifacts** — agents produce screenshots, browser recordings, task lists as proof of work (not just logs)
- **Computer Use** — agents control browser and terminal in sandboxed environment
- **Free tier** — public preview, macOS/Windows/Linux, rate limits refresh every 5 hours
- **Model support** — Gemini 3 Pro (primary), Claude Sonnet 4.5, OpenAI GPT-4

Antigravity's `SKILL.md` format is compatible with Claude Code — skills from this toolkit work in both tools without conversion.

### How it works

Antigravity searches for skills in two locations per project:
- `_agent/skills/<name>/SKILL.md` — triggered automatically by AI intent
- `_agent/workflows/<name>.md` — triggered by `/command` slash commands

Both use underscore prefix (`_agent/`) — dot-prefix (`.agent/`) is ignored by Antigravity's file search.

### Setup for a single project

```bash
PROJECT="/path/to/your/project"
mkdir -p "$PROJECT/_agent/skills" "$PROJECT/_agent/workflows"
for skill in build review refactor code-audit test-audit api-audit backlog; do
  ln -sf ~/.claude/skills/$skill "$PROJECT/_agent/skills/$skill"
  ln -sf ~/.claude/skills/$skill/SKILL.md "$PROJECT/_agent/workflows/$skill.md"
done
```

### Setup for all projects at once

```bash
bash ~/.claude/scripts/setup-antigravity-all.sh
```

This script sets up every project under `~/DEV/` and also symlinks `memory/backlog.md` → Claude Code's memory directory when a backlog exists.

### Shared memory between Claude Code and Antigravity

Claude Code stores per-project memory in `~/.claude/projects/<encoded-path>/memory/`.
The setup script creates symlinks so both tools share the same files:

| Symlink in project | Points to | Contains |
|-------------------|-----------|---------|
| `memory/backlog.md` | `~/.claude/projects/.../memory/backlog.md` | Task backlog |
| `MEMORY.md` | `~/.claude/projects/.../memory/MEMORY.md` | Project context — architecture, known bugs, patterns |

Antigravity reads `MEMORY.md` when it scans the project, giving Opus the same project knowledge that Claude Code loads automatically on every session.

### Auto-propagation

Since everything is symlinked, editing a skill in `skills/review/SKILL.md` immediately applies in all projects for both Claude Code and Antigravity — no sync needed.

When adding a new skill, re-run the setup script to add it to all projects.

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- `~/.claude/` directory (created automatically by Claude Code)

## Customization

- Edit rules in `rules/` — changes apply immediately (if symlinked)
- Add project-specific rules in your project's `.claude/rules/` (override globals)
- Create new skills: add `skills/your-skill/SKILL.md`

## License

MIT
