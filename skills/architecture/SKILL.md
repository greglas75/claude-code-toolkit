---
name: architecture
description: "Architecture skill — three modes: (1) review existing project architecture, (2) create ADRs for decisions, (3) design new systems. Use for 'review the architecture of [path]', 'should we use X or Y', 'design a system for', 'document this decision', or any technical decision needing structured trade-off analysis. NOT for 1-2 file changes (overkill — use /review)."
user-invocable: true
---

# /architecture — Review, ADR & System Design

Three modes: audit an existing codebase architecture, create an ADR for a decision, or design a new system from requirements.

## Parse $ARGUMENTS

| Input | Action |
|-------|--------|
| _(empty)_ | Ask: "What would you like to do? (review [path] / adr / design)" |
| `review [path]` | Architecture Review mode — scan codebase, assess structure and health |
| `review` (no path) | Architecture Review mode — scan current directory |
| "should we use X or Y…" | ADR mode — structured trade-off comparison |
| "design a system for…" | System design mode — full requirements → design |
| "document this decision…" | ADR mode — formalize a decision already made |
| "evaluate this proposal…" | ADR mode — review an existing design |

---

## Mode 1: Architecture Review

### When to use
Understanding and evaluating an existing codebase — before a major refactor, onboarding, tech debt planning, or when something "feels wrong" structurally.

### Step 1 — Read the project structure

Before any assessment, read actual files. In order:
1. `package.json` / `pyproject.toml` / `composer.json` — dependencies, scripts, stack
2. Directory tree (top 2 levels) — module boundaries visible from folder names
3. Entry points: `main.ts`, `app.module.ts`, `index.ts`, `server.ts` etc.
4. Key domain files: services, controllers, models (sample, not all)
5. `README.md`, `CLAUDE.md`, any `docs/` folder

**Never write the review from memory. Read first.**

### Step 2 — Map the architecture

Identify:
- **Layers:** presentation / application / domain / infrastructure — are they present and respected?
- **Module boundaries:** what are the main modules/services? are they cohesive?
- **Data flow:** how does a request travel from entry point to DB and back?
- **External dependencies:** external APIs, queues, caches — how coupled are they?
- **Cross-cutting concerns:** auth, logging, error handling — centralized or scattered?

### Step 3 — Score against 8 dimensions

| # | Dimension | What to check |
|---|-----------|--------------|
| A1 | **Modularity** | Clear module boundaries? Low coupling, high cohesion? |
| A2 | **Layering** | Layers respected? (No DB calls in controllers, no business logic in repositories) |
| A3 | **Dependency direction** | Dependencies point inward (domain doesn't depend on infra)? |
| A4 | **Single responsibility** | God classes / god modules? One module doing too many things? |
| A5 | **Scalability** | Horizontal scaling possible? Any shared mutable state blocking it? |
| A6 | **Testability** | Pure business logic isolated from I/O? Easy to unit test core? |
| A7 | **Observability** | Logging, metrics, tracing present? Correlation IDs? |
| A8 | **Security boundary** | Auth/authz at layer boundary? Input validated at entry point only? |

Score each: **Good** / **Needs work** / **Critical issue** + 1-line evidence.

### Step 4 — Identify top problems

For each Critical or Needs-work dimension, describe:
- **Pattern:** what's wrong (e.g., "Circular dependency between UserModule and AuthModule")
- **Risk:** what breaks if this stays (e.g., "Can't test UserService in isolation")
- **Fix:** concrete recommendation (e.g., "Extract shared AuthToken type to shared/types")

### Output — Architecture Review Report

```markdown
# Architecture Review: [Project Name]

**Date:** [YYYY-MM-DD]
**Stack:** [framework, language, key dependencies]
**Scope:** [which modules/paths were reviewed]

## Overview

[2-3 sentences: overall assessment — is this clean, messy, mixed?]

## Architecture Map

[ASCII or described component diagram showing key modules and data flow]

## Dimension Scores

| Dimension | Score | Evidence |
|-----------|-------|----------|
| A1 Modularity | Good / Needs work / Critical | [1-line finding] |
| A2 Layering | ... | ... |
| A3 Dependency direction | ... | ... |
| A4 Single responsibility | ... | ... |
| A5 Scalability | ... | ... |
| A6 Testability | ... | ... |
| A7 Observability | ... | ... |
| A8 Security boundary | ... | ... |

## Critical Issues

### [Issue title]
- **Pattern:** [what's wrong]
- **Risk:** [consequence if not fixed]
- **Fix:** [specific recommendation]
- **Files:** [key file:line references]

## Needs-Work Items

[Same format, lower severity]

## Strengths

[What's done well — architecture review should surface positives too]

## Recommendations

Prioritized by impact:
1. [Highest priority fix]
2. [Second priority]
3. [Third priority]

MANDATORY: run /backlog add for each Critical issue before finishing.
```

---

## Mode 2: ADR — Architecture Decision Record

### When to use
Capturing a significant technical decision: framework choice, data store selection, communication pattern, API design approach, auth strategy, etc.

### Step 1: Extract context

Before writing the ADR, gather:
- **The decision question** (concrete: "Use Kafka vs SQS for event bus")
- **Constraints** (timeline, team expertise, cost, existing stack)
- **Forces at play** (competing requirements driving the decision)
- **Options being considered** (at least 2 — even if one is clearly preferred)

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

### Step 3: Output — ADR Format

```markdown
# ADR-[N]: [Title — specific decision question]

**Status:** Proposed | Accepted | Deprecated | Superseded by ADR-[N]
**Date:** [YYYY-MM-DD]
**Deciders:** [Who needs to sign off]
**Context area:** [Auth / Data / Infra / API / Frontend / ...]

## Context

[What situation requires this decision? What forces or constraints are at play?
2-4 sentences. No solution yet — just the problem.]

## Decision

[What we are proposing to do. One clear sentence.]

## Options Considered

### Option A: [Name]

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low / Medium / High — [why] |
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
[Always consider this — sometimes the cost of change outweighs the benefit]

## Trade-off Analysis

[The key trade-offs between the top options. Where they differ most. What makes this decision hard.
Not a repeat of pros/cons — synthesize: "Option A wins on X and Y but loses on Z. Option B is better if [condition]." ]

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

### Framework (5 Steps)

**Step 1 — Requirements**
- Functional: what does it do? (user stories or capabilities)
- Non-functional: scale (RPS, users), latency (P50/P99), availability (SLA), cost constraints
- Constraints: team size, timeline, existing tech stack, compliance

**Step 2 — High-Level Design**
- Component diagram (ASCII or described): services, stores, queues, clients
- Data flow: how does data move from input to output?
- API contracts: what interfaces exist between components?
- Storage choices: which data store for which data, and why?

**Step 3 — Deep Dive** (pick the hardest parts)
- Data model: entities, relationships, indexes
- API design: endpoints, request/response shapes, pagination
- Caching strategy: what, where, TTL, invalidation
- Queue/event design: topics, consumers, at-least-once vs exactly-once
- Error handling: retry logic, dead-letter queues, circuit breakers

**Step 4 — Scale & Reliability**
- Load estimation: peak RPS, data volume, storage growth
- Bottlenecks: where does this break first?
- Horizontal scaling: which components need it?
- Failover: what happens when each component fails?
- Monitoring: which metrics indicate health?

**Step 5 — Trade-offs & Open Questions**
- Every design decision has trade-offs — make them explicit
- List assumptions that could change the design
- Identify what you'd revisit at 10x scale

### Output — Design Doc

```markdown
# [System Name] — Design Document

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
[Client] → [API Gateway] → [Service A] → [DB]
                                ↓
                          [Queue] → [Worker] → [External API]
```

## Data Model
[Key entities, relationships, important indexes]

## API Design
[Key endpoints with request/response shapes]

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

## Storing ADRs

Recommend storing in `docs/adr/` or `architecture/decisions/` in the repo:
```
docs/adr/
  0001-use-postgres-for-primary-store.md
  0002-use-kafka-for-event-bus.md
  0003-use-jwt-for-auth.md
```

Number sequentially. Never delete — supersede with a new ADR instead.
