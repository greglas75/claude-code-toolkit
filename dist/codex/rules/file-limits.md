# File Size & Modularization Rules (All Projects)

Hard limits regardless of stack. Project CLAUDE.md can override specific values.

---

## Hard Limits

- **Max 250 lines per file** (source code, not tests)
- **Max 50 lines per function/method**
- **Max 3 levels of nesting** (refactor if deeper)
- **Max 400 lines per test file**
- If file exceeds limits: split into modules before adding more code

## When to Split

### Components (>200 lines)

Extract to:
- `ComponentName.hooks.ts` -- custom hooks
- `ComponentName.types.ts` -- types/interfaces
- `ComponentName.utils.ts` -- helper functions
- `ComponentName/components/` -- sub-components

### Services/Utilities (>150 lines)

Split by domain/responsibility:
```
services/payment.ts (604 lines)     ->  services/payment/paypal.ts
                                        services/payment/cysend.ts
                                        services/payment/types.ts
```

### API/Route files (>200 lines)

Split by resource or endpoint group:
```
routes/api.ts (800 lines)           ->  routes/projects.routes.ts
                                        routes/orders.routes.ts
                                        routes/claims.routes.ts
```

## Structure Rules

1. **One component = one file** (no multiple component exports)
2. **Shared utilities** in `lib/` or `utils/` with clear naming
3. **Types/interfaces** in separate `.types.ts` when >50 lines of types
4. **Complex logic** extracted to hooks (React) or services (backend)
5. **Each module** has single responsibility

## Before Creating/Modifying Files

1. Check if file will exceed 250 lines after your change
2. If yes -- plan the split first, then implement
3. Keep related files in the same directory
4. Prefer smaller, focused files over large monoliths

## Naming Conventions

```
ComponentName.tsx              # Main component
ComponentName.hooks.ts         # Custom hooks
ComponentName.utils.ts         # Helper functions
ComponentName.types.ts         # TypeScript types
ComponentName.test.tsx         # Tests
use-feature-name.ts            # Standalone hooks (kebab-case)
feature-name.service.ts        # Backend services
feature-name.repository.ts    # Data access layer
```
