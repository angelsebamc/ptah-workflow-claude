# LOGS.md format

Every command appends an entry to `LOGS.md` when it completes, pauses, or fails, and **change entries** are appended in between as work happens. All entries follow the same strict schema.

This guide defines the schema. The discipline (when to log, when not to) lives in `RULES.md` under "Logging discipline". Every fixed value — statuses, change types, triggers, verdicts — is defined in [`vocabulary.md`](./vocabulary.md).

---

## Required structure

```
## <YYYY-MM-DD HH:MM:SS> — /<command> <status>
- <field>: <value>
- <field>: <value>
- ...
- Next step: <next-command-or-action>
```

## Rules

1. **Heading** — `H2` (`##`), exact format: `<YYYY-MM-DD HH:MM:SS> — /<command> <status>`
   - Date and time use 24-hour local time, e.g. `2026-05-08 14:32:07`
   - `<status>` is a **command status** from `vocabulary.md`: `completed`, `paused`, or `failed`
2. **Body** — unordered list (`-`), one field per line, in the order defined below
3. **One line per value** — no value spans lines; lists inside a value are comma-separated
4. **Last field** — must always be `Next step:` for command entries (change entries are exempt — see below)
5. **Separator** — one blank line between entries, no horizontal rules
6. **Order** — newest entries appended to the bottom (chronological), not the top
7. **No prose** — entries are bullets only, no paragraphs

Entries that name commands without the `ptah-` prefix (`— /spec completed`, `Next step: /design`) mean the same commands. Read them as their `/ptah-` equivalents, show the prefixed form to the user, and write new entries with the prefix only.

Subagent results use these same field names, so a dispatcher copies them across rather than translating — see [`result-format.md`](./result-format.md).

---

## `paused` and `failed` — any command

These two have the same fields whichever command wrote them.

### `/<command> paused`
- Blocked on (one line — what needs the user's input)
- Progress (one line — what's finished so far, or `none`)
- Files touched (comma-separated paths, or `none`)
- Next step (`answer the open questions, then re-run /<command>`)

Written by `/ptah-design` and `/ptah-implement` when their subagent returns `needs-input`. The user's answers follow as `decision` / `deviation` / `scope-change` change entries, and a re-run picks up from there.

### `/<command> failed`
- Reason (one line)
- Next step (`re-run /<command>`, or what to fix first)

Written when a subagent returns `error` or a malformed result. No artifact is written for a failed run.

---

## `completed` — per-command fields (required, in order)

### `/ptah-spec completed`
- Feature
- Source (ticket ID or `none`)
- Key decisions
- Next step

### `/ptah-design completed`
- Approach
- Key decisions
- Open questions (count or `none`)
- Next step

### `/ptah-implement completed`
- Summary
- Files created (count)
- Files modified (count)
- Deviations from design (`yes — see change entries above` or `no`)
- Known issues (`yes — <note>` or `no`)
- Next step

### `/ptah-code-review completed`
- 🔴 Blockers (count)
- 🟡 Major (count)
- 🟢 Minor (count)
- 💡 Suggestions (count)
- Acceptance criteria (`X of Y met`)
- Verdict (`fix-needed` or `ready-to-document`)
- Next step (`/ptah-fix` or `/ptah-document`, from the verdict)

### `/ptah-fix completed`
- Mode (`auto`, `plan`, or `interactive`)
- 🔴 Blockers fixed (count)
- 🟡 Major issues fixed (count)
- 🟢 Minor fixed (count, or `skipped — not in scope`)
- 💡 Suggestions fixed (count, or `none`)
- Skipped by user (count, or `none` — includes findings marked already fixed)
- New issues found (`yes — <note>` or `no`)
- Next step (`/ptah-document`)

### `/ptah-fix completed (pass <N>)`

`/ptah-fix --review <name>`, written to `.claude/reviews/<review-name>/LOGS.md`. Same fields as `/ptah-fix completed`, except:

- Next step (`/ptah-review <target> --name <review-name>`)

### `/ptah-document completed`
- Summary file written (`README.md`)
- Next step (`none — workflow complete`)

### `/ptah-review completed (pass <N>)` / `/ptah-review failed (pass <N>)`

Written to `.claude/reviews/<review-name>/LOGS.md`, never to a spec's `LOGS.md`.

- Target
- Base (`<branch> @ <short-sha>`)
- Source (ticket ID or `none`)
- 🔴 Blockers (count)
- 🟡 Major (count)
- 🟢 Minor (count)
- 💡 Suggestions (count)
- Verdict (`request-changes`, `approve-with-minors`, or `approve`)
- Next step

---

## Change entries

Between command entries, the agent appends **change entries** whenever a meaningful event happens mid-session: decisions, deviations from the design, scope changes, blockers, or corrections. They are the canonical record of in-flow events — completion entries reference them rather than restating them.

Heading uses `change during /<command>` instead of `<command> <status>`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — change during /<command>
- Trigger: <user-request | agent-decision>
- Type: <decision | deviation | scope-change | blocker | correction>
- What: <one-line description>
- Why: <reason>
- Impact: <files, decisions, or downstream steps affected; or "none">
```

All five fields are required, in the order shown. `Next step:` is **not** included — change entries record what happened, they don't move the workflow forward.

Entries written before the vocabulary was fixed may use `scope change`, `user request`, or `agent decision` with spaces. Read them as their kebab-case equivalents; write new entries in kebab-case only.

---

## Example

```markdown
## 2026-04-23 09:14:22 — /ptah-spec completed
- Feature: account creation with excluded from net worth toggle
- Source: PROJ-42
- Key decisions: toggle defaults to false
- Next step: /ptah-design

## 2026-04-23 11:47:03 — /ptah-design completed
- Approach: new boolean field on accounts table + UI toggle in form
- Key decisions: reuse existing form component
- Open questions: none
- Next step: /ptah-implement

## 2026-04-23 14:22:18 — /ptah-implement paused
- Blocked on: whether archived accounts count toward net worth
- Progress: form component and migration written
- Files touched: src/accounts/AccountForm.tsx, db/migrations/0042_archived.sql
- Next step: answer the open questions, then re-run /ptah-implement

## 2026-04-23 14:25:40 — change during /ptah-implement
- Trigger: user-request
- Type: scope-change
- What: archived accounts are excluded from net worth and hidden by default
- Why: resolves "should archived accounts still count toward net worth?"
- Impact: DESIGN.md updated, migration needs an `archived` column

## 2026-04-23 16:05:33 — /ptah-implement completed
- Summary: account creation form with excluded-from-net-worth toggle
- Files created: 3
- Files modified: 4
- Deviations from design: yes — see change entries above
- Known issues: no
- Next step: /ptah-code-review
```
