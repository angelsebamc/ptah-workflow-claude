# Ptah

Ptah is a spec-driven workflow, using slash commands. Each command has a single responsibility, produces a markdown artifact, and waits for your review before suggesting the next step.

---

## Philosophy

- **Spec before code** — define what to build before building it
- **One command, one responsibility** — no command does more than one thing
- **You stay in control** — every step produces an artifact you review before moving on
- **Resume anytime** — `LOGS.md` tracks the full session history so you can pick up after days away
- **Service-agnostic** — optional integration with JIRA, Linear, GitHub, or any MCP-backed ticket service through Ptah config

---

## The workflow

```
/spec → /design → /implement → /code-review → /fix → [/test] → /document
```

`/test` is **opt-in per project** — enabled via `commands.test.enabled: true` in `.claude/ptah/ptah.yml`. The default is **disabled**, so by default the workflow runs straight from `/fix` to `/document`. See "Testing is optional" below.

If tests fail (when testing is enabled):
```
/fix → /test → /fix → /test  (until all tests pass)
```

---

## Testing is optional

The `/test` step is off by default. To turn it on, set this in `.claude/ptah/ptah.yml`:

```yaml
commands:
  test:
    enabled: true
```

When disabled:
- `/test` refuses to run if invoked
- `/code-review` and `/fix` route their hand-off straight to `/document`
- `/document` doesn't check `TEST.md` and omits the "Test coverage" section from the generated README
- `/status` and `/resume` report `/document` as the next step where they'd otherwise say `/test`

When enabled, the full track including `/test` runs exactly as documented per command.

---

## Ptah config (optional)

If your project uses an external ticket service (JIRA, Linear, GitHub), drop a `.claude/ptah/ptah.yml` at the project root to wire it up. `/spec` will then accept a flag like `--jira PROJ-1234` and pull the ticket content into the spec automatically.

The same config file also controls per-command behavior — for example, `commands.fix.mode` sets the default mode for `/fix` (see the `/fix` section below).

Projects without Ptah config run with sensible defaults — nothing breaks.

See `ptah.example.yml` for a working template.

---

## Commands

Commands fall into two groups: meta-commands for navigation, and workflow commands.

### Meta-commands

#### `/status [--all]`
Lists all in-flight specs with their current state — what's paused, what's active, what's just started. By default hides completed work; pass `--all` to include it. Read-only — never modifies any file.

Use this as your first command when sitting down to a clean session.

**Produces:** nothing — just a printed report

---

#### `/resume <feature-name>`
Reloads the full working context for a spec — the project rules, the session history, and every relevant artifact produced so far. The agent ends up primed to run the next workflow command with full continuity, as if the session never ended. Read-only — does not run the next command and does not append to `LOGS.md`.

Use this at the start of a new session whenever you're continuing in-flight work.

**Produces:** nothing — just primes the agent's context

---

### Workflow commands

#### `/spec <feature-name> [--<source> <id>]`
Starts a guided conversation to define a solid use case. Creates the full spec folder structure and fills `SPEC.md` through a series of questions — one at a time.

If Ptah config is present and you pass a source flag (e.g. `--jira PROJ-1234`), the ticket content is pulled in and pre-fills relevant fields. You still review and confirm everything.

**Produces:** `.claude/specs/<feature-name>/SPEC.md`

---

#### `/design <feature-name>`
Reads `SPEC.md` and any files in `/refs`, asks clarifying questions if anything is unclear, then produces a thorough technical design covering architecture, data model, API, UI, file structure, and business logic.

**Produces:** `.claude/specs/<feature-name>/DESIGN.md`

---

#### `/implement <feature-name>`
Reads `DESIGN.md` and implements the feature exactly as designed. Documents what was built, files created/modified, and any deviations from the design.

**Produces:** `.claude/specs/<feature-name>/IMPLEMENTATION.md` + code

---

#### `/code-review <feature-name>`
Reviews the implemented code against the spec and design. Documentation only — no code changes. Findings are prioritized as:

| Icon | Level | Action |
|------|-------|--------|
| 🔴 | Blocker | Must fix before moving forward |
| 🟡 | Major | Should fix before moving forward |
| 🟢 | Minor | Nice to fix |
| 💡 | Suggestion | Optional |

**Produces:** `.claude/specs/<feature-name>/CODE-REVIEW.md`

---

#### `/fix <feature-name> [--auto | --plan | --interactive] [--include-minor | --blockers-only]`
Reads `CODE-REVIEW.md` and applies fixes for all 🔴 blockers and 🟡 major issues. Supports three modes that control how much the agent asks before applying:

| Mode | Behavior |
|------|----------|
| `auto` | Apply all in-scope fixes silently. Report at the end. |
| `plan` | Show a one-line-per-finding plan, wait for one confirmation, apply all in one pass. **Default.** |
| `interactive` | Ask per finding before applying. User can skip individual findings. |

Mode is resolved with precedence **flag > config > default (`plan`)**. The default mode can be set in `.claude/ptah/ptah.yml` under `commands.fix.mode`.

Minors and suggestions are deferred by default. Pass `--include-minor` (or set `commands.fix.include_minor: true` in config) to include 🟢 minor issues in the run. 💡 suggestions are never auto-fixed.

Regardless of mode, the **Stop and ask** rule from `RULES.md` still applies — `auto` does not bypass judgment for ambiguous fixes, design changes, or new dependencies.

**Produces:** Updated code + fix summary in `CODE-REVIEW.md`

---

#### `/test <feature-name>`
> **Opt-in:** requires `commands.test.enabled: true` in `.claude/ptah/ptah.yml`. Default is disabled.

Analyzes the spec and implementation to identify test scenarios, writes `.md` breakdowns for your review, then — after you confirm — generates one Maestro YAML flow per scenario organized into happy-path, edge-cases, and error-states folders. Runs all flows and documents results.

**Produces:** `.claude/specs/<feature-name>/TEST.md` + Maestro YAML flows

---

#### `/document <feature-name>`
The final step. Writes a clean, human-readable summary of the completed feature. Guards against documenting incomplete work — warns if there are unresolved blockers or failing tests.

**Produces:** `.claude/specs/<feature-name>/README.md`

---

## Folder structure

Ptah is split across three locations under `.claude/`:

- **`commands/ptah/`** — the slash command definitions (lives where Claude Code expects commands)
- **`ptah/`** — Ptah's own config and reference docs
- **`specs/`** — your work product, created as you use Ptah

```
.claude/
  commands/
    ptah/                         ← Ptah's slash commands
      status.md                   ← list in-flight specs
      resume.md                   ← load context for one spec
      spec.md
      design.md
      implement.md
      code-review.md
      fix.md
      test.md
      document.md

  ptah/                           ← Ptah's config + docs
    README.md                     ← this file
    RULES.md                      ← cross-cutting agent rules (referenced from CLAUDE.md)
    ptah.yml                      ← optional, wires up external ticket services
    ptah.example.yml              ← template for ptah.yml
    guides/
      logs-format.md              ← strict schema for LOGS.md entries

  specs/<feature-name>/           ← created by /spec, one per feature
    LOGS.md                       ← session journal — read first when resuming
    SPEC.md                       ← use case, problem, acceptance criteria
    DESIGN.md                     ← technical approach, file plan, data model
    IMPLEMENTATION.md             ← what was built, deviations, known issues
    CODE-REVIEW.md                ← findings + fix summary
    TEST.md                       ← test results
    README.md                     ← final summary (produced by /document)
    refs/                         ← screenshots, mockups, schema snippets
```

Maestro test flows live outside `.claude/`, in their own top-level folder:

```
.maestro/specs/<feature-name>/
  happy-path/
    happy-path.md
    happy_path_<scenario>.yaml
  edge-cases/
    edge-cases.md
    edge_<scenario>.yaml
  error-states/
    error-states.md
    error_<scenario>.yaml
```

And the project root holds:

```
CLAUDE.md           ← project-wide rules (stack, conventions, logging discipline)
```

---

## LOGS.md

Every command appends an entry to `LOGS.md` when it completes, and **change entries** are appended in between as work happens (decisions, deviations, scope changes, blockers, corrections). Reading `LOGS.md` top-to-bottom shows the full timeline of a feature.

A quick taste:

```markdown
## 2026-04-23 09:14:22 — /spec completed
- Feature: account creation with excluded from net worth toggle
- Source: PROJ-42
- Key decisions: toggle defaults to false
- Next step: /design

## 2026-04-23 14:22:18 — change during /implement
- Trigger: agent decision
- Type: deviation
- What: used Zustand instead of useReducer for form state
- Why: form grew to 12 fields, useReducer was getting unwieldy
- Impact: new dependency, IMPLEMENTATION.md will flag under "Deviations"
```

The full schema — required fields per command, change entry format, and rules — lives in [`guides/logs-format.md`](./guides/logs-format.md).

The mid-session logging discipline (when to log, when not to) lives in `CLAUDE.md` under "Logging discipline".

When resuming after a break, run `/status` to see what's in flight, then `/resume <name>` to load context for the one you want to continue.

---

## Getting started

1. Place the slash commands at `.claude/commands/ptah/` (so Claude Code picks them up)
2. Place Ptah's config and guides at `.claude/ptah/` (this includes `RULES.md`, `guides/`, and `ptah.example.yml`)
3. Add a one-line reference to `.claude/ptah/RULES.md` in your project's `CLAUDE.md` so the agent picks up the workflow rules
4. (Optional) If your project uses JIRA, Linear, or similar — copy `.claude/ptah/ptah.example.yml` to `.claude/ptah/ptah.yml` and configure it. The same file also configures per-command defaults (e.g. `commands.fix.mode`).
5. Run `/spec <your-first-feature>`

---

## Tips

### Sitting down to a clean session
- Run `/status` first — it shows what's in flight without needing to remember anything
- Pass `--all` to also see completed work (useful for audits or briefing teammates)
- Once you know what to continue, run `/resume <name>` — it loads the project rules, session history, and every relevant artifact into the agent's context, so the next workflow command runs with full continuity
- `/status` and `/resume` are read-only — they never modify files or append to `LOGS.md`

### Working a feature
- Add screenshots, mockups, or schema snippets to `refs/` before running `/design` — the agent will use them
- If `/design` produces open questions, resolve them before running `/implement`
- `/code-review` is documentation only — it never touches code
- `/fix` defaults to `plan` mode — you see the full plan before any code is touched. Set `commands.fix.mode: auto` in `ptah.yml` if you'd rather have it just apply everything, or pass `--auto` on a per-run basis. Use `--interactive` when the review found something risky and you want to triage finding by finding.
- `/fix` skips 🟢 minor issues by default — pass `--include-minor` or set `commands.fix.include_minor: true` to include them. 💡 suggestions are never auto-fixed.
- `/test` is opt-in per project — set `commands.test.enabled: true` in `ptah.yml` to use it. When enabled, it shows you the scenario breakdown before writing any YAML, so you can add or remove scenarios at that point. When disabled, `/fix` and `/code-review` route straight to `/document`.
- `/document` guards against incomplete work — it warns you if blockers are unresolved, and (when testing is enabled) also if tests are failing

### Ptah config
- Ptah config is opt-in per project
- Adding a new service (Linear, GitHub, Notion) is a config change, not a code change — all commands read from `.claude/ptah/ptah.yml`
- Per-command behavior also lives in `ptah.yml` under `commands:` — e.g. `commands.fix.mode` and `commands.fix.include_minor`
- If a fetch fails, commands stop loudly rather than falling back silently — fix the ticket ID or drop the flag to proceed manually
