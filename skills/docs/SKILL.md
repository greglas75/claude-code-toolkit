---
name: docs
description: "Write and update technical documentation. Use after /build (README for new module), after /refactor (update API docs), after /api-audit (generate endpoint reference), or when documentation is missing/outdated. Trigger with 'write docs', 'create README', 'document this API', 'write a runbook', 'update docs'."
user-invocable: true
---

# /docs — Technical Documentation

Generates or updates documentation by reading the actual codebase — not from templates, from real code.

**Never write docs from memory.** Always read the source files first.

## Parse $ARGUMENTS

| Input | Action |
|-------|--------|
| _(empty)_ | Ask: "What do you need documented? (readme / api / runbook / onboarding)" |
| `readme [path]` | Write or update README for the module/service at [path] |
| `api [path]` | Generate API reference from route/controller files at [path] |
| `runbook [topic]` | Write operational runbook for a specific process |
| `onboarding` | Write onboarding guide for new developers |
| `update [file]` | Read existing doc + source code, update stale sections (see Update Mode below) |

---

## Mode: Update (Staleness Check)

When `update [file]` is invoked, follow this strict procedure — **never rewrite from scratch**.

### Step 1: Read existing doc
Read the full file. Extract every factual claim as a checklist item:
- Commands (`npm install`, `docker-compose up`, etc.)
- File paths (`src/features/`, `prisma/schema.prisma`)
- Env var names and defaults
- API endpoints, request/response shapes
- Architecture descriptions (what connects to what)

### Step 2: Verify each claim against source
For each extracted claim, read the source file it references:

| Claim type | Where to verify |
|------------|----------------|
| Shell commands | `package.json` scripts, `Makefile`, `pyproject.toml`, CI config |
| File paths | `ls` / `Glob` — does the path still exist? |
| Env vars | `.env.example`, config loader file |
| API endpoints | Route/controller files — path, method, auth, params |
| Architecture | Import graph, docker-compose, infrastructure config |

Mark each claim: ✅ still true, ❌ stale, ❓ cannot verify (source missing).

### Step 3: Patch only stale sections
- **✅ claims** → leave unchanged (preserve original wording)
- **❌ claims** → update with correct information from source
- **❓ claims** → add `<!-- TODO: verify — source not found -->` comment
- **Missing info** → add new sections only if source code reveals undocumented features

### Step 4: Output a change summary
```
Update summary for [file]:
  ✅ [N] sections unchanged
  ❌ [N] sections updated: [list section names]
  ❓ [N] sections unverifiable: [list section names]
  + [N] new sections added: [list section names]
```

**Rule:** If ≤2 claims are stale → patch in place. If >50% of claims are stale → suggest full rewrite with `readme [path]` instead.

---

## Mandatory Reading (before writing ANYTHING)

For every doc type, read the relevant source files first:

| Doc Type | Files to read before writing |
|----------|------------------------------|
| README | `package.json`/`pyproject.toml`, main entry point, existing `README.md` (if any) |
| API docs | Route/controller files, DTO/schema files, auth guard files |
| Runbook | The code/service being operated, existing runbooks in `docs/` |
| Onboarding | `package.json`, `docker-compose.yml`, CI config, existing onboarding docs |

---

## Stack-Aware Commands (MANDATORY)

Before writing any doc with shell commands, detect the project's package manager and tooling. **Never hardcode `npm` — use what the project actually uses.**

| Signal | Install | Run dev | Run tests | Build |
|--------|---------|---------|-----------|-------|
| `pnpm-lock.yaml` | `pnpm install` | `pnpm dev` | `pnpm test` | `pnpm build` |
| `yarn.lock` | `yarn` | `yarn dev` | `yarn test` | `yarn build` |
| `bun.lockb` | `bun install` | `bun dev` | `bun test` | `bun run build` |
| `package-lock.json` | `npm install` | `npm run dev` | `npm test` | `npm run build` |
| `pyproject.toml` (poetry) | `poetry install` | `poetry run python manage.py runserver` | `poetry run pytest` | `poetry build` |
| `requirements.txt` | `pip install -r requirements.txt` | `python manage.py runserver` | `pytest` | — |
| `go.mod` | `go mod download` | `go run .` | `go test ./...` | `go build` |
| `Makefile` | Check `make install` target | Check `make dev`/`make run` target | Check `make test` target | Check `make build` target |
| `Cargo.toml` | `cargo build` | `cargo run` | `cargo test` | `cargo build --release` |
| `composer.json` | `composer install` | `php artisan serve` / `php yii serve` | `vendor/bin/phpunit` / `vendor/bin/codecept run` | — |

**Detection order:** lockfile → config file → Makefile → fallback to asking user.

If commands come from `package.json` scripts or `Makefile` targets — use the **exact script name** (e.g. `pnpm run dev:local`, not `pnpm dev`).

---

## Doc Type: README

### When to use
- After `/build` creates a new service, package, or module
- When `README.md` doesn't exist or is outdated
- When onboarding a new developer takes >30 min to get running

### What to read first
```bash
# Read these before writing:
cat package.json | jq '{name, description, scripts}'  # or pyproject.toml / Makefile
ls src/ app/ 2>/dev/null   # understand structure
cat .env.example           # document required config
cat docker-compose.yml     # if applicable
```

### Output format
```markdown
# [Service/Package Name]

> [One sentence — what is this and why does it exist?]

## Quick Start

```bash
# Minimum steps to get it running locally:
[INSTALL_CMD]                   # ← from Stack-Aware Commands table
cp .env.example .env            # fill in required values
[DEV_CMD]                       # ← from Stack-Aware Commands table
# → runs at http://localhost:[PORT]
```

## Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| DATABASE_URL | yes | — | PostgreSQL connection string |
| JWT_SECRET | yes | — | Secret for signing JWT tokens |
| PORT | no | 3000 | HTTP server port |

## Development

```bash
[DEV_CMD]        # start with hot reload
[TEST_CMD]       # run test suite
[LINT_CMD]       # lint + type check   ← from package.json scripts / Makefile
[BUILD_CMD]      # production build
```

## Project Structure

```
src/
  features/      # domain modules (one folder per domain)
  shared/        # utilities, types, middleware
  main.ts        # entry point
```

## API

[Link to API docs or brief summary. Full reference: `docs/api.md`]

## Contributing

1. Branch from `main`
2. Write tests for new code (see `CONTRIBUTING.md`)
3. PR requires 1 approval + CI green
```

### Quality checklist (before output)
- [ ] Quick start works in <5 commands
- [ ] All required env vars documented
- [ ] Commands match actual scripts in `package.json` / `Makefile` / `pyproject.toml` (see Command Validation Gate)
- [ ] No copy-paste from a template — everything is project-specific

---

## Doc Type: API Reference

### When to use
- After `/build` adds new endpoints
- After `/api-audit` identifies undocumented endpoints
- When frontend team asks "what does this endpoint return?"

### What to read first
All route/controller files in scope. For each endpoint, read:
- Route decorator / path definition
- Auth guard (what role is required?)
- DTO / request schema (required fields, types, validation)
- Service method (what does it return? what errors can it throw?)

### Output format
```markdown
# API Reference — [Service Name]

**Base URL:** `/api/v1`
**Auth:** Bearer token in `Authorization` header (except where noted)

---

## [Resource Name]

### GET /[resource]

List [resources] for the authenticated user's organization.

**Auth:** Required (role: `member` or above)

**Query Parameters**

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| page | number | no | Page number (default: 1) |
| limit | number | no | Items per page (default: 20, max: 100) |
| status | string | no | Filter by status: `draft`, `active`, `archived` |

**Response 200**
```json
{
  "items": [
    {
      "id": "uuid",
      "title": "string",
      "status": "draft | active | archived",
      "createdAt": "ISO 8601",
      "updatedAt": "ISO 8601"
    }
  ],
  "total": 42,
  "page": 1,
  "limit": 20
}
```

**Errors**
| Code | When |
|------|------|
| 401 | Missing or invalid token |
| 403 | Insufficient role |

---

### POST /[resource]

Create a new [resource].

**Auth:** Required (role: `admin` or above)

**Request Body**
```json
{
  "title": "string (required, max 200 chars)",
  "description": "string (optional)"
}
```

**Response 201** — created [resource] object (same shape as GET item)

**Errors**
| Code | When |
|------|------|
| 400 | Validation error — missing required field or invalid format |
| 401 | Missing or invalid token |
| 403 | Insufficient role |
| 409 | [Resource] with this title already exists in your org |
```

### Quality checklist
- [ ] Every endpoint has auth requirement noted
- [ ] All request fields documented with types and required/optional
- [ ] All meaningful error codes listed (not just 200)
- [ ] Response examples are real shapes from the code (not invented)

---

## Doc Type: Runbook

### When to use
- For any operation that requires >3 steps to execute safely
- For incident response steps (restart service, roll back, migrate DB)
- For recurring operational tasks (deploy, scale up, rotate secrets)

### Output format
```markdown
# Runbook: [Operation Name]

**When to use this:** [Specific trigger condition — "When the queue depth exceeds 10k" or "When deploying a DB migration"]
**Time required:** ~[N] minutes
**Who can run this:** [Role — e.g., "Any engineer with production access"]
**Risk level:** Low / Medium / High

## Prerequisites

- [ ] Access to [system] (request via [link/process])
- [ ] [Tool] installed and configured
- [ ] [Other requirement]

## Steps

### 1. [Step name]

[What to do and why]

```bash
# Command with explanation
kubectl rollout restart deployment/[service-name] -n production
```

**Expected output:** `deployment.apps/[service-name] restarted`
**If it fails:** [What to check / who to contact]

### 2. [Next step]

[...]

## Verification

After completing steps, verify success:

```bash
# Verification command
kubectl get pods -n production | grep [service-name]
```

Expected: all pods in `Running` state, `READY` column shows `1/1`.

## Rollback

If something goes wrong:

```bash
# Rollback command
kubectl rollout undo deployment/[service-name] -n production
```

## Escalation

If rollback doesn't resolve the issue → contact [person/team] via [channel].
```

---

## Doc Type: Onboarding Guide

### When to use
- When a new developer is joining the team
- When "getting up to speed" consistently takes >1 day
- When tribal knowledge is not written down anywhere

### What to read first
Entire project structure: root config files, CI config, `docker-compose.yml`, key service files.

### Output format
```markdown
# Developer Onboarding — [Project/Team Name]

**Time to first working local environment:** ~[N] minutes
**Time to first PR merged:** ~[N] days

## Environment Setup

### 1. Prerequisites

Install these first:
- [Runtime] [version] (e.g. Node.js via nvm, Python via pyenv, Go, Rust)
- Docker Desktop (if services use containers)
- [Other tools]

### 2. Clone and Install

```bash
git clone [repo-url]
cd [project]
[INSTALL_CMD]                   # ← from Stack-Aware Commands table
cp .env.example .env            # then fill in the values below
```

### 3. Required Config (`.env`)

| Variable | Where to get it |
|----------|----------------|
| DATABASE_URL | Ask [person] or check [location] |
| API_KEY | Generate at [url] |
| JWT_SECRET | Any random string for local dev |

### 4. Start the App

```bash
docker-compose up -d   # start Postgres + Redis (if applicable)
[DEV_CMD]              # ← from Stack-Aware Commands table
```

→ App runs at http://localhost:3000
→ API docs at http://localhost:3000/docs (if Swagger enabled)

## Key Systems

| System | What it does | Where the code lives |
|--------|-------------|---------------------|
| [Service A] | [Purpose] | `apps/api/` |
| [Service B] | [Purpose] | `apps/web/` |
| [Database] | [What's stored] | `prisma/schema.prisma` |

## Common Tasks

### Run tests
```bash
[TEST_CMD]                  # all tests
[TEST_CMD] -- --watch       # watch mode (if supported)
[TEST_CMD] [path]           # single file
```

### Add a new API endpoint
[Link to CONTRIBUTING.md or brief steps]

### Deploy to staging
[Link to deploy runbook or brief steps]

## Who to Ask

| Topic | Person | Channel |
|-------|--------|---------|
| Architecture decisions | [Name] | #engineering |
| DevOps / infrastructure | [Name] | #devops |
| Product questions | [Name] | #product |
```

---

## Integration with Other Skills

| After running... | Consider running |
|-----------------|-----------------|
| `/build` (new module) | `/docs readme [path]` — write README for the new module |
| `/build` (new endpoints) | `/docs api [path]` — document the new endpoints |
| `/refactor` (changed API) | `/docs update [api-doc-path]` — update existing docs |
| `/api-audit` | `/docs api [path]` — generate reference for undocumented endpoints |
| New team member joining | `/docs onboarding` — generate onboarding guide |

---

## Evidence Map (MANDATORY)

Every doc output must include an Evidence Map — a hidden comment or appendix that traces each section to its source.

**Purpose:** Prevents hallucination. If you can't point to a source file, you can't write the claim.

### Format (append to generated doc as HTML comment)

```markdown
<!-- Evidence Map
| Section | Source file(s) |
|---------|---------------|
| Quick Start | package.json:scripts (line 5-12) |
| Configuration | .env.example (line 1-15), src/config/env.ts:3-20 |
| API: GET /users | src/routes/users.controller.ts:24-45 |
| Project Structure | ls src/ (verified directory listing) |
| Deploy steps | .github/workflows/deploy.yml:18-42 |
-->
```

### Rules
- Every section with factual claims → must have ≥1 source entry
- Commands → source is the script definition file (`package.json`, `Makefile`, CI config)
- If a section has no source → mark it `<!-- TODO: needs source verification -->`
- Evidence Map is included in the output file but hidden from readers (HTML comment)

---

## Command Validation Gate (before finalizing)

After writing any doc that contains shell commands, validate they actually exist:

1. **Extract** all `bash` code blocks from the generated doc
2. **Check** each command against its source:
   - `package.json` → does the script name exist in `"scripts": {}`?
   - `Makefile` → does the target exist?
   - `pyproject.toml` → does the script exist in `[tool.poetry.scripts]` or `[project.scripts]`?
   - `docker-compose.yml` → do the referenced services exist?
   - CI config → do the referenced jobs/steps exist?
3. **Flag** any command that doesn't match a real script/target:
   ```
   ⚠ Command validation:
     ✅ pnpm dev → matches package.json scripts.dev
     ✅ pnpm test → matches package.json scripts.test
     ❌ pnpm run lint → no "lint" in package.json scripts (found "lint:check" instead)
     Fix: replace with `pnpm run lint:check`
   ```
4. **Fix** all ❌ items before outputting the doc

---

## Output Paths

### Default output locations

| Doc type | Default path | Flag override |
|----------|-------------|---------------|
| `readme` | `[target-path]/README.md` | `--out [path]` |
| `api` | `docs/api/[service-name].md` | `--out [path]` |
| `runbook` | `docs/runbooks/[topic].md` | `--out [path]` |
| `onboarding` | `docs/onboarding.md` | `--out [path]` |

### Path resolution
- `readme [path]` → writes `README.md` inside `[path]` (e.g. `readme apps/api` → `apps/api/README.md`)
- `readme` (no path) → writes `./README.md` (project root)
- `api [path]` → `docs/api/` with service name derived from `[path]`
- If `docs/` doesn't exist → create it
- If target file exists → ask before overwriting (unless `update` mode)

---

## Principles

1. **Read the code, write the docs** — never invent. Every claim in the docs must be verifiable in the source (see Evidence Map).
2. **Write for the reader** — README is for a developer who just found the repo. API docs are for someone building a client. Runbook is for someone at 2am.
3. **Start with the most useful information** — Quick Start before architecture details. Copy-paste command before explanation.
4. **Stale docs are worse than no docs** — Mark what you're unsure about. Add `TODO: verify this` rather than leaving incorrect information.
