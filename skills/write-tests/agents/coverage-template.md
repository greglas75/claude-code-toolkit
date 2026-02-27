---
name: coverage-template
description: "Coverage registry template, column definitions, and cross-skill usage. Read by /write-tests Phase 5.1b."
---

# Coverage Registry — Template & Reference

Read this file at **Phase 5.1b** when creating or updating `memory/coverage.md`.

---

## Template (create if `memory/coverage.md` does not exist)

```markdown
# Test Coverage Registry

> Auto-maintained by `/write-tests`, `/build`, `/refactor`, `/review`, `/fix-tests`.
> Updated after each test writing session. Read at start to skip re-scanning.

| File | Status | Methods | Covered | Test file | Risk | Updated | Source | Duration | TestRunTime |
|------|--------|---------|---------|-----------|------|---------|--------|----------|-------------|
```

---

## Column Definitions

| Column | Values | Description |
|--------|--------|-------------|
| **Status** | UNCOVERED \| PARTIAL \| PARTIAL-QUALITY \| COVERED | Coverage tier. PARTIAL-QUALITY = has tests but auto-fail patterns (typeof ≥3×, toBeDefined-only) or untested branches despite 100% method coverage → action: FIX in `/write-tests` (or `/fix-tests` for 10+ files with same pattern) |
| **Methods** | integer | Total exported methods/functions count |
| **Covered** | integer | Methods with at least one test (0 for UNCOVERED) |
| **Test file** | path or "none" | Path to test file |
| **Risk** | HIGH \| MEDIUM \| LOW | Risk classification |
| **Updated** | YYYY-MM-DD | Date of last update |
| **Source** | string | Which skill updated it (e.g., `write-tests/auto`, `build/phase-3`, `refactor/etap-1b`) |
| **Duration** | e.g., `3m`, `12m` | Time spent writing tests in this session. Set `—` for scan-only entries. |
| **TestRunTime** | e.g., `13ms`, `361ms`, `2.1s` | Execution time from test runner output (Vitest Duration, Jest Time, pytest passed-in). Used to identify slow tests. |

---

## Cross-Skill Usage

Any skill that writes tests SHOULD update `memory/coverage.md`:

| Skill | When |
|-------|------|
| `/build` | Phase 3.4 (test writing) → update files it tested |
| `/refactor` | ETAP-1B (test writing) → update files it tested |
| `/fix-tests` | After repairing tests → update files repaired |
| `/review fix` | Execute stage → update files it wrote tests for |
| `/test-audit` | After audit → update Status (downgrade COVERED → PARTIAL if score < 14/17 or critical gate fails) |
