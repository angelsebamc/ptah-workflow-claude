---
name: ptah-design
description: 'Produces DESIGN.md for a Ptah spec by dispatching the ptah-designer subagent, relaying its clarifying questions one at a time and logging the answers to LOGS.md. Second step of the Ptah pipeline, after /ptah-spec. Use when the user runs /ptah-design with a spec number.'
argument-hint: '<spec-id>'
disable-model-invocation: true
---

# /ptah-design

Produce a thorough technical design for a spec before any code is written.

`/ptah-design` is a thin dispatcher: the design work — reading the spec, exploring the codebase, writing the design — happens in the `ptah-designer` subagent's own context, so none of that reading lands in the main session. This session only relays questions, writes `DESIGN.md`, and logs. See **Delegated work** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md).

## Step 1 — Resolve the spec

When the user runs `/ptah-design <spec-id>`, resolve `<spec-id>` to a spec folder per **Spec identifiers** in [`.claude/ptah/RULES.md`](../../ptah/RULES.md) — it may be a bare number, `ptah-<n>`, or a full folder name. The rest of this file uses `<feature-name>` to mean that resolved folder.

If `.claude/specs/<feature-name>/SPEC.md` is empty or missing, stop and tell the user:

> "⚠️ No spec found for `<spec-id>`. Run `/ptah-spec <feature-name>` first."

---

## Step 2 — Dispatch to the designer subagent

Invoke the `ptah-designer` subagent. Its prompt must contain **only**:

```
Design the Ptah spec at .claude/specs/<feature-name>/
```

Nothing else — no summary of this conversation, no answers to earlier questions (those are in `LOGS.md`), no hints about the codebase. The subagent reads everything itself.

---

## Step 3 — Handle the result

Read the subagent's result per [`guides/result-format.md`](../../ptah/guides/result-format.md). Check it against every rule there before acting on it — a result that breaks any rule is **malformed** and handled like `error`, never guessed at or patched up.

### `Status: needs-input`

The subagent needs the user's input before it can design. Per **Delegated work** in `RULES.md`:

1. Append a `paused` entry to `LOGS.md`, copying the result's fields verbatim:
   ```markdown
   ## <YYYY-MM-DD HH:MM:SS> — /ptah-design paused
   - Blocked on: <from result>
   - Progress: <from result>
   - Files touched: <from result>
   - Next step: answer the open questions, then re-run /ptah-design
   ```
2. Ask the `### Questions` **one at a time**, in the order returned. Present each in your own words if it reads better, but don't answer, soften, or drop any.
3. After each answer, append a change entry recording it:
   ```markdown
   ## <YYYY-MM-DD HH:MM:SS> — change during /ptah-design
   - Trigger: user-request
   - Type: <the question's tag: decision | scope-change>
   - What: <the answer, as a one-line decision>
   - Why: <the question it resolves>
   - Impact: input to DESIGN.md
   ```
4. When every question is answered, go back to Step 2 and re-dispatch with the same prompt.

If the user wants to stop before answering everything, skip to Step 5, then hand off as paused. The `paused` entry already written means `/ptah-design <n>` picks up from the answered questions later, in any session.

Keep any `### Learn candidates` from this round for Step 5.

### `Status: complete`

Write the `===DESIGN.md===` block verbatim to `.claude/specs/<feature-name>/DESIGN.md`, then continue to Step 4.

### `Status: error`, or a malformed result

Write no artifact. Append a `failed` entry:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /ptah-design failed
- Reason: <from result, or "malformed result — <what was wrong>">
- Next step: re-run /ptah-design
```

Skip to Step 5, then hand off as failed. If the result was malformed, offer to show the raw response.

---

## Step 4 — Append to LOGS.md

Append the completion entry, copying the result's fields verbatim and adding `Next step:`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /ptah-design completed
- Approach: <from result>
- Key decisions: <from result>
- Open questions: <from result>
- Next step: /ptah-implement
```

See [`guides/logs-format.md`](../../ptah/guides/logs-format.md) for the full schema.

---

## Step 5 — Suggest capture before hand-off

Apply **Suggest capture before hand-off** from **Knowledge discipline** in `RULES.md` to the `### Learn candidates` from every round of this run, with duplicates merged. This runs whether the command completed, paused, or failed — a finding from a round that got stuck is still a finding.

---

## Step 6 — Hand off to user

Use the hand-off format in [`guides/result-format.md`](../../ptah/guides/result-format.md):

```
✅ /ptah-design <n> completed
Artifact: `.claude/specs/<feature-name>/DESIGN.md`
<Approach, in one line>
Open questions: <count> — resolve them before implementing   (omit if none)
Next: /ptah-implement <n>
```

```
⏸️ /ptah-design <n> paused
Blocked on: <Blocked on>
<count> question(s) still unanswered
Next: /ptah-design <n> — answer the remaining questions
```

```
❌ /ptah-design <n> failed
Reason: <Reason>
Next: /ptah-design <n>
```

---

## Workflow

This command is part of the Ptah workflow:

```
/ptah-spec → /ptah-design → /ptah-implement → /ptah-code-review → /ptah-fix → /ptah-document
```

Each command appends a session entry to `LOGS.md`. When resuming after a break, read `LOGS.md` first to understand where the feature stands.

Always wait for the user to review and confirm before suggesting the next step.
