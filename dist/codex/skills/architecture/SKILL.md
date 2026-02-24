---
name: architecture
description: "Create Architecture Decision Records (ADRs) or design systems. Use for 'should we use X or Y', 'how should we architect', 'system design for', 'document this decision', or any technical decision needing structured trade-off analysis."
---

# /architecture -- ADR & System Design

Two modes: create an ADR for a decision already being made, or design a system from requirements.

## Parse $ARGUMENTS

| Input | Action |
|-------|--------|
| _(empty)_ | Ask: "What decision or system are you working on?" |
| "should we use X or Y…" | ADR mode -- structured trade-off comparison |
| "design a system for…" | System design mode -- full requirements -> design |
| "document this decision…" | ADR mode -- formalize a decision already made |
| "evaluate this proposal…" | ADR mode -- review an existing design |

---

## Mode 1: ADR -- Architecture Decision Record

### When to use
Capturing a significant technical decision: framework choice, data store selection, communication pattern, API design approach, auth strategy, etc.

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

## Mode 2: System Design

### When to use
Designing a new service, API, or subsystem from requirements.

### Framework (5 Steps)

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

**Step 5 -- Trade-offs & Open Questions**
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

Number sequentially. Never delete -- supersede with a new ADR instead.
