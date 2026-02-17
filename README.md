# Claude Code Toolkit

Opinionated rules, skills, and protocols for [Claude Code](https://claude.ai/code).

Enforces test quality, file size limits, security practices, and provides multi-agent workflows for code review, refactoring, and test auditing.

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
| `testing.md` | Mandatory tests, Q1-Q15 self-eval checklist, coverage targets |
| `file-limits.md` | Max 250 lines/file, 50 lines/function, splitting patterns |
| `security.md` | OWASP top 10, input validation, secret management |
| `typescript.md` | Zero `any` policy, Zod-first types, strict error handling |
| `react-nextjs.md` | Server components, hooks rules, accessibility, performance |
| `stack-detection.md` | Auto-detects project stack, loads conditional rules |

### Skills (`skills/`)

Slash commands for Claude Code:

| Command | What it does |
|---------|-------------|
| `/test-audit all` | Mass audit all test files against Q1-Q15 + AP1-AP12 anti-patterns. Parallel Sonnet agents, tiered report (A/B/C/D). |
| `/review` | Code review with structured protocol — severity levels, fix recommendations |
| `/refactor` | Guided refactoring with CONTRACT system — split files, track quality gates |
| `/backlog` | Backlog management |

### Protocols (root `.md` files)

Deep reference documents loaded on demand by skills:

| File | Lines | Used by |
|------|-------|---------|
| `test-patterns.md` | ~940 | `/test-audit`, testing rules — 27 Good Patterns + 26 Gap Patterns |
| `refactoring-protocol.md` | ~600 | `/refactor` — CONTRACT format, quality gates, splitting patterns |
| `review-protocol.md` | ~400 | `/review` — severity classification, fix tracking |

### Conditional Rules (`conditional-rules/`)

Loaded only when stack matches:

| File | When |
|------|------|
| `python.md` | Python project detected |
| `skill-management.md` | Creating/editing skills |

## Test Quality System

The core of this toolkit is a test quality enforcement system:

1. **Q1-Q15 binary checklist** — 15 yes/no questions scored per test file
2. **AP1-AP12 anti-patterns** — each found = -1 point deduction
3. **Critical gate** — Q7 (error paths), Q11 (branches), Q13 (imports), Q15 (assertion depth)
4. **Tiers** — A (>=12, leave alone), B (8-11, fix), C (5-7, major rewrite), D (<5, delete)
5. **Self-eval** — mandatory after writing any test

## File Structure

```
claude-code-toolkit/
├── rules/                      # Always-on global rules
│   ├── testing.md
│   ├── file-limits.md
│   ├── security.md
│   ├── typescript.md
│   ├── react-nextjs.md
│   └── stack-detection.md
├── skills/                     # Slash commands
│   ├── test-audit/
│   │   ├── SKILL.md
│   │   └── orchestrator-prompt.md
│   ├── review/
│   │   ├── SKILL.md
│   │   └── rules.md
│   ├── refactor/
│   │   ├── SKILL.md
│   │   └── rules.md
│   └── backlog/
│       └── SKILL.md
├── conditional-rules/          # Stack-dependent rules
│   ├── python.md
│   └── skill-management.md
├── test-patterns.md            # Full pattern library (G-*/P-*)
├── refactoring-protocol.md     # CONTRACT system
├── review-protocol.md          # Review protocol
├── install.sh                  # Installer (symlink or copy)
└── README.md
```

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- `~/.claude/` directory (created automatically by Claude Code)

## Customization

- Edit rules in `rules/` — changes apply immediately (if symlinked)
- Add project-specific rules in your project's `.claude/rules/` (override globals)
- Create new skills: add `skills/your-skill/SKILL.md`

## License

MIT
