# /review

Review a branch or PR diff that has no Ptah spec behind it — typically **someone else's work**. Unlike `/code-review`, which checks in-flight work against its own `SPEC.md`/`DESIGN.md`, `/review` has no intent artifacts to compare against: the baseline is the diff itself, project conventions, and (optionally) a linked ticket.

Documentation only — `/review` never modifies the code under review. Findings persist under `.claude/reviews/<review-name>/` and can optionally be handed to `/fix`.

## Step 1 — Parse command arguments

The command accepts one optional positional argument (the diff target) plus optional flags:

- `<target>` — what to review. Accepts:
  - a branch name (e.g. `feature/login`) → reviewed against its merge-base with the default branch
  - a range (e.g. `main..feature/login` or `abc123..def456`)
  - omitted → reviews the current branch against its merge-base with the default branch
- `--name <review-name>` — name for the review folder. Defaults to the sanitized head branch name.
- `--jira <id>` (or any source flag declared in `ptah.yml`) — pull a ticket to review the change against its acceptance criteria, not just engineering standards.
- `--files <glob>` — narrow the review to matching paths only.

Examples:
- `/review` — review the current branch vs. default
- `/review feature/login` — review that branch vs. its merge-base
- `/review main..feature/login --jira PROJ-1234` — review the range against ticket intent
- `/review feature/login --files "src/auth/**"` — scope to auth files only

**Unknown flags** produce an error consistent with `/spec` and `/fix`:

> "⚠️ Unknown flag `--xyz`. Supported flags: `--name`, `--jira` (and other configured sources), `--files`."

---

## Step 2 — Resolve the review name and load config

### 2a. Determine `<review-name>`
- If `--name` was passed, sanitize it (lowercase, replace whitespace/slashes with `-`).
- Otherwise derive it from the head branch name, sanitized the same way.

If `.claude/reviews/<review-name>/` already exists, this is a **re-review** (the author pushed changes after a prior pass). Don't overwrite — append a new findings pass and a new `LOGS.md` entry. Tell the user:

> "🔁 `<review-name>` already exists — running a re-review. Prior findings are preserved; this pass is appended."

### 2b. Load Ptah config (only if a source flag was passed)
Read `.claude/ptah/ptah.yml`. The config is only needed to resolve a ticket flag — if no source flag was passed, skip straight to Step 3 (standards-only review).

If a source flag was passed, resolve and fetch it using the same rules as `/spec` Step 2 (validate against `id_pattern`, fetch via `fetch_via`, **stop loudly on fetch failure** — do not fall back silently). Keep the ticket's acceptance criteria in memory for Step 4.

---

## Step 3 — Capture the diff

Resolve the target into a concrete diff:

- branch → `git merge-base <default-branch> <branch>` then diff that base to the branch head
- range → diff the range directly
- omitted → current branch vs. its merge-base with the default branch

Apply `--files` as a pathspec filter if provided.

Create the review folder and snapshot the diff so the review has a stable baseline:

```
.claude/reviews/<review-name>/
  REVIEW.md      ← findings (written in Step 5)
  LOGS.md        ← review journal
  diff.patch     ← snapshot of the diff under review
```

Write the captured diff to `diff.patch`. If the diff is empty, stop and tell the user:

> "⚠️ No changes found for `<target>`. Nothing to review."

> Review no more than 400 lines of diff at a time. If the change is larger, split into logical chunks and note which chunk each finding belongs to.

---

## Step 4 — Review the diff

There is no design to check against — derive the change's intent from the diff, the branch name, the commit messages, and the ticket if one was linked. Review in this order of priority:

| Priority | Icon | Meaning | Action |
|----------|------|---------|--------|
| Blocker | 🔴 | Bug, crash, security risk, data loss | Must fix before merge |
| Major | 🟡 | Logic issue, missing edge case, test gap | Should fix before merge |
| Minor | 🟢 | Naming, readability, small improvements | Nice to fix |
| Suggestion | 💡 | Alternative approach, future consideration | Optional |

**What to focus on:**
- Logic: Does the change do what it appears to intend? Edge cases — null/empty/unexpected inputs?
- Security: Is user input validated? Auth checks in place? Any secrets or PII exposed in the diff?
- Conventions: Does it follow `CLAUDE.md` (stack, patterns, naming)?
- Regression risk: Does the change touch shared code in a way that could break callers outside the diff?
- Ticket fit (only if `--jira`/source was passed): Does the change satisfy the ticket's acceptance criteria?

**What to skip:**
- Formatting and style (linters' job)
- Naming preferences that don't affect readability
- Pre-existing issues outside the diff — review the change, not the whole codebase. Note adjacent problems only if the change makes them materially worse.

**How to frame feedback:**
- Prefer questions over commands: "Have you considered…?" over "Change this to…"
- Explain *why* something matters, not just *what* to change
- Acknowledge what's working well — this is someone else's work; be specific and fair

---

## Step 5 — Write REVIEW.md

Write findings to `.claude/reviews/<review-name>/REVIEW.md`. For a re-review, **append** a new dated pass rather than overwriting.

```markdown
# REVIEW — <review-name>

> **Target:** `<target>` (<head-branch> @ <short-sha>)
> **Base:** `<base-branch> @ <short-sha>`
> **Source:** [<ticket-id>](<url>) — <title>   (omit this line if no ticket)
> **Pass:** <N> — <date>

## Summary
<Overall assessment in 2-3 sentences. Is the change solid? Main concern? Safe to merge?>

## Findings

🔴 **BLOCKER: <short title>**
`<file>:<line>` — <what the issue is and why it matters>
Have you considered: <question or suggested fix>

🟡 **MAJOR: <short title>**
`<file>:<line>` — <what the issue is>
Suggestion: <alternative approach>

🟢 **minor: <short title>**
`<file>:<line>` — <brief note>

💡 **suggestion: <short title>**
<Optional idea, not blocking>

## Ticket fit
<Only if a ticket was linked. Check the change against each acceptance criterion:>
- [x] <criterion> — met
- [ ] <criterion> — not met: <reason>

## What's working well
<Specific, fair acknowledgement of good decisions in the diff>

## Verdict
< "Request changes — X blockers, Y major issues" >
< or "Approve with minors — no blockers or major issues" >
< or "Approve — clean" >
```

---

## Step 6 — Append to LOGS.md

After writing REVIEW.md, append an entry to `.claude/reviews/<review-name>/LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /review completed (pass <N>)
- Target: <target>
- Base: <base-branch> @ <short-sha>
- Source: <ticket-id, or "none">
- 🔴 Blockers: <count>
- 🟡 Major: <count>
- 🟢 Minor: <count>
- 💡 Suggestions: <count>
- Verdict: <request changes | approve with minors | approve>
- Next step: <handoff line — see Step 7>
```

This is a separate `LOGS.md` from any spec folder — it journals the review, not a feature. Re-reviews append additional `pass <N>` entries here, so the file shows the full review history as the author iterates.

---

## Step 7 — Hand off to user

Report the result and the path:

> "✅ Review complete — `.claude/reviews/<review-name>/REVIEW.md`
>
> 🔴 Blockers: X | 🟡 Major: Y | 🟢 Minor: Z | 💡 Suggestions: W
> Verdict: <verdict>"

**Optional `/fix` handoff.** Only mention this when there are in-scope findings (blockers or major) **and** the reviewer is on a branch they can modify — fixing someone else's PR is the author's job by default, not the reviewer's. When it applies:

> "If this is your branch to modify, you can apply the blocker/major fixes with `/fix --review <review-name>`. Otherwise, share `REVIEW.md` with the author."

Do **not** auto-run `/fix`. `/review` is read-only on the codebase.

---

## What `/review` is and isn't

**It is:** a standalone review of a diff that has no spec behind it — for reviewing others' PRs, or any change that didn't go through the Ptah feature track.

**It isn't:** `/code-review`. That command reviews *your own* in-flight work against its `SPEC.md`/`DESIGN.md` inside a spec folder, and is part of the `/spec → … → /document` pipeline. `/review` lives outside that pipeline entirely.

| | `/code-review` | `/review` |
|---|---|---|
| Input | a feature spec folder | a branch / PR diff |
| Baseline | SPEC.md + DESIGN.md | the diff + CLAUDE.md (+ optional ticket) |
| Output | `.claude/specs/<feature>/CODE-REVIEW.md` | `.claude/reviews/<name>/REVIEW.md` |
| Part of the pipeline | yes | no |
| Feeds `/fix` | yes (default) | optional (`/fix --review <name>`) |

---

## Workflow

`/review` is a standalone command, not part of the feature track:

```
/review <branch>            ← review a diff
  └─ (optional) /fix --review <name>   ← if it's yours to modify
```

It does not append to any spec's `LOGS.md` — only to its own review journal at `.claude/reviews/<review-name>/LOGS.md`.
