# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Ptah is a spec-driven workflow for Claude Code, delivered as skills run as slash commands (`skills/ptah-*/SKILL.md`), subagents (`agents/*.md`), a rules doc (`RULES.md`), a knowledge-base CLI (`ptah_knowledge.py`), and one bundled script (`skills/ptah-continue/scripts/resolve.sh`). Most of the "code" is prompt text in markdown: editing a skill means changing the instructions an agent follows. This repo does not use Ptah on itself.

There is no build, lint, or test suite.

## Source layout vs installed layout

The repo is **flat**. `install-ptah.sh` reshapes it into a target project's `.claude/` folder:

| Repo file | Installed at |
|---|---|
| `skills/ptah-*/` (whole folder) | `.claude/skills/ptah-*/` |
| `agents/*.md` | `.claude/agents/ptah/*.md` |
| `README.md`, `RULES.md`, `ptah_knowledge.py` | `.claude/ptah/` |
| `logs-format.md`, `knowledge-format.md`, `vocabulary.md`, `result-format.md` | `.claude/ptah/guides/` |
| `ptah_example.yml` | `.claude/ptah/ptah.example.yml` (and `ptah.yml` with `-CreateConfig`) |
| fenced block in `CLAUDE-snippet.md` | appended to the target's `CLAUDE.md` under `## Ptah workflow` |

Every path and relative link inside the markdown (e.g. `../../ptah/RULES.md`, `guides/knowledge-format.md`, `.claude/specs/...`) is written for the **installed** layout, so many of them don't resolve inside this repo. That's expected; don't "fix" them to repo-relative paths.

When you add, rename, or move a shipped file, update all of these together:
- `install-ptah.sh`: the `REQUIRED_SOURCE_ITEMS` list and the copy steps
- the folder-structure tree in `README.md`
- the path-conventions table in `RULES.md`

Try the installer against a scratch project. It is idempotent (it skips existing files unless `--force`), and it removes the pre-skills layout (`.claude/commands/ptah/`, `.claude/ptah/hooks/`, the `continue` hook in `.claude/settings.local.json`) if it finds one:
```bash
./install-ptah.sh --project-path /path/to/scratch --create-config --force
```

## Skill conventions

Every skill follows the Agent Skills format: `name` matches its folder, `description` says what it does and when to use it, and `metadata` carries `author` and a quoted `version`. On top of that, every Ptah skill sets `disable-model-invocation: true` (commands are user-run only; `/ptah-learn` in particular must never fire on its own), and takes an `argument-hint` when it has arguments. `compatibility` appears only where a skill has a real runtime requirement (Python 3 for `/ptah-learn` and `/ptah-recall`, bash for `/ptah-continue`). Don't add `allowed-tools` beyond `/ptah-continue`'s resolver, since it changes permission prompts. Links to `../../ptah/RULES.md` and `../../ptah/guides/` deliberately point outside the skill folder: those files are shared.

## Architecture: how the pieces relate

- **Pipeline:** `/ptah-spec` → `/ptah-design` → `/ptah-implement` → `/ptah-code-review` → `/ptah-fix` → `/ptah-document`. Each command writes one artifact into `.claude/specs/ptah-<n>-<slug>/` and appends a completion entry to that spec's `LOGS.md`. A command never auto-advances to the next one. Meta-commands (`/ptah-status`, `/ptah-resume`, `/ptah-continue`) are read-only and never write to `LOGS.md`. `/ptah-review` is a separate pipeline that reviews a diff and writes into `.claude/reviews/<name>/`.
- **`RULES.md` holds the rules that apply across commands** (read LOGS.md first, stop and ask, logging discipline, spec-id assignment and resolution, knowledge discipline, wait for confirmation). Commands point to its sections by name rather than repeating them. If you rename a `RULES.md` section, grep `skills/` and `agents/` for references to it.
- **Isolated review:** `/ptah-code-review` and `/ptah-review` are thin dispatchers. They pass the subagent only a resolved folder path. The subagent (`tools: Read, Grep, Glob`) reads everything itself, including `knowledge/INDEX.md`, and returns a result in the `result-format.md` shape (`===RESULT===`, `===CODE-REVIEW.md===`, `===END===`). The dispatcher writes that output to disk. Keep the subagents read-only, and never pass them conversation context: the isolation is the point of the design.
- **Delegated work:** `/ptah-design` and `/ptah-implement` are dispatchers too, for context size rather than independent judgment. They pass `ptah-designer` / `ptah-implementer` only the folder path. Subagents can't talk to the user, so they return `needs-input` with questions; the dispatcher logs a `paused` entry, asks them one at a time, logs each answer as a `LOGS.md` change entry, and re-dispatches. Answers travel through `LOGS.md`, never the prompt. Both return a `### Learn candidates` section so findings survive the subagent's context.
- **Spec numbering:** `/ptah-spec` reads and increments `specs.next_id` in `.claude/ptah/ptah.yml`. It never infers the next number from folder names. Every other command resolves `3` / `ptah-3` / full folder name using the order defined in `RULES.md`.
- **Knowledge base:** `ptah_knowledge.py` is the **only** code that touches `knowledge.db` (SQLite with FTS5; tables `entries`, `tags`, `edges`). Every write regenerates `INDEX.md`. Workflow commands only scan `INDEX.md`; only `/ptah-learn` and `/ptah-recall` call the script. Knowledge entries and `LOGS.md` never cite each other.
- **Formats:** `vocabulary.md` defines every fixed value (statuses, states, change types, severities, verdicts, fix modes). `result-format.md` defines the markdown shape of subagent results (`===RESULT===` … `===END===`) and of every command's hand-off. `logs-format.md` defines the `LOGS.md` entry schema, and `knowledge-format.md` the knowledge-base schema and CLI contract. Result fields are the `LOGS.md` fields by design, so changing what a command logs means updating `logs-format.md`, `result-format.md`'s per-command table, and the matching agent together. A new fixed value goes in `vocabulary.md` first.
- **`/ptah-continue` resolver:** `skills/ptah-continue/scripts/resolve.sh` runs through the skill's `` !`…` `` injection as the skill loads (pre-approved by its `allowed-tools`). It finds the newest `LOGS.md` by mtime whose last `## ` heading is not `— /ptah-document completed` (or the unprefixed `— /document completed`), then prints `Resolved /ptah-continue target: ...`. `skills/ptah-continue/SKILL.md` parses that exact string, so the heading text and the printed string are contracts shared by both files.

## Working with `ptah_knowledge.py`

Python 3, stdlib only. It uses the relative path `.claude/ptah/knowledge/`, so run it from a project root (a scratch dir works). Every subcommand prints JSON. Invalid enum values exit non-zero.

```bash
python3 ptah_knowledge.py init
python3 ptah_knowledge.py add --title "..." --category gotcha --confidence verified --body "..." --tags "a,b" --relates-to 1:supersedes
python3 ptah_knowledge.py get 1 | search "query" | by-tag a | by-category gotcha | related 1 --depth 2
python3 ptah_knowledge.py regenerate-index
```

The valid categories, confidences, and relations are defined twice: in the Python lists and in the SQL `CHECK` constraints. Keep the two in sync, along with `knowledge-format.md` and `skills/ptah-learn/SKILL.md`.

## Line endings

Files are committed with LF, but Windows checkouts end up with CRLF, which shows every file as modified. Use `git diff --ignore-cr-at-eol` to see real changes. Keep `skills/ptah-continue/scripts/resolve.sh` LF-only because bash fails on CRLF. The installer also strips CRs from it when it copies it, but the source should stay clean.
