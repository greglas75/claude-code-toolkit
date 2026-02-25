---
name: review
description: "Code review with triage, audit, confidence scoring, and auto-fix. Use when reviewing code changes, PRs, or diffs. NOT before writing any code."
user-invocable: true
---

# /review — Code Review

Triage + full audit in one step. No separate "Go" command needed.

## File Loading (Tier-Aware)

Load files in two phases to minimize token cost. Do a quick diff stat FIRST to detect TIER 0.

### Pre-load check (before Phase 1)

Run `git diff --stat [scope]` (1 command). Count total lines changed and new files.

```
IF total lines < 15 AND no new production files (.ts/.tsx/.py — not *.test.*) → TIER 0
  Load Phase 1: rules.md ONLY (skip code-quality.md)
ELSE
  Load Phase 1: rules.md + code-quality.md
```

### Phase 1: Always Load

```
1. ✅/❌  ~/.claude/skills/review/rules.md        — Iron Rules, severity, confidence, backlog
2. ✅/❌  ~/.claude/rules/code-quality.md         — CQ1-CQ20 (skip if TIER 0)
```

**If ANY required Phase 1 file is ❌ → STOP.**

### Phase 2: Conditional Loading (after triage Step 4 — tier known)

Load each file ONLY when its trigger condition is met:

| File | Load When | Skip When |
|------|-----------|-----------|
| `~/.claude/review-protocol.md` | TIER 2+ | TIER 0 or TIER 1 |
| `~/.claude/rules/testing.md` | TIER 2+, OR diff contains `*.test.*`/`*.spec.*` files | TIER 0-1 with no test files |
| `~/.claude/test-patterns.md` | Diff contains `*.test.*`/`*.spec.*` files | No test files in diff |
| `~/.claude/rules/security.md` | Triage Step 6 flags SECURITY conditional section, OR TIER 3 | TIER 0-2 with no security signals |

Print loaded files after triage:
```
FILES LOADED: rules.md, code-quality.md [Phase 1]
              + review-protocol.md, testing.md [Phase 2 — TIER 2]
              (skipped: test-patterns.md — no test files, security.md — no security signals)
```

**If a Phase 2 file is needed but unreadable → STOP.**

After reading, print step name before executing each step:
- `STEP: Triage` (tier + mode)
- `STEP: Scope Fence`
- `STEP: Audit` (which auditors, solo or team?)
- `STEP: CQ1-CQ20` (or N/A with reason)
- `STEP: Q1-Q17` on each test file (individual scores, critical gate)
- `STEP: Confidence Gate` (re-scorer)
- `STEP: 7.0 Compliance`
- `STEP: Report`

## Path Resolution (non-Claude-Code environments)

If running in Antigravity, Cursor, or other IDEs where `~/.claude/` is not accessible, resolve paths from `_agent/` in project root:
- `~/.claude/skills/` → `_agent/skills/`
- `~/.claude/rules/` → `_agent/rules/`
- `~/.claude/review-protocol.md` → `_agent/review-protocol.md`
- `~/.claude/test-patterns.md` → `_agent/test-patterns.md`

## Progress Tracking

## Tool Availability (Cursor / Codex / Antigravity)

Different environments have different tools. Adapt as follows:

| Tool | Claude Code | Cursor | Codex | Antigravity |
|------|-------------|--------|-------|-------------|
| `Task` (spawn agents) | ✅ | ❌ | ❌ | ❌ |
| `AskUserQuestion` | ✅ | ❌ | ❌ | ❌ |
| `TaskCreate` (progress tracking) | ✅ | ❌ | ❌ | ❌ |
| File read/write, Bash, git | ✅ | ✅ | ✅ | ✅ |

**If `Task` tool NOT available:**
- Skip all "Spawn via Task tool" blocks — do NOT attempt to call tools that don't exist
- Execute agent work **inline**, sequentially — read the agent's prompt and perform that analysis directly
- Model routing is ignored — use whatever model you are running on

**If `AskUserQuestion` NOT available (Cursor, Codex, Antigravity):**
- Skip all interactive prompts/gates that use `AskUserQuestion`
- MODE 1 (report only): after report → go directly to Execute (apply ALL fixes automatically)
- Questions Gate (QUESTIONS FOR AUTHOR): skip — proceed with original severity assessments
- Post-Execute "Next step?" prompt: skip — automatically proceed to Push if tests pass

**If `TaskCreate` NOT available:**
- Skip TaskCreate — instead print step status inline:
  `STEP: Triage [START]` → `STEP: Triage [DONE]`

Quality gates, checklists, and output format are identical in all environments.

## Step 0: Parse $ARGUMENTS

$ARGUMENTS controls WHAT gets reviewed AND which mode to use.

### Scope (what to review)

| Input | Interpretation | Git Command |
|-------|---------------|-------------|
| _(empty)_ | All uncommitted changes | `git diff --stat HEAD` |
| `new` | Commits since last review | `git diff --stat reviewed..HEAD` (tag) |
| `HEAD~1` | Last commit only | `git diff --stat HEAD~1..HEAD` |
| `HEAD~3` | Last 3 commits | `git diff --stat HEAD~3..HEAD` |
| `HEAD~2..HEAD~1` | Specific commit range | `git diff --stat HEAD~2..HEAD~1` |
| `apps/designer/` | Only this directory (uncommitted) | `git diff --stat HEAD -- apps/designer/` |
| `auth.controller.ts` | Only files matching name (uncommitted) | `git diff --stat HEAD -- '**/auth.controller.ts'` |
| `apps/api/ apps/runner/` | Multiple paths (uncommitted) | `git diff --stat HEAD -- apps/api/ apps/runner/` |
| `staged` | Only staged changes | `git diff --stat --cached` |

**Special: `new` keyword** — baseline resolution order:
1. Read `memory/last-reviewed.txt` → if file exists and hash is valid in current repo → use it
2. Fallback: git tag `reviewed` → if tag exists → use it
3. Fallback: warn + use `git diff --stat HEAD~5` (last 5 commits as approximation)

Reason for file-first: in Codex/Cursor, review fixes land on a separate branch. After merge to main, the `memory/last-reviewed.txt` file is already present with the correct hash — the git tag may be on the wrong branch.

Combines with paths: `new apps/api/` → only unreviewed changes in API dir

Multiple tokens can combine: `HEAD~1 apps/designer/` → last commit, only designer dir.

### Mode (what to do after audit)

| Token in $ARGUMENTS | Mode | Behavior |
|---------------------|------|----------|
| _(none)_ | MODE 1 | Report only. Wait for Execute. |
| `fix` | MODE 2 | Auto-fix ALL + tests + loop (Mode 2 gate applies) |
| `blocking` | MODE 3 | Fix CRITICAL/HIGH only + tests + loop |
| `tag` | UTIL | No audit. Just mark current HEAD as reviewed (updates file + tag). |

Examples: `/review`, `/review fix`, `/review HEAD~1 blocking`, `/review new apps/worker/ fix`

**Special: `tag` argument** — use after merging a review branch to main:
1. Run `git rev-parse HEAD` to get current hash
2. Write hash to `memory/last-reviewed.txt`
3. Run `git tag -f reviewed HEAD`
4. Print: "Marked [hash] as reviewed. Next `/review new` starts from here."
5. STOP — no audit, no report.

---

## Phase 0: Triage (Steps 1-6)

### Step 1: Detect Changes

Run the git command determined in Step 0 from the current working directory (git repo root).

Also check for new untracked files in scope: `git status --short` filtered by pathspec.

If no changes found in the resolved scope, check if user pasted code/diff.

If NOTHING found at all → trigger GATE A (see review-rules):
- Set Confidence = LOW
- Output Context Request Block (max 3 bullets)
- STOP — wait for context

### Step 2: Assess Scope

Fill this matrix from the diff:

```
TRIAGE RESULT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Files changed:    ___
Lines changed:    +___/-___
Change intent:    [BUGFIX/REFACTOR/FEATURE/INFRA]

Risk signals:
  [ ] DB/migration changes
  [ ] Security/auth changes
  [ ] API contract changes
  [ ] Payment/money flow
  [ ] >500 lines changed
  [ ] New production files added (.ts/.tsx/.py — not *.test.*)
  [ ] AI-generated code suspected

Tier:       [0-NANO / 1-LIGHT / 2-STANDARD / 3-DEEP]
Mode 2 OK:  [YES / NO — reason]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 3: Intent Detection

Heuristics (check commit messages + diff content):
- "fix", "bug", "patch", "hotfix" → **BUGFIX**
- "refactor", "rename", "extract", "move" → **REFACTOR**
- New files + new routes/endpoints/components → **FEATURE**
- Config/CI/Dockerfile/terraform → **INFRA**
- Can't determine → ask user (max 1 question)

### Step 4: Tier Selection

| Condition | Tier |
|-----------|------|
| <15 lines, no risk signals | TIER 0 (NANO) |
| 15-100 lines, no risk signals | TIER 1 (LIGHT) |
| 100-500 lines OR 5-15 files OR 1 risk signal | TIER 2 (STANDARD) |
| >500 lines OR 15+ files OR 2+ risk signals | TIER 3 (DEEP) |

**Intent downgrade (apply after table above):**
- `REFACTOR` + < 10 files + no DB/security/API/money signal → cap at TIER 2 (file count alone cannot push to TIER 3)
- `INFRA` (config, CI, Dockerfile, terraform only — no production code) → cap at TIER 1 unless > 300 lines

### Step 5: Mode 2 Blocker Check

Mode 2 (`/review fix`) is **FORBIDDEN** if ANY:
- TIER 3
- DB/migration changes
- Security/auth changes
- API contract changes
- Payment/money flow changes
- New production files + TIER 2 (suggest `blocking` instead — Behavior Auditor may find issues needing manual judgment)

If blocked and user requested `fix` → warn, downgrade to MODE 1 (report only), suggest `Execute BLOCKING` after report.

### Step 6: Conditional Sections

Flag which extra audit sections are needed:
- New feature? → Feature Completeness (Step 3.7)
- DB changes? → Database review (Step 4.3)
- i18n/strings? → Internationalization (Step 8)
- New dependencies? → Dependency Security (Step 7.2)
- External API? → External Services (Step 4.4)
- API/interface changes? → Backward Compatibility (Step 4.6)
- AI-generated code? → AI Code Smell Check (Step 3.8)

### Step 6.5: Read Backlog

Read `memory/backlog.md` from the project's auto memory directory (path shown in system prompt). If the file doesn't exist, create it from the template in rules.md. Check if any OPEN items are in files touched by this PR. If yes, include them in the report under `## BACKLOG ITEMS IN SCOPE`.

---

## Phase A: Audit (proceed immediately — no user confirmation needed)

Show header:
```
═══════════════════════════════════════════════════════════════
CODE REVIEW [+ AUTO-FIX if Mode 2/3]
═══════════════════════════════════════════════════════════════
REVIEWING: [1-2 sentence summary]
FILES: [X files, +Y/-Z lines]
TIER: [0/1/2/3] - [NANO/LIGHT/STANDARD/DEEP]
AUDIT: [SOLO / TEAM (2 auditors)]
CHANGE INTENT: [BUGFIX/REFACTOR/FEATURE/INFRA]
═══════════════════════════════════════════════════════════════
```

### Sub-Agent Preparation (tier-gated)

**IMPORTANT — Model Routing:**
The Task tool does NOT read `.claude/agents/*.md` files automatically. You MUST specify the `model` parameter explicitly on every Task call. Agent definition files are referenced in prompts so agents can read their own instructions, but the model is set by YOU.

**Agent spawning is gated by tier to avoid unnecessary API calls:**

```
IF TIER 0:
  → NO agents. Lead does inline audit only. Skip CQ self-eval (diff too small).
  → Confidence scoring inline.

IF TIER 1:
  → NO background agents. Lead does blast radius (single grep) and blame inline.
  → Confidence scoring inline.

IF TIER 2:
  → NO Blast Radius, Pre-Existing, or Structure Auditor.
  → Behavior Auditor: ONLY IF "New production files" risk signal is set.
  → Confidence Re-Scorer: ONLY IF Behavior Auditor spawned (otherwise lead scores inline).
  → Lead audits sequentially using protocol.md.

IF TIER 3:
  → ALL agents spawned (Blast Radius, Pre-Existing, Structure/Behavior Auditors, Re-Scorer).
```

**Agent model table (when spawned):**

| Agent | Model | subagent_type | Spawned When |
|-------|-------|---------------|--------------|
| Blast Radius Mapper | **sonnet** | Explore | TIER 3 only |
| Pre-Existing Checker | **haiku** | Explore | TIER 3 only |
| Structure Auditor | **sonnet** | Explore | TIER 3 only |
| Behavior Auditor | **sonnet** or **opus** | Explore | TIER 2 (new files) or TIER 3 |
| Confidence Re-Scorer | **haiku** | Explore | TIER 3 only (TIER 2: lead scores inline) |

#### TIER 0 and TIER 1 Inline Analysis (no agents)

Instead of spawning agents, the lead does this directly:

**Blast radius (inline):** Run a single `grep -r 'import.*[changed-file]'` or `grep -r 'from.*[module]'` to find importers. For 1-4 files / <100 lines, this is 1-2 tool calls vs an entire agent.

**Pre-existing check (inline):** Run `git blame -L <start>,<end> <file>` on changed hunks. For <100 lines, this is 1-2 Bash calls.

**Confidence scoring (inline):** With max 2-4 issues from TIER 0-1 audit, lead assigns confidence scores directly using the scoring table from rules.md.

#### TIER 2 Inline Analysis (no agents unless new files)

Lead runs all audit steps sequentially using protocol.md. No background agents unless "New production files" risk signal is set — in that case spawn Behavior Auditor only (see TIER 2 in agent table above).

#### TIER 3 Agent Spawning (+ Behavior Auditor for TIER 2 new files)

Spawn applicable agents in parallel (use Task tool, run_in_background=true). Don't wait — start auditing immediately. Incorporate results when available.

**Agent 1: Blast Radius Mapper** (Sonnet, background) — skip if files_changed < 3
```
Spawn via Task tool with:
  subagent_type: Explore
  model: "sonnet"
  run_in_background: true
  prompt: "Analyze the blast radius of these changed files: [list from triage].
For each file:
1. Run: grep -r 'import.*[filename]' or grep -r 'from.*[module]' to find all importers
2. List direct callers (files that import this)
3. List transitive callers (1 level up — who imports the importers)
4. Flag if changed file is: a public API, a shared utility, a config, a type definition
Return a dependency map showing blast radius per file."
```

**Agent 2: Pre-Existing Checker** (Haiku, background)
```
Spawn via Task tool with:
  subagent_type: Explore
  model: "haiku"
  run_in_background: true
  prompt: "For each changed file in this diff, run git blame on the changed line ranges.
Categorize each changed hunk as:
- NEW: line didn't exist before (added by this change)
- MODIFIED: line existed but was changed
- MOVED: line content is identical, just relocated
- PRE-EXISTING: surrounding context that wasn't touched
Return a summary: which lines are genuinely new/modified vs pre-existing.
This will be used to filter out pre-existing issues from the review."
```

### Audit Mode Decision

After Steps 0-1 (context), decide audit execution mode:

```
IF TIER 0 OR TIER 1:
  → SOLO AUDIT (inline, no agents)

IF TIER 2 AND "New production files" risk signal:
  → SOLO AUDIT + Behavior Auditor (single background agent)

IF TIER 2 (no new files):
  → SOLO AUDIT (lead runs protocol sequentially, no agents)

IF TIER 3:
  → TEAM AUDIT (all agents parallel)
```

### Audit Steps by Tier

**TIER 0 (NANO):** Steps 0 → 1 → 2.1 → Confidence Gate (inline) → Report (SOLO, skip CQ self-eval)
**TIER 1 (LIGHT):** Steps 0 → 1 → 2.1 → 6.1 → Confidence Gate (inline) → Report (always SOLO)
**TIER 2 (STANDARD):** Steps 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7.0 → 9 → Confidence Gate → Report
**TIER 3 (DEEP):** ALL steps 0-11 → Confidence Gate → Report

### Diff Scoping (reduce tokens passed to agents)

Before spawning audit agents, preprocess the diff to give each agent only the data it needs. This avoids passing the full diff 4× to different agents.

**Step: Prepare scoped diffs (lead, before spawning Team Audit agents)**

1. Run `git diff [scope]` to get the full diff
2. Split into scoped fragments:

| Agent | What to include in prompt | What to exclude |
|-------|--------------------------|-----------------|
| **Blast Radius Mapper** | File list + exported symbol names only (extracted via `git diff --stat` + grep for `export` in changed files). No diff hunks needed. | Full diff content |
| **Pre-Existing Checker** | Hunk headers (`@@ -12,5 +12,8 @@`) + file paths + line ranges only. No diff content needed — agent runs `git blame` on the ranges. | Diff content body |
| **Structure Auditor** | Diff of production code files only (`.ts`, `.tsx`, `.py`, `.go`, `.rs`, `.java`). Skip: `.md`, `.json`, `.lock`, `.env*`, `*.test.*`, `*.spec.*`. | Non-code files, test files |
| **Behavior Auditor** | Diff of production code files only. Skip: test files (`*.test.*`, `*.spec.*`), config files (`.json`, `.lock`, `.yaml`). | Test files, config files |

3. Pass the scoped fragment in each agent's prompt where it says `DIFF: [scoped diff]`

**TIER 0-1:** No diff scoping needed (lead processes everything inline, no agents spawned).

**TIER 2 (new files):** Pass only production code diff to Behavior Auditor (exclude test files, config). Lead processes full diff directly.

**Fallback:** If diff is small (<100 lines total), skip scoping — pass full diff to agent. The overhead of preprocessing exceeds the savings.

### Solo Audit (default)

Lead executes all steps sequentially. Used for TIER 0, TIER 1, and TIER 2.

### Team Audit (TIER 3 only)

After Steps 0-1 (lead, sequential — these set context for everything), spawn 2 audit agents in parallel. Each is read-only — they analyze the same diff through different "lenses."

#### Behavior Auditor Model Routing

The Behavior Auditor model depends on review complexity:

```
IF TIER 2 (new files only):
  → Behavior Auditor model: "sonnet"

IF TIER 3 AND (files_changed >= 15 OR risk_signals include SECURITY or MONEY):
  → Behavior Auditor model: "opus"

IF TIER 3 AND files_changed < 15 AND no security/money risk:
  → Behavior Auditor model: "sonnet"
```

Rationale: Sonnet handles CQ3-CQ10 adequately for medium reviews. Opus adds value only for large, complex reviews with security/financial cross-cutting concerns.

**Structure Auditor** — `~/.claude/skills/review/agents/structure-auditor.md` (Sonnet, read-only):
```
Spawn via Task tool with:
  subagent_type: Explore          ← enforces read-only (no Edit/Write)
  model: "sonnet"                 ← MUST set explicitly, Task tool ignores agent .md
  run_in_background: true
  prompt: "Read your full instructions at ~/.claude/skills/review/agents/structure-auditor.md, then audit these changed files.

CHANGED FILES: [list from Step 1]
DIFF: [scoped diff — see Diff Scoping section above]
TECH STACK: [detected stack]
CHANGE INTENT: [from triage]
TIER: [1/2/3]
CONDITIONAL SECTIONS: [list from triage]
BLAST RADIUS: [from Agent 1 if ready]

SCOPE RULES by TIER + INTENT:
- TIER 2 REFACTOR: focus on import correctness, barrel exports, file limits. Skip deep performance analysis unless obvious regression.
- TIER 2 FEATURE: full Steps 2, 4, 5.
- TIER 3: Include Steps 10 (Rollback) and 11 (Documentation).

Output STRUCT-N issues per the format in your instructions."
```

**Behavior Auditor** — `~/.claude/skills/review/agents/behavior-auditor.md` (Sonnet or Opus, read-only):
```
Spawn via Task tool with:
  subagent_type: Explore          ← enforces read-only (no Edit/Write)
  model: [use model from Behavior Auditor Model Routing above]
  run_in_background: true
  prompt: "Read your full instructions at ~/.claude/skills/review/agents/behavior-auditor.md, then audit these changed files.

CHANGED FILES: [list from Step 1]
DIFF: [scoped diff — see Diff Scoping section above]
TECH STACK: [detected stack]
CHANGE INTENT: [from triage]
TIER: [1/2/3]
CONDITIONAL SECTIONS: [list from triage]
PRE-EXISTING DATA: [from Agent 2 if ready]

SCOPE RULES by TIER + INTENT:
- TIER 2 REFACTOR: verify behavioral equivalence (before=after). Run ONLY affected tests, NOT full suite. Skip feature completeness (Step 3.7).
- TIER 2 FEATURE: full Steps 3, 6, 9. Run affected + related tests.
- TIER 3: Include Steps 7 (Security) and 8 (i18n). Full test suite allowed.

Output BEHAV-N issues per the format in your instructions."
```

**Lead collects results:**
1. Wait for both audit agents to complete
2. Merge issue lists (STRUCT-* + BEHAV-*)
3. Deduplicate — if both agents found the same issue, keep the one with more detail
4. Renumber sequentially: R-1, R-2, R-3...
5. Proceed to Confidence Gate with merged list

### Step Reference (details in ~/.claude/review-protocol.md)

**Step 0 — Pre-flight:** Understand WHY the change was made. Verify scope matches intent. Check blast radius mapper results (if ready) to understand who depends on changed code.

**Step 1 — Change Inventory:** Table of modified/new/deleted files with risk and blast radius (use mapper results). Dependency and config changes.

**Step 2 — Static & Architecture:**
- 2.1: Compilation, type safety, `any` abuse, non-null assertions, lint
- 2.2: Import correctness, circular deps, unused imports, barrel exports
- 2.3: Naming conventions
- 2.4: SRP, coupling, file/function size limits (250 lines source / 400 tests, 50 line functions — see `~/.claude/rules/file-limits.md`)

**Step 3 — Logic & Side Effects:**
- 3.1: Business logic correctness, edge cases, error handling + silent failure hunt
- 3.2: Hook integrity (useEffect deps, cleanup, stale closures) [React only]
- 3.3: Race conditions, async safety (AbortController, unmount)
- 3.4: State management (immutability, derived state, prop drilling)
- 3.5: Next.js specific (Server Components, Server Actions, caching, middleware) [Next.js only]
- 3.6: Python specific (async pitfalls, mutable defaults, type hints, FastAPI/Django) [Python only]
- 3.7: Feature completeness (loading/error/empty states, a11y) [conditional]
- 3.8: AI code smell check (hallucinated imports, generic names) [conditional]

**Step 4 — Integration:**
- 4.1: Component props/callbacks [React only]
- 4.2: API integration (endpoints, auth, error handling, types)
- 4.3: Database (indexes, migrations, N+1, transactions) [conditional]
- 4.4: External services (timeouts, circuit breakers, fallbacks) [conditional]
- 4.5: Environment variables (validated? secrets not exposed? .env.example updated?)
- 4.6: Backward compatibility (API shape, DB format, feature flags) [conditional]

**Step 5 — Performance:**
- 5.1: Re-renders, memoization, list keys, virtualization [React only]
- 5.2: Bundle size, memory leaks, lazy loading
- 5.3: Heavy computations, debounce, pagination, caching

**Step 6 — Regressions:**
- 6.1: Test impact (existing pass? new coverage? skipped tests?)
- 6.2: System impact (other modules, env vars, cache, cron, webhooks)
- 6.3: Test quality (behavior tests, deterministic, meaningful assertions)

**Step 7 — Security:** [TIER 3 only]
- 7.1: XSS, injection, secrets, auth, CSRF, PII logging
- 7.2: New dependency trustworthiness [conditional]

**Step 8 — i18n:** [conditional] Hardcoded strings, locale formatting, RTL

**Step 9 — Observability:** Logging quality, error tracking, debug support

**Step 10 — Rollback:** [TIER 3 only] Rollback plan, migration reversibility, feature flags

**Step 11 — Documentation:** README, API docs, TODOs tracked, env vars documented

### Confidence Gate (after audit, before report)

After completing all audit steps, DO NOT write the report yet. Instead:

1. Collect all candidate issues found during audit
2. Cross-reference with Pre-Existing Checker results (or inline blame for TIER 1) — mark any issue on pre-existing lines

#### TIER 1: Inline Confidence Scoring

For TIER 1 (max 2-3 issues), the lead scores confidence directly — no agent spawn needed.

Apply the scoring table from rules.md (Confidence Re-Scoring section):
- Score 0-25: DISCARD (hallucination / false positive)
- Score 26-50: DROP to backlog
- Score 51+: KEEP in report

Score UP when: matches a project rule, has concrete reproduction scenario, affects user-visible behavior, involves money/auth/data.
Score DOWN when: theoretical only, covered by tests, rarely-executed code, author made intentional choice.

For each issue, state: `Confidence: [X]/100 — [reason]`

#### TIER 2+: Confidence Re-Scorer Agent

3. Spawn **Confidence Re-Scorer** — `~/.claude/skills/review/agents/confidence-rescorer.md` (Haiku):

```
Spawn via Task tool with:
  subagent_type: Explore          ← read-only
  model: "haiku"                  ← MUST set explicitly
  prompt: "Read your full instructions at ~/.claude/skills/review/agents/confidence-rescorer.md, then re-score these issues.

ISSUES:
[paste issue list with: ID, severity, file, code quote, problem description]

CHANGE INTENT: [from triage]
BACKLOG: [path to memory/backlog.md if it exists]
PRE-EXISTING DATA: [from Agent 2 — which lines are new vs old]

Return the confidence table and summary per your instructions."
```

4. Wait for Re-Scorer result

#### Common (all tiers)

5. DROP from report any issue scoring < 51 — **PERSIST issues scoring 26-50 TO BACKLOG** (0-25 = DISCARD as hallucinations)
6. Adjust severity if re-scorer disagrees (e.g., reviewer said HIGH but scorer says 55 = downgrade to MEDIUM)
7. Write final report with issues scoring 51+
8. **MANDATORY: Write dropped issues (confidence 26-50) to `memory/backlog.md`** with their confidence score and "(dropped from report)" note — do this BEFORE showing the report to the user. Issues scoring 0-25 are DISCARDED (do not persist).

### Report Output

Generate the full report following the format in review-protocol.md. Include:
1. META (date, intent, tier, audit mode [SOLO/TEAM], confidence, agents used)
2. SCOPE FENCE (allowed files)
3. FINAL VERDICT + score
4. SUMMARY OF CHANGES
5. SKIPPED STEPS with reasons
6. VERIFICATION PASSED (what's OK)
7. BACKLOG ITEMS IN SCOPE (if any open backlog items touch changed files)
8. DROPPED ISSUES (brief list of what was filtered out by confidence gate, so user knows)
9. ISSUES (CRITICAL → HIGH → MEDIUM → LOW) — each with evidence, confidence score, fix code, verification
10. QUESTIONS FOR AUTHOR
11. QUALITY WINS
12. TEST ANALYSIS (validity gate, missing tests, existing status)
13. REQUIRED ACTIONS (prioritized: blocking → before-prod → tech-debt)
14. EXECUTION PLAN (fix list + test list + run commands)

### Backlog Update (after report)

**MANDATORY** — After writing the report, persist unfixed issues to backlog per rules.md:
- **Dropped issues (confidence 26-50)** → backlog
- **Discarded issues (confidence 0-25)** → NOT persisted (hallucinations)
- Pre-existing issues → backlog
- Issues on unmodified lines → backlog
- MODE 1 (report only): all reported issues go to backlog (not fixed yet)

**Prune on every write:** delete FIXED/WONT_FIX items. No RESOLVED section — fixed = deleted.

### Questions Gate (after report, before Execute)

If the report contains **QUESTIONS FOR AUTHOR** (section 10 is non-empty):

1. Do NOT proceed to Execute yet
2. Use `AskUserQuestion` to surface each question — max 4 at a time (tool limit):
   - Header: "Author input needed"
   - Each question becomes one `AskUserQuestion` question with options relevant to the question
   - If more than 4 questions: ask the first 4, wait, then ask remaining
3. Wait for user answers
4. Incorporate answers before proceeding:
   - Update affected issue severities if answers change the picture (e.g., "billing = display only" → R-6 drops from CRITICAL to LOW)
   - Mark answered questions with the user's response inline in the report
5. Then proceed to Execute prompt

If QUESTIONS FOR AUTHOR is empty → skip this gate, go directly to Execute prompt.

---

## Phase B: Execute (Mode 2 and 3, or on user command)

If MODE 1 (report only): after report + backlog update, use `AskUserQuestion` to prompt for next action:

```
Question: "What to do with the fixes?"
Header: "Execute"
Options:
  - "Execute" (Recommended) → apply ALL fixes from report
  - "Execute BLOCKING" → apply CRITICAL + HIGH only
  - "Skip" → do nothing, keep report for reference
```

This lets the user Tab + Enter to accept the recommended action instantly.

### Execute Flow

1. Show SCOPE FENCE + EXECUTION HEADER:
```
═══════════════════════════════════════════════════════════════
EXECUTING FIXES
═══════════════════════════════════════════════════════════════
ORIGINAL ISSUE: [summary]
CHANGE INTENT: [intent]
SCOPE FENCE:
  ALLOWED: [file list]
  FORBIDDEN: files outside scope, new APIs, "while we're here" fixes
FIXES TO APPLY:
  [ ] [ID] [description]
═══════════════════════════════════════════════════════════════
```

2. Apply fixes — choose execution mode:

   **Fix scope:**
   - MODE 2 ("fix"): ALL issues (CRITICAL + HIGH + MEDIUM + LOW)
   - MODE 3 ("BLOCKING"): CRITICAL + HIGH only
   - "Execute [ID]": specified issues only

   **Solo execution (default):** Apply fixes sequentially.

   **Parallel execution (when 3+ fixes touch DIFFERENT files):**
   Analyze which fixes can be applied independently (different target files, no interaction).
   Spawn up to 3 general-purpose agents via Task tool — each gets:
   - The issue(s) assigned to them (from report, with full fix code)
   - Allowed files (only files their issues touch)
   - Scope fence rules
   - Stack + test runner info
   Wait for all agents, then verify combined result.

   Do NOT parallelize fixes that touch the same file or that interact (e.g., one fix changes an interface, another uses that interface).

3. Write ALL required tests (complete, runnable — not stubs). Per CHANGE INTENT rules.
   If parallel execution was used, each agent writes tests for their own fixes (separate spec files). Lead verifies no conflicts.

4. Run verification — detect test runner from project:
   - If `turbo.json`: `npx turbo test --force && npx turbo type-check`
   - If `package.json` "test": `npm test` + `npm run typecheck` (if exists) + `npm run lint` (if exists)
   - If `pyproject.toml` with pytest: `pytest` + `mypy .` (if configured) + `ruff check .` (if configured)
   - If `manage.py` (Django): `python manage.py test` + `mypy .`
   - If `Makefile` with `test` target: `make test`
   - Otherwise: ask user for test command

5. If RED → check FLAKY (per rules.md), then fix and repeat step 4
6. If GREEN → run **Execute Verification Checklist** (below), then re-audit changed code
7. If NEW ISSUES → go back to step 2
8. If ALL GREEN → auto-commit + tag + show completion + update backlog:

### Execute Verification Checklist (NON-NEGOTIABLE)

After applying fixes and before committing, verify ALL of these. Print each with ✅/❌:

```
EXECUTE VERIFICATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅/❌  SCOPE: No files modified outside SCOPE FENCE (no "while we're here" additions)
✅/❌  SCOPE: No new features/tests added beyond what the fix requires
✅/❌  TESTS PASS: Full test suite green (not just changed files)
✅/❌  FILE LIMITS: All modified/created files ≤ 250 lines (production) / ≤ 400 lines (test)
✅/❌  CQ1-CQ20: Self-eval on each modified PRODUCTION file (or N/A if test-only)
✅/❌  Q1-Q17: Self-eval on each modified/created TEST file (individual scores + critical gate)
✅/❌  NO SCOPE CREEP: Only fixes from the report applied, nothing extra
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**If ANY is ❌ → fix before committing.** Common failures:
- Scope creep: adding tests or refactoring not in the report → revert extra changes
- File limit: split files created during fix exceed limits → split further
- Q1-Q17 not run: after splitting/rewriting test files, re-eval is mandatory

**Auto-Commit + Tag:**
1. `git add [list of modified/created files — specific names, not -A]`
2. `git commit -m "review-fix: [brief description of fixes applied]"`
3. `git tag review-[YYYY-MM-DD]-[short-slug]` (e.g., `review-2026-02-22-fix-auth-cq4`)

This creates a clean rollback point. User can `git reset --hard <tag>` if needed.

```
═══════════════════════════════════════════════════════════════
EXECUTION COMPLETE
═══════════════════════════════════════════════════════════════
ORIGINAL ISSUE: [summary]
FILES MODIFIED: [list]

FIXED:
  - [ID] [description]

TESTS WRITTEN:
  - [TEST-ID] [description]

VERIFIED:
  - Tests: PASS
  - Types: PASS

Commit: [hash] — [message]
Tag: [tag name] (rollback: git reset --hard [tag])
═══════════════════════════════════════════════════════════════
```

### Post-Execute Backlog Update

After Execute completes, persist unfixed issues to backlog:
- If `Execute BLOCKING`: all MEDIUM + LOW issues → backlog
- If `Execute [ID]`: all issues NOT in the ID list → backlog
- Mark any previously open backlog items as FIXED if the fix resolved them

---

## Phase C: Post-Execute

Changes are already committed and tagged (auto-commit in Phase B). Use `AskUserQuestion` to prompt:

```
Question: "Next step?"
Header: "Post-fix"
Options:
  - "Push" (Recommended) → push + tag reviewed
  - "Re-audit" → run full audit again on current state
  - "Done" → stop here, don't push
```

### Actions

**"Re-audit":**
1. Run full audit on current code state
2. If issues → show report, prompt Execute again
3. If clean → show "RE-AUDIT PASSED", prompt Push

**"Push":**
1. `git push origin [branch]`
2. Get current hash: `git rev-parse HEAD`
3. Write hash to `memory/last-reviewed.txt` (create file if not exists)
4. Move the `reviewed` tag to HEAD: `git tag -f reviewed HEAD`
5. Show pushed confirmation:
   ```
   Marked [short-hash] as reviewed.
   memory/last-reviewed.txt updated — works across branches (Codex, Cursor).
   git tag 'reviewed' updated — works in Claude Code.
   Next: /review new
   ```

**"Done":**
1. Get current hash: `git rev-parse HEAD`
2. Write hash to `memory/last-reviewed.txt`
3. Show summary of what was fixed
4. Print: "Not pushed. Marked [hash] as reviewed locally — run `/review new` after merging to main."
5. Stop — don't push (commit already done)

$ARGUMENTS
