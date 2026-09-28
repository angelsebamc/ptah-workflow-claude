# /fix

Read review findings and fix all blocker and major issues. Record what was changed next to the findings.

`/fix` works from one of two sources:

- **A spec** — `/fix <spec-id>` — fixes findings from `.claude/specs/<feature-name>/CODE-REVIEW.md`. This is the feature track.
- **A standalone review** — `/fix --review <review-name>` — fixes findings from the latest pass of `.claude/reviews/<review-name>/REVIEW.md`, written by `/review`.

Every finding carries a code assigned by the reviewer — `B1`, `B2` for 🔴 blockers, `M1` for 🟡 major, `N1` for 🟢 minor, `S1` for 💡 suggestions. The user steers individual findings by code; see **Directives by code** in Step 5. Severities, codes, and fix modes are defined in [`guides/vocabulary.md`](../../ptah/guides/vocabulary.md).

`/fix` supports three modes that control how much the agent asks before applying fixes. The default is `plan`. See **Modes & config** below.

## Step 1 — Parse command arguments

The command takes exactly one source — a positional spec identifier (see **Spec identifiers** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md): bare number, `ptah-<n>`, or full folder name) **or** `--review <review-name>` — plus optional flags:

- `--review <review-name>` — fix a standalone review instead of a spec
- `--auto` — apply all fixes without asking
- `--plan` — show the plan, wait for one confirmation, then apply
- `--interactive` — ask per finding before applying
- `--include-minor` — also fix 🟢 minor issues
- `--blockers-only` — exclude 🟢 minor issues even if config includes them

Examples:
- `/fix 3` — uses mode from `ptah.yml`, or `plan` if no config
- `/fix 3 --auto` — applies all fixes silently this run
- `/fix 3 --interactive --include-minor` — asks per finding, includes minors
- `/fix --review feature-login` — fixes the latest pass of that review

**Source errors** stop the command:

- No spec identifier and no `--review`, or both:
  > "⚠️ `/fix` needs exactly one source: a spec number (`/fix 3`) or `--review <review-name>`."
- `--review` without a value:
  > "⚠️ `--review` needs a review name, e.g. `/fix --review feature-login`."

**Mutually-exclusive flag pairs** produce an error and stop:
- `--auto`, `--plan`, `--interactive` (pick one)
- `--include-minor` and `--blockers-only`

> "⚠️ Conflicting flags: `<flag1>` and `<flag2>`. Pick one."

**Unknown flags** produce an error consistent with `/spec`:

> "⚠️ Unknown flag `--xyz`. Supported flags: `--review`, `--auto`, `--plan`, `--interactive`, `--include-minor`, `--blockers-only`."

---

## Step 2 — Resolve mode and scope

Determine the effective mode and scope for this run. Precedence is **flag > config > default**.

### 2a. Load Ptah config
Read `.claude/ptah/ptah.yml`.

- If the file doesn't exist, or `commands.fix` is missing → use defaults (`mode: plan`, `include_minor: false`)
- If `commands.fix.mode` is set, validate it's a fix mode from `vocabulary.md`. Anything else → stop:
  > "⚠️ Invalid `commands.fix.mode` value `<value>` in `ptah.yml`. Must be one of: `auto`, `plan`, `interactive`."

### 2b. Apply flag overrides
- `--auto` / `--plan` / `--interactive` override `commands.fix.mode`
- `--include-minor` forces `include_minor: true`
- `--blockers-only` forces `include_minor: false`

The config file is never modified by `/fix`. Flags only affect the current run.

### 2c. Compute in-scope findings
- Always in scope: 🔴 `B` and 🟡 `M` findings
- If `include_minor` is true: also 🟢 `N` findings
- 💡 `S` findings are never in scope by default

Directives by code (Step 5) can take any finding out of scope, or pull an individual out-of-scope finding in, for this run only.

---

## Step 3 — Resolve the source and read context

### 3a. Spec source
Resolve the spec identifier to a folder per **Spec identifiers** in `RULES.md`. The rest of this file uses `<feature-name>` for that resolved folder.

Read:

- `.claude/specs/<feature-name>/CODE-REVIEW.md` — the findings to fix
- `.claude/specs/<feature-name>/DESIGN.md` — original technical design
- `.claude/specs/<feature-name>/IMPLEMENTATION.md` — what was built
- `.claude/specs/<feature-name>/LOGS.md` — session history, to understand current state

If `CODE-REVIEW.md` is empty or missing, stop:

> "⚠️ No code review found for `<spec-id>`. Run `/code-review <n>` first."

### 3b. Review source
Sanitize `<review-name>` the same way `/review` does (lowercase, whitespace and slashes become `-`). If `.claude/reviews/<review-name>/` doesn't exist, stop:

> "⚠️ No review found named `<review-name>`. Run `/review` first."

Read:

- `.claude/reviews/<review-name>/REVIEW.md` — the findings to fix
- `.claude/reviews/<review-name>/diff.patch` — the change under review
- `.claude/reviews/<review-name>/LOGS.md` — the review's own journal
- `.claude/reviews/<review-name>/ticket.md`, if it exists

Fix from the **latest pass only** — the block under the last `> **Pass:** <N>` line. Codes are scoped per pass, so `B1` always means the latest pass's `B1`; earlier passes are history and are never fixed from. Use `<N>` as this run's pass number.

**Branch check.** Take the head branch from the latest pass's `> **Target:**` line and compare it with the current branch (`git rev-parse --abbrev-ref HEAD`). If they differ, stop:

> "⚠️ Review `<review-name>` is for `<head-branch>`, but you're on `<current-branch>`. Check out `<head-branch>` and re-run — `/fix` changes the working tree."

### 3c. Nothing in scope
If no findings are in scope after Step 2c, write nothing and hand off using the format in [`guides/result-format.md`](../../ptah/guides/result-format.md):

```
✅ /fix <n> — nothing in scope          (review source: "/fix --review <review-name> — nothing in scope (pass <N>)")
Out of scope: <codes, or "none"> — pull any in with --include-minor, or by code in plan mode
Next: /document <n>          (review source: nothing to do until the next /review pass)
```

### 3d. Consult prior knowledge
Read `.claude/ptah/knowledge/INDEX.md` if it exists. Scan for anything relevant to the findings you're about to fix — a `gotcha` entry can turn "the review flagged this" into "this is the same root cause as entry 14, fix it the same way." Cheap scan, not a search; skip silently if `INDEX.md` doesn't exist. Full entry, if needed: `python3 .claude/ptah/ptah_knowledge.py get <id>`. Per **Knowledge discipline** in `RULES.md`, don't cite this in `LOGS.md` — if it changes how a fix is applied, that belongs in the fix's own note in the Fix Summary.

---

## Step 4 — Clarify before fixing

Apply the **Stop and ask** rule from [`.claude/ptah/RULES.md`](../../ptah/RULES.md). Review all in-scope findings; if any is ambiguous or could have side effects beyond this change's scope, ask before touching code.

This applies in **all three modes** — modes control verbosity for routine fixes, not judgment for ambiguous ones.

---

## Step 5 — Apply fixes (mode-specific)

### Directives by code

In `plan` and `interactive` modes, the user can steer individual findings by code in a free-form reply, several per message — e.g. "B2: use the existing validator instead. ignore M2. N3 is already fixed."

| Directive | Effect |
|---|---|
| A different approach for a code | Replaces the review's suggested fix for that finding. Recorded as user-directed. |
| Ignore / skip | Finding moves to **Skipped** — reason: ignored by user, plus any reason given. |
| Already fixed | Finding moves to **Skipped** — reason: already fixed (per user). Not re-verified. |
| Fix an out-of-scope code (an `N` outside `include_minor`, or any `S`) | Pulled into scope for this run. |
| Code not mentioned | Handled as planned. |

- Match codes case-insensitively — `b2` is `B2`.
- A code that doesn't exist in the findings being fixed → stop and ask. Don't guess which finding was meant.
- A directive that's ambiguous about what to do → stop and ask, per the **Stop and ask** rule.
- A user-directed approach still obeys Step 6 — if it requires a design change or a new dependency, ask first.

`auto` mode shows no prompt, so it takes no directives.

### `auto` mode
Apply every in-scope fix without asking. Do not narrate each fix as it happens — produce the Fix Summary at the end. The only interruption is the stop-and-ask rule from Step 4 for genuinely ambiguous fixes.

### `plan` mode (default)
Before touching any code, present a fix plan. `<source>` is `<n>` for a spec, or `review <review-name>` for a review:

```
📋 Fix plan — <source>

🔴 B1 — <title>
   Change: <one-line summary of intended change>
   Files:  <comma-separated list of files to be modified>

🟡 M1 — <title>
   Change: <one-line summary>
   Files:  <files>

(🟢 N findings included only if include_minor is true)

Not in this run: <out-of-scope codes, or "none">

Mode: plan
Total: <X> blockers, <Y> major<, Z minor if included>

Apply all of these? Reply "yes", or steer by code — e.g. "B2: do X instead, skip M1".
```

- **"yes" (or similar)** → apply the plan as shown.
- **Directives** → apply the plan with the directives folded in. A reply made of directives is itself the confirmation; don't re-prompt unless something needs clarifying.
- **A plain decline** → stop and ask what to do differently.

Once confirmed, apply all fixes in one pass without further narration.

### `interactive` mode
Work through in-scope findings one at a time. For each:

1. State the finding (icon, code, title, `file:line`)
2. Describe the intended change in one or two lines
3. Ask: "Apply this fix? (yes / skip / or tell me a different approach)"
4. Wait for the reply — any directive by code applies, including ones for findings later in the list
5. Apply, briefly note the result
6. Move to the next finding

The user can pause the loop or change direction at any point.

---

## Step 6 — Rules while fixing

These apply regardless of mode:

- Fix only what is documented in the findings being fixed — do not refactor unrelated code
- If a fix requires a design change, stop and ask the user before proceeding
- If a fix introduces a new dependency not in the original design, ask first
- Keep fixes minimal and focused — don't improve things that aren't broken
- 💡 `S` findings are fixed only when the user names them in a directive

---

## Step 7 — Record the fixes

### 7a. Fix Summary
Append a **Fix Summary** to the findings file — `CODE-REVIEW.md` for a spec, `REVIEW.md` for a review. For a review, the heading is `## Fix Summary — pass <N> — <date>` so it's tied to the pass it fixed.

```markdown
## Fix Summary — <date>

### Mode
<auto | plan | interactive>, include_minor: <true | false>

### Fixed
- [x] 🔴 B1 — <title> — <brief note on how it was fixed>
- [x] 🔴 B2 — <title> — <brief note> (user-directed: <the approach given>)
- [x] 🟡 M1 — <title> — <brief note>
- [x] 🟢 N1 — <title> — <brief note> (only if in scope this run)
- [x] 💡 S2 — <title> — <brief note> (named by the user)

### Skipped
- [ ] 🟡 M2 — <title> — ignored by user<: reason, if given>
- [ ] 🟢 N3 — <title> — already fixed (per user)
<"None" if every in-scope finding was applied.>

### Deferred
- [ ] 🟢 N2 — <title> — deferred: not in scope this run
- [ ] 💡 S1 — <title> — deferred: suggestion, not auto-fixed

### New issues found during fix
<Any new issues discovered while fixing. "None" if clean.>
```

The Fix Summary is structurally identical across all three modes and both sources. Every finding of the fixed pass appears exactly once — under Fixed, Skipped, or Deferred.

### 7b. LOGS.md entry

**Spec source** — append to `.claude/specs/<feature-name>/LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /fix completed
- Mode: <auto | plan | interactive>
- 🔴 Blockers fixed: <count>
- 🟡 Major issues fixed: <count>
- 🟢 Minor fixed: <count, or "skipped — not in scope">
- 💡 Suggestions fixed: <count, or "none">
- Skipped by user: <count, or "none">
- New issues found: <"no", or "yes — <brief note>">
- Next step: /document
```

**Review source** — append to `.claude/reviews/<review-name>/LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /fix completed (pass <N>)
- Mode: <auto | plan | interactive>
- 🔴 Blockers fixed: <count>
- 🟡 Major issues fixed: <count>
- 🟢 Minor fixed: <count, or "skipped — not in scope">
- 💡 Suggestions fixed: <count, or "none">
- Skipped by user: <count, or "none">
- New issues found: <"no", or "yes — <brief note>">
- Next step: /review <target> --name <review-name>
```

`<target>` comes from the latest pass's `> **Target:**` line. See [`guides/logs-format.md`](../../ptah/guides/logs-format.md) for the full schema.

---

## Step 8 — Suggest capture before hand-off

Apply **Suggest capture before hand-off** from **Knowledge discipline** in `RULES.md`. A fix whose root cause wasn't obvious from the finding is a strong candidate.

---

## Step 9 — Hand off to user

Use the hand-off format in [`guides/result-format.md`](../../ptah/guides/result-format.md).

**Spec source:**

```
✅ /fix <n> completed
Artifact: `.claude/specs/<feature-name>/CODE-REVIEW.md` (fix summary appended)
Mode: <mode> — fixed: <codes> · skipped: <codes, or "none"> · deferred: <codes, or "none">
New issues found: <"no", or "yes — <note>">
Next: /document <n>
```

**Review source:**

```
✅ /fix --review <review-name> completed (pass <N>)
Artifact: `.claude/reviews/<review-name>/REVIEW.md` (fix summary appended)
Mode: <mode> — fixed: <codes> · skipped: <codes, or "none"> · deferred: <codes, or "none">
New issues found: <"no", or "yes — <note>">
Next: commit the changes, then /review <target> --name <review-name> for pass <N+1>
```

Use the number, not the full folder name, when telling the user what to run next — see **Spec identifiers** in `RULES.md`.

---

## Modes & config

`/fix` has three modes:

| Mode | Behavior |
|------|----------|
| `auto` | Apply all in-scope fixes silently. Report at the end. Takes no directives. |
| `plan` | Show a one-line-per-finding plan, wait for one reply — "yes" or directives by code — then apply all in one pass. **Default.** |
| `interactive` | Ask per finding before applying. Directives by code work at every prompt. |

Mode is resolved with precedence **flag > config > default (`plan`)**.

### Config (`.claude/ptah/ptah.yml`)

```yaml
commands:
  fix:
    mode: plan              # auto | plan | interactive
    include_minor: false    # also fix 🟢 minor issues by default?
```

Both keys are optional. Missing keys fall back to defaults.

### Flags (per-run override)

- `--auto`, `--plan`, `--interactive` — override `mode` for this run
- `--include-minor` — force `include_minor: true` for this run
- `--blockers-only` — force `include_minor: false` for this run

Conflicting flags produce an error and stop. The config file is never modified by `/fix`.

### The stop-and-ask rule always applies

Regardless of mode, the **Stop and ask** rule from `RULES.md` applies — if a fix is ambiguous, could have side effects beyond scope, requires a design change, or introduces a new dependency, the agent stops and asks. `auto` mode does not suppress this.

---

## Workflow

On the feature track, `/fix` sits between review and documentation:

```
/spec → /design → /implement → /code-review → /fix → /document
```

On a standalone review, `/fix --review` closes the loop with `/review`:

```
/review <branch> → /fix --review <name> → /review <branch> (next pass) → ...
```

Each command appends an entry to its own `LOGS.md` — the spec's for the feature track, the review's for a standalone review. When resuming after a break, read `LOGS.md` first to understand where the work stands.

Always wait for the user to review and confirm before suggesting the next step.
