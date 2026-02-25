# Stack Detection (All Projects)

At the start of every session, determine the project's tech stack. This controls which conditional rules apply.

## How to Detect

**Step 1:** Check project CLAUDE.md for a `Tech Stack` section or table. If present, use it as the source of truth.

**Step 2:** If no CLAUDE.md or no stack declaration, auto-detect from config files:

| Signal | Stack |
|--------|-------|
| `tsconfig.json` or `.ts`/`.tsx` files | TypeScript -> apply `typescript.md` |
| `package.json` with `react` in deps | React -> apply `react-nextjs.md` |
| `package.json` with `next` in deps | Next.js -> apply `react-nextjs.md` |
| `pyproject.toml`, `requirements.txt`, `setup.py`, or `.py` files | Python -> apply `python.md` |
| `composer.json` with `yiisoft/yii2` in require | Yii2 -> apply `php-yii2.md` |
| `composer.json` with `yiisoft/yii-*` or `yiisoft/yii` in require | Yii3 -> apply `php-yii2.md` (base PHP rules) |
| `composer.json` with `laravel/framework` in require | Laravel -> apply `php-yii2.md` (base PHP rules) |
| `codeception.yml` or `codeception.yaml` | Codeception test runner |
| `phpunit.xml` or `phpunit.xml.dist` | PHPUnit test runner |
| `vitest.config.*` or `vitest` in devDeps | Vitest (test runner) |
| `jest.config.*` or `jest` in devDeps | Jest (test runner) |
| `wrangler.toml` | Cloudflare Workers |
| `next.config.*` | Next.js |
| `vite.config.*` | Vite |
| `prisma/schema.prisma` | Prisma ORM |

## Conditional Rules

These rules in `~/.cursor/rules/` are stack-dependent -- apply ONLY when stack matches:

| Rule file | Apply when |
|-----------|-----------|
| `typescript.md` | TypeScript detected |
| `react-nextjs.md` | React or Next.js detected |

These rules in `~/.cursor/rules/` ALWAYS apply regardless of stack:

| Rule file | Scope |
|-----------|-------|
| `file-limits.md` | All projects |
| `testing.md` | All projects |
| `code-quality.md` | All projects -- CQ1-CQ20 production code self-eval |
| `security.md` | All projects |
| `task-routing.md` | All projects -- routes tasks to `/build`, `/refactor`, `/review` |

These are loaded ON-DEMAND (not in `~/.cursor/rules/`):

| File | Loaded when | Location |
|------|-------------|----------|
| `python.md` | Python detected | `~/.cursor/conditional-rules/python.md` -- read if Python stack |
| `php-yii2.md` | PHP/Yii2 detected | `~/.cursor/conditional-rules/php-yii2.md` -- read if Yii2/PHP stack |
| `test-patterns-yii2.md` | PHP/Yii2 + writing tests | `~/.cursor/test-patterns-yii2.md` -- Yii2+Codeception pattern library |
| Build workflow | `/build` invoked | `~/.cursor/skills/build/SKILL.md` -- structured feature dev |
| Review rules | `/review` invoked | `~/.cursor/skills/review/rules.md` -- read by skill |
| Review protocol | `/review` invoked | `~/.cursor/review-protocol.md` -- detailed checklists, report templates |
| Refactoring rules | `/refactor` invoked | `~/.cursor/skills/refactor/rules.md` -- read by skill |
| Refactoring protocol | `/refactor` invoked | `~/.cursor/refactoring-protocol.md` -- CONTRACT + ETAP stages |
| Test patterns (core) | `/test-audit`, `/review`, `/refactor`, `/write-tests` | `~/.cursor/test-patterns.md` -- Q1-Q17, lookup table, scoring |
| Test patterns (catalog) | Core lookup routes here | `~/.cursor/test-patterns-catalog.md` -- G-1–G-40, P-1–P-46 |
| Test patterns (Redux) | Code type = REDUX-SLICE | `~/.cursor/test-patterns-redux.md` -- G-41–G-45, P-40, P-41, P-44 |
| Test patterns (NestJS) | Code type = CONTROLLER + NestJS | `~/.cursor/test-patterns-nestjs.md` -- G-33–G-34, NestJS-G1–G2, NestJS-AP1, NestJS-P1–P3, security S1-S7, templates |
| Code audit | `/code-audit` invoked | `~/.cursor/skills/code-audit/SKILL.md` -- CQ1-CQ20 mass audit |
| Test audit | `/test-audit` invoked | `~/.cursor/skills/test-audit/SKILL.md` -- Q1-Q17 mass audit |
| Write tests | `/write-tests` invoked | `~/.cursor/skills/write-tests/SKILL.md` -- coverage scanner + pattern selector + Q1-Q17 gates |
| API audit | `/api-audit` invoked | `~/.cursor/skills/api-audit/SKILL.md` -- endpoint integrity |
| Backlog management | `/backlog` invoked | `~/.cursor/skills/backlog/SKILL.md` -- tech debt tracking |
| Refactoring examples | `/refactor` invoked (stack-specific) | `~/.cursor/refactoring-examples/{stack}.md` -- test patterns per stack |
| God class protocol | `/refactor` GOD_CLASS detected | `~/.cursor/refactoring-god-class.md` -- extended splitting protocol |
| Skill management | Creating/editing skills | `~/.cursor/conditional-rules/skill-management.md` -- read on need |
