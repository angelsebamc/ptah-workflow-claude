# /design

Read the feature spec and produce a thorough technical design before any code is written.

## Step 1 — Read the spec

When the user runs `/design <feature-name>`, read the following files:

- `.claude/specs/<feature-name>/SPEC.md` — the use case and acceptance criteria
- `.claude/specs/<feature-name>/refs/` — any referenced screenshots, mockups, or files
- `CLAUDE.md` — project conventions, stack, architecture decisions

If `SPEC.md` is empty or missing, stop and tell the user:

> "⚠️ No spec found for `<feature-name>`. Run `/spec <feature-name>` first."

---

## Step 2 — Clarify before designing

Apply the **Stop and ask** rule from [`.claude/ptah/RULES.md`](../../ptah/RULES.md). Review the spec and refs; if anything is ambiguous, ask before designing. If everything is clear, skip this step.

---

## Step 3 — Write DESIGN.md

Produce a thorough technical design and write it to `.claude/specs/<feature-name>/DESIGN.md`.

The design must cover every aspect an agent needs to implement the feature without ambiguity. Use the following structure:

```markdown
# DESIGN — <feature-name>

## Overview
<Brief summary of the technical approach>

## Architecture
<How this feature fits into the existing codebase — which layers are touched, 
which existing modules are reused or extended>

## Data model
<Any new or modified data structures, database tables, types, schemas>

## API / interfaces
<New endpoints, edge functions, hooks, or service methods needed.
Include input/output shapes>

## UI / screens
<Screens or components affected. Describe layout, interactions, states 
(loading, empty, error, success)>

## File structure
<New files to create and existing files to modify, with their purpose>

## Logic & business rules
<Key logic, validations, edge cases, and error handling to implement>

## Dependencies
<Any new packages, APIs, or services required>

## Open questions
<Anything unclear that the user should decide before implementation starts>
```

Only include sections that are relevant — skip sections that don't apply to this feature.

---

## Step 4 — Append to LOGS.md

After writing DESIGN.md, append the following entry to `.claude/specs/<feature-name>/LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /design completed
- Approach: <one-line summary of the technical approach>
- Key decisions: <any notable design choices or tradeoffs>
- Open questions: <number of open questions, or "none">
- Next step: /implement
```

See **LOGS.md format** in the project `README.md` for the full schema.

---

## Step 5 — Hand off to user

After writing both files, tell the user:

> "✅ `DESIGN.md` is ready. Review it at `.claude/specs/<feature-name>/DESIGN.md`.
>
> Pay special attention to **Open questions** — resolve any before moving forward.
>
> When you're happy with it, run `/implement <feature-name>` to start implementation."

---

## Workflow

This command is part of the Ptah workflow:

```
/spec → /design → /implement → /code-review → /fix → /test
```

Each command appends a session entry to `LOGS.md`. When resuming after a break, read `LOGS.md` first to understand where the feature stands.

Always wait for the user to review and confirm before suggesting the next step.
