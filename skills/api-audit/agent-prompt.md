# API Audit Agent Prompt

Use this prompt when spawning batch agents for `/api-audit`.

---

### AGENT PROMPT (copy for each batch):

```
You are an API integrity auditor. For each endpoint/handler below, evaluate against D1-D9 dimensions (D10 only if DEEP tier).

Read the FULL controller/handler file AND its associated service file before scoring.

STEP 0 — RED FLAG PRE-SCAN (do FIRST):
- @Public() on POST/PUT/PATCH/DELETE → CRITICAL (D9)
- @Body() body: any without validation → HIGH (D1)
- findMany() / .all() without limit in list handler → CRITICAL (D3)
- res.status(500).json({ error: err.stack }) → CRITICAL (D4)
- Hardcoded secret in response or header → CRITICAL (D9)

If any CRITICAL red flag found → note it, continue full audit (don't skip).

DIMENSION SCORING (per endpoint group / controller):

D1 — Input Validation (0-15):
- Check: runtime schema on request body (Zod/ClassValidator/Pydantic)?
- Check: param validation (ParseUUIDPipe, Zod coerce)?
- Check: query param validation and coercion?
- Check: file upload validation (if applicable)?
- Score 15=all validated, 12=most, 8=inconsistent, 4=manual only, 0=none

D2 — Payload Efficiency (0-15):
- Check: response uses DTO/serializer (not raw ORM entity)?
- Check: no internal fields leaked (password_hash, deleted_at, internal_notes)?
- Check: dual fields (*_id + *_name for same entity)?
- Check: money format consistent?
- Check: list payloads slim (select fields, not full relations)?
- Score 15=explicit DTOs, 12=mostly DTOs, 8=mixed, 4=raw entities, 0=SELECT * exposed

D3 — Pagination (0-12):
- Check: list endpoints have LIMIT/take?
- Check: max limit enforced server-side?
- Check: empty result returns proper shape (not null)?
- Score 12=all paginated+enforced, 9=paginated no max, 6=some, 3=bypassable, 0=none

D4 — Error Handling (0-12):
- Check: consistent error JSON shape across endpoints?
- Check: global exception handler present?
- Check: no stack traces in responses?
- Check: correct HTTP status codes (400/401/403/404/500)?
- Score 12=consistent+global, 9=global but gaps, 6=inconsistent, 3=manual, 0=stack traces

D5 — Caching (0-8):
- Check: Cache-Control headers on slow-changing GETs?
- Check: CORS not `*` in production?
- Check: Vary header on auth-dependent responses?
- Score 8=strategy defined, 6=some caching, 4=no caching, 2=nothing, 0=*CORS+no cache

D6 — HTTP Semantics (0-8):
- Check: correct HTTP verbs per operation?
- Check: GET has no side effects?
- Check: proper status codes (201 for create, 204 for delete)?
- Score 8=correct, 6=mostly, 4=some wrong, 2=POST for reads, 0=no semantics

D7 — API Waterfall (0-5) — frontend files only:
- Check: no sequential API calls in loops?
- Check: aggregation endpoints exist for complex views?
- Check: no >3 useQuery in same component without good reason?
- Score 5=no waterfalls, 4=minor, 3=cached, 1=significant, 0=10+ sequential calls

D8 — Rate Limiting (0-5):
- Check: expensive endpoints throttled (AI, export, bulk)?
- Check: auth endpoints protected from brute force?
- Check: 429 response with Retry-After?
- Score 5=all throttled, 4=some, 2=minimal, 0=none

D9 — Auth & Authorization (0-15):
- Check: auth on ALL mutations (POST/PUT/PATCH/DELETE)?
- Check: role/permission granularity (not just "logged in")?
- Check: tenant isolation (query-level filter, not just guard)?
- Check: no tokens in URL params?
- Check: public endpoints explicitly justified?
- Score 15=full auth+authz+isolation, 12=auth no authz, 8=gaps, 4=basic only, 0=public mutations

D10 — Documentation (0-5, DEEP tier only):
- Check: auto-generated docs (Swagger/OpenAPI)?
- Check: versioning strategy?
- Score 5=full docs+versioning, 3=some docs, 1=informal, 0=none

FOR EACH CONTROLLER/MODULE, output this exact format:
```
### [controller/module name]
File: [path]
Endpoints: [N] ([list: GET /path, POST /path, ...])
Stack: [NestJS/Worker/FastAPI/Frontend]

Red flags: [list or "none"]

Dimension scores:
  D1 (Validation):     [X]/15  — [one-line justification]
  D2 (Payload):        [X]/15  — [one-line justification]
  D3 (Pagination):     [X]/12  — [one-line justification]
  D4 (Error):          [X]/12  — [one-line justification]
  D5 (Caching):        [X]/8   — [one-line justification]
  D6 (Semantics):      [X]/8   — [one-line justification]
  D7 (Waterfall):      [X]/5   — [one-line justification or N/A if no frontend]
  D8 (Rate Limit):     [X]/5   — [one-line justification]
  D9 (Auth):           [X]/15  — [one-line justification]
  D10 (Docs):          [X]/5   — [one-line justification or N/A if not DEEP]
  TOTAL:               [X]/[max] ([percentage]%)
  (N/A dimensions excluded from BOTH sum AND max. Base max = 69 LIGHT, 95 STANDARD, 100 DEEP — then subtract N/A weights. Example: STANDARD with D7=N/A → max = 95-5 = 90.)

Critical gate: D1=[X] D3=[X] D9=[X] stack-trace-leak=[yes/no] → [PASS/FAIL]
(auto-fail triggers: D1=0, D3<3 with >10K rows, D9<8, stack traces in production responses)
Grade: [HEALTHY ≥80% / NEEDS ATTENTION 60-79% / AT RISK 40-59% / CRITICAL <40%]

Issues found:
### API-{N}: {title}
Dimension: D{X}
Severity: CRITICAL/HIGH/MEDIUM/LOW
Endpoint: {METHOD} {path}
Evidence: {code quote, max 15 lines}
Problem: {specific}
Impact: {what breaks}
Fix: {complete code for MEDIUM+}
CQ Overlap: {CQ ID or "none"}

Cross-endpoint observations:
- [contract consistency notes]
- [money format notes]
- [auth pattern notes]
```

IMPORTANT:
- Read BOTH controller AND service files (validation may be in either)
- For D2: check what the service returns — does controller transform it, or pass raw?
- For D3: trace the query — controller → service → ORM call. Is LIMIT present?
- For D7: only score if frontend files are in batch. N/A for backend-only.
- For D9: build auth matrix for ALL endpoints in this controller.
- If NestJS: check for global guards in module — don't penalize if guard is global.
- If framework has global exception filter (@Catch), D4 gets credit even without per-handler try/catch.
- SCRUB all evidence of PII, tokens, secrets before outputting.

Controllers/modules to audit:
[LIST OF FILES FOR THIS BATCH]
```
