---
name: quality-rules
description: "Edge case checklist, validator depth, self-eval evidence, auto-fail patterns, mock safety. Read by /write-tests Phase 3.2 and 3.3."
---

# Test Quality Rules — Reference

Read this file at two points during `/write-tests`:
1. **Phase 3.2** (before writing tests) — edge cases, validator depth, mock safety
2. **Phase 3.3** (before self-eval) — evidence requirements, auto-fail patterns

---

## Edge Case Checklist (MANDATORY)

For EVERY parameter the method accepts, check which input types apply and write tests for each:

| Input type | Edge cases to test | Example assertion |
|------------|-------------------|-------------------|
| **string** | `null`, `undefined`, `''` (empty), `' '` (whitespace only), very long (`'a'.repeat(10000)`), Unicode (`'日本語'`), special chars (`'<script>alert(1)</script>'`) | `expect(fn('')).toThrow()` or verify fallback behavior |
| **number** | `null`, `undefined`, `0`, `-1`, `NaN`, `Infinity`, `Number.MAX_SAFE_INTEGER`, float where int expected (`3.14`) | `expect(fn(NaN)).toThrow()` |
| **array** | `null`, `undefined`, `[]` (empty), single element `[x]`, very large array, duplicate elements | `expect(fn([])).toEqual([])` or verify empty handling |
| **object** | `null`, `undefined`, `{}` (empty), missing required keys, extra unknown keys, nested null (`{ meta: null }`) | `expect(fn({ meta: null })).not.toThrow()` |
| **boolean** | explicit `false` (not just truthy/falsy check), `undefined` vs `false` distinction | `expect(fn(false)).toBe(X)` — not same as `fn(undefined)` |
| **Date** | `null`, invalid date (`new Date('invalid')`), epoch (`new Date(0)`), far future | `expect(fn(new Date('invalid'))).toThrow()` |
| **optional param** | omitted entirely vs passed as `undefined` vs passed as `null` — verify all three behave correctly | `fn()` vs `fn(undefined)` vs `fn(null)` |
| **enum/union** | every member of the union, plus an invalid value not in the union | `expect(fn('INVALID_STATUS')).toThrow()` |

**How to apply:** For each method, list its parameters. For each parameter, find its type in the table above. Write at least the `null`/`undefined`/empty test. Write boundary tests where the method has conditional logic (if/switch) that depends on that parameter.

**Shortcut for methods with many params:** Use factory pattern. Test one edge case per `it()`, override one field at a time:
```typescript
it('handles null userComment', () => {
  expect(fn(createInput({ userComment: null }))).toBe(expectedFallback);
});
```

**Common misses** (agents frequently skip these):
- `null` in nested objects (`{ metadata: { category: null } }` vs `{ metadata: null }`)
- Empty string vs null (`''` and `null` are different — test both)
- Optional field omitted vs explicitly `undefined`
- Array with one element (off-by-one in `.length` checks)
- Mock returning `[]` or `null` instead of expected data (tests the caller's null handling)

---

## Validator/Schema/DTO — DEPTH Requirements

When code type is VALIDATOR (files with `validator`, `schema`, `dto` in name, or Joi/Zod/class-validator schemas):

| Requirement | What to test | Example |
|-------------|-------------|---------|
| **Each rule individually** | One `it()` per validation rule — not just "valid passes, invalid fails" | `it('should reject email without @')` |
| **Error messages** | Assert the specific error message text, not just that it throws | `expect(error.message).toContain('must be a valid email')` |
| **Boundary values per field** | Empty string, null, undefined, min length, max length, type mismatch, special chars | `makePayload({ email: '' })` |
| **Multiple errors** | Send payload with 2+ invalid fields — verify ALL errors returned | `expect(error.details).toHaveLength(2)` |
| **Valid edge cases** | Minimum valid payload, optional fields omitted, Unicode in string fields | `makePayload({ name: '日本語テスト' })` |

Minimum test count for a validator with N fields: **N×3** (valid + invalid + boundary per field) + 1 multi-error + 1 minimal valid = **N×3 + 2**.

---

## Mock Safety

For each mock hazard identified by Pattern Selector:

| Hazard type | WRONG (causes hang) | CORRECT |
|-------------|---------------------|---------|
| `AsyncGenerator` / `async function*` | `vi.fn()` — returns undefined, iteration hangs | `vi.fn().mockImplementation(async function*() { yield chunk; })` |
| `for await (const chunk of stream)` | mock that is not async iterable | mock must implement `Symbol.asyncIterator` |
| `stream.pipe(writer)` | no-op mock — writer never emits `finish` | `writer.on = vi.fn((event, cb) => event === 'finish' && cb())` or use a PassThrough stream |
| `EventEmitter.on('data')` / `.on('end')` | `vi.fn()` — callbacks never called | mock EventEmitter with `.emit('data', chunk)` + `.emit('end')` in implementation |
| Promise from `new Promise(resolve => stream.on('finish', resolve))` | stream mock that never emits `finish` | mock stream as PassThrough or manually call finish handler |

**Always verify**: run a quick mental trace — does the mock return something the production code can iterate/await/subscribe to? If not → the test will hang silently.

---

## Self-Eval Evidence Requirements

Self-eval inflation is the #1 quality problem. Agents give 17/17 when real score is 8/17. Each critical gate Q=1 MUST include a proof line. Without proof → score as 0.

| Q | Proof required (cite specific test names or line ranges) |
|---|----------------------------------------------------------|
| **Q7** | Name the `it()` block that tests an error/rejection path. Quote the `toThrow`/`rejects`/error assertion. |
| **Q11** | List ALL conditional branches (`if/else`, `switch`, ternary, `??`, `\|\|`) in the production code. For EACH branch, name the test that exercises it. Any branch without a test → Q11=0. |
| **Q15** | Count assertions by type: (a) **value assertions** (`toEqual`, `toBe`, `toContain` with specific values), (b) **weak assertions** (`toBeDefined`, `toBeTruthy`, `typeof`, `toHaveBeenCalled` without args). If weak > 50% of total → Q15=0. |
| **Q17** | For each key assertion, answer: "Does this verify something the CODE COMPUTED, or something I SET UP in the test?" If the expected value comes from a mock/fixture setup (not a computation by the production code) → that assertion is echo, not verification. If >50% are echo → Q17=0. |

---

## Auto-Fail Patterns

If found → corresponding Q = 0, no exceptions. **These patterns must be REMOVED during the fix loop** — delete or replace with behavioral assertions. Do not leave them and accept Q=0.

| Pattern | Auto-fails | Why |
|---------|-----------|-----|
| `typeof x === 'function'` appears ≥3× | Q15 | Tests interface shape, not behavior |
| `toBeDefined()` is the SOLE assertion in an `it()` block | Q15 | Proves existence, not correctness |
| `expect(screen).toBeDefined()` | Q15, Q17 | Screen is always defined — tests nothing |
| No test calls the function with invalid/error input | Q7 | No error path coverage |
| Production code has `if (level)` / `switch` but no test varies that param | Q11 | Untested branch |
| All `toHaveBeenCalledWith` args are literals from mock setup | Q17 | Echo, not computed verification |
| `expect(spy).toHaveBeenCalled()` without `CalledWith` checking args | Q15 | Proves call happened, not correctness |
