# /recall

Look up something Ptah's knowledge base already knows, without starting another investigation from scratch. Read-only — `/recall` never writes to `knowledge.db` and never appends to `LOGS.md`, same as `/status` and `/resume`.

## Step 1 — Parse arguments

Exactly one lookup mode per call:

- `/recall 42` — direct lookup by id
- `/recall --tag <tag>` — all entries with that tag
- `/recall --category <cat>` — all entries in that category
- `/recall "<free text>"` — full-text search over title + body
- `/recall --related 42 [--depth N]` — graph traversal from that entry (default depth 1)

**More than one mode passed at once** is an error:

> "⚠️ `/recall` takes one lookup mode at a time. Pick one: an id, `--tag`, `--category`, free text, or `--related`."

**No arguments at all**: don't error — read `INDEX.md` and print a one-line count per category as a quick orientation (e.g. "🐛 gotcha: 4 · 📐 convention: 2 · 🔒 security: 1"), then suggest a lookup mode.

---

## Step 2 — Dispatch

| Mode | Call |
|---|---|
| id | `python3 .claude/ptah/ptah_knowledge.py get <id>` |
| `--tag` | `python3 .claude/ptah/ptah_knowledge.py by-tag <tag>` |
| `--category` | `python3 .claude/ptah/ptah_knowledge.py by-category <category>` |
| free text | `python3 .claude/ptah/ptah_knowledge.py search "<query>"` |
| `--related` | `python3 .claude/ptah/ptah_knowledge.py related <id> --depth <N>` |

Parse the JSON result.

---

## Step 3 — Present results

- **Direct id lookup**: show the full entry — title, category icon, confidence, tags, body, and both `relates_to` (outgoing) and `related_from` (incoming) edges with their relation type.
- **Tag / category listing**: a table — ID, Title, Confidence.
- **Free-text search**: a ranked table — ID, Title, Category, Confidence.
- **`--related` traversal**: a list grouped by distance, each row showing the relation type (e.g. "1 hop, `supersedes`: 34 — Stripe webhook retries can arrive out of order").

**Nothing found** (`{"status":"ok","results":[]}` or `{"status":"not_found",...}`):

> "No knowledge entries found for `<query>`. If you just discovered something worth keeping, `/learn` will capture it."

---

## Workflow

`/recall` is a meta-command, alongside `/status`, `/resume`, `/continue`, and its counterpart `/learn`:

```
/status, /resume, /continue   ← navigation
/learn                        ← capture knowledge
/recall                       ← query knowledge (you are here)
/spec, /design, ...           ← actual work commands
```

Use `/recall` any time you want to check "have we already figured this out?" before digging in yourself. Workflow commands do a lighter version of this automatically — they scan `INDEX.md` at the start of a run — but `/recall` is for a direct, explicit ask, including the graph traversal `--related` gives you that `INDEX.md`'s plain table can't.
