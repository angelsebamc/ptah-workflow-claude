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

## Step 3 — Handle the result

Read the subagent's result per [`guides/result-format.md`](../../ptah/guides/result-format.md). Check it against every rule there before acting on it — a result that breaks any rule is **malformed** and handled like `error`, never guessed at or patched up.

- **`Status: complete`** — write the `===CODE-REVIEW.md===` block verbatim to `.claude/specs/<feature-name>/CODE-REVIEW.md`, then continue to Step 4.
- **`Status: error`, or a malformed result** — write no artifact. Append a `failed` entry, then skip to Step 5 and hand off as failed. If the result was malformed, offer to show the raw response.
  ```markdown
  ## <YYYY-MM-DD HH:MM:SS> — /code-review failed
  - Reason: <from result, or "malformed result — <what was wrong>">
  - Next step: re-run /code-review
  ```

---

## Step 4 — Append to LOGS.md

Append the completion entry, copying the result's fields verbatim and adding `Next step:` from the verdict:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /code-review completed
- 🔴 Blockers: <from result>
- 🟡 Major: <from result>
- 🟢 Minor: <from result>
- 💡 Suggestions: <from result>
- Acceptance criteria: <from result>
- Verdict: <from result>
- Next step: <see routing rule below>
```

**`Next step:` routing rule** — from the verdict, per [`guides/vocabulary.md`](../../ptah/guides/vocabulary.md):

| Verdict | `Next step:` |
|---|---|
| `fix-needed` | `/fix` |
| `ready-to-document` | `/document` |

See [`guides/logs-format.md`](../../ptah/guides/logs-format.md) for the full schema.

---

## Step 5 — Hand off to user

Use the hand-off format in [`guides/result-format.md`](../../ptah/guides/result-format.md):

```
✅ /code-review <n> completed
Artifact: `.claude/specs/<feature-name>/CODE-REVIEW.md`
🔴 <blockers> | 🟡 <major> | 🟢 <minor> | 💡 <suggestions> — acceptance criteria <x> of <y> met
Next: /fix <n>          (or "/document <n> — no blockers or major issues, /fix can be skipped")
```

```
❌ /code-review <n> failed
Reason: <Reason>
Next: /code-review <n>
```

---

## Workflow

This command is part of the Ptah workflow:

```
/spec → /design → /implement → /code-review → /fix → /document
```

Each command appends a session entry to `LOGS.md`. When resuming after a break, read `LOGS.md` first to understand where the feature stands.

Always wait for the user to review and confirm before suggesting the next step.
