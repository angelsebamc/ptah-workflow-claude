# /status

List all in-flight specs with their current state. Use this to discover what's been started but not finished — the typical first command when sitting down to a clean session.

By default, hides completed work to reduce noise. Pass `--all` to include completed specs too.

## Step 1 — Read the context

When the user runs `/status` (or `/status --all`), apply the **Always read LOGS.md first** rule from [`.claude/ptah/RULES.md`](../../ptah/RULES.md) — `/status` _is_ the rule applied broadly: it reads every `LOGS.md` to surface state.

Scan this location:
- `.claude/specs/ptah-*/LOGS.md` — one per feature (also include any legacy non-numbered folders under `.claude/specs/*/LOGS.md`)

For each match, note the **full folder name** (`ptah-<n>-<slug>`) — this is what gets displayed in Step 4 — and the spec number `<n>` extracted from it, needed for the `next:` line. Legacy folders without a `ptah-<n>` prefix are just their own folder name, with no separate number to extract.

If the folder doesn't exist or is empty, tell the user:

> "No specs found. Run `/spec <name>` to start one."

---

## Step 2 — Determine state for each spec

For each `LOGS.md`, read the **last entry** to determine state.

### State derivation rules

Look at the heading of the last entry — `## <YYYY-MM-DD HH:MM:SS> — /<command> <status>`.

| Last entry heading | State | Icon |
|---|---|---|
| `/document completed` | **Completed** | ✅ |
| `/<anything> paused` | **Paused** | ⏸️ |
| Any other `completed` | **Active** | 🔄 |
| No entries / empty file | **Just started** | 🆕 |

For active and paused entries, also extract the `Next step:` field from the last entry — it tells the user what command to run next.

For paused entries, also extract `Blocked on:` — that's what the user needs to resolve.

For completed entries with `--all`, no extra info needed beyond the date.

---

## Step 3 — Filter

By default (no flag), **exclude** completed entries from the output.

If `--all` was passed, **include** everything.

If after filtering nothing remains, tell the user:

> "Nothing in flight. Run `/status --all` to see completed work too, or `/spec <name>` to start something new."

---

## Step 4 — Print the report

Group by state in this order: **paused → active → just started → completed** (completed only appears with `--all`). Within each group, sort ascending by spec number.

Use this exact format — the identifier column shows the **full spec name** (`ptah-<n>-<slug>`), so the report reads as a scannable overview rather than a bare list of numbers. The `next:` line still uses the bare number, since that's what you'd actually type to run it.

```
📋 Status

  ⏸️ ptah-4-dark-mode            paused at /<command>
                                 blocked on: <one-line summary>
  🔄 ptah-7-user-login           last: /<command> <status>
                                 next: /<next-command> 7
  🆕 ptah-9-export-csv           just started, no commands run yet

(With --all, also:)
  ✅ ptah-2-onboarding-flow      completed YYYY-MM-DD
```

Include the spec number (not the full name) in the `next:` line so it's directly runnable (e.g. `next: /fix 7`). Left-align the identifier column, padding to the longest name in the list so the status text lines up. Keep the icon column consistent (one space after the icon, then the identifier). Truncate `blocked on:` to one line — full detail is in `LOGS.md`.

Legacy specs without a `ptah-<n>` folder name are listed the same way, using their full folder name as-is.

---

## Step 5 — Hand off to user

End with a short prompt that points the user toward the next move:

> "Run `/resume <n>` to load context for one, or run the suggested `next:` command directly if you're ready to continue."

Do **not** automatically run any command. `/status` is read-only — it never modifies files or appends to `LOGS.md`.

---

## Workflow

`/status` is a meta-command — it sits above the workflow:

```
/status              ← discovery (you are here)
/resume <n>          ← load context for a specific spec
/spec, /design, ... ← actual work commands
```

Use `/status` when:
- Sitting down to a clean session and you've forgotten what's in flight
- Wondering whether a feature got finished or got stuck
- Auditing the project before a teammate asks "what's the state of X?"

`/status` does not append to any `LOGS.md` — it's purely a read.