# Principal Architect Code Review Protocol v2.1

> **Purpose:** Ruthless verification of code quality. Find bugs that linters and unit tests won't catch.
> **Philosophy:** Evidence-based, actionable, honest severity assessment.
> **Usage:** Read on-demand by `/review` command. Core rules in `~/.antigravity/skills/review/rules.md` (read by skill on invocation).

---

## Tech Stack Declaration (Fill Before Review)

```yaml
tech_stack:
  language: [TypeScript/JavaScript/Python/Go/Rust/Java/C#/Other]
  framework: [Next.js/React SPA/Vue/Angular/Svelte/SolidJS/None]
  backend: [NestJS/Express/Fastify/FastAPI/Django/Flask/Go/None]
  state_management: [Redux/Zustand/MST/Jotai/Pinia/Vuex/Context/None]
  database: [PostgreSQL/MySQL/MongoDB/Redis/Prisma/SQLAlchemy/Drizzle/None]
  testing: [Jest/Vitest/Playwright/Cypress/pytest/unittest/None]
  deployment: [Vercel/AWS/GCP/Cloudflare/Docker/K8s/Other]
```

**Auto-detect from files:** Check `package.json`, `pyproject.toml`, `requirements.txt`, `next.config.*`, `manage.py` to fill this automatically.

Sections marked [TECH: X] only apply if X is in your stack. Key conditional sections:
- [TECH: Next.js] -> Steps 3.5, 4.5, 5.1b
- [TECH: Python] -> Steps 3.6, security 7.1 Python red flags
- [TECH: React] -> Steps 3.2, 4.1, 5.1

---

## STEP 0: PRE-FLIGHT CHECK

- [ ] Do I understand WHY this change was made?
- [ ] Is the scope as expected (not scope creep)?
- [ ] Do I have baseline (before changes) for comparison?
- [ ] Does PR/MR description explain intentions?
- [ ] Are there linked tickets/issues?
- [ ] Did I actually PULL and RUN the code locally?

### 0.1 Git Blame Context Check

Before flagging any issue, verify it's NOT pre-existing:
```bash
git blame -L <start>,<end> <file>    # Who wrote this line? When?
git log --oneline -5 -- <file>       # Recent history of this file
```

Rules:
- If the problematic line was NOT modified in this change -> **skip it** (pre-existing, not author's responsibility)
- If the pattern existed before and was just moved/reformatted -> **skip it**
- If git blame shows the same author recently -> check if it's part of an ongoing refactor (context matters)
- Only flag issues on lines the author actually changed or on new code they wrote

Output:
```
### STEP 0: PRE-FLIGHT
- Change Intent: [BUGFIX/REFACTOR/FEATURE/INFRA]
- Purpose understood: [YES/NO] - [brief description]
- Scope appropriate: [YES/NO]
- Baseline available: [YES/NO]
- Description quality: [Good/Adequate/Poor]
- Code executed locally: [YES/NO]
- Git blame checked: [YES/NO]
```

---

## STEP 1: CHANGE INVENTORY

### 1.1 Modified Files

| File | Main Changes | Risk | Blast Radius |
|------|--------------|------|--------------|
| `path/to/file.ts` | [description] | R/Y/G | [who uses this?] |

### 1.2 New Files

| File | Purpose | Risk | Test Coverage |
|------|---------|------|---------------|
| `path/to/new.ts` | [description] | R/Y/G | [has tests?] |

### 1.3 Deleted Files

| File | Was it used? | Migration needed? | Verified unused? |
|------|--------------|-------------------|------------------|
| `path/to/old.ts` | [YES/NO - by what] | [YES/NO] | [how verified?] |

### 1.4 Dependency Changes

| Package | Change | Version | Risk | Justification |
|---------|--------|---------|------|---------------|
| package-name | Added/Removed/Updated | X.Y.Z | R/Y/G | [why?] |

### 1.5 Configuration Changes

| File | Change | Impact | Requires restart? |
|------|--------|--------|-------------------|
| `.env.example` | [description] | [impact] | [YES/NO] |

---

## STEP 2: STATIC & ARCHITECTURAL ANALYSIS

### 2.1 Compilation & Type Safety

Checklist:
- [ ] Code compiles without errors
- [ ] No `any` without justification
- [ ] No unsafe type assertions (`as X` without validation)
- [ ] No non-null assertions (`!`) without justification
- [ ] ESLint/Prettier passes
- [ ] Strict mode respected

Red flags to hunt:
```typescript
// [TECH: TypeScript]
data as any
response as unknown as SpecificType
value!.property  // non-null assertion without guard
// @ts-ignore
// @ts-expect-error (without explanation)
Object.keys(obj).forEach  // loses type safety
```

```python
# [TECH: Python]
def process(items=[]):       # mutable default argument!
x: Any                       # untyped / Any abuse
result = eval(user_input)    # eval/exec on untrusted input
# type: ignore               # without explanation
isinstance(x, dict)          # instead of proper type narrowing
```

Python type safety:
- [ ] Type hints on all public functions (params + return)
- [ ] No `Any` without justification
- [ ] `mypy --strict` or `pyright` passes (if configured)
- [ ] No bare `except:` or `except Exception:`
- [ ] Dataclasses/Pydantic models for structured data (not raw dicts)

### 2.2 Imports & Dependencies

- [ ] All imports correct and used
- [ ] No circular dependencies
- [ ] No unused imports
- [ ] Relative paths correct after restructure
- [ ] Barrel exports (`index.ts`) updated
- [ ] Tree-shaking will work
- [ ] No importing from `dist/` or build artifacts

### 2.3 Naming & Conventions

- [ ] Names consistent with project conventions
- [ ] Self-documenting names
- [ ] Case conventions respected (camelCase, PascalCase, snake_case)
- [ ] File names match exported components/classes
- [ ] Booleans start with `is`, `has`, `should`, `can`

### 2.4 Architectural Integrity

- [ ] SRP maintained
- [ ] Component doesn't "know too much" about outside world
- [ ] Proper separation: UI / Business Logic / Data
- [ ] No God components/functions (>250 lines = smell, see `~/.antigravity/rules/file-limits.md`)
- [ ] Follows existing project patterns

Architecture Smell Metrics:
| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Largest function (lines) | ___ | <50 | |
| Largest file (lines) | ___ | <250 (source) / <400 (tests) | |
| Max nesting depth | ___ | <4 | |
| Cyclomatic complexity | ___ | <10 | |

---

## STEP 3: LOGIC & SIDE-EFFECTS DEEP DIVE

### 3.1 Functionality & Error Handling Verification

For each modified function/component:
- [ ] Business logic intact
- [ ] Edge cases handled (null, empty, boundary)
- [ ] Error handling complete
- [ ] Input validation works
- [ ] Defaults and fallbacks sensible
- [ ] Return types accurate (not lying about null)

#### Silent Failure Hunt (for every try/catch, .catch, except block):

Locate ALL error handling in changed code, then for each one verify:

**Is it silent?**
- [ ] Error is logged (not just swallowed)
- [ ] Log includes context (what failed, relevant IDs, user action)
- [ ] User gets actionable feedback (not just console.log)
- [ ] No empty catch blocks (CRITICAL if found)

**Is the catch too broad?**
- [ ] Catches specific errors, not everything (`catch (e)` / `except Exception:`)
- [ ] Unexpected errors can still bubble up
- [ ] List what OTHER errors this catch might accidentally hide

**Are fallbacks hiding problems?**
- [ ] Fallback behavior is intentional and documented (not just masking failure)
- [ ] User knows they're seeing fallback, not normal behavior
- [ ] No production code falling back to mock/stub/default data

**Hidden failure patterns to hunt:**
```typescript
// JS/TS
catch (e) { /* empty */ }                           // CRITICAL: silent swallow
catch (e) { console.log(e); }                       // no user feedback, lost in logs
.catch(() => null)                                   // returns null, caller doesn't know it failed
data ?? defaultValue                                 // is data ever actually null? why?
optional?.chaining?.everywhere                       // hiding potential bugs behind ?.
```

```python
# Python
except:                                              # CRITICAL: catches SystemExit, KeyboardInterrupt
    pass
except Exception as e:                               # too broad
    logger.error(e)                                  # no context, no re-raise
    return None                                      # caller doesn't know it failed
result = response.json().get("data", [])             # silently returns [] on missing key
```

### 3.2 Hook Integrity [TECH: React/Vue/Svelte]

- [ ] useEffect/watch dependencies COMPLETE
- [ ] useMemo/useCallback/computed dependencies COMPLETE
- [ ] Cleanup functions present where needed
- [ ] No stale closures
- [ ] Custom hooks follow rules of hooks
- [ ] No hooks called conditionally

Red flags:
```typescript
// Missing dependencies
useEffect(() => { fetchData(userId); }, []);

// Object/function in deps without memo
useEffect(() => { doSomething(config); }, [config]);

// Missing cleanup
useEffect(() => { const sub = subscribe(handler); /* no return */ }, []);

// Stale closure
const [count, setCount] = useState(0);
useEffect(() => {
  setInterval(() => console.log(count), 1000); // always logs 0
}, []);
```

### 3.3 Race Conditions & Async Safety

- [ ] Async operations have cancellation (AbortController)
- [ ] No state updates after unmount
- [ ] Loading/error state handling
- [ ] Debounce/throttle for rapid actions
- [ ] Optimistic updates have rollback
- [ ] Concurrent requests handled

Red flags:
```typescript
// Race condition -- no abort
useEffect(() => { fetchData().then(setData); }, []);

// Race between searches
const handleSearch = async (query) => {
  const results = await search(query); // Previous still running!
  setResults(results);
};
```

### 3.4 State Management

- [ ] State updates are immutable
- [ ] No derived state stored redundantly
- [ ] State at appropriate level
- [ ] No prop drilling (use context/store if >3 levels)
- [ ] State shape normalized
- [ ] No state that could be URL params

### 3.5 Next.js Specific [TECH: Next.js]

Server Components vs Client Components:
- [ ] `"use client"` only where needed (interactivity, hooks, browser APIs)
- [ ] No `"use client"` on pages/layouts unless necessary
- [ ] Server Components don't import client-only libs (useState, useEffect, browser APIs)
- [ ] Client Components don't accidentally pull in large server-only deps

Server Actions:
- [ ] `"use server"` functions validate ALL inputs (they're public endpoints!)
- [ ] Auth checked inside every server action (not just in middleware)
- [ ] No secrets/tokens passed from client to server action
- [ ] revalidatePath/revalidateTag called after mutations

App Router patterns:
- [ ] loading.tsx / error.tsx / not-found.tsx present for key routes
- [ ] Metadata exported (title, description) for SEO
- [ ] `generateStaticParams` for dynamic routes where possible
- [ ] Middleware.ts not doing heavy work (runs on every request)
- [ ] Route handlers (app/api/) validate input + return proper status codes

Red flags:
```tsx
// Server Component importing client code
import { useState } from 'react';        // ERROR in server component
export default function Page() { ... }

// Server Action without auth check
"use server"
async function deleteUser(id: string) {   // Anyone can call this!
  await db.user.delete({ where: { id } });
}

// Passing secrets client-side
<ClientComponent apiKey={process.env.SECRET_KEY} />  // Exposed to browser!

// Over-fetching in layout (runs for ALL child routes)
export default async function Layout() {
  const allData = await fetchEverything();  // Too heavy for layout
}
```

Caching & revalidation:
- [ ] `fetch()` cache behavior explicit (no-store, force-cache, revalidate)
- [ ] `unstable_cache` / `cache()` used for expensive computations
- [ ] Cache invalidated after mutations (revalidatePath, revalidateTag)
- [ ] No stale data shown after form submissions

### 3.6 Python Specific [TECH: Python]

Async patterns:
- [ ] `async`/`await` used correctly (no blocking calls in async context)
- [ ] No `time.sleep()` in async code (use `asyncio.sleep()`)
- [ ] Background tasks properly awaited or fire-and-forget is intentional
- [ ] Connection pools used for DB/HTTP (not creating connections per request)

Common Python bugs:
- [ ] No mutable default arguments (`def f(items=[])` -> `def f(items=None)`)
- [ ] No late binding closures in loops (`lambda: i` captures by reference!)
- [ ] Context managers used for resources (`with open(...)`, `async with session`)
- [ ] No bare `except:` -- always catch specific exceptions
- [ ] `__all__` defined for public API modules

Red flags:
```python
# Mutable default -- shared across all calls
def add_item(item, items=[]):
    items.append(item)  # BUG: list is shared!

# Blocking call in async context
async def handler():
    result = requests.get(url)     # Blocks the event loop!
    # Should be: async with httpx.AsyncClient() as client: ...

# Late binding closure
callbacks = [lambda: i for i in range(5)]
callbacks[0]()  # Returns 4, not 0!

# Resource leak
f = open("file.txt")  # No context manager, never closed on exception

# Dangerous deserialization
data = pickle.loads(user_input)     # Remote code execution!
data = yaml.load(user_input)        # Use yaml.safe_load()!
```

FastAPI specific:
- [ ] Pydantic models for request/response (not raw dicts)
- [ ] Dependency injection for DB sessions (Depends)
- [ ] Background tasks for slow operations
- [ ] Proper status codes (201 for create, 204 for delete)
- [ ] `response_model` set on endpoints (filters sensitive fields)

Django specific:
- [ ] QuerySets are lazy -- `.all()` alone doesn't hit DB
- [ ] `select_related` / `prefetch_related` for foreign keys (N+1)
- [ ] Forms/serializers validate input (not raw `request.POST`)
- [ ] CSRF middleware enabled for form endpoints
- [ ] `get_object_or_404` instead of bare `.get()` + manual 404

### 3.7 Feature Completeness [conditional: new feature]

Functionality:
- [ ] Feature complete per requirements
- [ ] Happy path works end-to-end
- [ ] Edge cases identified and handled

UI/UX:
- [ ] Loading states
- [ ] Error states (user-friendly messages)
- [ ] Empty states
- [ ] Responsive
- [ ] Accessibility (aria, keyboard, contrast)

Robustness:
- [ ] Double-click, back button handled
- [ ] Network failure/timeout handled
- [ ] Invalid input handled

### 3.8 AI Code Smell Check [conditional: AI-generated suspected]

- [ ] No placeholder/generic TODOs left
- [ ] No suspiciously generic variable names (`data`, `result`, `temp`)
- [ ] No hallucinated imports/APIs (verify they exist!)
- [ ] No overly verbose comments explaining obvious code
- [ ] No inconsistent style within same file

---

## STEP 4: INTEGRATION POINTS

### 4.1 Component Integration [TECH: React/Vue/Angular/Svelte]

- [ ] Parent components pass correct props
- [ ] Child components receive all required props
- [ ] Callbacks correctly passed and invoked
- [ ] Context providers at proper tree level

### 4.2 API Integration

- [ ] Endpoints correctly called (method, path, body)
- [ ] Auth headers passed
- [ ] Error responses handled (4xx, 5xx, network)
- [ ] Retry logic where needed
- [ ] Request/response types validated
- [ ] Timeout configured

### 4.3 Database [conditional: DB changes]

- [ ] Queries syntactically correct
- [ ] Indexes used efficiently
- [ ] Migrations tested (up AND down)
- [ ] Transactions for related operations
- [ ] Connection pooling configured
- [ ] N+1 avoided
- [ ] Data types match (dates, decimals)

### 4.4 External Services [conditional]

- [ ] Graceful degradation when unavailable
- [ ] Sensible timeouts (connect: 5s, read: 30s)
- [ ] Circuit breakers
- [ ] Retry with exponential backoff
- [ ] Credentials not hardcoded

### 4.5 Environment Variables

- [ ] New env vars documented in `.env.example` / `.env.template`
- [ ] Env vars validated at startup (zod schema, pydantic BaseSettings, t3-env)
- [ ] No `process.env.X` / `os.environ["X"]` deep in business logic (inject via config)
- [ ] `NEXT_PUBLIC_*` prefix only for vars safe to expose to browser [TECH: Next.js]
- [ ] Secrets not in `NEXT_PUBLIC_*` [TECH: Next.js]
- [ ] No fallback to insecure defaults (`SECRET_KEY || "dev-secret"` in production)

### 4.6 Backward Compatibility [conditional: API/interface changes]

API:
- [ ] Old clients can call new API
- [ ] New required fields have defaults
- [ ] Response shape additions backward compatible
- [ ] Breaking changes documented and versioned

Database:
- [ ] Old code can read new data format
- [ ] New code can read old data format
- [ ] Migrations reversible

---

## STEP 5: PERFORMANCE & RENDER TOPOLOGY

### 5.1 Frontend Performance [TECH: React/Vue/Angular/Svelte]

- [ ] No unnecessary re-renders
- [ ] Memoization used where beneficial
- [ ] Keys correct in lists (not index for dynamic lists!)
- [ ] Large lists virtualized (>100 items)
- [ ] Images lazy-loaded
- [ ] Code splitting at route level

Red flags:
```typescript
<Component style={{ color: 'red' }} />           // new object every render
<Component onClick={() => handleClick(id)} />     // new function every render
{items.map((item, i) => <Item key={i} />)}        // index as key
<Component {...props} />                          // spreading unknown props
```

### 5.1b Next.js Performance [TECH: Next.js]

- [ ] Server Components used for static/data-fetching content (no client JS shipped)
- [ ] `next/image` for images (not raw `<img>`) -- auto-optimization, lazy loading
- [ ] `next/link` for internal navigation (not `<a>`) -- prefetching
- [ ] `next/font` for fonts (not external CSS @font-face) -- no layout shift
- [ ] Dynamic imports (`next/dynamic`) for heavy client components
- [ ] Route segments parallelized where possible (parallel routes)
- [ ] No `fetch()` in client components when server component could pre-fetch

### 5.2 Bundle & Memory

- [ ] No memory leaks (event listeners, intervals, subscriptions)
- [ ] Bundle size not significantly increased
- [ ] Lazy loading where possible
- [ ] No duplicate dependencies
- [ ] Dead code eliminated

### 5.3 Computation

- [ ] Heavy computations outside render path
- [ ] Web Workers for CPU-intensive (>100ms)
- [ ] Debounce/throttle expensive operations
- [ ] Pagination for large datasets
- [ ] Caching effective (and correctly invalidated)

---

## STEP 6: SIDE EFFECTS & REGRESSIONS

### 6.1 Test Impact

- [ ] Existing tests still pass
- [ ] New code has test coverage
- [ ] No tests skipped/disabled without reason
- [ ] Snapshot tests updated intentionally

### 6.2 System Impact

- [ ] Other modules using changed code
- [ ] Environment variables and configuration
- [ ] Build process and deployment
- [ ] Existing user data/sessions
- [ ] Cache invalidation (Redis, CDN, browser)
- [ ] Scheduled jobs / cron
- [ ] Webhooks / event listeners
- [ ] Analytics / tracking events

### 6.3 Test Quality

- [ ] Tests test BEHAVIOR, not implementation
- [ ] Tests deterministic (no flaky)
- [ ] Meaningful assertions (not just "doesn't throw")
- [ ] Test names: "should X when Y"
- [ ] Mocks minimal
- [ ] Edge cases tested
- [ ] Error paths tested
- [ ] No test interdependencies

Red flags [Jest/Vitest]:
```typescript
// Tests implementation, not behavior
expect(mockSetLoading).toHaveBeenCalledWith(true);

// Meaningless assertion
test('renders without crashing', () => { render(<C />); /* no assertions */ });

// Over-mocking
jest.mock('./api'); jest.mock('./utils'); jest.mock('./hooks'); jest.mock('./components');
```

Red flags [pytest]:
```python
# No assertions
def test_create_user():
    create_user("test")  # No assert -- what are we testing?

# Testing implementation, not behavior
mock_db.save.assert_called_once_with(expected)  # Fragile -- tests internals

# Fixture abuse -- too many layers of indirection
@pytest.fixture
def user(org, plan, role, permissions, settings):  # 5 fixture deps = smell

# Not using parametrize for similar cases
def test_valid_email_1(): ...
def test_valid_email_2(): ...  # Use @pytest.mark.parametrize instead
```

---

## STEP 7: SECURITY REVIEW [TIER 3]

### 7.1 Code Security

- [ ] No new vulnerabilities
- [ ] Input sanitization
- [ ] No hardcoded secrets
- [ ] Permissions/authorization preserved
- [ ] SQL injection impossible (parameterized)
- [ ] XSS impossible (proper escaping)
- [ ] CSRF protection
- [ ] Sensitive data not logged

Red flags [TypeScript/JavaScript]:
```typescript
db.query(`SELECT * FROM users WHERE id = ${userId}`);          // SQL injection
<div dangerouslySetInnerHTML={{ __html: userInput }} />          // XSS
<a href={userInput}>Click</a>                                    // javascript: XSS
const API_KEY = 'sk-1234567890';                                 // hardcoded secret
console.log('User:', { password, ssn });                         // PII logging
const token = Math.random().toString(36);                        // insecure random
fs.readFileSync(`./uploads/${userInput}`);                        // path traversal
```

Red flags [Python]:
```python
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")    # SQL injection
os.system(f"convert {user_filename}")                           # command injection
subprocess.call(user_input, shell=True)                         # command injection
data = pickle.loads(user_bytes)                                 # RCE via deserialization
data = yaml.load(user_input)                                    # use yaml.safe_load()
eval(user_expression)                                           # code execution
exec(user_code)                                                 # code execution
open(f"./uploads/{user_path}")                                  # path traversal
SECRET_KEY = "hardcoded-secret-123"                             # hardcoded secret
logging.info(f"Login: {username} / {password}")                 # PII logging
```

### 7.2 Dependency Security [conditional: new deps]

- [ ] `npm audit` / `pip audit` clean
- [ ] New deps trustworthy (>10k downloads/wk, <6mo last update, >1 maintainer)
- [ ] Licenses compatible
- [ ] No unnecessary deps (native API available?)

---

## STEP 8: INTERNATIONALIZATION [conditional: user-facing strings]

- [ ] Hardcoded strings extracted to translations
- [ ] Date/number formatting respects locale
- [ ] RTL supported (if applicable)
- [ ] Pluralization correct
- [ ] No string concatenation that breaks translations
- [ ] Currency formatting correct

---

## STEP 9: OBSERVABILITY

- [ ] Appropriate logs added (with context, not spam)
- [ ] Log levels appropriate
- [ ] Sensitive data not logged
- [ ] Correlation IDs propagated
- [ ] Error tracking (Sentry) will catch new errors
- [ ] Error messages actionable
- [ ] Stack traces preserved

---

## STEP 10: ROLLBACK READINESS [TIER 3]

- [ ] Clear rollback plan
- [ ] DB changes reversible
- [ ] Feature flags for risky changes
- [ ] Restore previous version <15 min
- [ ] Backward compatibility during transition

---

## STEP 11: DOCUMENTATION

- [ ] README updated (if needed)
- [ ] API docs current
- [ ] Inline comments current
- [ ] TODOs justified with ticket number
- [ ] Environment variables documented

---

## DEPENDENCY IMPACT ANALYSIS [TIER 2+3]

### Who Calls This Code?
```
Direct callers (files that import this):
Transitive callers (who calls the callers):
```

### What Does This Code Call?
```
Direct dependencies:
External effects:
  [ ] Database?  [ ] External API?  [ ] LocalStorage?
  [ ] File system?  [ ] Global state?  [ ] URL/routing?
```

### Change Propagation
| If This Changes... | What Breaks? | How to Verify? |
|--------------------|--------------|----------------|
| Interface/types | [dependents] | TypeScript compilation |
| Behavior | [affected flows] | [tests] |
| Return value shape | [consumers] | Integration tests |

---

## REPORT FORMAT

```markdown
# ARCHITECT'S REVIEW REPORT: [Branch/PR Name]

## META
Reviewer: Claude
Date: [YYYY-MM-DD]
Code Executed Locally: [YES/NO]
Change Intent: [BUGFIX/REFACTOR/FEATURE/INFRA]

## TECH STACK
[filled block]

## TRIAGE
Tier: [1/2/3] - [LIGHT/STANDARD/DEEP]
Reasoning: [why this tier]
Mode 2 Allowed: [YES/NO]
Conditional sections: [list or none]

## SCOPE FENCE
Allowed Files: [list]
Forbidden: files outside scope, new APIs, new deps

## FINAL VERDICT: [APPROVE / APPROVE WITH COMMENTS / REQUEST CHANGES / REJECT]

| Metric | Value |
|--------|-------|
| Overall Score | [X/10] |
| Risk Level | [Low/Medium/High/Critical] |
| Confidence | [High/Medium/Low] |

## SUMMARY OF CHANGES
[2-3 sentences]
Files: [X], Lines: +[Y]/-[Z]

## SKIPPED STEPS
| Step | Reason |

## VERIFICATION PASSED
[what's OK -- be specific]

## CRITICAL & HIGH ISSUES (Must Fix -- Confidence >= 75 only)
[ordered by blast radius, each with: ID, severity, confidence score, location, current code, problem, impact, pre-existing check, fix, verification]

## MEDIUM & LOW ISSUES
[each with: ID, severity, category, location, issue, fix]

## QUESTIONS FOR AUTHOR

## QUALITY WINS

## TEST ANALYSIS
### Test Validity Gate (BLOCKING)
| Area | Rule | Status |
| Required tests | No TODO/SKIP | PASS/FAIL |
| Behavior coverage | Changed logic has tests | PASS/FAIL |

### Missing Tests (BLOCKING)
| ID | Scenario | Why Required | File |

### Recommended Tests
| ID | Scenario | Priority |

## METRICS DELTA
| Metric | Before | After | Change | Status | Source |

## REQUIRED ACTIONS
### BLOCKING (must fix):
### BEFORE PRODUCTION (can merge to staging):
### TECH DEBT (backlog):

## FINAL QUALITY SCORECARD
| Category | Score | Notes |
| Code Quality | [0-10] | |
| Type Safety | [0-10] | |
| Performance | [+/-/=] | |
| Security | [+/-/=] | |
| Maintainability | [0-10] | |
| Test Coverage | [0-10] | |
| OVERALL | [0-10] | |

## EXECUTION PLAN
### Step 1: Fix -- [checklist]
### Step 2: Write Tests -- [checklist]
### Step 3: Run Tests
### Step 4: Re-audit
### Step 5: Commit

Suggested Commit Message:
review-fix: [brief description of fixes applied]

## TESTS TO IMPLEMENT
| ID | File | Scenario | Notes |
```

---

## CONFIDENCE RE-SCORING GATE

After completing ALL audit steps, before writing the final report:
1. List every candidate issue found
2. Score each 0-100 (see rules for scale)
3. Run git blame on each -- mark pre-existing issues
4. Check against false positive filter (see rules)
5. Report ALL issues -- do NOT drop by score (user wants full visibility)
6. Sort issues by severity (CRITICAL -> HIGH -> MEDIUM -> LOW), then by confidence desc

Show all findings so the user can decide what to act on.

---

## REVIEWER SELF-CHECK

Thoroughness:
- [ ] Did I actually RUN the code?
- [ ] Did I check the ticket/requirements?
- [ ] Did I trace at least one complete flow?
- [ ] Did I check what OTHER files use the changed code?

Fairness:
- [ ] Am I blocking on style preferences, not real issues?
- [ ] Would I accept this feedback if given to me?

Actionability:
- [ ] Actionable feedback, not just criticism?
- [ ] WHY something is an issue, not just that it is?
- [ ] Clear path to resolution for each issue?
- [ ] Issues prioritized?

---

*Protocol Version: 2.1*
