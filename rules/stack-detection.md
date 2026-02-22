# Stack Detection (All Projects)

At the start of every session, determine the project's tech stack. This controls which conditional rules apply.

## How to Detect

**Step 1:** Check project CLAUDE.md for a `Tech Stack` section or table. If present, use it as the source of truth.

**Step 2:** If no CLAUDE.md or no stack declaration, auto-detect from config files:

| Signal | Stack |
|--------|-------|
| `tsconfig.json` or `.ts`/`.tsx` files | TypeScript → apply `typescript.md` |
| `package.json` with `react` in deps | React → apply `react-nextjs.md` |
| `package.json` with `next` in deps | Next.js → apply `react-nextjs.md` |
| `pyproject.toml`, `requirements.txt`, `setup.py`, or `.py` files | Python → apply `python.md` |
| `vitest.config.*` or `vitest` in devDeps | Vitest (test runner) |
| `jest.config.*` or `jest` in devDeps | Jest (test runner) |
| `wrangler.toml` | Cloudflare Workers |
| `next.config.*` | Next.js |
| `vite.config.*` | Vite |
| `prisma/schema.prisma` | Prisma ORM |

## Conditional Rules

These rules in `~/.claude/rules/` are stack-dependent — apply ONLY when stack matches:

| Rule file | Apply when |
|-----------|-----------|
| `typescript.md` | TypeScript detected |
| `react-nextjs.md` | React or Next.js detected |

These rules in `~/.claude/rules/` ALWAYS apply regardless of stack:

| Rule file | Scope |
|-----------|-------|
| `file-limits.md` | All projects |
| `testing.md` | All projects |
| `code-quality.md` | All projects — CQ1-CQ20 production code self-eval |
| `security.md` | All projects |
| `task-routing.md` | All projects — routes tasks to `/build`, `/refactor`, `/review` |

These are loaded ON-DEMAND (not in `~/.claude/rules/`):

| File | Loaded when | Location |
|------|-------------|----------|
| `python.md` | Python detected | `~/.claude/conditional-rules/python.md` — read if Python stack |
| Build workflow | `/build` invoked | `~/.claude/skills/build/SKILL.md` — structured feature dev |
| Review rules | `/review` invoked | `~/.claude/skills/review/rules.md` — read by skill |
| Refactoring rules | `/refactor` invoked | `~/.claude/skills/refactor/rules.md` — read by skill |
| Skill management | Creating/editing skills | `~/.claude/conditional-rules/skill-management.md` — read on need |
