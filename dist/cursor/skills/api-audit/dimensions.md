# API Audit Dimensions -- Detailed Scoring Criteria

Reference file for `/api-audit` agents. Contains per-dimension checks, scoring rubrics, discovery scripts, and stack-specific patterns.

---

## D1 -- Input Validation & Type Safety (Weight: 15/100)

For EACH endpoint/handler, verify:

| Check | Good | Bad | Severity |
|-------|------|-----|----------|
| Schema validation at edge | Zod/ClassValidator/Pydantic on route handler | Manual `if (!body.name)` checks | HIGH |
| Param validation | `@Param('id', ParseUUIDPipe)` or Zod coerce | `req.params.id` used as-is (string treated as number) | MEDIUM |
| Body completeness | All fields in schema, no extra fields allowed | Partial schema (some fields unchecked) | HIGH |
| Query param validation | Validated + coerced (string->number, enum check) | Raw `req.query.page` used directly | MEDIUM |
| File upload validation | MIME type + size limit + extension allowlist | Accept anything | CRITICAL |

**Stack-specific patterns:**

| Stack | Good | Bad |
|-------|------|-----|
| **NestJS** | `@Body(ValidationPipe) dto: CreateOfferDto` + class-validator decorators | `@Body() body: any` or `@Body() body: CreateOfferDto` without ValidationPipe |
| **Workers** | Zod `.parse(await request.json())` in handler | `const body = await request.json() as ProjectPayload` (no runtime check) |
| **FastAPI** | Pydantic model as parameter type (auto-validated) | `request.json()` then manual checks |
| **Frontend** | Zod on API response before state update | `const data = await res.json()` then `data.items.map(...)` |

**Scoring:**
- 15: All endpoints have runtime schema validation (request + response)
- 12: Most endpoints validated, gaps on query params or responses
- 8: Validation exists but inconsistent across endpoints
- 4: Mostly manual validation or `as Type` casts
- 0: No validation library, raw body access everywhere

---

## D2 -- Payload Efficiency & Data Contracts (Weight: 15/100)

| Check | Good | Bad | Severity |
|-------|------|-----|----------|
| Response shape | Explicit DTO/serializer | Raw ORM entity with all relations | HIGH |
| Internal field leakage | No `password_hash`, `deleted_at`, `internal_notes` | DB columns exposed directly | CRITICAL (if sensitive) |
| Payload size | <100KB for list endpoints, <500KB for detail | >1MB JSON responses | MEDIUM |
| Nested depth | Max 3 levels, flattened where possible | 5+ nested levels, circular refs | LOW |
| Dual field exposure | Single canonical field + computed display | Both `country_id` AND `country_name` stored independently | MEDIUM |
| Money representation | Consistent format across all endpoints | `cpi: 40.32` in one, `cpi: "5000000 VND"` in another | HIGH |

**Discovery:**
```bash
# Find endpoints returning raw ORM entities (no DTO/serializer)
grep -rn "return.*findMany\|return.*findOne\|return.*find(" "$SRC" --include="*.service.ts" | head -20

# Find select/exclude patterns (good -- slim payload)
grep -rn "select:\|exclude:\|@Exclude()\|@Expose()" "$SRC" --include="*.ts" | head -20
```

**Scoring:**
- 15: Explicit DTOs, no leakage, consistent money format, no dual fields
- 12: DTOs exist but some endpoints expose raw entities
- 8: Mixed -- some endpoints slim, others return full ORM objects
- 4: Most endpoints return raw entities, some internal fields leak
- 0: `SELECT *` returned directly, sensitive fields exposed

---

## D3 -- Pagination & Unbounded Queries (Weight: 12/100)

| Check | Good | Bad | Severity |
|-------|------|-----|----------|
| List endpoints have LIMIT | `take: limit` or `LIMIT 100` | `findMany()` without limit | CRITICAL |
| Max limit enforced | `Math.min(requestedLimit, 100)` | Client can request `?limit=999999` | HIGH |
| Pagination type | Cursor-based for large/real-time datasets | Offset-only (skip+take) for >10K rows | MEDIUM |
| Empty result handled | `{ data: [], total: 0, hasNext: false }` | `null` or `undefined` on empty | LOW |
| Count query optimization | `COUNT(*)` cached or estimated | `findMany()` then `.length` for total | MEDIUM |

**Discovery:**
```bash
# Find unbound queries
grep -rn "\.findMany(\s*{" "$SRC" --include="*.ts" | grep -v "take:" | head -20
grep -rn "\.find(\s*{" "$SRC" --include="*.ts" | grep -v "limit:" | head -20
grep -rn "\.all()" "$SRC" --include="*.py" | head -20
```

**Scoring:**
- 12: All list endpoints paginated, max limit enforced, cursor-based where needed
- 9: Paginated but offset-only, no max limit enforcement
- 6: Some endpoints paginated, others return all
- 3: Pagination exists but client can bypass limits
- 0: No pagination anywhere

---

## D4 -- Error Handling & Standardization (Weight: 12/100)

| Check | Good | Bad | Severity |
|-------|------|-----|----------|
| Consistent error shape | Same JSON shape from all endpoints | Different shapes per controller | HIGH |
| Global error handler | ExceptionFilter / middleware / exception handler | Manual try/catch in every route | MEDIUM |
| No stack traces in prod | Generic message to client, full stack to logs | `res.status(500).json({ error: err.stack })` | CRITICAL |
| HTTP status correctness | 400 validation, 401 authn, 403 authz, 404 not found | `200 OK` with `{ error: true }` | HIGH |
| Correlation ID | Request ID in error response for debugging | Just "Something went wrong" | LOW |

**Discovery:**
```bash
# Manual 500 responses (bypassing global handler)
grep -rn "res\.status(500)\|\.status(500)" "$SRC" --include="*.ts" | head -10

# Stack trace exposure
grep -rn "err\.stack\|error\.stack\|traceback" "$SRC" --include="*.ts" --include="*.py" | head -10

# 200 OK with error body
grep -rn "status(200).*error\|success.*false" "$SRC" --include="*.ts" | head -10
```

**Scoring:**
- 12: Global handler, consistent shape, no stack traces, correct HTTP codes
- 9: Global handler exists but some controllers bypass it
- 6: Inconsistent shapes, some stack trace leaks
- 3: No global handler, manual handling per route
- 0: Stack traces in responses, 200 for errors

---

## D5 -- Caching & HTTP Headers (Weight: 8/100)

| Check | Good | Bad | Severity |
|-------|------|-----|----------|
| Cache-Control on GETs | `max-age=3600` for slow-changing data | Every GET hits DB dynamically | MEDIUM |
| ETag / Last-Modified | Conditional GET for large payloads | Full response every time | LOW |
| CORS configuration | Explicit allowed origins | `Access-Control-Allow-Origin: *` in production | HIGH |
| Vary header | `Vary: Authorization` for user-specific responses | Missing Vary on auth-dependent GETs | MEDIUM |

**Slow-changing data candidates (should be cached):**
- Country lists, language lists, currency lists
- Configuration/settings endpoints
- Pricing tables, base rates
- Permission/role definitions, enum values

**Scoring:**
- 8: Cache strategy defined, headers present, CORS locked down
- 6: Some caching but no consistent strategy
- 4: No caching, CORS too permissive
- 2: No cache headers at all
- 0: `*` CORS in production + no caching

---

## D6 -- HTTP Semantics Correctness (Weight: 8/100)

| Check | Good | Bad | Severity |
|-------|------|-----|----------|
| POST for creation | Returns `201 Created` | Returns `200 OK` | LOW |
| DELETE response | `204 No Content` or `200` with entity | `200` with `{ success: true }` | LOW |
| GET is idempotent | No side effects on GET | GET triggers mutation | CRITICAL |
| Method correctness | Proper verbs per operation | POST used for everything | MEDIUM |
| Bulk operations | Batch endpoint for N items | Client loops POST per item | MEDIUM |

**Scoring:**
- 8: Correct methods, proper status codes, idempotent GETs
- 6: Mostly correct, minor status code mismatches
- 4: Some wrong methods
- 2: POST used for reads, GET has side effects
- 0: No semantic correctness

---

## D7 -- N+1 API Waterfall (Client-Side) (Weight: 5/100)

Analyze frontend code for sequential API calls where aggregation endpoint would be better.

```typescript
// BAD -- client waterfall (N+1)
const offers = await api.get('/offers');
for (const offer of offers.data) {
  const markets = await api.get(`/offers/${offer.id}/markets`);  // N calls!
}

// GOOD -- aggregated endpoint or include param
const offers = await api.get('/offers?include=markets,services');
```

**Discovery:**
```bash
# Multiple useQuery in same component (potential waterfall)
for f in $(find "$SRC" -name "*.tsx" -o -name "*.ts"); do
  COUNT=$(grep -c "useQuery\|useSuspenseQuery" "$f" 2>/dev/null || true)
  [ "$COUNT" -gt 3 ] && echo "$f: $COUNT queries"
done

# Sequential API calls in loops
grep -rn "for.*of\|\.forEach\|\.map" "$SRC" --include="*.tsx" -A5 | \
  grep -B3 "api\.\|fetch(" | head -30
```

**Scoring:**
- 5: Aggregation endpoints exist, no client-side waterfalls
- 4: Minor waterfalls on non-critical pages
- 3: Some waterfalls but with caching mitigation
- 1: Significant waterfalls causing visible latency
- 0: Client makes 10+ sequential calls to render one page

---

## D8 -- Rate Limiting & Throttling (Weight: 5/100)

| Check | Good | Bad | Severity |
|-------|------|-----|----------|
| Expensive endpoints throttled | Rate limiter on AI/LLM, export, bulk ops | No rate limiting | HIGH |
| Auth endpoints protected | Brute-force protection on login/reset | Unlimited login attempts | CRITICAL |
| Per-user vs global | Per-user limits for fair sharing | Global only | MEDIUM |
| Retry-After header | `429` with `Retry-After` | Silent drop or `500` | LOW |

**Discovery:**
```bash
# Find rate limiting
grep -rn "RateLimiter\|Throttle\|ThrottlerGuard\|rateLimit" "$SRC" --include="*.ts" --include="*.py" | head -10

# Find expensive endpoints WITHOUT rate limiting
grep -rn "chatgpt\|openai\|export\|download\|bulk\|import\|migrate" "$SRC" --include="*.controller.ts" | head -10
```

**Scoring:**
- 5: All expensive endpoints throttled, per-user limits, proper 429
- 4: Some throttling but inconsistent
- 2: Only on one or two endpoints
- 0: No rate limiting at all

---

## D9 -- Authentication & Authorization Integrity (Weight: 15/100)

API-level security audit. Covers CQ4 (defense in depth) and CQ5 (secret exposure) from API surface perspective.

| Check | Good | Bad | Severity |
|-------|------|-----|----------|
| Auth on all mutations | Every POST/PUT/PATCH/DELETE requires auth | `@Public()` on mutation | CRITICAL |
| Authorization granularity | Role/permission check per endpoint | Any logged-in user can do anything | CRITICAL |
| Tenant isolation | Query-level filtering by org/workspace ID | Auth guard only, no query filter | CRITICAL |
| Token exposure | Tokens in headers only | `?token=xxx` in query string | HIGH |
| Public endpoint inventory | Explicit, justified list | Unknown which are public | HIGH |

**NestJS:**
```bash
# ALL @Public() endpoints
grep -rn "@Public()" "$SRC" --include="*.controller.ts" -B2 -A5 | head -40

# Mutation endpoints without guards
grep -rn "@Post\|@Put\|@Patch\|@Delete" "$SRC" --include="*.controller.ts" -B5 | \
  grep -v "Guard\|@UseGuards\|@Roles" | head -20
```

**FastAPI:**
```bash
grep -rn "@router\.\(post\|put\|patch\|delete\)" "$SRC" --include="*.py" -A5 | \
  grep -v "Depends.*current_user\|Depends.*auth" | head -20
```

**Scoring:**
- 15: Auth on all mutations, role-based authz, tenant isolation with query filters
- 12: Auth present but some endpoints lack authorization (auth != authz)
- 8: Most endpoints protected, gaps in tenant isolation
- 4: Basic auth only, no role checks, some public mutations
- 0: Public mutations, no tenant isolation, tokens in URLs

---

## D10 -- API Documentation & Contracts (Weight: 5/100, DEEP tier only)

| Check | Good | Bad | Severity |
|-------|------|-----|----------|
| Auto-generated docs | Swagger from decorators | Confluence-only | MEDIUM |
| Response examples | Real examples in docs | Just type definitions | LOW |
| Versioning strategy | `/v1/`, `/v2/` or header-based | No versioning | HIGH |
| Deprecation notices | `@Deprecated` with migration guide | Endpoints silently removed | HIGH |

**Scoring:**
- 5: Auto-generated docs, versioning, deprecation strategy
- 3: Some documentation exists but gaps
- 1: Only informal documentation
- 0: No documentation at all

---

## Stack-Specific Red Flags (Quick Reference)

### NestJS
- `@Public()` on `@Post`/`@Put`/`@Patch`/`@Delete` endpoints
- `@Body() body: any` without ValidationPipe
- Controller methods >20 lines (business logic in controller)
- `findMany()` without `take` in service called by list endpoint
- `res.status(500).json()` bypassing global ExceptionFilter

### Cloudflare Workers
- `request.json() as Type` without runtime validation
- No auth check in `fetch()` handler
- `Response.json(data)` exposing internal fields
- No rate limiting on expensive operations
- Inconsistent error response shapes

### FastAPI
- `request.json()` instead of Pydantic model parameter
- Missing `Depends(get_current_user)` on mutation routes
- `db.query(Model).all()` without `.limit()`
- `HTTPException(500, detail=str(e))` leaking stack traces
- No `RateLimiter` on AI/LLM/export endpoints

### Frontend API Calls
- `fetch()` + `setState()` when project uses React Query
- `await res.json()` without response shape validation
- Sequential `useQuery` calls that could be aggregated
- Missing error handling (no `.catch()`, no `onError`)
- Optimistic updates without rollback on API failure
