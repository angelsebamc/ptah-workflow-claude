# Ptah — install

This folder contains everything Ptah needs. Drop the `.claude/` folder into your project root, then add a snippet to your `CLAUDE.md`.

## What's in here

```
.claude/
  commands/ptah/        ← 9 slash commands (status, resume, spec, design,
                          implement, code-review, fix, test, document)
    RULES.md             ← cross-cutting agent rules (logging, paths, spec numbering, etc.)
    ptah.example.yml    ← template for ptah.yml (rename to ptah.yml to use)
    guides/
      logs-format.md    ← strict schema for LOGS.md entries

CLAUDE-snippet.md       ← paste this block into your project's CLAUDE.md
INSTALL.md              ← this file
```

## Steps

1. **Copy `.claude/` into your project root.** If a `.claude/` already exists, merge — keep your existing `commands/` and add `commands/ptah/` alongside it.

2. **Copy the snippet.** Open `CLAUDE-snippet.md`, copy the markdown block inside, and paste it into your project root's `CLAUDE.md`. Create `CLAUDE.md` if you don't have one.

3. **(Optional) Configure `ptah.yml`.** Copy `.claude/ptah/ptah.example.yml` to `.claude/ptah/ptah.yml` and edit it if you want to:
   - Enable the `/test` step (default is disabled — set `commands.test.enabled: true`)
   - Wire up ticket integration (JIRA, Linear, GitHub issues)
   - Change `/fix` mode defaults

   Skip this entirely if you don't need any of that — Ptah works without `ptah.yml`, just with `/test` disabled.

5. **Try it.** Run `/status` (you should see "No specs found"), then `/spec my-first-feature` to start. Ptah will create it as `ptah-1-my-first-feature` and every command after that — `/design`, `/implement`, and so on — takes just the number (`1`), not the full name.

## Where work goes

Once you start using Ptah, a folder will appear under `.claude/` as you work:

- `.claude/specs/ptah-<n>-<slug>/` — created by `/spec`, holds your feature specs. `<n>` is an auto-assigned number and `<slug>` is derived from the feature name — see "Spec identifiers" in `RULES.md`.

This is your work product. Don't pre-create it.

## Documentation

- **For the full overview** — `.claude/ptah/README.md`
- **For agent rules** — `.claude/ptah/RULES.md`
- **For LOGS.md schema** — `.claude/ptah/guides/logs-format.md`
- **For each slash command** — `.claude/commands/ptah/<command>.md`
