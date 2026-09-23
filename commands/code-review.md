# /code-review

Review the implemented code against the design and spec. Do not modify any code — this step is documentation only.

`/code-review` is a thin dispatcher: it resolves the spec, hands the actual review off to the `ptah-code-reviewer` subagent, and writes what comes back. The review judgment itself happens in that subagent's own fresh context, deliberately isolated from this conversation — so it isn't anchored by whatever reasoning happened while the code was being written. See **Why the review is isolated** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md).

## Step 1 — Resolve the spec

When the user runs `/code-review <spec-id>`, resolve `<spec-id>` to a spec folder per **Spec identifiers** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md). The rest of this file uses `<feature-name>` to mean that resolved folder.

If `.claude/specs/<feature-name>/IMPLEMENTATION.md` is empty or missing, stop and tell the user:

> "⚠️ No implementation found for `<spec-id>`. Run `/implement <spec-id>` first."

---

## Step 2 — Delegate to the reviewer subagent

Invoke the `ptah-code-reviewer` subagent. Its prompt must contain **only**:

```
Review the Ptah spec at .claude/specs/<feature-name>/
```

Nothing else. Do not add context from this conversation, summarize what happened during `/implement`, or explain any deviations or decisions on the implementer's behalf — the subagent reads `SPEC.md`, `DESIGN.md`, `IMPLEMENTATION.md`, and `LOGS.md` itself. Passing it anything beyond the folder path defeats the point of isolating it.

---

## Step 3 — Write CODE-REVIEW.md

The subagent returns a `===CODE-REVIEW.md===` block and a `===SUMMARY===` block (see `.claude/agents/ptah/ptah-code-reviewer.md` for the exact contract).

Write the `===CODE-REVIEW.md===` content verbatim to `.claude/specs/<feature-name>/CODE-REVIEW.md`.

If the response doesn't match this shape — a block missing, malformed counts — don't guess or patch it up. Stop and tell the user:

> "⚠️ The reviewer subagent returned something unexpected. Nothing was written. You can re-run `/code-review <spec-id>`, or I can show you the raw response."

---

## Step 4 — Append to LOGS.md

Using the counts from the `===SUMMARY===` block, append the following entry to `.claude/specs/<feature-name>/LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /code-review completed
- 🔴 Blockers: <blockers>
- 🟡 Major: <major>
- 🟢 Minor: <minor>
- 💡 Suggestions: <suggestions>
- Acceptance criteria: <criteria_met> of <criteria_total> met
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
