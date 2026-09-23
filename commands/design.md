# /design

Read the feature spec and produce a thorough technical design before any code is written.

## Step 1 — Read the spec

When the user runs `/design <spec-id>`, first resolve `<spec-id>` to a spec folder per **Spec identifiers** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md) — it may be a bare number, `ptah-<n>`, or a full folder name. The rest of this file uses `<feature-name>` to mean that resolved folder.

Then read the following files:

- `.claude/specs/<feature-name>/SPEC.md` — the use case and acceptance criteria
- `.claude/specs/<feature-name>/refs/` — any referenced screenshots, mockups, or files
- `CLAUDE.md` — project conventions, stack, architecture decisions

If `SPEC.md` is empty or missing, stop and tell the user:

> "⚠️ No design found for `<spec-id>`. Run `/spec <feature-name>` first."

---

## Step 2 — Consult prior knowledge

Read `.claude/ptah/knowledge/INDEX.md` if it exists. Scan titles, categories, and tags for anything relevant to this feature — an `architecture` or `dependency` entry touching the same area is worth knowing before designing, not after implementing around it.

This is a cheap scan, not a search — if nothing looks relevant, move on. If something does and you need the full detail:

```
python3 .claude/ptah/ptah_knowledge.py get <id>
```

If `INDEX.md` doesn't exist yet, skip silently — expected on a fresh project, not an error.

Per **Knowledge discipline** in `RULES.md`: don't cite this in `LOGS.md`. If a finding changes a design decision, log the decision itself as usual — the knowledge entry is context that informed it, not part of the record.

---

## Step 3 — Clarify before designing

Apply the **Stop and ask** rule from [`.claude/ptah/RULES.md`](../../ptah/RULES.md). Review the spec, refs, and anything surfaced in Step 2; if anything is ambiguous, ask before designing. If everything is clear, skip this step.

---

## Step 4 — Write DESIGN.md

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

## Step 5 — Append to LOGS.md

After writing DESIGN.md, append the following entry to `.claude/specs/<feature-name>/LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /design completed
- Approach: <one-line summary of the technical approach>
- Key decisions: <any notable design choices or tradeoffs>
- Open questions: <number of open questions, or "none">
- Next step: /implement
```

See **LOGS.md format** in [`guides/logs-format.md`](../../ptah/guides/logs-format.md) for the full schema.

---

## Step 6 — Hand off to user

After writing both files, tell the user:

> "✅ `DESIGN.md` is ready. Review it at `.claude/specs/<feature-name>/DESIGN.md`.
>
> Pay special attention to **Open questions** — resolve any before moving forward.
>
> When you're happy with it, run `/implement <n>` to start implementation."

Use the number, not the full folder name, when telling the user what to run next — see **Spec identifiers** in `RULES.md`.

---

## Workflow

This command is part of the Ptah workflow:

```
/spec → /design → /implement → /code-review → /fix → /document
```

Each command appends a session entry to `LOGS.md`. When resuming after a break, read `LOGS.md` first to understand where the feature stands.

Always wait for the user to review and confirm before suggesting the next step.
