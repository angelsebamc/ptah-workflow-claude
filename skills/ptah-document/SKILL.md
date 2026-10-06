---
name: ptah-document
description: 'Writes the final README.md summary for a completed Ptah spec, guards against unresolved blockers, and sweeps the feature for knowledge worth capturing with /ptah-learn. Last step of the Ptah pipeline. Use when the user runs /ptah-document with a spec number.'
argument-hint: '<spec-id>'
disable-model-invocation: true
---

# /ptah-document

Summarize a completed feature into a clean, human-readable record. This is the terminal step of the Ptah workflow.

## Step 1 — Read the context

When the user runs `/ptah-document <spec-id>`, first resolve `<spec-id>` to a spec folder per **Spec identifiers** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md) — it may be a bare number, `ptah-<n>`, or a full folder name. The rest of this file uses `<feature-name>` to mean that resolved folder.

Then read these files from the spec folder:

- `.claude/specs/<feature-name>/SPEC.md`
- `.claude/specs/<feature-name>/DESIGN.md`
- `.claude/specs/<feature-name>/IMPLEMENTATION.md`
- `.claude/specs/<feature-name>/CODE-REVIEW.md`
- `.claude/specs/<feature-name>/LOGS.md`

If the spec folder doesn't exist, stop and tell the user:

> "⚠️ No spec found for `<spec-id>`. Run `/ptah-spec <feature-name>` first."

**Completeness guard.** Check `CODE-REVIEW.md` for unresolved 🔴 blockers before documenting.

If unresolved blockers are found, stop and tell the user:

> "⚠️ This feature doesn't appear to be fully complete yet. There are unresolved issues in `CODE-REVIEW.md`. Are you sure you want to document it now?"

Wait for confirmation before proceeding.

---

## Step 2 — Write README.md

Write a clean, human-readable summary to `.claude/specs/<feature-name>/README.md`:

```markdown
# <feature-name>

> <one-line description from SPEC.md>

## What this feature does
<2-3 sentences explaining the feature from the user's perspective>

## Problem it solves
<from SPEC.md — why this feature matters>

## User flow
<step-by-step from SPEC.md use case>

## Technical approach
<summary of key design decisions from DESIGN.md — keep it concise>

## Files changed
**Created:**
- `<path>` — <purpose>

**Modified:**
- `<path>` — <what changed>

## Deferred items
<Minor issues and suggestions from CODE-REVIEW.md that were not fixed.
"None" if everything was resolved.>

## Notes
<Any important context, gotchas, or decisions future developers should know about>
```

---

## Step 3 — Append to LOGS.md

After writing the summary file, append the following to `.claude/specs/<feature-name>/LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /ptah-document completed
- Summary file written: README.md
- Next step: none — workflow complete ✅
```

See **LOGS.md format** in [`guides/logs-format.md`](../../ptah/guides/logs-format.md) for the full schema.

---

## Step 4 — Capture any final knowledge

Apply **Suggest capture before hand-off** from **Knowledge discipline** in `RULES.md` for anything this session surfaced.

`/ptah-document` also sweeps the written record, since it's the one command that sees the whole feature — review findings in particular never lived in a main-session context, so no earlier check could have caught them. Look specifically at:

- `CODE-REVIEW.md` findings — a 🔴/🟡 finding often *is* a `gotcha` or `security` entry, already written down but never promoted
- `LOGS.md` change entries — a **decision** or **deviation** logged mid-flow (a library swap, a naming convention, a workaround) is often exactly the kind of thing worth keeping past this one feature
- Anything in **Known issues** (`IMPLEMENTATION.md`) or **Deferred items** (this file's `README.md`) that's a project-wide fact rather than something specific to this feature

Merge candidates from the session and the sweep into one list, then ask one at a time, the same way the rule describes:

> "This feature surfaced `<brief description>`. Worth capturing with `/ptah-learn` before we close it out?"

---

## Step 5 — Hand off to user

Use the hand-off format in [`guides/result-format.md`](../../ptah/guides/result-format.md):

```
✅ /ptah-document <n> completed
Artifact: `.claude/specs/<feature-name>/README.md`
Deferred items: <count, or "none"> — the full workflow is complete 🎉
Next: none — workflow complete
```

---

## Workflow

This is the final command in the Ptah workflow:

```
/ptah-spec → /ptah-design → /ptah-implement → /ptah-code-review → /ptah-fix → /ptah-document
```

Each command appends a session entry to `LOGS.md`. The `README.md` produced here is the permanent record of the work.
