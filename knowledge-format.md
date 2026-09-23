# knowledge.db format

`knowledge.db` is Ptah's persistent knowledge base — a SQLite file at `.claude/ptah/knowledge/knowledge.db`, committed to git alongside the rest of the project. `ptah_knowledge.py` is the **only** thing that reads or writes it; no command touches it with raw SQL. `INDEX.md`, in the same folder, is a disposable, auto-regenerated mirror — never hand-edited, always safe to overwrite.

This guide defines the schema and CLI contract. The discipline — when `/learn` fires, what workflow commands do with `INDEX.md`, how this stays disjoint from `LOGS.md` — lives in `RULES.md` under "Knowledge discipline."

---

## Storage

```
.claude/ptah/knowledge/
  knowledge.db     ← SQLite — the real store, committed to git
  INDEX.md         ← regenerated on every write, human-readable mirror
```

Requires Python 3, stdlib only (`sqlite3`, `json`, `argparse`) — no new binaries beyond what running Ptah already assumes.

---

## Schema

### `entries` — one row per captured fact

| Column | Type | Notes |
|---|---|---|
| `id` | `INTEGER PRIMARY KEY AUTOINCREMENT` | SQLite guarantees this is never reused, even after a delete. Displayed and referenced as the plain integer. |
| `title` | `TEXT` | One line, the gist |
| `category` | `TEXT` | One of the seven fixed categories below — enforced by `CHECK` |
| `confidence` | `TEXT` | `verified` or `suspected` — enforced by `CHECK` |
| `body` | `TEXT` | The full writeup |
| `source_command` | `TEXT` | Which command was running when this was captured, e.g. `/implement ptah-7-user-login`. `NULL` if captured manually outside any command. |
| `added_at` | `TEXT` | ISO 8601 UTC timestamp |

### Categories (fixed — seven only)

| Category | Icon | Use for |
|---|---|---|
| `gotcha` | 🐛 | Non-obvious behavior that cost time to discover |
| `convention` | 📐 | A project-specific pattern or rule, not enforced by a linter |
| `architecture` | 🏗️ | How a system or module is structured, and why |
| `dependency` | 📦 | Quirks or constraints of a library, package, or external service |
| `performance` | ⚡ | Something that measurably affects speed or resource use |
| `security` | 🔒 | Anything with auth, validation, or exposure implications |
| `tooling` | 🔧 | CLI, build, or dev-environment quirks |

### Confidence

- `verified` — confirmed true: reproduced, tested, or documented upstream
- `suspected` — observed once, plausible, not yet confirmed

Not a formality — `/recall` and the workflow commands' consult-index step both surface confidence alongside every result, so a `suspected` gotcha never gets read with the same weight as a `verified` one.

### `tags` — free-form, many-to-many

| Column | Type | Notes |
|---|---|---|
| `entry_id` | `INTEGER` | References `entries.id` |
| `tag` | `TEXT` | Normalized lowercase kebab-case (`rate-limit`, not `Rate Limit`) |

Unlike `category`, tags aren't a fixed list — invent whatever's useful. `ptah_knowledge.py` normalizes casing/spacing on write so `Rate Limit` and `rate-limit` don't end up as two different tags.

### `edges` — the graph

| Column | Type | Notes |
|---|---|---|
| `from_id` | `INTEGER` | Source entry |
| `to_id` | `INTEGER` | Target entry |
| `relation` | `TEXT` | One of the four fixed relations below — enforced by `CHECK` |

Relations are fixed for the same reason categories are — a free-text relation field drifts into a dozen synonyms for the same idea within a year:

| Relation | Meaning |
|---|---|
| `related` | Default. The two entries are relevant to each other; no stronger claim. |
| `supersedes` | This entry replaces or corrects another entry. The other entry is **not** deleted — it stays as history, and the edge itself records which one is current. |
| `depends-on` | This entry only makes sense in light of another. |
| `conflicts-with` | Two entries appear to contradict each other — worth a human look. |

Edges are directional, but `get`/`related` surface both `relates_to` (outgoing) and `related_from` (incoming), so you don't have to remember which direction you wrote a link in.

### `entries_fts` — search index (FTS5)

Mirrors `title` + `body` for free-text search. Kept in sync by SQL triggers on `entries` — nothing in `ptah_knowledge.py` has to remember to update it separately.

---

## `ptah_knowledge.py` CLI contract

Every subcommand prints JSON to stdout — this is what `/learn` and `/recall` parse, so the shape is load-bearing, not cosmetic. `<id>` is the plain integer, e.g. `42`.

```
python3 .claude/ptah/ptah_knowledge.py init
    → creates knowledge.db (and .claude/ptah/knowledge/) if missing. Idempotent.

python3 .claude/ptah/ptah_knowledge.py add \
    --title "..." --category gotcha --confidence verified \
    --body "..." [--tags "jwt,auth"] [--source "/implement ptah-7-user-login"] \
    [--relates-to 12] [--relates-to 34:supersedes]
    → inserts the entry, regenerates INDEX.md, prints {"status":"ok","id":"<n>"}

python3 .claude/ptah/ptah_knowledge.py get <id>
    → full entry as JSON, including tags and both edge directions

python3 .claude/ptah/ptah_knowledge.py search "<query>"
    → FTS5 match over title+body, ranked

python3 .claude/ptah/ptah_knowledge.py by-tag <tag>
python3 .claude/ptah/ptah_knowledge.py by-category <category>
    → list matching entries (id, title, confidence)

python3 .claude/ptah/ptah_knowledge.py related <id> [--depth N]
    → graph traversal, both directions, up to N hops (default 1)

python3 .claude/ptah/ptah_knowledge.py regenerate-index
    → rebuilds INDEX.md from the DB without touching any data
```

Invalid category, confidence, relation, or a `--relates-to` target that doesn't exist are all hard errors (non-zero exit, `{"status":"error",...}` printed) — never silently coerced to a default or dropped. Same "hard failures over silent fallbacks" principle as the rest of Ptah.

---

## `INDEX.md`

Regenerated in full on every `add` — never hand-edited, never diffed against a previous version, just overwritten. One table per category (categories with zero entries are omitted), columns: ID, Title (with `→ <id>` suffixes for outgoing edges), Tags, Confidence. Full `body` text is never in `INDEX.md` — that's what `get` / `/recall <id>` is for.

This is the only file the main-session workflow commands (`/design`, `/implement`, `/fix`, `/document`) read when consulting prior knowledge, and the only one the isolated review subagents (`ptah-code-reviewer`, `ptah-reviewer`) read too — see "Knowledge discipline" in `RULES.md`. None of them query `knowledge.db` directly.
