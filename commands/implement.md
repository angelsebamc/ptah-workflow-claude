# /implement

Read the feature design and implement the code. Document what was built in IMPLEMENTATION.md.

## Step 1 — Read the design

When the user runs `/implement <spec-id>`, first resolve `<spec-id>` to a spec folder per **Spec identifiers** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md) — it may be a bare number, `ptah-<n>`, or a full folder name. The rest of this file uses `<feature-name>` to mean that resolved folder.

Then read the following files:

- `.claude/specs/<feature-name>/DESIGN.md` — the technical design
- `.claude/specs/<feature-name>/SPEC.md` — the use case and acceptance criteria
- `.claude/specs/<feature-name>/refs/` — any referenced screenshots, mockups, or files
- `.claude/specs/<feature-name>/LOGS.md` — session history, to understand current state
- `CLAUDE.md` — project conventions, stack, architecture decisions

If `DESIGN.md` is empty or missing, stop and tell the user:

> "⚠️ No design found for `<spec-id>`. Run `/design <spec-id>` first."

---

## Step 2 — Consult prior knowledge

Read `.claude/ptah/knowledge/INDEX.md` if it exists. Scan titles, categories, and tags for anything relevant — a `gotcha` about a library you're about to call, or a `convention` this codebase already settled on, is worth knowing before writing code around it rather than after.

Cheap scan, not a search — move on if nothing looks relevant. If something does and you need the full writeup:

```
python3 .claude/ptah/ptah_knowledge.py get <id>
```

If `INDEX.md` doesn't exist yet, skip silently.

Per **Knowledge discipline** in `RULES.md`: don't cite this in `LOGS.md`. If a finding changes an implementation choice, log the decision itself — the knowledge entry is context, not part of the record.

---

## Step 3 — Clarify before implementing

Apply the **Stop and ask** rule from [`.claude/ptah/RULES.md`](../../ptah/RULES.md). Review the design; if anything is ambiguous, ask before writing code. If everything is clear, skip this step.

---

## Step 4 — Implement

Implement the feature following the design exactly. Respect all project conventions from `CLAUDE.md`.

- Follow the file structure defined in `DESIGN.md`
- Implement all logic, validations, and edge cases described
- Handle loading, empty, and error states for any UI
- Do not introduce dependencies not listed in the design — if you need one, ask first
- Do not deviate from the design without asking the user first

---

## Step 5 — Write IMPLEMENTATION.md

After implementation is complete, write a summary to `.claude/specs/<feature-name>/IMPLEMENTATION.md`:

```markdown
# IMPLEMENTATION — <feature-name>

## Summary
<Brief description of what was built>

## Files created
- `<path>` — <purpose>

## Files modified
- `<path>` — <what changed and why>

## Deviations from design
<Any changes made vs DESIGN.md, and the reason. "None" if everything matched.>

## Known issues
<Anything incomplete, hacky, or worth flagging for code review. "None" if clean.>
```

---

## Step 6 — Append to LOGS.md

After writing IMPLEMENTATION.md, append the following entry to `.claude/specs/<feature-name>/LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /implement completed
- Summary: <one-line summary of what was built>
- Files created: <count>
- Files modified: <count>
- Deviations from design: <yes — brief note, or "no">
- Known issues: <yes — brief note, or "no">
- Next step: /code-review
```

See **LOGS.md format** in [`guides/logs-format.md`](../../ptah/guides/logs-format.md) for the full schema.

---

## Step 7 — Hand off to user

After writing both files, tell the user:

> "✅ Implementation is complete. Review the changes and `IMPLEMENTATION.md` at `.claude/specs/<feature-name>/IMPLEMENTATION.md`.
>
> Pay attention to **Deviations from design** and **Known issues** if any.
>
> When you're happy with it, run `/code-review <n>` to start the review."

Use the number, not the full folder name, when telling the user what to run next — see **Spec identifiers** in `RULES.md`.

---

## Workflow

This command is part of the Ptah workflow:

```
/spec → /design → /implement → /code-review → /fix → /document
```

Each command appends a session entry to `LOGS.md`. When resuming after a break, read `LOGS.md` first to understand where the feature stands.

Always wait for the user to review and confirm before suggesting the next step.
