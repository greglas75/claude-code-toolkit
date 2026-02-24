# TypeScript Rules (Conditional)

**Apply when:** TypeScript detected (see `stack-detection.md`). **Skip** for pure Python or non-TS projects.

---

## Zero `any` Policy

```typescript
// NEVER use `any` -- use `unknown` or proper types
catch (err: unknown) {
  const message = err instanceof Error ? err.message : String(err);
}

// NEVER use `as any` casts -- extend interfaces or use proper generics
// NEVER use implicit `any` -- always type function params and returns
```

**When encountering `any` in existing code:** fix it when modifying that file. Don't ignore it.

## Type-First Development (Zod)

When project uses Zod: define schemas first, infer types from them.

```typescript
// CORRECT: Zod schema is the single source of truth
export const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  role: z.enum(["admin", "user"]),
});
export type User = z.infer<typeof UserSchema>;

// WRONG: manually duplicated interface
interface User { id: string; email: string; role: string; }
```

## Strict Typing Rules

```typescript
// ALWAYS type function returns explicitly
async function fetchUsers(): Promise<User[]> { ... }

// Use discriminated unions for complex states
type RequestState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };

// NEVER leave variables untyped
const data: any = await fetch(); // WRONG
const data: unknown = await fetch(); // then validate/parse
```

## Error Handling Types

```typescript
// ALWAYS: catch unknown, narrow with instanceof
try { ... }
catch (err: unknown) {
  if (err instanceof Error) { logger.error(err.message); }
  else { logger.error("Unknown error", { err }); }
}

// NEVER: catch (err: any) or catch (err) without narrowing
```

## Enums and Constants

```typescript
// Prefer const objects or union types over enums
const STATUS = { ACTIVE: "active", INACTIVE: "inactive" } as const;
type Status = (typeof STATUS)[keyof typeof STATUS];

// Or simple union types
type Direction = "up" | "down" | "left" | "right";
```

## Generic Constraints

```typescript
// Use constraints to make generics useful
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

// Avoid unconstrained generics -- they're just `any` in disguise
function bad<T>(x: T): T { return x; } // Too loose
```

## Import Types

```typescript
// Use `import type` for type-only imports (better tree-shaking)
import type { User, UserSchema } from "./types";
import { validateUser } from "./validation"; // runtime import
```
