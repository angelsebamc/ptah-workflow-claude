# LOGS.md format

Every command appends an entry to `LOGS.md` when it completes, and **change entries** are appended in between as work happens. All entries follow the same strict schema.

This guide defines the schema. The discipline (when to log, when not to) lives in `CLAUDE.md` under "Logging discipline".

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
   - `<status>` is one of: `completed`, `paused`, `failed`
2. **Body** — unordered list (`-`), one field per line, in the order defined per command below
3. **Last field** — must always be `Next step:` for command entries (change entries are exempt — see below)
4. **Separator** — one blank line between entries, no horizontal rules
5. **Order** — newest entries appended to the bottom (chronological), not the top
6. **No prose** — entries are bullets only, no paragraphs

---

## Per-command fields (required, in order)

### `/spec completed`
- Feature
- Source (ticket ID or `none`)
- Key decisions
- Next step

### `/design completed`
- Approach
- Key decisions
- Open questions (count or `none`)
- Next step

### `/implement completed`
- Summary
- Files created (count)
- Files modified (count)
- Deviations from design (`yes — see change entries above` or `no`)
- Known issues (`yes — <note>` or `no`)
- Next step

### `/code-review completed`
- 🔴 Blockers (count)
- 🟡 Major (count)
- 🟢 Minor (count)
- 💡 Suggestions (count)
- Acceptance criteria (`X of Y met`)
- Next step (`/fix`, or `/document` if no issues)

### `/fix completed`
- 🔴 Blockers fixed (count)
- 🟡 Major issues fixed (count)
- 🟢 Minor deferred (count)
- New issues found (`yes — <note>` or `no`)
- Next step (`/document`)

### `/document completed`
- Summary file written (`README.md`)
- Next step (`none — workflow complete`)

---

## Change entries

Between command entries, the agent appends **change entries** whenever a meaningful event happens mid-session: decisions, deviations from the design, scope changes, blockers, or corrections. They are the canonical record of in-flow events — completion entries reference them rather than restating them.

Heading uses `change during /<command>` instead of `<command> <status>`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — change during /<command>
- Trigger: <user request | agent decision>
- Type: <decision | deviation | scope change | blocker | correction>
- What: <one-line description>
- Why: <reason>
- Impact: <files, decisions, or downstream steps affected; or "none">
```

All five fields are required, in the order shown. `Next step:` is **not** included — change entries record what happened, they don't move the workflow forward.

---

## Example

```markdown
## 2026-04-23 09:14:22 — /spec completed
- Feature: account creation with excluded from net worth toggle
- Source: PROJ-42
- Key decisions: toggle defaults to false
- Next step: /design

## 2026-04-23 11:47:03 — /design completed
- Approach: new boolean field on accounts table + UI toggle in form
- Key decisions: reuse existing form component
- Open questions: none
- Next step: /implement

## 2026-04-23 14:22:18 — change during /implement
- Trigger: agent decision
- Type: deviation
- What: used Zustand instead of useReducer for form state
- Why: form grew to 12 fields, useReducer was getting unwieldy
- Impact: new dependency added, IMPLEMENTATION.md will flag under "Deviations"

## 2026-04-23 15:08:51 — change during /implement
- Trigger: user request
- Type: scope change
- What: added optional `archived` flag to accounts table
- Why: user clarified that inactive accounts should be hidden by default
- Impact: DESIGN.md updated, migration file needs a new column

## 2026-04-23 16:05:33 — /implement completed
- Summary: account creation form with excluded-from-net-worth toggle
- Files created: 3
- Files modified: 4
- Deviations from design: yes — see change entries above
- Known issues: no
- Next step: /code-review
```
