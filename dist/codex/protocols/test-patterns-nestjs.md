# Test Patterns -- NestJS (Domain-Specific)

> Loaded when code type = **CONTROLLER** with NestJS stack detected.
> Core protocol (Q1-Q17, scoring): `~/.codex/test-patterns.md`
> General patterns (G-1–G-40, G-51–G-55, P-1–P-46, P-53–P-57): `~/.codex/test-patterns-catalog.md`

---

## Lookup Table (NestJS)

| Code Type | Good patterns | Gap patterns |
|-----------|---------------|--------------|
| **CONTROLLER** | G-32†, G-33, G-34, NestJS-G1, NestJS-G2 | P-27†, P-28, P-33, P-34, P-38, AP15, AP16, NestJS-AP1, NestJS-P1, NestJS-P2, NestJS-P3 |
| **SERVICE (NestJS)** | G-2, G-4, G-9, G-28, G-32†, G-53, G-54 | P-27†, P-28, P-29, P-31, P-32, P-56†, NestJS-P3 |
| **GUARD** | G-32†, NestJS-G1 | P-1, P-7, NestJS-P2 |
| **PIPE/DTO** | NestJS-G2 | P-1, P-8 |

†See notes in "Catalog Pattern Notes -- NestJS Context" section below.

**Always apply for CONTROLLER:** G-32 (guard symmetry), G-54 (regression anchors), P-38 (public method coverage).

---

## Good Patterns

### G-33: SmartMock / Proxy Factory for Mega-Controllers
- **When:** Controller/class has 10+ injected dependencies
- **Do:**
  ```typescript
  function createSmartMock<T extends object>(baseMocks: Partial<T> = {}): T {
    const cache = new Map<string | symbol, jest.Mock>();
    return new Proxy(baseMocks as T, {
      get(target, prop) {
        if (prop in target) return target[prop as keyof T];
        if (!cache.has(prop)) cache.set(prop, jest.fn().mockResolvedValue(undefined));
        return cache.get(prop);
      },
    });
  }
  ```
  - Mock only what you test, Proxy auto-creates the rest
  - Eliminates 500+ lines of `useValue: { method1: jest.fn(), method2: jest.fn() }`
- **Why:** 18-provider manual mock setup is the #1 contributor to test bloat in NestJS projects. SmartMock reduces setup from 200 lines to 20 while maintaining type safety.
- **Source:** review 2026-02-21, OfferController refactored test -- SmartMock Proxy cut setup from 500 to ~80 lines

### G-34: Direct Instantiation over TestingModule (NestJS)
- **When:** NestJS controller/service has 10+ providers AND test doesn't need NestJS-specific features (pipes, guards, interceptors at module level)
- **Do:** `controller = new Controller(dep1, dep2, dep3, ...)` instead of `Test.createTestingModule({...}).compile()`
- **Combine with G-33:** SmartMock for each dependency
- **Why:** TestingModule compilation with 20+ providers adds latency per test run and forces you to declare every mock upfront. Direct instantiation is faster and lets SmartMock handle unused methods.
- **When NOT to use:** When testing guards, interceptors, pipes, or validation that requires the NestJS DI pipeline
- **Source:** review 2026-02-21, OfferController refactored test -- bypassed 47-provider TestingModule

### NestJS-G1: Guard Direct Testing (Plain Class Unit)
- **When:** Testing a NestJS guard (`@Injectable()` class implementing `CanActivate`)
- **Do:** Instantiate the guard directly, use `createMockContext()` helper for `ExecutionContext`:
  ```typescript
  // Helper -- put this at top of guard test file or in test-utils/
  function createMockContext(user?: Partial<RequestUser>): ExecutionContext {
    return {
      switchToHttp: () => ({
        getRequest: () => ({ user: user ? { id: 'user-1', roles: ['user'], orgId: 'org-1', ...user } : undefined }),
      }),
      getHandler: jest.fn(),
      getClass: jest.fn(),
    } as unknown as ExecutionContext;
  }

  describe('RolesGuard', () => {
    let guard: RolesGuard;
    let reflector: jest.Mocked<Reflector>;

    beforeEach(() => {
      reflector = { getAllAndOverride: jest.fn() } as unknown as jest.Mocked<Reflector>;
      guard = new RolesGuard(reflector);
    });

    it('allows access when user has required role', () => {
      reflector.getAllAndOverride.mockReturnValue(['admin']);
      expect(guard.canActivate(createMockContext({ roles: ['admin'] }))).toBe(true);
    });

    it('denies access when user lacks required role', () => {
      reflector.getAllAndOverride.mockReturnValue(['admin']);
      expect(guard.canActivate(createMockContext({ roles: ['viewer'] }))).toBe(false);
    });

    it('denies access when no user on request (unauthenticated)', () => {
      reflector.getAllAndOverride.mockReturnValue(['admin']);
      expect(guard.canActivate(createMockContext())).toBe(false);  // undefined user
    });
  });
  ```
- **Why:** Guards are pure logic -- no TestingModule overhead needed. `createMockContext()` collapses 10 lines of boilerplate per test to 1, and the unauthenticated case (`undefined` user) is visually obvious.
- **Minimum tests:** allowed, denied (wrong role), denied (no user/unauthenticated)
- **Source:** NestJS guard testing best practices -- added 2026-02-24

### NestJS-G2: DTO / Pipe Validation Testing
- **When:** Testing that `class-validator` decorators on a DTO actually reject invalid input
- **Do:** Use `validate()` from `class-validator` directly -- no HTTP layer needed:
  ```typescript
  import { validate } from 'class-validator';
  import { plainToInstance } from 'class-transformer';

  // Helper -- reusable across DTO test files
  async function validateDto<T extends object>(cls: new () => T, plain: Record<string, unknown>) {
    const dto = plainToInstance(cls, plain);
    return validate(dto);
  }

  describe('CreateOfferDto validation', () => {
    const valid = { title: 'Test', price: 100, currency: 'USD' };

    it('passes with all required fields', async () => {
      expect(await validateDto(CreateOfferDto, valid)).toHaveLength(0);
    });

    it('fails when title is missing', async () => {
      const errors = await validateDto(CreateOfferDto, { ...valid, title: undefined });
      expect(errors.find(e => e.property === 'title')?.constraints).toHaveProperty('isNotEmpty');
    });

    it('fails when price is negative', async () => {
      const errors = await validateDto(CreateOfferDto, { ...valid, price: -1 });
      expect(errors.some(e => e.property === 'price')).toBe(true);
    });

    it('fails when currency is not in allowed list', async () => {
      const errors = await validateDto(CreateOfferDto, { ...valid, currency: 'INVALID' });
      expect(errors.some(e => e.property === 'currency')).toBe(true);
    });
  });
  ```
- **Why:** DTO validation is easy to declare but easy to mis-configure (`@IsOptional()` where required, wrong decorator, missing `@Type()`). Direct `validate()` catches decorator mismatches at unit-test speed.
- **Minimum tests per DTO:** valid case (no errors), each required field missing, each format constraint violated
- **Source:** NestJS DTO testing pattern -- added 2026-02-24

---

## Gap Patterns

### NestJS-AP1: Private Method Testing via Controller
*(Previously documented as NestJS-AP15 -- renumbered to own namespace)*
- **When:** Test calls `controller['__privateMethod']()` or `(controller as any).__method()` directly
- **Problem:** Bypasses the public API surface. 15 direct private-method calls found in OfferController test, avg score 3.0/10. Tests break on any internal refactor (rename, extract to service) even when public behavior is unchanged.
- **Fix:** Test through the public route handler that calls the private method. If the private method contains complex logic worth unit-testing, extract it to a service and test the service directly.
  ```typescript
  // BAD -- testing private method directly
  const result = await (controller as any).__calculateDiscount(offer);
  expect(result).toBe(0.15);

  // GOOD -- test through the public handler that uses it
  mockOfferService.findOne.mockResolvedValue(OFFER_WITH_DISCOUNT);
  const result = await controller.getOffer('offer-123');
  expect(result.discount).toBe(0.15);
  ```
- **Related:** G-34 (direct instantiation makes public-method testing easier)
- **Source:** audit 2026-02-24, OfferController -- 3.0/10, 15 private method calls

### NestJS-P1: 10+ DI Provider TestingModule Smell
*(Previously documented as NestJS-P47 -- renumbered to own namespace)*
- **When:** `Test.createTestingModule({ providers: [...] })` has 10+ providers
- **Problem:** Empirical: 10+ providers in TestingModule -> avg score 2.8/10 (N=92). Each provider requires a full manual mock, producing 200-500 lines of boilerplate. Tests become brittle -- adding a new dependency to the controller breaks every test file.
- **Fix:** Apply G-33 (SmartMock Proxy) + G-34 (direct instantiation) to eliminate TestingModule:
  ```typescript
  // BAD -- 47-provider TestingModule
  const module = await Test.createTestingModule({
    providers: [
      OfferController,
      { provide: OfferService, useValue: { find: jest.fn(), create: jest.fn(), ... } },
      // ... 45 more providers
    ],
  }).compile();

  // GOOD -- direct instantiation + SmartMock
  const offerService = createSmartMock<OfferService>({ find: jest.fn().mockResolvedValue(OFFER_FIXTURES) });
  const controller = new OfferController(offerService, createSmartMock(), createSmartMock());
  ```
- **Threshold:** 10+ providers = flag. 20+ providers = mandatory G-33/G-34 application.
- **Source:** audit 2026-02-24, Offer Module 92-file scan -- 10+ providers correlates with sub-3.0 scores

### NestJS-P2: Missing Unauthorized Path Tests
*(Previously documented as NestJS-P48 -- renumbered to own namespace)*
- **When:** Controller method has a guard (`@UseGuards`, `@Roles`, `@Permissions`) but test only covers the authorized path
- **Problem:** Guard is never exercised from the failing side. If guard is removed or broken, tests still pass.
- **Fix:** For EVERY guarded endpoint, write 3 tests (G-32 symmetry applied to NestJS):
  ```typescript
  describe('POST /offers', () => {
    it('creates offer for authorized user', async () => {
      const result = await controller.create(CREATE_DTO, makeUser({ roles: ['admin'] }));
      expect(offerService.create).toHaveBeenCalledWith(CREATE_DTO, 'user-1', 'org-1');
    });

    it('throws ForbiddenException for viewer role (S3)', async () => {
      await expect(controller.create(CREATE_DTO, makeUser({ roles: ['viewer'] })))
        .rejects.toThrow(ForbiddenException);
      expect(offerService.create).not.toHaveBeenCalled();  // guard fires BEFORE mutation
    });

    it('throws UnauthorizedException when unauthenticated (S2)', async () => {
      await expect(controller.create(CREATE_DTO, undefined))
        .rejects.toThrow(UnauthorizedException);
      expect(offerService.create).not.toHaveBeenCalled();
    });
  });
  ```
- **The `.not.toHaveBeenCalled()` check is non-negotiable** -- proves guard fires before the service call.
- **Detection:** Count guarded handlers vs tests with `.not.toHaveBeenCalled()`. Ratio should be >=1:1.
- **Source:** NestJS guard coverage gap -- added 2026-02-24

### NestJS-P3: Self-Mock Anti-Pattern (`spyOn` on Own Service)
*(Previously documented as NestJS-P49 -- renumbered to own namespace)*
- **When:** NestJS service test uses `jest.spyOn(service, 'ownMethod')` to mock an internal method of the service under test
- **Problem:** You are testing the mock, not the code. The spy replaces the implementation -- test proves "spy returns what we told it to" not "code computes correctly".
  ```typescript
  // BAD -- spying on own service method
  const spy = jest.spyOn(service, 'calculateDiscount').mockResolvedValue(0.15);
  const result = await service.processOffer(offerId);
  expect(spy).toHaveBeenCalledWith(offerId);  // tests nothing -- spy is the impl
  ```
- **Fix:** Mock only external injected dependencies, test the full internal flow:
  ```typescript
  // GOOD -- mock external dep, test computed result
  pricingService.getBasePrice.mockResolvedValue(100);
  const result = await service.processOffer(offerId);
  expect(result.finalPrice).toBe(85);  // 100 * (1 - 0.15) -- computed value
  ```
- **Exception:** `spyOn` on own method is acceptable for testing observable side effects (event emission, logging), but only when the side effect itself is the assertion target.
- **Metric:** `spyOn(service, service.ownMethod)` -> avg 3.0/10 (Red Flags table in test-patterns.md)
- **Source:** stack adjustments NestJS -- added 2026-02-24

---

## Security Test Checklist (NestJS Endpoints)

Every NestJS controller endpoint MUST include these tests:

| # | Test | Expected | Assert service? |
|---|------|----------|-----------------|
| S1 | Invalid DTO (missing/bad fields) | `400 BadRequestException` | `service.not.toHaveBeenCalled()` |
| S2 | Auth missing (no JWT/session) | `401 UnauthorizedException` | `service.not.toHaveBeenCalled()` |
| S3 | Auth forbidden (wrong role/permissions) | `403 ForbiddenException` | `service.not.toHaveBeenCalled()` |
| S4 | Tenant isolation (different orgId/ownerId) | `403 ForbiddenException` | `service.not.toHaveBeenCalled()` + no data returned |
| S5 | Rate limit on auth endpoints | `429` after threshold | -- |
| S6 | XSS in HTML-rendering paths | Sanitized output | -- |
| S7 | Path/ID traversal (if file/resource access) | `400` or `403` | -- |

**S1-S4: always required.** S5-S7: skip if not applicable.

```typescript
// COPY-PASTE TEMPLATE -- replace [Controller], [Method], [DTO], [service] per endpoint:
describe('[Controller].[Method]', () => {
  it('returns result for valid authorized request', async () => {
    [service].doThing.mockResolvedValue(FIXTURE);
    const result = await controller.[method](VALID_DTO, makeUser());
    expect([service].doThing).toHaveBeenCalledWith(/* expected args */);
    expect(result).toMatchObject(/* expected shape */);
  });

  it('throws BadRequestException for invalid DTO (S1)', async () => {
    await expect(controller.[method]({} as [DTO], makeUser()))
      .rejects.toThrow(BadRequestException);
    expect([service].doThing).not.toHaveBeenCalled();
  });

  it('throws UnauthorizedException when no user (S2)', async () => {
    await expect(controller.[method](VALID_DTO, undefined))
      .rejects.toThrow(UnauthorizedException);
    expect([service].doThing).not.toHaveBeenCalled();
  });

  it('throws ForbiddenException for wrong role (S3)', async () => {
    await expect(controller.[method](VALID_DTO, makeUser({ roles: ['viewer'] })))
      .rejects.toThrow(ForbiddenException);
    expect([service].doThing).not.toHaveBeenCalled();
  });

  it('throws ForbiddenException for different org (S4)', async () => {
    await expect(controller.[method](VALID_DTO, makeUser({ orgId: 'other-org' })))
      .rejects.toThrow(ForbiddenException);
    expect([service].doThing).not.toHaveBeenCalled();
  });
});
```

---

## Stack Adjustments (NestJS)

Scored as separate deductions in Q1-Q17 evaluation:

| Check | Bad | Good |
|-------|-----|------|
| No self-mock `spyOn` | `jest.spyOn(service, 'ownMethod')` | Mock external deps; test own logic end-to-end |
| Factory over inline fixture | 100+ LOC `const data = { id: 1, ... }` | `makeOffer({ id: 1 })` with overrides |
| Public methods only | `(controller as any).__internal()` | `controller.publicHandler()` |
| Error assertion pattern | `try { } catch(e) { expect(e.message)... }` | `await expect(...).rejects.toThrow(SomeException)` |
| Guard coverage | Test happy path only | Allowed + denied + no-auth per guarded endpoint |
| DTO validation | Trust type system | Test DTOs with `validate()` from `class-validator` |

---

## Test Structure Templates

### Template 1: Direct Instantiation + SmartMock (Preferred -- use unless DI pipeline needed)

```typescript
// offer.controller.spec.ts
import { OfferController } from './offer.controller';
import { ForbiddenException, BadRequestException, UnauthorizedException } from '@nestjs/common';

function createSmartMock<T extends object>(baseMocks: Partial<T> = {}): T {
  const cache = new Map<string | symbol, jest.Mock>();
  return new Proxy(baseMocks as T, {
    get(target, prop) {
      if (prop in target) return target[prop as keyof T];
      if (!cache.has(prop)) cache.set(prop, jest.fn().mockResolvedValue(undefined));
      return cache.get(prop);
    },
  });
}

const makeOffer = (overrides: Partial<Offer> = {}): Offer => ({
  id: 'offer-1', title: 'Test Offer', price: 100, ownerId: 'user-1', orgId: 'org-1', ...overrides,
});

const makeUser = (overrides: Partial<RequestUser> = {}): RequestUser => ({
  id: 'user-1', orgId: 'org-1', roles: ['admin'], ...overrides,
});

describe('OfferController', () => {
  let controller: OfferController;
  let offerService: jest.Mocked<OfferService>;

  beforeEach(() => {
    offerService = createSmartMock<OfferService>({
      findAll: jest.fn().mockResolvedValue([makeOffer()]),
      create: jest.fn().mockResolvedValue(makeOffer()),
    });
    controller = new OfferController(offerService, createSmartMock(), createSmartMock());
  });

  describe('GET /offers', () => {
    it('returns org-scoped offers for authenticated user', async () => {
      const result = await controller.findAll(makeUser());
      expect(result).toEqual([makeOffer()]);
      expect(offerService.findAll).toHaveBeenCalledWith({ orgId: 'org-1' });
    });
  });
});
```

### Template 2: TestingModule (ONLY when DI pipeline is required)

```typescript
// Use when:
// - Verifying @UseGuards decorators are applied to the right methods
// - Testing ValidationPipe integration with actual HTTP semantics
// - Integration test: controller + guards + pipes together

import { Test, TestingModule } from '@nestjs/testing';

describe('OfferController (DI integration)', () => {
  let module: TestingModule;

  beforeEach(async () => {
    module = await Test.createTestingModule({
      controllers: [OfferController],
      providers: [
        { provide: OfferService, useValue: createSmartMock<OfferService>() },
        RolesGuard,
        Reflector,
      ],
    }).compile();
  });

  afterEach(() => module.close());

  it('RolesGuard is applied to create endpoint', () => {
    const guards = Reflect.getMetadata('__guards__', OfferController.prototype.create);
    expect(guards).toContain(RolesGuard);
  });
});
```

---

## Catalog Pattern Notes -- NestJS Context

Patterns from `test-patterns-catalog.md` that need special handling in NestJS. Read full entries in catalog -- these are addenda only.

### G-32: Admin/Non-Admin Symmetry
**NestJS application:** Required for every `@UseGuards()` decorated handler. Test #3 (`service.not.toHaveBeenCalled()`) is non-negotiable -- proves guard fires *before* service, not just that an error is thrown somewhere.

### P-27: Silent False-Positive via try/catch
**NestJS variant (seen 3x in reviews):** Always use `.rejects.toThrow(ExceptionClass)` -- never wrap in try/catch:
```typescript
// BAD -- passes if controller does NOT throw
try { await controller.findOne(id); } catch (err) { expect(err.response.statusCode).toBe(400); }

// GOOD
await expect(controller.findOne(id)).rejects.toThrow(BadRequestException);
```

### P-28: Phantom Mocks
**NestJS context:** Common in TestingModule setups -- `useValue: { method: jest.fn() }` where the method is never actually exercised by any test. Each phantom mock = code path with zero regression safety.

### P-29: Type Hack Proliferation
**NestJS context:** Particularly common when mocking `ExecutionContext`, `Request`, `ModuleRef`. Fix: use `createMockContext()` helper (see NestJS-G1) instead of scattered `as unknown as ExecutionContext` casts.

### P-33: Input Echo Assertions
**NestJS context:** Very common -- test passes a DTO and asserts `result.fieldFromDto === dto.field`. Always assert computed values: the ID assigned by DB, the timestamp added by service, the derived status enum.

### Q5: `as any` Mocks -- Accepted Trade-off in Vitest + NestJS
**NestJS + Vitest context:** `Test.createTestingModule()` fails with Vitest due to DI lifecycle incompatibilities. This forces `as any` / `as unknown as ServiceType` casts on mock providers -- scoring Q5=0 across all test files using TestingModule.

**This is a known trade-off, not a defect.** Do NOT fix by adding more type casts.

**Real fix:** Apply G-33 (SmartMock Proxy) + G-34 (direct instantiation) to eliminate TestingModule entirely. When using direct instantiation, TypeScript resolves mock types through the class constructor -- no `as any` needed:
```typescript
// TestingModule + Vitest -> forces as any:
{ provide: OfferService, useValue: { find: jest.fn() } as any }  // Q5=0

// Direct instantiation -> properly typed:
const offerService = createSmartMock<OfferService>({ find: jest.fn() });  // Q5=1
const controller = new OfferController(offerService, ...);
```

**Signal:** If a NestJS test file has Q5=0 due to `as any` mock casts -> it's using TestingModule (NestJS-P1). Apply G-33+G-34 to eliminate both problems at once.

### P-56: Mock Drift / Interface Divergence
**NestJS-specific note:** TypeScript types protect compile-time only. A mock typed as `Partial<OfferService>` will not catch when the real service adds a required field that the mock omits. At runtime, `result.status` is `undefined` in the test but has a value in production.

```typescript
// BAD -- mock returns partial shape without createdAt
offerService.create.mockResolvedValue({ id: 'offer-1' } as Offer);
// Test passes. But real service returns { id, createdAt, status, ...}
// Component that reads result.createdAt.toISOString() -> crashes in test

// GOOD -- mock returns the full shape via factory
offerService.create.mockResolvedValue(makeOffer());
// makeOffer() always includes all fields -> shape mismatch caught immediately
```
Fix: mock return values via factory functions (G-4) that return the complete shape, not partial object literals.

---

## Quick-Fail Pre-Scan

Run before full Q1-Q17 to identify the highest-signal problems first:

```bash
# NestJS-P3: self-mock (spyOn on own service)
grep -n "spyOn(service\|spyOn(controller" [test_file]

# NestJS-AP1: private method calls
grep -n "as any)\.\|__[a-z]" [test_file]

# P-27 NestJS variant: try/catch instead of rejects.toThrow
grep -n "} catch" [test_file]

# NestJS-P1: TestingModule with 10+ providers
grep -c "useValue:" [test_file]  # > 10 = flag

# NestJS-P2: guard tests missing not.toHaveBeenCalled
grep -n "ForbiddenException\|UnauthorizedException" [test_file]
# verify each exception test has .not.toHaveBeenCalled() nearby
```
