# /resume

Orient the agent on a spec's current state at the start of a new session, so the next workflow command can be run with confidence. Run this before continuing any in-flight work.

`/resume` is read-only — it does not append to `LOGS.md` and does not run the next workflow command. Its job is **orientation, not preloading**: it reads the session history and reports where the work stands. It does not load artifacts — every workflow command (`/design`, `/implement`, `/fix`, etc.) reads its own inputs when it runs, so loading them here would only put the same content in context twice.

## Step 1 — Locate the spec

When the user runs `/resume <spec-id>`, resolve `<spec-id>` to a spec folder per **Spec identifiers** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md) — it may be a bare number, `ptah-<n>`, or a full folder name.

If no matching folder exists, stop and tell the user:

> "⚠️ No spec found for `<spec-id>`. Run `/status` to see what's in flight."

---

## Step 2 — Read the session history

Apply the **Always read LOGS.md first** rule from `RULES.md`: read the full `LOGS.md` for the resolved spec folder. This is the only file `/resume` reads.

If `LOGS.md` is empty or missing, tell the user:

> "⚠️ No history found for `<spec-id>`. The folder exists but no commands have been logged yet. Start with `/spec <feature-name>`."

Otherwise, identify:
- **The last command entry** (`/<command> completed | paused | failed`) — anchors what state the work is in
- **All change entries since that last command entry** — decisions, deviations, and corrections from the most recent step
- **Counts** of command entries and change entries in the whole file

---

## Step 3 — Inventory artifacts and refs

Derive which artifacts have been produced from the command entries in `LOGS.md` — not by opening the files:

| Command logged as completed | Artifact produced |
|---|---|
| `/spec` | `SPEC.md` |
| `/design` | `DESIGN.md` |
| `/implement` | `IMPLEMENTATION.md` |
| `/code-review` | `CODE-REVIEW.md` |
| `/fix` | `CODE-REVIEW.md` (fix summary appended) |
| `/document` | `README.md` |

List the filenames in the spec folder's `refs/` with `Glob`. Filenames only — do not open them.

### Do not read

- Any artifact (`SPEC.md`, `DESIGN.md`, `IMPLEMENTATION.md`, `CODE-REVIEW.md`, `README.md`)
- Anything in `refs/`
- Any source file, including files listed in `IMPLEMENTATION.md`
- `CLAUDE.md` or `RULES.md` — `CLAUDE.md` is already in context from session start, and the next command follows its references to `RULES.md` as needed
- `.claude/ptah/knowledge/INDEX.md` — workflow commands consult it themselves

---

## Step 4 — Print the summary

Use this exact format — the header shows the spec's **number only**, never the slug or full folder name:

```
🔄 Resumed <n>

History: LOGS.md (<count> command entries, <count> change entries)
Artifacts: <comma-separated artifact filenames from Step 3>
Refs: <comma-separated refs/ filenames, or "none">

Last command:
## <heading line, verbatim>
- <fields, verbatim>

Changes since then:
- <HH:MM> <type> — <the entry's "What:" value>

(One line per change entry since the last command. If none: "None.")

Where you are: <one-line synthesis based on the last command's "Next step:" field>
```

If the resolved spec is a legacy folder without a `ptah-<n>` name, show its full folder name in place of `<n>`.

### Rules for the synthesis line

The `Where you are:` line is the only piece of original prose in the response — everything else comes from `LOGS.md`. Keep it to one sentence, and reference the next command by number. Examples:

- `"Implementation finished. Next step: /code-review 7."`
- `"Code review done with 2 blockers, 1 major. Next step: /fix 7."`
- `"Spec written. Next step: /design 7."`

If the last entry is `paused`, name what it's blocked on instead of a next command, e.g. `"Paused during /implement, blocked on: <Blocked on: value>."`

If the workflow is complete (last entry is `/document completed`), the synthesis line is:

> `"This work is complete. The full record is in ptah-<n>'s folder."`

---

## Step 5 — Hand off to user

End with:

> "Oriented on <n>. Run the next command yourself when you're ready — it loads the artifacts it needs."

Do **not** auto-run anything. Do **not** append to `LOGS.md` — `/resume` is purely a read.

---

## What `/resume` is and isn't

**It is:** an orientation command. It reads `LOGS.md` and reports where the work stands, so you and the agent agree on the next step before running it.

**It isn't:** a context preloader. Artifacts, refs, and code are loaded by the workflow command that needs them, when it runs. It also isn't a state report across specs (use `/status` for that), and isn't a workflow command — it never produces or modifies artifacts, never appends to `LOGS.md`.

---

## Workflow

`/resume` is a meta-command, alongside `/status`:

```
/status              ← what's in flight?
/resume <n>          ← orient on one spec (you are here)
/spec, /design, ...  ← actual work commands
```

Use `/resume` when:
- Starting a new session and continuing work from a previous one
- Switching between two in-flight specs (run `/resume <other-n>` to swap)
- Briefing a fresh agent (or a teammate) on the current state of a feature

`/resume` does not append to any `LOGS.md` — it's purely a read.
