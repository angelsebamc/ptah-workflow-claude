# Snippet for your project's CLAUDE.md

Add this to your project root's `CLAUDE.md` so the agent picks up the Ptah workflow rules:

```markdown
## Ptah workflow

This project uses Ptah for spec-driven development. Read [`.claude/ptah/RULES.md`](./.claude/ptah/RULES.md) for workflow rules — logging discipline, path conventions, spec numbering, knowledge discipline, when to stop and ask, and how to wait for user confirmation between commands. Slash commands live in `.claude/commands/ptah/`.

Every spec is numbered (`ptah-<n>-<slug>`) the moment `/spec` creates it — every command after that takes just the number, e.g. `/design 3`, `/fix 3`.

Ptah also maintains a persistent, project-wide knowledge base at `.claude/ptah/knowledge/`, separate from any one spec's `LOGS.md`. Use `/learn` to capture a gotcha, convention, or other durable finding; use `/recall` to look one up directly. Every workflow command checks it automatically before starting — nothing needs to be asked for.

Meta-commands help with session continuity:
- `/status` lists in-flight specs
- `/resume <n>` reads a spec's `LOGS.md` and reports where the work stands and what to run next; the next command loads its own artifacts
- `/continue` does the same for the most recently active spec, no number needed
```

That's it — one block in `CLAUDE.md`, full rules live in `RULES.md`.
