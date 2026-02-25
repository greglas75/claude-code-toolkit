# Skill Workflows -- When to Use What

Quick reference: which skill to run, in what order, and why.

---

## Decision Tree -- "I want to..."

```
I want to BUILD a new feature
  └─ 3+ files -> /build [description]
  └─ 1-2 files -> direct coding + CQ self-eval + tests

I want to FIX a bug
  └─ Cause unknown -> /debug [error/stack trace]
  └─ Cause known -> fix directly + /review [file]

I want to REFACTOR existing code
  └─ /refactor [description] or /refactor continue

I want to REVIEW code before pushing
  └─ /review staged       (staged, not yet committed)
  └─ /review HEAD~N       (last N commits)
  └─ /review [path]       (specific files)

I want to AUDIT code quality
  └─ Production code -> /code-audit [path]
  └─ Test files -> /test-audit [path]
  └─ API endpoints -> /api-audit [path]
  └─ System structure -> /architecture review [path]

I want to FIX systematic test issues
  └─ /fix-tests --triage   (discover what's broken)
  └─ /fix-tests --pattern [ID] [path]

I want to DOCUMENT something
  └─ New module/service -> /docs readme [path]
  └─ New endpoints -> /docs api [path]
  └─ Operational procedure -> /docs runbook [topic]
  └─ New developer joining -> /docs onboarding

I want to TRACK tech debt
  └─ /backlog add [description]
  └─ /backlog list
  └─ /backlog prioritize

I want to make an ARCHITECTURE DECISION
  └─ "Should we use X or Y" -> /architecture (ADR mode)
  └─ "Design a system for" -> /architecture (system design mode)
  └─ "Review the whole project" -> /architecture review [path]
```

---

## Workflow: New Feature

```
1. /build [feature description]
   ├─ Phases 1-4: analysis, plan, implement, verify
   ├─ Phase 5.2: auto /review staged (only changed files)
   └─ Phase 5.3: auto-commit + tag

2. Optional after build:
   ├─ /docs readme [path]   -- if new module/service created
   └─ /docs api [path]      -- if new endpoints added

3. git push origin [branch]
```

---

## Workflow: Bug Fix

```
1. /debug [error or "why does X happen"]
   └─ Output: root cause + fix + regression test

2. Apply the fix manually

3. /review [file]
   └─ Verifies fix quality, CQ, tests

4. commit + push
```

---

## Workflow: Refactoring

```
1. /refactor [task description]
   ├─ ETAP-1A: audit + plan -> HARD STOP for approval
   ├─ ETAP-1B: structural cleanup -> commit
   ├─ ETAP-2: extraction/assertion work -> commit per phase
   ├─ Phase 5: /review HEAD~[N] -> tag
   └─ Output: suggests /docs update if API changed

2. Optional after refactor:
   ├─ /code-audit [new files]   -- if large SPLIT/EXTRACT, verify CQ of new modules
   └─ /docs update [doc-file]   -- if API or module structure changed

3. git push origin [branch]
```

---

## Workflow: Code Quality Cleanup

```
1. /code-audit [path]
   └─ Output: tiered report (A/B/C/D) + routing suggestion

2. Based on routing:
   ├─ Tier D (critical)        -> fix directly + /review
   ├─ CQ14=0 in 2+ files       -> /refactor [duplicated files]
   ├─ Same CQ fails 3+ files   -> fix all + /review
   ├─ CQ18=0 (multi-store)     -> /build [sync mechanism]
   └─ A1/A2/A3 issues          -> /architecture review [path]

3. After fixes: /review [changed files] -> commit -> push
```

---

## Workflow: Test Quality Cleanup

```
1. /test-audit [path]
   └─ Output: tiered report + pattern breakdown

2. /fix-tests --triage [path]
   └─ Counts each pattern, asks which to fix

3. /fix-tests --pattern [ID] [path]
   └─ Parallel fixer agents per batch of 5 files

4. /review [fixed test files]
   └─ Verifies no regressions, validates Q1-Q17 improvement

5. commit + push
```

---

## Workflow: API Quality Audit

```
1. /api-audit [path]
   └─ Output: D1-D10 scores + routing suggestion

2. Based on routing:
   ├─ D1=0 (no validation)    -> /code-audit [controllers]
   ├─ D9<8 (auth gaps)        -> /code-audit [controllers]
   ├─ D3<3 (no pagination)    -> /refactor [services]
   └─ D10<3 (no docs)         -> /docs api [path]

3. After fixes: /review [changed files] -> commit -> push
```

---

## Workflow: Architecture Review

```
1. /architecture review [path]
   └─ Output: A1-A8 scores + critical issues + recommendations

2. For each Critical issue:
   ├─ /backlog add [issue]     -- track it
   └─ /refactor or /build      -- fix it (depending on scope)

3. For architectural decisions:
   └─ /architecture (ADR mode) -- document the decision in docs/adr/
```

---

## Backlog as Hub

Every skill writes to `memory/backlog.md`:

| Skill | Writes when |
|-------|------------|
| `/build` | Test Quality Auditor finds issues |
| `/refactor` | Post-Extraction Verifier + Test Auditor find issues |
| `/review` | Confidence gate drops issues (26-50), unfixed warnings |
| `/code-audit` | Tier B/C/D findings, confidence 26+ |
| `/test-audit` | Tier C/D, critical gate failures per file |
| `/api-audit` | All findings confidence 26+ |
| `/fix-tests` | SKIP + NEEDS_REVIEW files |
| `/debug` | Unrelated issues found during debugging |
| `/architecture` | Critical issues from review |

Manage with: `/backlog list` · `/backlog prioritize` · `/backlog fix B-{N}` · `/backlog add`

---

## When NOT to Use Each Skill

| Skill | Do NOT use when |
|-------|----------------|
| `/build` | Bug fix (use `/debug` + direct fix + `/review`) |
| `/build` | Pure refactoring (use `/refactor`) |
| `/refactor` | Adding new features (use `/build`) |
| `/code-audit` | You want immediate fixes (use `/review fix`) |
| `/test-audit` | You want immediate fixes (use `/fix-tests`) |
| `/review` | You haven't written any code yet |
| `/architecture` | Simple 1-2 file changes (overkill) |
| `/docs` | You haven't read the source files first (it will anyway) |
| `/fix-tests` | Tests are structurally wrong (rewrite needed, not pattern fix) |

---

## Skill Integration Map (quick reference)

```
/build ──────────────────────────► /review staged (auto, before commit)
  └─ suggests ──────────────────► /docs readme | /docs api

/refactor ───────────────────────► /review HEAD~N (auto, before tag)
  └─ suggests ──────────────────► /docs update
  └─ consider after ────────────► /code-audit [new files] (if large split)

/code-audit ─────────────────────► /refactor | /build | /review (via routing)
  └─ A1-A3 failures ────────────► /architecture review

/test-audit ─────────────────────► /fix-tests (via pattern routing)
  └─ after fix-tests ───────────► /review [fixed files]

/api-audit ──────────────────────► /code-audit | /refactor | /docs api (via routing)

/debug ──────────────────────────► fix -> /review [file] -> commit
  └─ unrelated issues ──────────► /backlog add

/architecture review ────────────► /backlog add | /refactor | /build
  └─ decisions ─────────────────► ADR in docs/adr/
```
