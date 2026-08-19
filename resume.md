# /resume

Reload the full working context for a spec so the agent can pick up the work as if the session never ended. Run this at the start of a new session before continuing any in-flight work.

`/resume` is read-only — it does not append to `LOGS.md` and does not run the next workflow command. Its job is to **prime the agent**: pull every relevant artifact into context so the next command runs with full knowledge of what came before.

When the user runs `/resume <spec-id>`, resolve `<spec-id>` to a spec folder per **Spec identifiers** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md) — it may be a bare number, `ptah-<n>`, or a full folder name.

If no matching folder exists, stop and tell the user:

> "⚠️ No spec found for `<spec-id>`. Run `/status` to see what's in flight."

---

## Step 2 — Load the project rules

Apply the **Always read LOGS.md first** rule from [`.claude/ptah/RULES.md`](../../ptah/RULES.md). Read these files in order:

1. `CLAUDE.md` (project root) — stack, conventions, the reference to RULES.md
2. `.claude/ptah/RULES.md` — workflow rules (logging discipline, stop-and-ask, path conventions)

These give the agent the project-wide context it needs to operate correctly on this work.

---

Read the full `LOGS.md` for the resolved spec folder.

If `LOGS.md` is empty or missing, tell the user:

> "⚠️ No history found for `<spec-id>`. The folder exists but no commands have been logged yet. Start with `/spec <feature-name>`."

Otherwise, identify:
- **The last command entry** (`/<command> completed | paused | failed`) — anchors what state the work is in
- **All change entries since that last command entry** — captures decisions, deviations, and corrections from the most recent step

---

## Step 4 — Load the relevant artifacts

Load **only the artifacts that exist and are relevant for the current state**. Do not load artifacts that haven't been produced yet — they don't exist.

Read `.claude/ptah/ptah.yml` to determine whether testing is enabled (`commands.test.enabled`, defaults to `false`). When testing is disabled, `TEST.md` will never have been produced, so it's not in the load list even at later workflow stages.

The mapping below tells you which artifacts to load based on the last command logged.

| Last command logged | Artifacts to load |
|---|---|
| `/spec completed` | `SPEC.md` |
| `/design completed` | `SPEC.md`, `DESIGN.md` |
| `/implement completed` | `SPEC.md`, `DESIGN.md`, `IMPLEMENTATION.md` |
| `/code-review completed` | `SPEC.md`, `DESIGN.md`, `IMPLEMENTATION.md`, `CODE-REVIEW.md` |
| `/fix completed` | `SPEC.md`, `DESIGN.md`, `IMPLEMENTATION.md`, `CODE-REVIEW.md` (with fix summary) |
| `/test completed` | `SPEC.md`, `DESIGN.md`, `IMPLEMENTATION.md`, `CODE-REVIEW.md`, `TEST.md` |
Also load any files in the spec folder's `refs/` that exist — they're referenced by the spec or design.

---

## Step 5 — Confirm context is loaded

Print a short summary that proves the loading happened. Use this exact format — the header shows the spec's **number only**, never the slug or full folder name:

```
🔄 Resumed <n>

Loaded:
- Project rules: CLAUDE.md, .claude/ptah/RULES.md
- Session history: LOGS.md (<count> command entries, <count> change entries)
- Artifacts: <comma-separated list of artifact filenames>
- Refs: <list of refs/ filenames, or "none">

Last command:
## <heading line, verbatim>
- <fields, verbatim>

Recent changes since then:
## <change entry heading, verbatim>
- <fields, verbatim>

(Repeat for each change entry since the last command. If none: "No change entries since the last command.")

Where you are: <one-line synthesis based on the last command's "Next step:" field>
If the resolved spec is a legacy folder without a `ptah-<n>` name, show its full folder name in place of `<n>`.

### Rules for the synthesis line

The `Where you are:` line is the only piece of original prose in the response — everything else is verbatim from `LOGS.md`. Keep it to one sentence, and reference the next command by number. Examples:

- `"Implementation finished. Next step: /code-review 7."`
- `"Code review done with 2 blockers, 1 major. Next step: /fix 7."`
- `"Spec written. Next step: /design 7."`

**Routing override when testing is disabled.** If the `Next step:` field in the last command entry is `/test` but `commands.test.enabled` is `false` (or `ptah.yml` is missing), the synthesis line should suggest `/document` instead. This matches the routing override in `/status`.

If the workflow is complete (last entry is `/document completed`), the synthesis line is:

> `"This work is complete. The full record is in ptah-<n>'s folder."`

---

## Step 6 — Hand off to user

End with:

> "Context loaded. Run the next command yourself when you're ready."

Do **not** auto-run anything. Do **not** append to `LOGS.md` — `/resume` is purely a read.

The user now has an agent primed with everything needed to execute the next workflow command with full continuity.

---

## What `/resume` is and isn't

**It is:** a context-loading command. It pulls every relevant artifact into the agent's working memory so the next workflow command (`/design`, `/implement`, `/fix`, etc.) runs with full knowledge of what came before.

**It isn't:** a state report for the user (use `/status` for that), and isn't a workflow command (it never produces or modifies artifacts, never appends to `LOGS.md`).

The summary printed in Step 5 is _evidence_ that the loading happened — the real value is the agent's context window now contains everything needed to continue.

---

## Workflow

`/resume` is a meta-command, alongside `/status`:

/resume <n>          ← load full working context for one spec (you are here)
/spec, /design, ...  ← actual work commands
```

Use `/resume` when:
- Starting a new session and continuing work from a previous one
- Switching between two in-flight specs (run `/resume <other-n>` to swap context)
- Briefing a fresh agent (or a teammate) on the current state of a feature

`/resume` does not append to any `LOGS.md` — it's purely a read.
