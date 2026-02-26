# Code Quality Rules (All Projects)

Production code quality checklist. Applies regardless of stack.
Agent runs this self-eval AFTER writing code, BEFORE writing tests.

---

## CQ Self-Eval Checklist (20 Questions)

**20 binary questions (1 = YES, 0 = NO):**

| # | Category | Question |
|---|----------|----------|
| CQ1 | Types | No `string`/`number` where union, enum, or branded type is appropriate? (status fields, action types, role values). [JS/TS only] No loose equality (`==`/`!=`) -- use strict (`===`/`!==`) to prevent type coercion bugs? |
| CQ2 | Types | All public function return types explicitly declared? No implicit `any` from untyped dependencies? |
| CQ3 | Validation | **CRITICAL** -- Boundary validation complete? ALL three: (a) required fields checked, (b) format/range/allowlist enforced, (c) runtime schema (Zod/class-validator/pipe) at entry point? |
| CQ4 | Security | **CRITICAL** -- Guards (auth, ownership) reinforced by query-level filtering? Guard is NOT the only defense? |
| CQ5 | Security | **CRITICAL** -- No sensitive data leaked in logs, error messages, or API responses? (tokens, passwords, PII, hardcoded secrets, user enumeration via error messages). Evidence: redaction/masking policy (logger scrubber, filter middleware) or explicit proof that no PII reaches logs. |
| CQ6 | Resources | **CRITICAL** -- No unbounded memory from external data? Pagination, streaming, or batching for large datasets? |
| CQ7 | Resources | All DB queries bounded? (LIMIT, pagination cursor). List endpoints return slim payload (`select` fields), not full entity with all relations? |
| CQ8 | Errors | **CRITICAL** -- Infrastructure failures handled? (DB down, network timeout, transaction rollback, filesystem error, DB constraint violation). No empty `catch {}`. Timeouts set on all outbound calls. Error either handled locally with context (log + rethrow) OR explicitly propagated to global handler that logs with correlation ID. **Global filter credit:** only if the specific failure mode is handled gracefully -- a race condition causing unhandled constraint violation that global filter turns into generic 500 != "handled". |
| CQ9 | Data | Multi-table mutations wrapped in transactions? FK order respected in delete/create sequences? |
| CQ10 | Data | Nullable values handled explicitly? No silent `null` propagation, no unsafe `array[0]`/`.find()` without guard? No `as Type` cast on nullable/unknown data without narrowing? (Note: `as Type` on external API data is primarily CQ3/CQ19 -- CQ10 covers casts on nullable/unknown within already-validated code.) |
| CQ11 | Structure | Functions <= 50 lines? Single responsibility? No god methods mixing concerns? |
| CQ12 | Structure | No magic strings/numbers in logic? No index-based data mapping (`row[0]`, `row[46]`)? No duplicate key/id values in config arrays (route definitions, column configs, menu items)? Named constants, config values, or mapping objects used? |
| CQ13 | Hygiene | No dead code? (commented-out blocks, unreachable code after return, unused functions/imports) |
| CQ14 | Hygiene | **CRITICAL** -- No duplicated logic? (>10 lines repeated across methods/configs = extract to shared helper or generator). **Procedure: list all methods >20 lines + declarative structures (routes, column mappings, reducers) -> check for repeated skeletons/blocks.** |
| CQ15 | Async | Every async call `await`ed or explicitly fire-and-forget with error handler (`.catch()` + observability tag: job name/correlation ID)? No `promise` silently dropped? No `sleep()`/`setTimeout()` as synchronization mechanism instead of event/callback/stream completion? |
| CQ16 | Data | Monetary/financial calculations use exact arithmetic? No native `float`/`number` for money -- use `decimal.js`, `big.js`, or integer-cents? No mixed money representations (`cpi: 40.32` number + `cpi: "5000000 VND"` string) in same domain? |
| CQ17 | Performance | No sequential `await` inside loops where batch query or `Promise.all` (with concurrency limit) would work? No N+1 pattern? |
| CQ18 | Data | Cross-system data consistency verified? When same entity lives in multiple stores (DB + vector DB, new table + legacy fields, cache + source), sync mechanism handles partial failures? |
| CQ19 | Contract | API request AND response shapes validated by runtime schema (Zod, class-validator, JSON Schema)? No "hope-based" typing where caller assumes response shape without validation? **Scope:** CRITICAL on external boundaries (HTTP, webhook, queue). For internal module calls: schema required only if data is JSON/dynamic or from untrusted source. |
| CQ20 | Contract | Each data point has ONE canonical source? No dual fields (`*_id` + `*_name`, `number` + `string-with-currency`) stored and modified independently? Derived fields computed, not stored? |

### Scoring

**Static critical gate:** CQ3, CQ4, CQ5, CQ6, CQ8, CQ14 -- any = 0 -> FAIL regardless of total.

**Conditional critical gate** (activated by code context):
- **CQ16** -> critical if code touches prices, costs, discounts, invoices, payouts, exchange rates
- **CQ19** -> critical if code receives or sends data across API/module boundary (request OR response). **Thin controller exception:** if controller only returns data constructed by typed service code (not forwarding external/unvalidated data), the conditional gate does NOT activate -- CQ19=0 counts as a normal score deduction (not a critical gate FAIL). In `/code-audit` tier system: cap = B (not C).
- **CQ20** -> critical if payload contains `*_id` + `*_name` pairs, or number + string-with-currency for same field

When conditional gate activates: that CQ = 0 -> FAIL, same as static gate.

**Thresholds:**
- **PASS:** >= 16/20 AND all active critical gate = 1
- **CONDITIONAL PASS:** 14-15/20 AND all active critical gate = 1 (fix before merge encouraged, not blocking)
- **FAIL:** any active critical gate = 0, OR score < 14 (must fix and re-score)

### Evidence Requirement

For every critical gate CQ scored as 1, provide evidence:

```
CQ3=1 -> schema: CreateOfferDto (src/offer/dto/create-offer.dto.ts:12), pipe: ValidationPipe global
CQ4=1 -> guard: OwnerGuard + query filter: where { ownerId } (src/offer/offer.service.ts:45)
CQ8=1 -> try/catch with context logging (src/offer/offer.service.ts:67-72)
CQ16=1 -> Decimal.js used (src/pricing/calculator.ts:23), no float arithmetic
```

Without evidence -> score as 0. "It's validated somewhere" is not evidence.

### N/A Rules (Strict)

N/A is scored as 1, but requires justification. Abuse of N/A = false PASS.

| CQ | N/A when | NOT N/A (common mistake) |
|----|----------|--------------------------|
| CQ3 | Pure internal helper called only from already-validated entry points (no external input reaches it directly) | "It's simple" -- if function accepts user/external input, CQ3 applies |
| CQ4 | Pure utility with zero auth context | "It's an internal service" -- if it has user-scoped data, CQ4 applies |
| CQ5 | Pure computation with zero I/O, zero logging, zero error messages (no channel for PII to leak) | "We don't log PII" -- if function has logger/response/error message, CQ5 applies |
| CQ6/CQ7 | Function doesn't process collections at all | "Small dataset" -- if external data, size is not guaranteed |
| CQ8 | Pure synchronous computation with zero I/O (no DB, no network, no filesystem) | "Errors are rare" -- if function calls any external system, CQ8 applies |
| CQ9 | Read-only operations or single-table writes | "We don't use transactions" -- multi-table = needs transaction |
| CQ15 | Synchronous-only code (no async anywhere) | "Simple async" -- if async exists, CQ15 applies |
| CQ16 | Zero monetary/financial calculations | "It's just a display field" -- if it's used in math, CQ16 applies |
| CQ17 | No loops over async operations | "Small loop" -- N+1 is N+1 regardless of N |
| CQ18 | Writes to single data store only | "Cache is just cache" -- if cache inconsistency breaks UX, CQ18 applies |
| CQ19 | Internal helper where caller already validated | "Types are enough" -- TS types don't exist at runtime |
| CQ20 | Code doesn't define/consume domain entities | "Legacy dual fields" -- legacy is not an excuse, flag it |

### Output Format

```
Code quality self-eval: CQ1=1 CQ2=1 CQ3=1 CQ4=1 CQ5=1 CQ6=1 CQ7=1 CQ8=0 CQ9=1 CQ10=1 CQ11=1 CQ12=0 CQ13=1 CQ14=1 CQ15=1 CQ16=1 CQ17=1 CQ18=1 CQ19=1 CQ20=1
  Score: 18/20 -> FAIL | Critical gate: CQ3=1 CQ4=1 CQ5=1 CQ6=1 CQ8=0 CQ14=1 -> FAIL (CQ8)
  Conditional gate: CQ16=1(money) CQ19=1(API) -> PASS
  Evidence: CQ3=schema:CreateOfferDto(dto/create-offer.dto.ts:12) CQ4=guard+filter(offer.service.ts:45) CQ8=FAIL CQ16=Decimal(calculator.ts:23) CQ19=Zod(offer.schema.ts:8)
  Fix: CQ8 -- add try/catch with context to cleanup() at offer.service.ts:88
```

---

## Patterns by Code Type

Quick lookup -- which CQ questions are highest risk per code type.

| Code Type | High-Risk CQs | Common Failures |
|-----------|---------------|-----------------|
| **SERVICE** | CQ1, CQ3, CQ4, CQ8, CQ14, CQ16, CQ17, CQ18, CQ20 | Status as string, missing param validation, guard without query filter, unhandled DB errors, copy-paste methods, float for money, await-in-loop, multi-store sync, dual fields |
| **CONTROLLER** | CQ3, CQ4, CQ5, CQ12, CQ13, CQ19 | Missing DTO validation, auth bypass, PII in error response, magic status codes, commented-out endpoints, no response schema |
| **REACT component** | CQ6, CQ10, CQ11, CQ13, CQ15 | Unbounded list render, null props crash, 200+ line component, dead code, missing await on fire-and-forget |
| **ORM/DB** | CQ6, CQ7, CQ9, CQ10, CQ17, CQ20 | Unbounded findMany, no LIMIT, wrong delete order, null column not handled, N+1 in loops, dual canonical fields |
| **ORCHESTRATOR** | CQ6, CQ8, CQ9, CQ14, CQ15, CQ17, CQ18 | All IDs in memory, no infra error handling, no transaction, repeated orchestration blocks, dropped promises, sequential-where-batch, multi-store sync |
| **GUARD/AUTH** | CQ4, CQ5 | Guard not reinforced by query filter, role/org leaked in error message |
| **API-CALL** | CQ3, CQ5, CQ8, CQ15, CQ17, CQ19 | No response validation, API key in log, no timeout/retry, missing await on response, sequential API calls in loop, unvalidated response shape |
| **PURE** | CQ1, CQ2, CQ10, CQ12, CQ16 | Stringly-typed params, no return type, null edge case, magic numbers, float arithmetic for money |

### Defense in Depth (CQ4) -- Detailed

CQ4 is the most commonly missed pattern. The issue:

```typescript
// LOOKS SAFE -- but guard is the ONLY defense
async getItems(surveyId: string, orgId: string) {
  await this.verifyOwnership(surveyId, orgId);  // guard
  return this.prisma.item.findMany({
    where: { surveyId }  // NO orgId filter -- relies solely on guard
  });
}

// DEFENSE IN DEPTH -- guard + query filter
async getItems(surveyId: string, orgId: string) {
  await this.verifyOwnership(surveyId, orgId);  // guard
  return this.prisma.item.findMany({
    where: { surveyId, organizationId: orgId }  // belt AND suspenders
  });
}
```

When to apply: any query after an ownership/auth guard. If the guard has a bug, the query filter is the backup.

When N/A: pure utility functions, functions without auth context, internal-only helpers.

### Resource Bounds (CQ6) -- Detailed

```typescript
// DANGEROUS -- all IDs in memory
const sessions = await prisma.session.findMany({ where: { surveyId } });
const ids = sessions.map(s => s.id);  // could be millions

// SAFE -- cursor-based batching with bounded memory
let cursor: string | undefined;
while (true) {
  const batch = await prisma.session.findMany({
    where: { surveyId },
    take: 1000,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    select: { id: true },
  });
  if (batch.length === 0) break;
  await processBatch(batch.map(s => s.id));
  cursor = batch[batch.length - 1].id;
}
```

### Infrastructure Errors (CQ8) -- Detailed

```typescript
// MISSING -- no infra error handling
async cleanup(surveyId: string) {
  await this.prisma.$transaction(async (tx) => {
    await tx.response.deleteMany({ where: { surveyId } });
    await tx.session.deleteMany({ where: { surveyId } });
  });
  this.logger.log('Cleanup done');  // runs even if transaction fails? No -- but no catch either
}

// HANDLED -- infra errors propagated with context
async cleanup(surveyId: string) {
  try {
    await this.prisma.$transaction(async (tx) => {
      await tx.response.deleteMany({ where: { surveyId } });
      await tx.session.deleteMany({ where: { surveyId } });
    });
    this.logger.log('Cleanup done');
  } catch (err: unknown) {
    this.logger.error(`Cleanup failed for survey ${surveyId}`, err instanceof Error ? err.stack : err);
    throw err;  // re-throw for caller to handle
  }
}
```

### Dead Code (CQ13) -- Detailed

```typescript
// BAD -- commented-out code, unreachable return, unused function
async processOrder(id: string) {
  const order = await this.findOrder(id);
  if (!order) return null;
  // const oldResult = await this.legacyProcess(order);  // DEAD: remove, git has history
  // if (oldResult) { return oldResult; }                 // DEAD
  const result = await this.newProcess(order);
  return result;
  await this.notify(order);  // UNREACHABLE after return
}

// CLEAN
async processOrder(id: string) {
  const order = await this.findOrder(id);
  if (!order) return null;
  const result = await this.newProcess(order);
  await this.notify(order);
  return result;
}
```

### Duplicated Logic (CQ14) -- Detailed

```typescript
// BAD -- 150 lines copy-pasted between two export methods (B5)
async exportToStream(ids: string[], res: Response, writer: StreamWriter) {
  const sessions = await this.getSessions(ids);
  for (const s of sessions) { this.writeRow(writer, this.buildRow(s)); }
}
async exportLatestToStream(surveyId: string, res: Response, writer: StreamWriter) {
  const sessions = await this.getLatestSessions(surveyId);
  for (const s of sessions) { this.writeRow(writer, this.buildRow(s)); }  // identical copy
}

// CLEAN -- shared logic extracted
private writeSessionRows(sessions: Session[], writer: StreamWriter) {
  for (const s of sessions) { this.writeRow(writer, this.buildRow(s)); }
}
// callers fetch their own sessions, then call writeSessionRows()
```

**Procedure:** List all methods >20 lines AND declarative structures (route configs, column mappings, reducers, form field definitions). For each pair, check if >10 lines are structurally identical. If yes -> extract. Also check for:
- Repeated if-chains (30× sort mapping = config-driven `Record<K, V>`)
- Identical reducer/handler skeletons (18× "find -> map -> calculate" = extract generic handler)
- Route config boilerplate (20× same CRUD pattern = `generateCrudRoutes()` generator)
- Column mapping duplication (identical header->field mapping = shared builder)

### Missing Await (CQ15) -- Detailed

```typescript
// BAD -- promise silently dropped (B22)
async runJob(records: Record[]) {
  this.migrateRAJob(records, 'daily');  // no await! errors lost
  return { status: 'ok' };
}

// NOT A BUG -- async auto-flattens Promise<Promise<T>> -> Promise<T>
async getAllOffers(): Promise<Offer[]> {
  const results = this.offerModel.findAll({...}); // Promise<Offer[]> (no await)
  return results; // async wraps -> Promise<Promise<Offer[]>> -> auto-flattened
}
// Caller: await service.getAllOffers() -> Offer[] correctly. Style issue, not bug.

// BAD -- sleep instead of stream completion (B18)
stream.pipe(writer);
await sleep(30000);  // hopes 30s is enough

// CLEAN -- explicit fire-and-forget with error handler
this.migrateRAJob(records, 'daily')
  .catch(err => this.logger.error('Migration failed', err));

// CLEAN -- await stream completion
await new Promise<void>((resolve, reject) => {
  writer.on('finish', resolve);
  writer.on('error', reject);
  stream.pipe(writer);
});
```

### Financial Precision (CQ16) -- Detailed

```typescript
// BAD -- native float arithmetic for money (JS precision: 0.1 + 0.2 = 0.30000000000000004)
const cpiAfterDiscount = parseFloat(baseCpi) * (1 - discount / 100);
const total = quantity * cpiAfterDiscount * exchangeRate;
// At scale: $10,000 order can drift by $0.01-$1.00 per line item

// BAD -- accumulating float errors in loop
let sum = 0;
for (const item of lineItems) {
  sum += item.price * item.qty * (1 - item.discount);  // error compounds per iteration
}

// CLEAN -- use decimal.js (or big.js) for monetary calculations
import Decimal from 'decimal.js';
const cpiAfterDiscount = new Decimal(baseCpi).mul(new Decimal(1).minus(new Decimal(discount).div(100)));
const total = new Decimal(quantity).mul(cpiAfterDiscount).mul(exchangeRate).toDecimalPlaces(2);

// CLEAN -- alternative: integer-cents (multiply by 100, keep arithmetic in integers)
const priceCents = Math.round(baseCpi * 100);
const discountedCents = Math.round(priceCents * (100 - discount) / 100);  // integer math, round once
const totalCents = quantity * discountedCents;
const totalDollars = totalCents / 100;  // convert back only for display
```

When to apply: any code calculating prices, costs, discounts, exchange rates, CPI, payouts, invoices, balances.

When N/A: code with no monetary/financial calculations.

### Sequential Async / N+1 (CQ17) -- Detailed

```typescript
// BAD -- N+1: one query per item in loop (B42/B54)
for (const id of surveyIds) {
  const survey = await this.surveyModel.findByPk(id);  // N queries!
  results.push(survey);
}

// BAD -- sequential API calls when parallel would work
for (const email of emails) {
  const valid = await this.verifyEmail(email);  // sequential, takes N * latency
  results.push({ email, valid });
}

// BAD -- N+1 updates inside transaction (B54)
await prisma.$transaction(async (tx) => {
  for (const claim of claims) {
    await tx.claim.update({ where: { id: claim.id }, data: { status: 'paid' } });  // N updates!
  }
});

// CLEAN -- batch query (single DB call)
const surveys = await this.surveyModel.findAll({
  where: { id: { [Op.in]: surveyIds } },
});

// CLEAN -- parallel with concurrency limit (p-limit or Promise.allSettled)
import pLimit from 'p-limit';
const limit = pLimit(10);  // max 10 concurrent
const results = await Promise.allSettled(
  emails.map(email => limit(() => this.verifyEmail(email)))
);

// CLEAN -- batch update (single DB call)
await prisma.claim.updateMany({
  where: { id: { in: claims.map(c => c.id) } },
  data: { status: 'paid' },
});
```

When to apply: any loop containing `await` for DB queries, API calls, or I/O operations. Check: "Can this be a single batch call or parallel execution?"

When N/A: code with no loops over async operations, or cases where sequential order is semantically required (e.g., migration steps that must run in order).

### Cross-System Data Consistency (CQ18) -- Detailed

```typescript
// BAD -- soft delete in SQL + hard delete in vector DB (B32)
async deleteClause(id: string) {
  await this.prisma.clause.update({
    where: { id },
    data: { deletedAt: new Date() },  // soft delete in SQL
  });
  await this.qdrant.delete(id);  // HARD delete in vector DB!
  // If user restores clause -> vector is gone forever
}

// BAD -- dual source of truth without sync (B41)
async translateMessage(messageId: string, lang: string) {
  const translation = await translate(message.body, lang);
  // Write to NEW table
  await this.prisma.messageTranslation.create({ data: { messageId, lang, text: translation } });
  // Also write to LEGACY fields on message (for backward compat)
  await this.prisma.message.update({
    where: { id: messageId },
    data: { [`body_${lang}`]: translation },
  });
  // If one write fails -> inconsistent state between tables
}

// CLEAN -- transactional sync with matching operations
async deleteClause(id: string) {
  await this.prisma.$transaction(async (tx) => {
    await tx.clause.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
    await tx.clauseVector.update({
      where: { clauseId: id },
      data: { deletedAt: new Date() },  // soft delete BOTH
    });
  });
  // Async cleanup job later removes vector from Qdrant
  // Note: if queue.add() fails, add retry/dead-letter handling
  await this.vectorCleanupQueue.add({ clauseId: id })
    .catch(err => this.logger.error(`Vector cleanup queue failed for ${id}`, err));
}

// CLEAN -- single source of truth + derived view
async translateMessage(messageId: string, lang: string) {
  const translation = await translate(message.body, lang);
  await this.prisma.messageTranslation.upsert({
    where: { messageId_lang: { messageId, lang } },
    create: { messageId, lang, text: translation },
    update: { text: translation },
  });
  // Legacy fields: populated by DB trigger or read-through cache, not manual dual-write
}
```

When to apply: any code that writes the same logical entity to multiple stores (SQL + NoSQL, DB + vector DB, DB + cache, new table + legacy columns).

When N/A: code that only writes to a single data store.

### Data Contract Integrity (CQ19) -- Detailed

```typescript
// BAD -- "hope-based" typing: caller assumes response shape
const response = await fetch('/api/offers');
const data = await response.json();
const total = data.total;  // assumes number -- what if backend returns "4662"?
const offers = data.items;  // assumes array -- what if backend returns { results: [...] }?

// BAD -- no response validation on external API
const result = await this.externalApi.getPrice(id);
return result.price * quantity;  // if API changes shape, silent bug

// CLEAN -- runtime schema validation at boundary
import { z } from 'zod';

const OfferListSchema = z.object({
  items: z.array(OfferSchema),
  total: z.number(),
  page: z.number(),
});

const response = await fetch('/api/offers');
const raw = await response.json();
const data = OfferListSchema.parse(raw);  // throws if shape wrong
// data.total is guaranteed number

// CLEAN -- validated external API response
const ExternalPriceSchema = z.object({
  price: z.number(),
  currency: z.string(),
});
const result = ExternalPriceSchema.parse(await this.externalApi.getPrice(id));
return new Decimal(result.price).mul(quantity);
```

When to apply: any code that receives data from API (external or internal), database queries returning JSON columns, webhook payloads, form submissions.

When N/A: internal helpers that don't cross API/module boundaries (data already validated upstream).

### CQ12 vs CQ20 Boundary

CQ12 = **representation inconsistency** -- same concept expressed in different ways in same codebase:
- `is_deleted: false` in one query, `status: ACTION_STATUS.INACTIVE` in another (same boolean, different representation)
- Magic number `1` in one place, `ACTION_STATUS.ACTIVE` constant in another

CQ20 = **dual source of truth** -- two independent fields storing the same data, updated separately:
- `country_id: 5` + `country_name: "Poland"` (if name changes, which field is truth?)
- `cpi: 40.32` (number) + `cpi_display: "5000000 VND"` (string) stored independently

**Rule of thumb:** If deleting one field would lose information -> CQ20 (dual source). If it's just inconsistent coding style -> CQ12.

### Canonical Source of Truth (CQ20) -- Detailed

```typescript
// BAD -- dual fields stored independently (which is truth?)
interface Offer {
  offer_stage_id: number;    // canonical?
  offer_stage: string;       // or this?  "offer_stage_3" != stage ID 2
}

// BAD -- money as number AND string-with-currency in same domain
const market1 = { cpi: 40.32 };                    // number
const market2 = { cpi: "5000000 VND" };             // string with currency!
// Which format should the calculation function expect?

// BAD -- same field derived differently per context
const offer = {
  original_cpi_discount: totalAfterDiscount,  // name says "cpi discount", value is "total after discount"
};

// CLEAN -- one canonical field, name derived via lookup
interface Offer {
  stageId: OfferStage;  // canonical: enum value
  // stage name: computed via OFFER_STAGE_LABELS[stageId], never stored
}

// CLEAN -- money model: one canonical representation
interface Money {
  amountMinor: number;     // integer cents/minor units (e.g., 503200 = $5032.00)
  currency: CurrencyCode;  // "USD" | "VND" | "EUR"
}
// Display: formatMoney(money) -> "5,000,000 VND"
// Calculation: always on amountMinor, never on display string

// CLEAN -- field names match their values
const offer = {
  totalAfterDiscount: calculatedTotal,  // name = value semantics
};
```

When to apply: any code defining domain entities (DTOs, models, interfaces) or working with fields that have both ID and name/label versions.

When N/A: code that doesn't define or consume domain entities (pure computation, infrastructure).
