# Result and hand-off format

Every Ptah command ends with a final report, and every report has one of two readers:

- **A dispatching command** reads a subagent's **result** and turns it into files and a `LOGS.md` entry.
- **The user** reads a command's **hand-off**.

Both are markdown, and both use the same fields as `LOGS.md` — so a result maps onto its log entry field for field, and all three read the same way. Every fixed value comes from [`vocabulary.md`](./vocabulary.md).

---

## Subagent result

Returned as the subagent's final message by `ptah-designer`, `ptah-implementer`, `ptah-code-reviewer`, and `ptah-reviewer`.

````
===RESULT===
- Status: <complete | needs-input | error>
- <Field>: <value>
- ...

### Questions
- [<change-type>] <question> — <why it matters>

### Learn candidates
- <category> | <one-line title> | <one-line note>
===<ARTIFACT>.md===
<raw markdown, verbatim>
===END===
````

### Rules

1. **Nothing outside the blocks.** No preamble before `===RESULT===`, nothing after `===END===`.
2. **`Status:` is always the first bullet.**
3. **The fields after it are the `LOGS.md` fields for the entry that status produces** — `completed`, `paused`, or `failed` (see the mapping in `vocabulary.md` and the per-command fields below). Same names, same order. The dispatcher adds the fields it owns (always `Next step:`, plus a few per command) and copies the rest verbatim.
4. **One line per value.** No value spans lines. Lists inside a value are comma-separated.
5. **Every fixed value comes from `vocabulary.md`**, exactly as written there.
6. **`###` sections appear only when they apply** — never written empty. `### Questions` appears only with `needs-input`. `### Learn candidates` is optional, and only the designer and implementer return it.
7. **Artifact blocks are named after the file they become** (`===DESIGN.md===`) and appear only with `complete`. Their content is raw markdown, written verbatim.
8. **`===END===` closes every result.**

### Malformed results

A result is malformed if any rule above is broken: text outside the blocks, `Status:` missing or not first, a required field missing, a value outside its vocabulary, a missing artifact block on `complete`, or no `===END===`.

The dispatcher never guesses or patches a malformed result. It treats it exactly like `Status: error` — logs a `failed` entry with `Reason: malformed result — <what was wrong>`, writes no artifact, and hands off with ❌.

### Per-command fields

| Subagent | `complete` fields | `needs-input` fields | Artifact block | Dispatcher adds |
|---|---|---|---|---|
| `ptah-designer` | Approach, Key decisions, Open questions | Blocked on, Progress, Files touched | `===DESIGN.md===` | Next step |
| `ptah-implementer` | Summary, Files created, Files modified, Deviations from design, Known issues | Blocked on, Progress, Files touched | `===IMPLEMENTATION.md===` | Next step |
| `ptah-code-reviewer` | 🔴 Blockers, 🟡 Major, 🟢 Minor, 💡 Suggestions, Acceptance criteria, Verdict | — | `===CODE-REVIEW.md===` | Next step |
| `ptah-reviewer` | 🔴 Blockers, 🟡 Major, 🟢 Minor, 💡 Suggestions, Verdict | — | `===REVIEW.md===` | Target, Base, Source, Next step |

`error` always carries exactly one field: `Reason: <one line>`.

Field formats are defined in [`logs-format.md`](./logs-format.md) under each command.

### Example

````
===RESULT===
- Status: needs-input
- Blocked on: whether archived accounts count toward net worth
- Progress: form component and migration written
- Files touched: src/accounts/AccountForm.tsx, db/migrations/0042_archived.sql

### Questions
- [decision] Should archived accounts still count toward net worth? — the design hides them from the list but doesn't say whether the total excludes them.

### Learn candidates
- gotcha | Migrations must be registered in db/index.ts | a new migration file is silently skipped until it's added there
===END===
````

---

## Hand-off

Every command's final message to the user, including meta-commands that produce a result (`/review`) and excluding purely read-only ones (`/status`, `/resume`, `/continue`, `/recall`, `/learn` — they have their own formats).

```
<icon> /<command> <n> <status>
Artifact: `<path to the artifact the user should review>`
<one to three lines of key facts>
Next: <`/<next-command> <n>`, or what the user needs to do>
```

- **Icon and status** come from the command status in `vocabulary.md` — ✅ `completed`, ⏸️ `paused`, ❌ `failed`.
- **`<n>`** is the spec number only, never the slug — see **Spec identifiers** in `RULES.md`. `/review` uses the review name instead.
- **`Artifact:`** is the full path, since the user opens it. Omit the line when no artifact was written (`paused`, `failed`).
- **Key facts** are what the user should look at before moving on: counts, open questions, deviations, the blocker or failure reason. One to three lines, no more.
- **`Next:`** matches the `Next step:` just written to `LOGS.md`, with the spec number added so it's directly runnable.

The hand-off comes after everything else — files written, `LOGS.md` appended, and any **Suggest capture before hand-off** questions asked (see `RULES.md`).

### Example

```
✅ /code-review 3 completed
Artifact: `.claude/specs/ptah-3-user-login/CODE-REVIEW.md`
🔴 1 | 🟡 2 | 🟢 3 | 💡 1 — acceptance criteria 4 of 5 met
Next: /fix 3
```
