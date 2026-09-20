# /code-review

Review the implemented code against the design and spec. Document all findings in CODE-REVIEW.md. Do not modify any code — this step is documentation only.

## Step 1 — Read the context

When the user runs `/code-review <spec-id>`, first resolve `<spec-id>` to a spec folder per **Spec identifiers** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md) — it may be a bare number, `ptah-<n>`, or a full folder name. The rest of this file uses `<feature-name>` to mean that resolved folder.

Then read the following files:

- `.claude/specs/<feature-name>/SPEC.md` — acceptance criteria to verify against
- `.claude/specs/<feature-name>/DESIGN.md` — intended technical design
- `.claude/specs/<feature-name>/IMPLEMENTATION.md` — what was built and any known issues
- `.claude/specs/<feature-name>/LOGS.md` — session history, to understand current state
- `CLAUDE.md` — project conventions, architecture decisions

Then read all files created or modified during `/implement` (listed in IMPLEMENTATION.md).

> Review no more than 400 lines at a time. If the implementation is larger, split the review into logical chunks and note which chunk each finding belongs to.

---

## Step 2 — Review the code

Focus on what matters. Review in this order of priority:

| Priority | Icon | Meaning | Action |
|----------|------|---------|--------|
| Blocker | 🔴 | Bug, crash, security risk, data loss | Must fix before moving forward |
| Major | 🟡 | Logic issue, missing edge case, test gap | Should fix before moving forward |
| Minor | 🟢 | Naming, readability, small improvements | Nice to fix |
| Suggestion | 💡 | Alternative approach, future consideration | Optional |

**What to focus on:**
- Logic: Does it work correctly? Are edge cases handled? What happens when inputs are null/empty/unexpected?
- Security: Is user input validated? Are auth checks in place? Any secrets or PII exposed?
- Correctness: Does the implementation match the design? Are all acceptance criteria met?
- Maintainability: Clear naming? Single responsibility? Unnecessary duplication?
- Performance: N+1 queries? Unnecessary re-renders? Memory leaks?

**What to skip:**
- Formatting and style (that's what linters are for)
- Naming preferences that don't affect readability
- Architecture debates outside the scope of this feature

**How to frame feedback:**
- Prefer questions over commands: "Have you considered...?" over "Change this to..."
- Always explain *why* something matters, not just *what* to change
- Acknowledge what's working well, not just what's wrong

---

## Step 3 — Write CODE-REVIEW.md

Write all findings to `.claude/specs/<feature-name>/CODE-REVIEW.md`:

```markdown
# CODE-REVIEW — <feature-name>

## Summary
<Overall assessment in 2-3 sentences. Is the code solid? What's the main concern?>

## Findings

🔴 **BLOCKER: <short title>**
`<file>:<line>` — <what the issue is and why it matters>
Have you considered: <question or suggested fix>

🟡 **MAJOR: <short title>**
`<file>:<line>` — <what the issue is>
Suggestion: <alternative approach>

🟢 **minor: <short title>**
`<file>:<line>` — <brief note>

💡 **suggestion: <short title>**
<Optional idea for consideration, not blocking>

## Acceptance criteria check
- [x] <criterion from SPEC.md> — met
- [ ] <criterion from SPEC.md> — not met: <reason>

## What's working well
<Acknowledge good decisions, clean code, or solid patterns found during review>

## Verdict
< "Ready for /fix — X blockers, Y major issues" >
< or "No issues found — skip /fix and run /document directly" >
```

---

## Step 4 — Append to LOGS.md

After writing CODE-REVIEW.md, append the following entry to `.claude/specs/<feature-name>/LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /code-review completed
- 🔴 Blockers: <count>
- 🟡 Major: <count>
- 🟢 Minor: <count>
- 💡 Suggestions: <count>
- Acceptance criteria: <X of Y met>
- Next step: <see routing rule below>
```

**`Next step:` routing rule.**

| Blockers/Major found? | `Next step:` value |
|---|---|
| yes | `/fix` |
| no | `/document` |

See **LOGS.md format** in [`guides/logs-format.md`](../../ptah/guides/logs-format.md) for the full schema.

---

## Step 5 — Hand off to user

After writing both files, tell the user:

> "✅ Code review complete. See `.claude/specs/<feature-name>/CODE-REVIEW.md`.
>
> 🔴 Blockers: X | 🟡 Major: Y | 🟢 Minor: Z | 💡 Suggestions: W
>
> When you're ready, run `/fix <n>` to address the issues."

If there are zero blockers and zero major issues:

> "✅ Code review complete — no blockers or major issues found. You can skip `/fix` and run `/document <n>` directly."

Use the number, not the full folder name, when telling the user what to run next — see **Spec identifiers** in `RULES.md`.

---

## Workflow

This command is part of the Ptah workflow:

```
/spec → /design → /implement → /code-review → /fix → /document
```

Each command appends a session entry to `LOGS.md`. When resuming after a break, read `LOGS.md` first to understand where the feature stands.

Always wait for the user to review and confirm before suggesting the next step.
