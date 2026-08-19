# Ptah — install

This folder contains everything Ptah needs. Drop the `.claude/` folder into your project root, then add a snippet to your `CLAUDE.md`.

## What's in here

```
.claude/
  commands/ptah/        ← 8 slash commands (status, resume, spec, design,
                          implement, code-review, fix, document)
  ptah/                 ← Ptah's config + reference docs
    README.md           ← project overview, command reference, folder structure
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
   - Wire up ticket integration (JIRA, Linear, GitHub issues)
   - Change `/fix` mode defaults

   Skip this entirely if you don't need any of that — Ptah works without `ptah.yml`.

4. **(Only if you plan to use `/continue`) Register the `/continue` hook.** `/continue` (see `.claude/commands/ptah/continue.md`) resolves its target spec entirely through this hook — there's no fallback. Skip this step if you don't plan to use `/continue`; every other Ptah command works without it.

   - Save `ptah-continue-resolve.sh` to `.claude/ptah/hooks/ptah-continue-resolve.sh` and make it executable (`chmod +x`).
   - Add it to `.claude/settings.json` at your project root — **not** `~/.claude/settings.json` (personal-only) or `.claude/settings.local.json` (gitignored). Project-level `.claude/settings.json` is the shareable one, meant to be committed, so the hook works for teammates too without them setting it up individually. If the file already exists, merge `"UserPromptExpansion"` into its existing `"hooks"` key rather than overwriting the file:

   ```json
   {
     "hooks": {
       "UserPromptExpansion": [
         {
           "matcher": "continue",
           "hooks": [
             {
               "type": "command",
               "command": "${CLAUDE_PROJECT_DIR}/.claude/ptah/hooks/ptah-continue-resolve.sh",
               "args": []
             }
           ]
         }
       ]
     }
   }
   ```

   - **Verify the matcher.** `UserPromptExpansion` matches on command name, but the exact string Claude Code assigns to a project command under `.claude/commands/ptah/continue.md` hasn't been confirmed. After installing, open the `/hooks` menu in Claude Code and check the hook fires when you run `/continue`. If it doesn't, adjust `matcher` to whatever name the menu shows — `/continue` will otherwise stop every time with "no acceleration-hook resolution detected" instead of doing anything useful.

5. **Restart your Claude session** so the new slash commands and `CLAUDE.md` rules get picked up.

6. **Try it.** Run `/status` (you should see "No specs found"), then `/spec my-first-feature` to start. Ptah will create it as `ptah-1-my-first-feature` and every command after that — `/design`, `/implement`, and so on — takes just the number (`1`), not the full name.

## Where work goes

Once you start using Ptah, a folder will appear under `.claude/` as you work:

- `.claude/specs/ptah-<n>-<slug>/` — created by `/spec`, holds your feature specs. `<n>` is an auto-assigned number and `<slug>` is derived from the feature name — see "Spec identifiers" in `RULES.md`.

This is your work product. Don't pre-create it.

## Documentation

- **For the full overview** — `.claude/ptah/README.md`
- **For agent rules (including spec numbering)** — `.claude/ptah/RULES.md`
- **For LOGS.md schema** — `.claude/ptah/guides/logs-format.md`
- **For each slash command** — `.claude/commands/ptah/<command>.md`
