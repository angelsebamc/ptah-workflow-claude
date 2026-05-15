# /document

Summarize a completed feature into a clean, human-readable record. This is the terminal step of the Ptah workflow.

## Step 1 — Read the context

When the user runs `/document <feature-name>`, read these files from the spec folder:

- `.claude/specs/<feature-name>/SPEC.md`
- `.claude/specs/<feature-name>/DESIGN.md`
- `.claude/specs/<feature-name>/IMPLEMENTATION.md`
- `.claude/specs/<feature-name>/CODE-REVIEW.md`
- `.claude/specs/<feature-name>/LOGS.md`

Also read `.claude/ptah/ptah.yml` to determine whether testing is enabled (`commands.test.enabled`, defaults to `false`). If testing is enabled, also read:

- `.claude/specs/<feature-name>/TEST.md`

If the spec folder doesn't exist, stop and tell the user:

> "⚠️ No spec found for `<feature-name>`. Run `/spec <feature-name>` first."

**Completeness guard.** Check for unresolved work before documenting:

- Always check `CODE-REVIEW.md` for unresolved 🔴 blockers
- If testing is enabled, also check `TEST.md` for failing tests

If either check finds unresolved work, stop and tell the user:

> "⚠️ This feature doesn't appear to be fully complete yet. There are unresolved issues in `CODE-REVIEW.md`<, or failing tests in `TEST.md`> (include the second clause only if testing is enabled). Are you sure you want to document it now?"

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
## <YYYY-MM-DD HH:MM:SS> — /document completed
- Summary file written: README.md
- Next step: none — workflow complete ✅
```

See **LOGS.md format** in the project `README.md` for the full schema.

---

## Step 4 — Hand off to user

> "✅ Feature documented.
>
> - Summary: `.claude/specs/<feature-name>/README.md`
>
> The full workflow for `<feature-name>` is complete. 🎉"

---

## Workflow

This is the final command in the Ptah workflow:

```
/spec → /design → /implement → /code-review → /fix → [/test] → /document
```

`/test` is opt-in per project — controlled by `commands.test.enabled` in `.claude/ptah/ptah.yml`.

Each command appends a session entry to `LOGS.md`. The `README.md` produced here is the permanent record of the work.
