# /implement

Implement a spec's design, and document what was built in `IMPLEMENTATION.md`.

`/implement` is a thin dispatcher: the implementation — reading the design, writing the code — happens in the `ptah-implementer` subagent's own context, so none of that code lands in the main session. This session only relays questions, writes `IMPLEMENTATION.md`, and logs. See **Delegated work** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md).

## Step 1 — Resolve the spec

When the user runs `/implement <spec-id>`, resolve `<spec-id>` to a spec folder per **Spec identifiers** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md) — it may be a bare number, `ptah-<n>`, or a full folder name. The rest of this file uses `<feature-name>` to mean that resolved folder.

If `.claude/specs/<feature-name>/DESIGN.md` is empty or missing, stop and tell the user:

> "⚠️ No design found for `<spec-id>`. Run `/design <spec-id>` first."

---

## Step 2 — Dispatch to the implementer subagent

Invoke the `ptah-implementer` subagent. Its prompt must contain **only**:

```
Implement the Ptah spec at .claude/specs/<feature-name>/
```

Nothing else — no summary of this conversation, no answers to earlier questions (those are in `LOGS.md`), no progress notes (the subagent finds them in `LOGS.md` and on disk). The subagent reads everything itself.

---

## Step 3 — Handle the result

Read the subagent's result per [`guides/result-format.md`](../../ptah/guides/result-format.md). Check it against every rule there before acting on it — a result that breaks any rule is **malformed** and handled like `error`, never guessed at or patched up.

### `Status: needs-input`

The subagent stopped partway and needs the user's input. Work it already finished is on disk. Per **Delegated work** in `RULES.md`:

1. Append a `paused` entry to `LOGS.md`, copying the result's fields verbatim:
   ```markdown
   ## <YYYY-MM-DD HH:MM:SS> — /implement paused
   - Blocked on: <from result>
   - Progress: <from result>
   - Files touched: <from result>
   - Next step: answer the open questions, then re-run /implement
   ```
   This entry is what lets the next dispatch pick up where this one stopped — including in a later session.
2. Ask the `### Questions` **one at a time**, in the order returned. Present each in your own words if it reads better, but don't answer, soften, or drop any.
3. After each answer, append a change entry recording it:
   ```markdown
   ## <YYYY-MM-DD HH:MM:SS> — change during /implement
   - Trigger: user-request
   - Type: <the question's tag: decision | deviation | scope-change>
   - What: <the answer, as a one-line decision>
   - Why: <the question it resolves>
   - Impact: <what it changes — files, design sections, or "none">
   ```
   If an answer changes the design itself, update `DESIGN.md` to match before re-dispatching, and say so in `Impact:`.
4. When every question is answered, go back to Step 2 and re-dispatch with the same prompt.

If the user wants to stop before answering everything, skip to Step 5, then hand off as paused. The `paused` entry already written means `/implement <n>` picks up later, in any session.

Keep any `### Learn candidates` from this round for Step 5.

### `Status: complete`

Write the `===IMPLEMENTATION.md===` block verbatim to `.claude/specs/<feature-name>/IMPLEMENTATION.md`, then continue to Step 4.

### `Status: error`, or a malformed result

Write no artifact. Append a `failed` entry:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /implement failed
- Reason: <from result, or "malformed result — <what was wrong>">
- Next step: check git status, then re-run /implement
```

Skip to Step 5, then hand off as failed. Code may have changed on disk even though nothing was logged as built — the hand-off says so. If the result was malformed, offer to show the raw response.

---

## Step 4 — Append to LOGS.md

Append the completion entry, copying the result's fields verbatim and adding `Next step:`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /implement completed
- Summary: <from result>
- Files created: <from result>
- Files modified: <from result>
- Deviations from design: <from result>
- Known issues: <from result>
- Next step: /code-review
```

See [`guides/logs-format.md`](../../ptah/guides/logs-format.md) for the full schema.

---

## Step 5 — Suggest capture before hand-off

Apply **Suggest capture before hand-off** from **Knowledge discipline** in `RULES.md` to the `### Learn candidates` from every round of this run, with duplicates merged. This runs whether the command completed, paused, or failed — a finding from a round that got stuck is still a finding.

---

## Step 6 — Hand off to user

Use the hand-off format in [`guides/result-format.md`](../../ptah/guides/result-format.md):

```
✅ /implement <n> completed
Artifact: `.claude/specs/<feature-name>/IMPLEMENTATION.md`
<Summary> — <created> created, <modified> modified
Deviations: <yes — see LOGS.md | none> · Known issues: <Known issues>
Next: /code-review <n>
```

```
⏸️ /implement <n> paused
Blocked on: <Blocked on>
Done so far: <Progress>
Next: /implement <n> — answer the remaining questions
```

```
❌ /implement <n> failed
Reason: <Reason>
Code may have changed on disk — check `git status` before re-running.
Next: /implement <n>
```

---

## Workflow

This command is part of the Ptah workflow:

```
/spec → /design → /implement → /code-review → /fix → /document
```

Each command appends a session entry to `LOGS.md`. When resuming after a break, read `LOGS.md` first to understand where the feature stands.

Always wait for the user to review and confirm before suggesting the next step.
