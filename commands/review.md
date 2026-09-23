# /review

Review a branch or PR diff that has no Ptah spec behind it — typically **someone else's work**. Unlike `/code-review`, which checks in-flight work against its own `SPEC.md`/`DESIGN.md`, `/review` has no intent artifacts to compare against: the baseline is the diff itself, project conventions, and (optionally) a linked ticket.

Documentation only — `/review` never modifies the code under review. This command captures the diff (and the ticket, if any), then hands the actual judgment off to the `ptah-reviewer` subagent, which runs in its own fresh context and can only `Read`, `Grep`, `Glob` — it has no way to write or edit anything. Findings persist under `.claude/reviews/<review-name>/` and can optionally be handed to `/fix`.

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

If a source flag was passed, resolve and fetch it using the same rules as `/spec` Step 2 (validate against `id_pattern`, fetch via `fetch_via`, **stop loudly on fetch failure** — do not fall back silently). Keep the fetched ticket content in memory — it gets written to disk in Step 3, since the reviewer subagent can't see anything held only in this conversation.

---

## Step 3 — Capture the diff

Resolve the target into a concrete diff:

- branch → `git merge-base <default-branch> <branch>` then diff that base to the branch head
- range → diff the range directly
- omitted → current branch vs. its merge-base with the default branch

Apply `--files` as a pathspec filter if provided.

Create the review folder and snapshot everything the subagent will need, since it starts with a blank context and can only read from disk:

```
.claude/reviews/<review-name>/
  REVIEW.md      ← findings (assembled in Step 5 from the subagent's output)
  LOGS.md        ← review journal
  diff.patch     ← snapshot of the diff under review
  ticket.md      ← fetched ticket content, only if a source flag was passed in Step 2
```

Write the captured diff to `diff.patch`. If a ticket was fetched in Step 2b, write its content to `ticket.md`. If the diff is empty, stop and tell the user:

> "⚠️ No changes found for `<target>`. Nothing to review."

> The subagent reviews no more than 400 lines of diff at a time and will chunk larger changes itself — nothing to configure here.

---

## Step 4 — Delegate to the reviewer subagent

Invoke the `ptah-reviewer` subagent. Its prompt must contain only the following facts — nothing else from this conversation:

```
Review .claude/reviews/<review-name>/
target: <target>
head: <head-branch> @ <short-sha>
base: <base-branch> @ <short-sha>
pass: <N>
date: <YYYY-MM-DD>
ticket: <ticket-id> — <url> — <title>   (or "none")
files filter: <glob, or "none">
```

The subagent reads `diff.patch`, `CLAUDE.md`, and `ticket.md` itself. Don't summarize the diff, narrate the branch's history, or characterize the change beyond these facts — that's exactly the context isolation is meant to avoid.

---

## Step 5 — Write REVIEW.md

The subagent returns a `===REVIEW-PASS===` block and a `===SUMMARY===` block (see `.claude/agents/ptah/ptah-reviewer.md` for the exact contract).

- **First pass:** write
  ```markdown
  # REVIEW — <review-name>

  <===REVIEW-PASS=== content, verbatim>
  ```
- **Re-review (pass 2+):** append a blank line, then the `===REVIEW-PASS===` content, verbatim, to the existing file. Never overwrite prior passes.

If the response doesn't match this shape, don't guess — stop and tell the user:

> "⚠️ The reviewer subagent returned something unexpected. Nothing was written. You can re-run `/review`, or I can show you the raw response."

---

## Step 6 — Append to LOGS.md

Using the counts from `===SUMMARY===`, append an entry to `.claude/reviews/<review-name>/LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /review completed (pass <N>)
- Target: <target>
- Base: <base-branch> @ <short-sha>
- Source: <ticket-id, or "none">
- 🔴 Blockers: <blockers>
- 🟡 Major: <major>
- 🟢 Minor: <minor>
- 💡 Suggestions: <suggestions>
- Verdict: <verdict>
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
| Reviewer | isolated subagent `ptah-code-reviewer` | isolated subagent `ptah-reviewer` |

---

## Workflow

`/review` is a standalone command, not part of the feature track:

```
/review <branch>            ← review a diff
  └─ (optional) /fix --review <name>   ← if it's yours to modify
```

It does not append to any spec's `LOGS.md` — only to its own review journal at `.claude/reviews/<review-name>/LOGS.md`.
