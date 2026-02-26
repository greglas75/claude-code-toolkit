---
name: api-audit
description: "Comprehensive API and endpoint integrity audit. Covers validation, payload efficiency, pagination, error handling, caching, auth, rate limiting, and contract consistency. Supports NestJS, Cloudflare Workers, FastAPI/Python, and frontend API call patterns. Use: /api-audit [path] or /api-audit full"
---

# /api-audit -- API & Endpoint Integrity Audit

Standalone skill for auditing how applications expose, consume, and validate data across API boundaries.

**When to use:** Periodic health check of API layer, before major releases, after adding new endpoints, when investigating overfetching/waterfall issues.
**When NOT to use:** Single-file code review (`/review`), refactoring (`/refactor`), feature development (`/build`).

## Mandatory File Reading (NON-NEGOTIABLE)

Before starting ANY work, read ALL files below. Confirm each with [x] or [ ]:

```
1. [x]/[ ]  ~/.codex/rules/code-quality.md         -- CQ1-CQ20 (this audit extends CQ3/5/7/16/19/20)
2. [x]/[ ]  ~/.codex/rules/security.md             -- SSRF, path traversal, auth patterns
3. [x]/[ ]  dimensions.md (skill-internal)           -- D1-D10 scoring rubrics, discovery scripts
4. [x]/[ ]  agent-prompt.md (skill-internal)         -- agent execution template, output format
```

**If ANY file is [ ] -> STOP. Do not proceed with a partial rule set.**

Parse $ARGUMENTS as target scope (directory, module, or "full" for entire project).

---

## Safety Gates (NON-NEGOTIABLE)

### GATE 1 -- Mutation Prevention
**NEVER execute POST, PUT, PATCH, DELETE** against any environment without explicit user confirmation AND sandbox detection. GET and OPTIONS only for live probing.

Before any HTTP request:
1. Check URL -- is it localhost, staging, or production?
2. If production domain detected -> REFUSE (ask user to provide sandbox URL)
3. If staging -> present the full probing plan (list of endpoints + methods), get ONE user approval for the batch, then execute all. Do NOT ask per-request.
4. If localhost/sandbox -> proceed with GET/OPTIONS only

### GATE 2 -- PII & Credential Censorship
When logging API responses, headers, or payloads:
- Replace Bearer tokens: `Bearer ***`
- Replace API keys: `x-api-key: ***`
- Replace emails: `email: ***@***.***`
- Replace passwords: `password: ***`
- Strip AWS signatures, session tokens, cookies

**ALL output files and reports must be scrubbed BEFORE writing.**

### GATE 3 -- Script Execution
Long discovery scripts (>20 lines) MUST be saved to file first, then `chmod +x`, then executed. Never paste long scripts directly into terminal.

---

## CQ Integration

This audit extends (not duplicates) the CQ checklist. Relevant CQ dimensions:

| CQ | API Audit Dimension | Depth |
|----|---------------------|-------|
| CQ3 | D1 (Validation) -- schema completeness across ALL endpoints | Extended |
| CQ5 | D9 (Auth) -- secret exposure in headers/responses | Extended |
| CQ7 | D3 (Pagination) -- query bounds and payload size | Extended |
| CQ16 | D2 (Payload) -- money fields representation consistency cross-endpoint | Extended |
| CQ19 | D1+D2 -- runtime schema on both request AND response | Extended |
| CQ20 | D2 (Payload) -- dual fields in response payloads cross-endpoint | Extended |

**If `/review` already scored these CQs:** Focus on what CQ self-eval misses -- cross-endpoint consistency, client-side waterfall patterns, caching strategy, and system-wide contract drift.

---

## Phase 0: Detection & Scope

### 0.1 Stack Detection

Save as `api_detect.sh`, `chmod +x`, execute:

```bash
#!/bin/bash
set -euo pipefail
SRC="${1:-.}"

echo "=== API STACK DETECTION ==="

# NestJS
NEST_CONTROLLERS=$(find "$SRC" -name "*.controller.ts" 2>/dev/null | wc -l)
NEST_MODULES=$(find "$SRC" -name "*.module.ts" 2>/dev/null | wc -l)
[ "$NEST_CONTROLLERS" -gt 0 ] && echo "NestJS: $NEST_CONTROLLERS controllers, $NEST_MODULES modules"

# Cloudflare Workers
WRANGLER=$(find "$SRC" -name "wrangler.toml" 2>/dev/null | wc -l)
[ "$WRANGLER" -gt 0 ] && echo "Cloudflare Workers: $WRANGLER wrangler configs"

# FastAPI / Python
FASTAPI_ROUTERS=$(grep -rl "APIRouter\|FastAPI()" "$SRC" --include="*.py" 2>/dev/null | wc -l)
[ "$FASTAPI_ROUTERS" -gt 0 ] && echo "FastAPI/Python: $FASTAPI_ROUTERS routers"

# Frontend API calls
REACT_QUERY=$(grep -rl "useQuery\|useMutation\|useInfiniteQuery" "$SRC" --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l)
RAW_FETCH=$(grep -rl "fetch(\|axios\." "$SRC" --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l)
[ "$REACT_QUERY" -gt 0 ] && echo "React Query: $REACT_QUERY files"
[ "$RAW_FETCH" -gt 0 ] && echo "Raw fetch/axios: $RAW_FETCH files"

# Validation libs
ZOD=$(grep -rl "z\.object\|z\.string\|z\.number" "$SRC" --include="*.ts" 2>/dev/null | wc -l)
CLASS_VAL=$(grep -rl "@IsString\|@IsNumber\|@IsNotEmpty\|ValidationPipe" "$SRC" --include="*.ts" 2>/dev/null | wc -l)
PYDANTIC=$(grep -rl "BaseModel\|Field(" "$SRC" --include="*.py" 2>/dev/null | wc -l)
echo "--- Validation: Zod=$ZOD files, ClassValidator=$CLASS_VAL files, Pydantic=$PYDANTIC files"

# Swagger/OpenAPI
SWAGGER=$(grep -rl "@ApiTags\|@ApiResponse\|@ApiProperty" "$SRC" --include="*.ts" 2>/dev/null | wc -l)
[ "$SWAGGER" -gt 0 ] && echo "Swagger decorators: $SWAGGER files"

echo "=== DETECTION COMPLETE ==="
```

### 0.2 Tier Selection

| Tier | When | Dimensions | Probing |
|------|------|-----------|---------|
| LIGHT | Single module, <10 endpoints | D1, D2, D3, D4, D9 | Static only |
| STANDARD | Full service, 10-50 endpoints | D1-D9 (all) | Static + GET probing |
| DEEP | Cross-service, >50 endpoints or pre-release | D1-D10 (all + documentation) | Static + GET probing + response analysis |

**Risk signals that force DEEP tier:**
- Payment/money endpoints detected
- Auth/permission endpoints detected
- Multi-tenant data isolation endpoints
- External API integrations (third-party calls)
- File upload/download endpoints

### 0.3 Endpoint Inventory

Build a complete list before auditing. Per stack:

**NestJS:**
```bash
grep -rn "@Get\|@Post\|@Put\|@Patch\|@Delete\|@All" "$SRC" --include="*.controller.ts" | \
  sed 's/.*@\(Get\|Post\|Put\|Patch\|Delete\|All\)(\(.*\))/\1 \2/' | sort
```

**Cloudflare Workers:**
```bash
grep -rn "request\.method\|url\.pathname\|router\.\(get\|post\|put\|delete\)" "$SRC" --include="*.ts" | head -50
```

**FastAPI:**
```bash
grep -rn "@router\.\(get\|post\|put\|patch\|delete\)\|@app\.\(get\|post\)" "$SRC" --include="*.py" | sort
```

**Frontend API calls:**
```bash
grep -rn "useQuery\|useMutation\|fetch(\|axios\.\(get\|post\|put\|patch\|delete\)" "$SRC" \
  --include="*.ts" --include="*.tsx" | head -80
```

**Inventory completeness check:** Grep-based discovery can miss routes behind:
- Controller/router prefixes (`@Controller('api/v1/offers')`)
- Dynamic route registration (middleware, plugin systems)
- Re-exported routers (barrel files, `RouterModule.forRoutes()`)
- Decorator wrappers (`@CrudController`, custom route factories)

After grep discovery, cross-check against: (1) module imports/exports, (2) Swagger/OpenAPI spec if available, (3) test files hitting endpoints not in inventory.

Output:
```
ENDPOINT INVENTORY
------------------------------
Stack: [detected]
Tier: [LIGHT/STANDARD/DEEP]
Total endpoints: [N]
Risk signals: [list or "none"]
Completeness: [high/medium -- note any gaps]
------------------------------
```

---

## Phase 1: Dimension Analysis (10 Dimensions)

Detailed dimension definitions and scoring in `dimensions.md`.

For EACH dimension, agent evaluates all endpoints in scope and assigns a score:

| # | Dimension | Weight | Max | Critical Gate |
|---|-----------|--------|-----|---------------|
| D1 | Input Validation & Type Safety | 15% | 15 | D1=0 -> auto-fail |
| D2 | Payload Efficiency & Data Contracts | 15% | 15 | -- |
| D3 | Pagination & Unbounded Queries | 12% | 12 | D3<3 AND >10K rows -> auto-fail |
| D4 | Error Handling & Standardization | 12% | 12 | -- |
| D5 | Caching & HTTP Headers | 8% | 8 | -- |
| D6 | HTTP Semantics Correctness | 8% | 8 | -- |
| D7 | N+1 API Waterfall (Client-Side) | 5% | 5 | -- |
| D8 | Rate Limiting & Throttling | 5% | 5 | -- |
| D9 | Authentication & Authorization | 15% | 15 | D9<8 -> auto-fail |
| D10 | Documentation & Contracts (DEEP only) | 5% | 5 | -- |

**Tier-aware scoring:**
- **LIGHT** (D1+D2+D3+D4+D9): max = 69. D5-D8,D10 = N/A.
- **STANDARD** (D1-D9): max = 95. D10 = N/A.
- **DEEP** (D1-D10): max = 100.

**Health grades** (always percentage-based = score/max × 100):
- >= 80%: HEALTHY -- minor improvements possible
- 60-79%: NEEDS ATTENTION -- significant issues to address
- 40-59%: AT RISK -- multiple critical/high issues
- < 40%: CRITICAL -- immediate remediation required

**Critical gate:** D9 < 8 (auth gaps on mutations), D1 = 0 (no validation), D3 < 3 with >10K records, stack traces in production responses -> auto-fail regardless of total.

---

## Phase 1 Execution

Split endpoints into batches by controller/module. Each batch covers one controller/module and all its endpoints.

**If inline analysis is available** (Claude Code):
Spawn parallel agents with the prompt from `agent-prompt.md`:
Perform this analysis inline.

Max 6 parallel agents.

**If inline analysis is NOT available** (Cursor, Codex, other IDEs):
Evaluate each controller/module sequentially inline, following the same `agent-prompt.md` instructions and output format.

---

## Phase 2: GET-Only Probing (STANDARD+ tier)

**Prerequisites:**
1. User confirms target environment (localhost/staging/sandbox)
2. Production domains -> REFUSE
3. Auth token provided by user (never auto-extract from code)

### Probing Protocol

For EACH list endpoint discovered in Phase 0:

```bash
# Health check
curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health"

# Probe list endpoints for payload size
curl -s -w "\n%{size_download} %{http_code} %{time_total}" \
  -H "Authorization: Bearer $TOKEN" \
  "$BASE_URL$ENDPOINT?limit=10"

# Check response headers
curl -s -I -H "Authorization: Bearer $TOKEN" "$BASE_URL$ENDPOINT" | \
  grep -i "cache-control\|etag\|vary\|x-ratelimit\|content-type\|cors"

# Error shape consistency
curl -s "$BASE_URL/nonexistent-endpoint-404-test"
curl -s "$BASE_URL$PROTECTED_ENDPOINT"  # without auth -> should be 401
```

Record per endpoint:
```
| Endpoint | Method | Status | Size | Time | Cache | Issues |
```

**SCRUB ALL RESPONSES** before recording. Apply Gate 2 censorship.

---

## Phase 3: Cross-Cutting Analysis (STANDARD+ tier)

After per-endpoint scoring, analyze system-level patterns:

### 3.1 Contract Consistency
- Same entity returned from different endpoints -- is the shape identical?
- Frontend expects field X, backend returns field Y (contract drift)
- Pagination format consistent across all list endpoints?
- Error shape consistent across all stacks?

### 3.2 Money Field Audit (if applicable)
- List ALL fields with money values across all endpoints
- Verify: same representation (number OR integer-cents, never both)
- Verify: currency always travels with amount (never implicit)
- Flag: `cpi: 40.32` in one endpoint vs `cpi: "5000000 VND"` in another

### 3.3 Auth Matrix
Build endpoint × role matrix:
```
| Endpoint           | Public | User | Admin | Manager | Evidence |
|--------------------|--------|------|-------|---------|----------|
| GET /offers        |        | X    | X     | X       | @UseGuards(AuthGuard) |
| DELETE /offers/:id |        |      | X     |         | @Roles('admin') |
| POST /migrate      | X      |      |       |         | @Public() ← CRITICAL! |
```

### 3.4 Payload Size Analysis (if probing done)
- Flag endpoints returning >100KB for list views
- Flag endpoints returning nested relations >3 levels deep
- Flag dual fields in responses (`*_id` + `*_name` for same entity)

---

## Phase 4: Report

Save to: `audits/api-audit-[date].md`

```markdown
# API & Endpoint Integrity Audit

## Metadata
| Field | Value |
|-------|-------|
| Project | {name} |
| Date | {date} |
| Tier | {LIGHT/STANDARD/DEEP} |
| Stacks | {detected} |
| Total Endpoints | {N} |
| Probing | {Static only / Static + GET on {env}} |

## Score Summary

| Dimension | Score | Max | |
|-----------|-------|-----|---|
| D1. Input Validation | {X} | 15 | |
| D2. Payload Efficiency | {X} | 15 | |
| D3. Pagination | {X} | 12 | |
| D4. Error Standardization | {X} | 12 | |
| D5. Caching & Headers | {X} | 8 | |
| D6. HTTP Semantics | {X} | 8 | |
| D7. API Waterfall | {X} | 5 | |
| D8. Rate Limiting | {X} | 5 | |
| D9. Auth & Authorization | {X} | 15 | |
| D10. Documentation | {X} | 5 | |
| **TOTAL** | **{X}** | **{max: 69/95/100}** | **{grade} ({X/max}%)** |

## Critical Findings
{CRITICAL/HIGH severity -- SCRUBBED of PII}

## All Findings (by dimension)
{Grouped D1-D10, ordered by severity}

## Cross-Cutting Analysis
{Contract consistency, money audit, auth matrix}

## Recommendations (prioritized)
{Top 5 fixes with effort + impact}

## CQ Overlap
{Where this audit found gaps that CQ self-eval missed}
```

### Issue Format

```
### API-{N}: {Short Title}
Dimension: D{X} -- {name}
Severity: CRITICAL / HIGH / MEDIUM / LOW
Confidence: {X}/100
Endpoint: {METHOD} {path}
Stack: {NestJS/Worker/FastAPI/Frontend}
File: `{path}` -> `{handler}()`
Evidence: {code quote or response excerpt, max 15 lines -- SCRUBBED}
Problem: {specific}
Impact: {user/security/performance}
Fix: {complete code for MEDIUM+}
CQ Overlap: {CQ3/CQ5/CQ7/CQ19/CQ20 or "none -- cross-endpoint only"}
```

### Backlog Persistence (MANDATORY)

After audit, persist ALL findings (confidence 26+) to `memory/backlog.md`:
1. Read existing backlog
2. Compute fingerprint per issue: `file_path:dimension:endpoint` (e.g., `src/offer/offer.controller.ts:D1:POST /offers`)
3. Search for matching fingerprint (same file + same dimension + same endpoint) -> increment `Seen` count, keep highest severity
4. New -> append with next `B-{N}` ID, source: `api-audit/{date}`, category: `Code`
5. Confidence 0-25 -> DISCARD (consistent with `/review` rules)

Item format (aligned with `/backlog` template):
```
### B-{N}: D1: missing DTO validation on POST /offers
- **Severity:** HIGH
- **Category:** Code
- **File:** `src/offer/offer.controller.ts` -> `createOffer()`
- **Fingerprint:** `src/offer/offer.controller.ts:D1:POST /offers`
- **Problem:** No runtime validation on request body
- **Fix:** Add @Body(ValidationPipe) dto: CreateOfferDto
- **Source:** api-audit 2026-02-25
- **Seen:** 1x
```

Print summary: `Backlog updated: {N} new items (B-{X}–B-{Y}), {M} duplicates incremented`

### Next-Step Routing

After report and backlog, propose the most impactful next action based on findings:

| Condition | Suggested action |
|-----------|-----------------|
| D1 = 0 (no validation) | `/code-audit [controllers]` -- audit CQ3/CQ19 across all endpoints |
| D9 < 8 (auth gaps) | `/code-audit [controllers]` -- audit CQ4/CQ5 auth defense in depth |
| D3 < 3 AND >10K rows possible | `/refactor [services]` -- add pagination/cursor to unbounded queries |
| D10 < 3 (undocumented endpoints) | `/docs api [path]` -- generate API reference from controller files |
| D1 + D9 both critical | Fix D9 (auth) first -- security before correctness |
| All dimensions >= 8 | No action needed -- consider scheduling next audit in 30 days |

Output the routing suggestion as:
```
RECOMMENDED NEXT ACTION
------------------------------
[condition met] -> [suggested command]
Reason: [1 sentence why this is the highest-impact fix]
------------------------------
```

---

## Execution Notes

- Use **Sonnet** for LIGHT/STANDARD tiers
- Use **Opus** for DEEP tier
- Max 6 parallel agents, one per controller/module
- Always read project CLAUDE.md first for stack-specific conventions
- DEEP tier estimated: ~15-20 min for 50 endpoints
- STANDARD tier estimated: ~8-10 min for 30 endpoints
- LIGHT tier estimated: ~3-5 min for <10 endpoints
