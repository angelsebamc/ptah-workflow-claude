---
name: ptah-resume
description: 'Orients on one Ptah spec by reading its LOGS.md and reporting the last command, changes since, artifacts produced, and the next step. Read-only; loads no artifacts or code. Use when the user runs /ptah-resume with a spec number to continue in-flight work.'
argument-hint: '<spec-id>'
disable-model-invocation: true
---

# /ptah-resume

Orient the agent on a spec's current state at the start of a new session, so the next workflow command can be run with confidence. Run this before continuing any in-flight work.

`/ptah-resume` is read-only — it does not append to `LOGS.md` and does not run the next workflow command. Its job is **orientation, not preloading**: it reads the session history and reports where the work stands. It does not load artifacts — every workflow command (`/ptah-design`, `/ptah-implement`, `/ptah-fix`, etc.) reads its own inputs when it runs, so loading them here would only put the same content in context twice.

## Step 1 — Locate the spec

When the user runs `/ptah-resume <spec-id>`, resolve `<spec-id>` to a spec folder per **Spec identifiers** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md) — it may be a bare number, `ptah-<n>`, or a full folder name.

If no matching folder exists, stop and tell the user:

> "⚠️ No spec found for `<spec-id>`. Run `/ptah-status` to see what's in flight."

---

## Step 2 — Read the session history

Apply the **Always read LOGS.md first** rule from `RULES.md`: read the full `LOGS.md` for the resolved spec folder. This is the only file `/ptah-resume` reads.

If `LOGS.md` is empty or missing, tell the user:

> "⚠️ No history found for `<spec-id>`. The folder exists but no commands have been logged yet. Start with `/ptah-spec <feature-name>`."

Otherwise, identify:
- **The last command entry** (`/<command> completed | paused | failed`) — anchors what state the work is in. Change entries don't count; skip past them when looking for it.
- **All change entries since that last command entry** — decisions, deviations, and corrections from the most recent step
- **Counts** of command entries and change entries in the whole file

---

## Step 3 — Inventory artifacts and refs

Derive which artifacts have been produced from the command entries in `LOGS.md` — not by opening the files:

| Command logged as completed | Artifact produced |
|---|---|
| `/ptah-spec` | `SPEC.md` |
| `/ptah-design` | `DESIGN.md` |
| `/ptah-implement` | `IMPLEMENTATION.md` |
| `/ptah-code-review` | `CODE-REVIEW.md` |
| `/ptah-fix` | `CODE-REVIEW.md` (fix summary appended) |
| `/ptah-document` | `README.md` |

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

- `"Implementation finished. Next step: /ptah-code-review 7."`
- `"Code review done with 2 blockers, 1 major. Next step: /ptah-fix 7."`
- `"Spec written. Next step: /ptah-design 7."`

If the last command entry is `paused`, name what it's blocked on and how to pick it back up. The change entries after it are the user's answers so far. E.g. `"Paused during /ptah-implement, blocked on: <Blocked on: value> — 2 answers logged. Re-run /ptah-implement 7 to continue."`

If the last command entry is `failed`, give the reason and the re-run, e.g. `"/ptah-code-review failed: <Reason: value>. Re-run /ptah-code-review 7."` For a failed `/ptah-implement`, add that code may have changed on disk.

Command statuses and spec states are defined in [`guides/vocabulary.md`](../../ptah/guides/vocabulary.md).

If the workflow is complete (last entry is `/ptah-document completed`), the synthesis line is:

> `"This work is complete. The full record is in ptah-<n>'s folder."`

---

## Step 5 — Hand off to user

End with:

> "Oriented on <n>. Run the next command yourself when you're ready — it loads the artifacts it needs."

Do **not** auto-run anything. Do **not** append to `LOGS.md` — `/ptah-resume` is purely a read.

---

## What `/ptah-resume` is and isn't

**It is:** an orientation command. It reads `LOGS.md` and reports where the work stands, so you and the agent agree on the next step before running it.

**It isn't:** a context preloader. Artifacts, refs, and code are loaded by the workflow command that needs them, when it runs. It also isn't a state report across specs (use `/ptah-status` for that), and isn't a workflow command — it never produces or modifies artifacts, never appends to `LOGS.md`.

---

## Workflow

`/ptah-resume` is a meta-command, alongside `/ptah-status`:

```
/ptah-status              ← what's in flight?
/ptah-resume <n>          ← orient on one spec (you are here)
/ptah-spec, /ptah-design, ...  ← actual work commands
```

Use `/ptah-resume` when:
- Starting a new session and continuing work from a previous one
- Switching between two in-flight specs (run `/ptah-resume <other-n>` to swap)
- Briefing a fresh agent (or a teammate) on the current state of a feature

`/ptah-resume` does not append to any `LOGS.md` — it's purely a read.
