---
name: ptah-learn
description: 'Captures one entry (gotcha, convention, architecture, dependency, performance, security, or tooling) into Ptah''s knowledge base via ptah_knowledge.py, linking related entries and regenerating INDEX.md. The only way anything is written to knowledge.db. Use when the user runs /ptah-learn.'
argument-hint: '["<title>"] [--category <cat>] [--confidence <verified | suspected>] [--tags <a,b>] [--relates-to <id[:relation]>] [--source <text>]'
disable-model-invocation: false
compatibility: Requires Python 3 (stdlib only)
---

# /ptah-learn

Capture one piece of knowledge into Ptah's persistent knowledge base, so future sessions — on this feature or any other — don't have to rediscover it. This is the **only** way anything gets written to `knowledge.db`. No workflow command captures automatically; see "Knowledge discipline" in [`.claude/ptah/RULES.md`](../../ptah/RULES.md) for why.

`/ptah-learn` is a meta-command, callable any time, from any command, on any feature — it isn't part of the `/ptah-spec → … → /ptah-document` pipeline and never touches `LOGS.md`.

## Step 1 — Parse command arguments

- `/ptah-learn` — start a guided capture, asking each field in turn
- `/ptah-learn "<title>"` — pre-fill the title, still ask the rest
- Optional flags, any of which can be pre-filled to skip that question:
  - `--category <cat>` — one of `gotcha`, `convention`, `architecture`, `dependency`, `performance`, `security`, `tooling`
  - `--confidence <verified|suspected>`
  - `--tags <a,b,c>`
  - `--relates-to <id[:relation]>` (repeatable; relation is one of `related`, `supersedes`, `depends-on`, `conflicts-with`, defaults to `related`)
  - `--source <text>` — defaults to the currently running command context if this was triggered mid-workflow (e.g. `/ptah-implement ptah-7-user-login`), or `manual` if run standalone

**Unknown flags** produce an error consistent with other commands:

> "⚠️ Unknown flag `--xyz`. Supported flags: `--category`, `--confidence`, `--tags`, `--relates-to`, `--source`."

---

## Step 2 — Fill in the missing fields, one at a time

Ask only for fields not already supplied. Order:

1. **Title** (if not given positionally): "What's the one-line finding?"
2. **Category**: present all seven with their icons and one-line definitions from `guides/knowledge-format.md`, ask the user to pick one.
3. **Confidence**: "Is this confirmed (`verified`), or something you've observed once and suspect but haven't fully confirmed (`suspected`)?"
4. **Body**: "Give me the full explanation — enough that someone with zero context on this session could understand and act on it."
5. **Tags** (optional): "Any tags to attach? Comma-separated, or skip."

---

## Step 3 — Check for related entries

Before writing, run a quick search against the title so far:

```
python3 .claude/ptah/ptah_knowledge.py search "<title>"
```

If anything relevant comes back, show the top matches (ID + title) and ask:

> "This looks related to `<id> — <title>`. Link them? If so, how — `related`, `supersedes`, `depends-on`, or `conflicts-with`?"

Skip this step silently if the search returns nothing, or if `knowledge.db` doesn't exist yet (first entry on this project).

---

## Step 4 — Write the entry

Call:

```
python3 .claude/ptah/ptah_knowledge.py add \
  --title "<title>" --category <category> --confidence <confidence> \
  --body "<body>" [--tags "<tags>"] [--source "<source>"] \
  [--relates-to <id[:relation]> ...]
```

Parse the JSON result.

- **On success** (`{"status":"ok","id":"<n>"}`): proceed to Step 5.
- **On error** (`{"status":"error","message":"..."}`): relay the message to the user verbatim and stop. Don't guess a fix or retry with different values — if it was a bad category, tag format, or a `--relates-to` target that doesn't exist, that's for the user to correct.

---

## Step 5 — No LOGS.md entry

`/ptah-learn` never appends to any spec's `LOGS.md`. Knowledge entries are disjoint from session history — see "Knowledge discipline" in `RULES.md`. `INDEX.md` is updated automatically as a side effect of Step 4; nothing else needs writing.

---

## Step 6 — Hand off to user

> "📚 Captured as entry **<n>** (`<category>`). The knowledge index is updated — future `/ptah-design`, `/ptah-implement`, `/ptah-fix`, `/ptah-document`, `/ptah-code-review`, and `/ptah-review` runs on this project will see it automatically. Run `/ptah-recall <n>` any time to pull it back up."

---

## Workflow

`/ptah-learn` is a meta-command, alongside `/ptah-status`, `/ptah-resume`, `/ptah-continue`, and its counterpart `/ptah-recall`:

```
/ptah-status, /ptah-resume, /ptah-continue   ← navigation
/ptah-learn                        ← capture knowledge (you are here)
/ptah-recall                       ← query knowledge
/ptah-spec, /ptah-design, ...           ← actual work commands
```

Use `/ptah-learn` the moment something worth remembering surfaces — mid-`/ptah-implement`, after a `/ptah-code-review` finding, during manual debugging outside any Ptah command, or any other time. Nothing captures on your behalf; if it's worth keeping, run `/ptah-learn` explicitly.
