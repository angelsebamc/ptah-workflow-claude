# Snippet for your project's CLAUDE.md

Add this to your project root's `CLAUDE.md` so the agent picks up the Ptah workflow rules:

```markdown
## Ptah workflow

This project uses Ptah for spec-driven development. Read [`.claude/ptah/RULES.md`](./.claude/ptah/RULES.md) for workflow rules — logging discipline, path conventions, when to stop and ask, and how to wait for user confirmation between commands. Slash commands live in `.claude/commands/ptah/`.

Two meta-commands help with session continuity:
- `/status` lists in-flight specs
- `/resume <name>` reloads the full working context (project rules, session history, and every relevant artifact) so the agent can continue work from a previous session as if it had never stopped
```

That's it — one block in `CLAUDE.md`, full rules live in `RULES.md`.
