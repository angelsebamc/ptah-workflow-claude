# Ptah vocabulary

Every fixed value Ptah uses — in `LOGS.md`, in subagent results, in hand-offs, in `/ptah-status` — is defined here and only here. Other files reference this guide instead of repeating the lists.

Values are **kebab-case**, lowercase, and exact. A value that isn't on its list is an error, never something to coerce to the nearest match — same "hard failures over silent fallbacks" principle as the rest of Ptah.

---

## Command status

The `<status>` in a `LOGS.md` command entry heading: `## <timestamp> — /<command> <status>`.

| Value | Meaning | Written when |
|---|---|---|
| `completed` | The command produced its artifact | The command finishes normally |
| `paused` | The command stopped to wait for the user | A subagent returned `needs-input` (`/ptah-design`, `/ptah-implement`) |
| `failed` | The command stopped without producing its artifact | A subagent returned `error`, or a malformed result |

Field schemas for each status: [`logs-format.md`](./logs-format.md).

## Result status

The first field of every subagent result — see [`result-format.md`](./result-format.md). Each maps to exactly one command status, which is what the dispatcher logs.

| Value | Meaning | Logged as |
|---|---|---|
| `complete` | The work is done; artifact block(s) follow | `completed` |
| `needs-input` | The subagent stopped with questions for the user | `paused` |
| `error` | The subagent couldn't do the work at all (e.g. missing input) | `failed` |

Only `ptah-designer` and `ptah-implementer` return `needs-input`. The reviewers return `complete` or `error`.

## Spec state

What `/ptah-status` shows for a spec, derived from its **last command entry** — change entries are ignored for this.

| Value | Icon | Last command entry |
|---|---|---|
| `just-started` | 🆕 | none yet |
| `active` | 🔄 | any `completed`, other than `/ptah-document completed` |
| `paused` | ⏸️ | any `paused` |
| `failed` | ❌ | any `failed` |
| `completed` | ✅ | `/ptah-document completed` |

## Change type

The `Type:` field of a `LOGS.md` change entry.

| Value | Use for |
|---|---|
| `decision` | A choice that affects the work — library, pattern, structure, naming, or a user's answer to a question |
| `deviation` | The implementation diverged from the spec or design |
| `scope-change` | Something was added to, removed from, or moved out of scope mid-flow |
| `blocker` | Hit something that needs resolving, outside a subagent question loop (those are `paused` command entries) |
| `correction` | The user pointed out something was wrong, and it's being redone |

A subagent tags each question it returns with the change type its answer will be logged as — only `decision`, `deviation`, or `scope-change`.

## Change trigger

The `Trigger:` field of a `LOGS.md` change entry.

| Value | Meaning |
|---|---|
| `user-request` | The user asked for it or answered a question |
| `agent-decision` | The agent decided on its own |

## Finding severity

Used by `/ptah-code-review`, `/ptah-review`, and `/ptah-fix`.

| Value | Icon | Code | Meaning | `/ptah-fix` default |
|---|---|---|---|---|
| `blocker` | 🔴 | `B<n>` | Bug, crash, security risk, data loss | always in scope |
| `major` | 🟡 | `M<n>` | Logic issue, missing edge case, test gap | always in scope |
| `minor` | 🟢 | `N<n>` | Naming, readability, small improvements | in scope only with `include_minor` |
| `suggestion` | 💡 | `S<n>` | Alternative approach, future consideration | only when named by code |

### Finding codes

Every finding carries a code: the severity's letter plus a number, e.g. `B1`, `M2`, `S1`. Numbering restarts at 1 for each severity, in the order findings appear in the review (per pass, for `/ptah-review`). Codes are how `/ptah-fix` and the user refer to findings — to steer a fix, skip one, or pull in an out-of-scope minor or suggestion.

## Verdict

| Command | Value | Meaning | Next step |
|---|---|---|---|
| `/ptah-code-review` | `fix-needed` | At least one blocker or major finding | `/ptah-fix` |
| `/ptah-code-review` | `ready-to-document` | No blockers or major findings | `/ptah-document` |
| `/ptah-review` | `request-changes` | At least one blocker or major finding | share with the author, or `/ptah-fix --review` |
| `/ptah-review` | `approve-with-minors` | Only minor findings or suggestions | merge at the author's discretion |
| `/ptah-review` | `approve` | Clean | merge |

## Fix mode

| Value | Behavior |
|---|---|
| `auto` | Apply all in-scope fixes silently, report at the end |
| `plan` | Show a one-line-per-finding plan, wait for one confirmation, apply in one pass — **default** |
| `interactive` | Ask per finding before applying |

## Hand-off icon

The first character of every command's final message to the user — see [`result-format.md`](./result-format.md).

| Icon | Command status |
|---|---|
| ✅ | `completed` |
| ⏸️ | `paused` |
| ❌ | `failed` |

## Knowledge base

Categories, confidence levels, and relations are defined in [`knowledge-format.md`](./knowledge-format.md) — they're enforced in `ptah_knowledge.py` and the database's `CHECK` constraints, so that guide stays their source of truth.

Knowledge **tags** are deliberately free-form — the one set of labels in Ptah that isn't fixed.
