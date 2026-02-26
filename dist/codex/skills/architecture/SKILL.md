---
name: architecture
description: "Architecture skill -- three modes: (1) review existing project architecture, (2) create ADRs for decisions, (3) design new systems. Use for 'review the architecture of [path]', 'should we use X or Y', 'design a system for', 'document this decision', or any technical decision needing structured trade-off analysis. NOT for 1-2 file changes (overkill -- use /review)."
---

# /architecture -- Review, ADR & System Design

Three modes: audit an existing codebase architecture, create an ADR for a decision, or design a new system from requirements.

## Parse $ARGUMENTS

**Explicit flags (preferred -- no ambiguity):**

| Flag | Action |
|------|--------|
| `--mode review [path]` | Architecture Review mode -- scan codebase, assess structure and health |
| `--mode adr` | ADR mode -- create/evaluate an architecture decision record |
| `--mode design` | System Design mode -- full requirements -> design |

**Heuristic fallback (when no `--mode` flag):**

| Input | Detected Mode |
|-------|---------------|
| _(empty)_ | Ask: "What would you like to do? (review [path] / adr / design)" |
| `review [path]` | Review mode |
| `review` (no path) | Review mode -- scan current directory |
| "should we use X or Y…" | ADR mode |
| "design a system for…" | Design mode |
| "document this decision…" | ADR mode |
| "evaluate this proposal…" | ADR mode |

**Ambiguous input:** if heuristic is uncertain, ask the user to confirm mode before proceeding.

---

## Mode 1: Architecture Review

### When to use
Understanding and evaluating an existing codebase -- before a major refactor, onboarding, tech debt planning, or when something "feels wrong" structurally.

### Step 1 -- Read the project structure

Before any assessment, read actual files. In order:
1. `package.json` / `pyproject.toml` / `composer.json` -- dependencies, scripts, stack
2. Directory tree (top 2 levels) -- module boundaries visible from folder names
3. Entry points: `main.ts`, `app.module.ts`, `index.ts`, `server.ts` etc.
4. Key domain files: services, controllers, models (sample, not all)
5. `README.md`, `CLAUDE.md`, any `docs/` folder
6. **Test infrastructure** -- discover test locations and runner config (see below)

#### Test discovery (MANDATORY for A6 scoring)

Tests can live in multiple locations. Check ALL of these -- do NOT stop at the first miss:

| Location type | Where to look |
|--------------|---------------|
| Co-located | `*.test.ts`, `*.spec.ts`, `*.test.tsx` next to source files |
| Centralized dirs | `__tests__/`, `tests/`, `test/`, `spec/` at root or inside `src/` |
| Runner config | `jest.config.*` -> `testMatch`/`roots`; `vitest.config.*` -> `include`; `pytest.ini`/`pyproject.toml` -> `testpaths`; `phpunit.xml` -> `<testsuite>` paths; `codeception.yml` -> `paths: tests:` |
| CI config | `.github/workflows/` or CI config -- check which test command runs and from which directory |

**Procedure:**
1. Read test runner config file to determine configured test paths
2. Check each configured path for actual test files
3. If no runner config found -> glob for `**/*.test.*`, `**/*.spec.*`, `**/__tests__/**` across the project
4. Record: test location pattern (co-located / centralized / mixed), approximate test count, coverage config presence

**Never score A6 without completing test discovery.** "No tests found" is only valid after checking ALL location types above.

**Never write the review from memory. Read first.**

### Scope Bounding (when `[path]` is specified)

When reviewing a specific path (`--mode review src/billing`):
- **Step 1-2:** read structure and map architecture **within the path only**. Cross-boundary imports (from outside the path into it, and from it outward) are noted as external dependencies but not audited.
- **Step 2.5 metrics:** compute fan-in/fan-out, LOC, cycles **for modules inside the path**. External modules appear only as edge nodes (fan-in/fan-out targets, not scored).
- **Step 3 scoring:** A1-A8 scored **for the scoped path**. If a dimension is unobservable within scope (e.g., A7 Observability when only reviewing a utility module), mark as N/A with justification.
- **Step 4 + report:** issues and recommendations scoped to the path. Broader architectural concerns noted in a separate "Out of Scope Observations" section (not scored, not in backlog).

When `[path]` is omitted or set to project root -> full-project review, no scope restriction.

### Step 2 -- Map the architecture

Identify:
- **Layers:** presentation / application / domain / infrastructure -- are they present and respected?
- **Module boundaries:** what are the main modules/services? are they cohesive?
- **Data flow:** how does a request travel from entry point to DB and back?
- **External dependencies:** external APIs, queues, caches -- how coupled are they?
- **Cross-cutting concerns:** auth, logging, error handling -- centralized or scattered?

### Step 2.5 -- Structural metrics (MANDATORY)

Before qualitative scoring, gather these metrics. They provide evidence for A1-A4 and prevent subjective drift.

1. **Dependency cycles:** check for circular imports between modules/directories. Use import analysis (grep for cross-module imports, check if A->B->A or A->B->C->A). Report: cycle count + paths.
2. **Fan-in / fan-out per module:** for each top-level module, count how many other modules import it (fan-in) and how many it imports (fan-out). High fan-out (>5) = coupling risk. High fan-in (>8) = fragile shared module.
3. **Module size:** LOC per top-level module/directory. Flag modules >2000 LOC (potential god module).
4. **Instability index:** per module: `I = fan-out / (fan-in + fan-out)`. Stable (I<0.3) modules should be abstract; unstable (I>0.7) modules should be concrete. Flag violations.

Report these in a `## Structural Metrics` section before the dimension scores.

### Step 3 -- Score against 8 dimensions

| # | Dimension | What to check |
|---|-----------|--------------|
| A1 | **Modularity** | Clear module boundaries? Low coupling, high cohesion? |
| A2 | **Layering** | Layers respected? (No DB calls in controllers, no business logic in repositories) |
| A3 | **Dependency direction** | Dependencies point inward (domain doesn't depend on infra)? |
| A4 | **Single responsibility** | God classes / god modules? One module doing too many things? |
| A5 | **Scalability** | Horizontal scaling possible? Any shared mutable state blocking it? |
| A6 | **Testability** | Tests exist and cover core logic? (use Step 1 test discovery results) Pure business logic isolated from I/O? Easy to unit test? |
| A7 | **Observability** | Logging, metrics, tracing present? Correlation IDs? |
| A8 | **Security boundary** | Auth/authz at layer boundary? Input validated at entry point only? |

Score each dimension **0-3**:

| Score | Label | Meaning |
|-------|-------|---------|
| 3 | Good | No issues found, pattern correctly applied |
| 2 | Minor gaps | Small deviations, low risk, easy fix |
| 1 | Needs work | Significant issues, structural risk if not addressed |
| 0 | Critical | Architectural violation actively causing problems |

Each score requires **1-line evidence** (file:line or pattern reference).

**Weighted total:** `A_total = sum(A1..A8) / 24 × 100%`

| Total | Verdict | Action |
|-------|---------|--------|
| >=80% | Healthy | Minor improvements only |
| 60-79% | Needs attention | Plan targeted refactoring |
| 40-59% | Significant issues | Prioritized rework sprint |
| <40% | Critical | Architecture overhaul needed |

**Critical gate:** any A1-A4 = 0 -> verdict capped at **no higher than** "Significant issues" (structural fundamentals broken). If total <40%, verdict stays "Critical" -- the cap only prevents upgrading past "Significant".

### Step 4 -- Identify top problems

For each Critical or Needs-work dimension, describe:
- **Pattern:** what's wrong (e.g., "Circular dependency between UserModule and AuthModule")
- **Risk:** what breaks if this stays (e.g., "Can't test UserService in isolation")
- **Fix:** concrete recommendation (e.g., "Extract shared AuthToken type to shared/types")

### Output -- Architecture Review Report

```markdown
# Architecture Review: [Project Name]

**Date:** [YYYY-MM-DD]
**Stack:** [framework, language, key dependencies]
**Scope:** [which modules/paths were reviewed]

## Overview

[2-3 sentences: overall assessment -- is this clean, messy, mixed?]

## Architecture Map

[ASCII or described component diagram showing key modules and data flow]

## Structural Metrics

| Module | LOC | Fan-in | Fan-out | Instability | Flags |
|--------|-----|--------|---------|-------------|-------|
| [module] | [N] | [N] | [N] | [0.0-1.0] | [>2000 LOC / high fan-out / cycle] |

Dependency cycles: [N found -- list paths, or "none"]

## Dimension Scores

| Dimension | Score (0-3) | Evidence |
|-----------|-------------|----------|
| A1 Modularity | [0-3] | [1-line finding] |
| A2 Layering | [0-3] | ... |
| A3 Dependency direction | [0-3] | ... |
| A4 Single responsibility | [0-3] | ... |
| A5 Scalability | [0-3] | ... |
| A6 Testability | [0-3] | ... |
| A7 Observability | [0-3] | ... |
| A8 Security boundary | [0-3] | ... |

**Total: [N]/24 ([N]%) -> [Healthy/Needs attention/Significant issues/Critical]**
**Critical gate: A1=[N] A2=[N] A3=[N] A4=[N] -> [PASS/FAIL]**

## Critical Issues

### [Issue title]
- **Pattern:** [what's wrong]
- **Risk:** [consequence if not fixed]
- **Fix:** [specific recommendation]
- **Files:** [key file:line references]

## Needs-Work Items

[Same format, lower severity]

## Strengths

[What's done well -- architecture review should surface positives too]

## Recommendations

Prioritized by impact:
1. [Highest priority fix]
2. [Second priority]
3. [Third priority]

MANDATORY: run /backlog add for each Critical issue before finishing.
```

---

## Mode 2: ADR -- Architecture Decision Record

### When to use
Capturing a significant technical decision: framework choice, data store selection, communication pattern, API design approach, auth strategy, etc.

### Step 0: Check existing ADRs (MANDATORY)

Before writing a new ADR, search for existing ones:
1. Check `docs/adr/`, `architecture/decisions/`, `adr/` directories
2. Search for ADRs covering the same topic (keyword match on title/context)
3. If related ADR exists:
   - **Same decision:** update status of existing ADR instead of creating duplicate
   - **Conflicting decision:** new ADR must reference the old one with `Supersedes: ADR-[N]` and update old ADR status to `Superseded by ADR-[N]`
   - **Related but different:** add `Related: ADR-[N]` cross-reference
4. Determine next ADR number from existing files

### Step 1: Extract context

Before writing the ADR, gather:
- **The decision question** (concrete: "Use Kafka vs SQS for event bus")
- **Constraints** (timeline, team expertise, cost, existing stack)
- **Forces at play** (competing requirements driving the decision)
- **Options being considered** (at least 2 -- even if one is clearly preferred)

### Step 2: Evaluate each option

Score each option across these dimensions:

| Dimension | What to assess |
|-----------|---------------|
| Complexity | How hard to implement, operate, debug? |
| Cost | Infrastructure, licensing, operational overhead |
| Scalability | Does it handle 10x growth? Where does it break? |
| Team familiarity | Does the team know this? Learning curve? |
| Maintenance | How painful to keep running over 2+ years? |
| Lock-in | How easy to migrate away if this turns out wrong? |

### Step 3: Output -- ADR Format

```markdown
# ADR-[N]: [Title -- specific decision question]

**Status:** Proposed | Accepted | Deprecated | Superseded by ADR-[N]
**Date:** [YYYY-MM-DD]
**Deciders:** [Who needs to sign off]
**Context area:** [Auth / Data / Infra / API / Frontend / ...]

## Context

[What situation requires this decision? What forces or constraints are at play?
2-4 sentences. No solution yet -- just the problem.]

## Decision

[What we are proposing to do. One clear sentence.]

## Options Considered

### Option A: [Name]

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low / Medium / High -- [why] |
| Cost | [estimate or relative] |
| Scalability | [ceiling and growth path] |
| Team familiarity | [current knowledge level] |
| Maintenance | [operational burden over time] |
| Lock-in | [migration cost if wrong] |

**Pros:**
- [Specific advantage]
- [Specific advantage]

**Cons:**
- [Specific disadvantage]
- [Specific disadvantage]

### Option B: [Name]
[Same format]

### Option C: Status Quo / Do Nothing
[Always consider this -- sometimes the cost of change outweighs the benefit]

## Trade-off Analysis

[The key trade-offs between the top options. Where they differ most. What makes this decision hard.
Not a repeat of pros/cons -- synthesize: "Option A wins on X and Y but loses on Z. Option B is better if [condition]." ]

## Decision Rationale

[Why this option. Connect to specific constraints and requirements from Context.
"We chose Option A because [constraint from Context] makes [Advantage of A] the dominant concern."]

## Consequences

**Becomes easier:**
- [What this enables]

**Becomes harder:**
- [What this constrains or complicates]

**What to revisit:**
- [Trigger conditions that would change this decision]
- [Timeline for reviewing if assumptions hold]

## Action Items

- [ ] [Implementation step 1]
- [ ] [Implementation step 2]
- [ ] [Document/communicate to team]
```

---

## Mode 3: System Design

### When to use
Designing a new service, API, or subsystem from requirements.

### Framework (6 Steps)

**Step 1 -- Requirements**
- Functional: what does it do? (user stories or capabilities)
- Non-functional: scale (RPS, users), latency (P50/P99), availability (SLA), cost constraints
- Constraints: team size, timeline, existing tech stack, compliance

**Step 2 -- High-Level Design**
- Component diagram (ASCII or described): services, stores, queues, clients
- Data flow: how does data move from input to output?
- API contracts: what interfaces exist between components?
- Storage choices: which data store for which data, and why?

**Step 3 -- Deep Dive** (pick the hardest parts)
- Data model: entities, relationships, indexes
- API design: endpoints, request/response shapes, pagination
- Caching strategy: what, where, TTL, invalidation
- Queue/event design: topics, consumers, at-least-once vs exactly-once
- Error handling: retry logic, dead-letter queues, circuit breakers

**Step 4 -- Scale & Reliability**
- Load estimation: peak RPS, data volume, storage growth
- Bottlenecks: where does this break first?
- Horizontal scaling: which components need it?
- Failover: what happens when each component fails?
- Monitoring: which metrics indicate health?

**Step 5 -- Rollout & Migration (MANDATORY)**
- **Migration plan:** how to get from current state to new design (if replacing existing system)
- **Backward compatibility:** what breaks, what needs dual-write/dual-read period
- **Rollout strategy:** big bang / gradual / feature flag / canary -- and why
- **Rollback plan:** how to revert if deployment fails -- data rollback, API compatibility
- **Timeline:** phases with milestones and go/no-go criteria

**Step 6 -- Trade-offs & Open Questions**
- Every design decision has trade-offs -- make them explicit
- List assumptions that could change the design
- Identify what you'd revisit at 10x scale

### Output -- Design Doc

```markdown
# [System Name] -- Design Document

**Status:** Draft | Review | Approved
**Author(s):** [Names]
**Date:** [YYYY-MM-DD]
**Related ADRs:** [ADR-N links if applicable]

## Summary
[2-3 sentences: what this system does and the key design choices]

## Requirements

### Functional
- [Capability 1]
- [Capability 2]

### Non-Functional
- Scale: [RPS, users, data volume]
- Latency: [P50/P99 targets]
- Availability: [SLA]

### Constraints
- [Timeline, team, stack, compliance]

## High-Level Design

[ASCII diagram or description of components]

```
[Client] -> [API Gateway] -> [Service A] -> [DB]
                                ↓
                          [Queue] -> [Worker] -> [External API]
```

## Data Model
[Key entities, relationships, important indexes]

## API Design
[Key endpoints with request/response shapes]

## Rollout & Migration

### Migration Plan
- [Step-by-step from current state to new design, or "Greenfield -- no migration needed"]

### Backward Compatibility
- [What breaks, dual-write/dual-read requirements, API versioning]

### Rollout Strategy
- [big bang / gradual / feature flag / canary -- and why]

### Rollback Plan
- [How to revert if deployment fails -- data rollback, API compatibility]

### Timeline
- [Phases with milestones and go/no-go criteria]

## Trade-offs

| Decision | Chose | Alternative | Why |
|----------|-------|-------------|-----|
| [e.g. DB] | Postgres | Mongo | [reason] |

## Open Questions
- [Question that needs resolution before implementation]
- [Assumption to validate]

## What to Revisit at Scale
- [Trigger: if X, then reconsider Y]
```

---

## Backlog Integration (ALL MODES -- MANDATORY)

After completing any mode, persist risks and action items to backlog:

**Review mode:** run `/backlog add` for each Critical **and** Needs-work issue from the report. Critical = CRITICAL severity, Needs-work = HIGH severity.

**ADR mode:** run `/backlog add` for:
- Each item in "Becomes harder" (Consequences section) -- these are accepted trade-offs that need tracking
- Each "What to revisit" trigger -- schedule a review when trigger conditions approach
- Each Action Item that can't be completed immediately

**Design mode:** run `/backlog add` for:
- Each Open Question that blocks implementation
- Each "What to Revisit at Scale" trigger
- Each risk identified in Rollout/Migration plan (rollback scenarios, compatibility gaps)

**Zero risks may be silently discarded.** If the output has Consequences, Open Questions, or Risks -- they must end up in the backlog.

---

## Storing ADRs

Recommend storing in `docs/adr/` or `architecture/decisions/` in the repo:
```
docs/adr/
  0001-use-postgres-for-primary-store.md
  0002-use-kafka-for-event-bus.md
  0003-use-jwt-for-auth.md
```

Number sequentially. Never delete -- supersede with a new ADR instead.
