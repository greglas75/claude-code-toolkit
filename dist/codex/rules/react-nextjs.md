# React & Next.js Rules (Conditional)

**Apply when:** React or Next.js detected (see `stack-detection.md`). **Skip** for non-React projects.

---

## Component Rules

- **One component per file** (no multiple exported components)
- **Functional components only** (no class components)
- **Props interface at top of file** or in `.types.ts` if >50 lines
- **No inline function definitions in JSX** for event handlers used in lists (extract or useCallback)

## Hooks Rules

- Hooks at the top of the component (before any conditionals/returns)
- Custom hooks in separate files (`useFeatureName.ts`)
- Never call hooks inside loops, conditions, or nested functions
- Always include all dependencies in useEffect/useMemo/useCallback deps arrays
- Prefer `useMemo`/`useCallback` only when there's a measurable perf benefit -- don't premature-optimize

### Common Anti-Patterns (flag these)

- **N× useState for form** -> use `useReducer` or form library (React Hook Form) when 5+ related fields
- **useEffect to sync props->state** -> use `key=` prop to force remount instead
- **useCallback + debounce with deps that change often** -> creates new debounce instance on each deps change, killing the debounce. Use `useRef` for the debounce function or `useMemo` with stable deps
- **Multiple `setState` calls in a loop** -> batch into single state update (build array/object first, set once)
- **Raw fetch+setState when project uses React Query/SWR** -> use the established data fetching pattern for consistency
- **Optimistic state updates without rollback** -> if API call fails, UI stays in wrong state
- **`document.getElementById` / direct DOM manipulation** -> breaks React's virtual DOM, causes hydration errors in SSR
- **Native `confirm()`/`alert()`** -> use custom modal component consistent with UI framework

## State Management Hierarchy

```
Is this SERVER data? (API, database)
  └─ YES -> TanStack Query / SWR / server actions
  └─ NO -> Is this GLOBAL client state?
      └─ YES -> Zustand / Redux
      └─ NO -> Shared between 2-3 components?
          └─ YES -> React Context (small subtree)
          └─ NO -> local useState
```

- **Server state** (TanStack Query/SWR): cache, refetch, stale/fresh management
- **Global client state** (Zustand): theme, sidebar, user preferences
- **Context**: only for small component subtrees (forms, wizards) -- NOT for global state
- **Local state**: component-specific UI state (open/closed, input values)

## Next.js App Router

### Server vs Client Components
- **Default to Server Components** -- only add `"use client"` when needed
- `"use client"` required for: hooks, browser APIs, event handlers, Context providers
- Server Components: data fetching, heavy computation, secrets access
- **Never import server-only code into client components**

### Server Actions
- Validate inputs with Zod in every server action
- Check auth in every server action (not just pages)
- Use `revalidatePath`/`revalidateTag` after mutations
- Never expose sensitive data in action responses

### Environment Variables
- `NEXT_PUBLIC_*` -- exposed to client (NEVER for secrets)
- Non-prefixed vars -- server-only (safe for API keys, DB URLs)

## Performance Patterns

### Debouncing
```typescript
// ALWAYS debounce search/filter inputs (300ms)
const debouncedSearch = useDebounce(search, 300);
```

### Large Lists
- Use virtual scrolling for 1000+ items (`react-window`, `@tanstack/virtual`)
- Paginate or infinite-scroll for API-backed lists

### Code Splitting
- Use `React.lazy()` + `Suspense` for route-level splitting
- Use `next/dynamic` in Next.js for heavy components

## Accessibility (WCAG 2.1 AA)

- **ARIA labels** on all interactive elements without visible text
- **Keyboard navigation**: all actions reachable via keyboard
- **Focus management**: trap focus in modals, restore on close
- **Color contrast**: 4.5:1 for text, 3:1 for UI components
- **Live regions**: `aria-live="polite"` for dynamic content updates
- **Semantic HTML**: use `<button>`, `<a>`, `<nav>`, `<main>` -- not `<div onClick>`
- Decorative icons: `aria-hidden="true"`

## Error Handling

- Wrap feature sections in `ErrorBoundary`
- Log errors to monitoring (Sentry) with context tags
- Show user-friendly fallback UI, not raw error messages
- Re-throw errors after logging (for error boundaries to catch)

## Tailwind CSS (when used)

- Design tokens in `tailwind.config` -- no magic values (`bg-[#3b82f6]`)
- Max ~15 utility classes inline -- extract component if more
- Mobile-first breakpoints (`w-full md:w-1/2 lg:w-1/3`)
- Use `cn()` utility for conditional class merging
