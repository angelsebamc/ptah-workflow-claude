---
name: ptah-continue
description: 'Auto-selects the most recently active Ptah spec that isn''t complete and orients on it the same way /ptah-resume does, with no spec number needed. Read-only. Use when the user runs /ptah-continue to pick up wherever they left off.'
disable-model-invocation: true
compatibility: Requires bash
allowed-tools: Bash(.claude/skills/ptah-continue/scripts/resolve.sh)
---

# /ptah-continue

Resume whatever you were last actively working on — no spec number required. `/ptah-continue` auto-resolves the target spec, then orients on it exactly like `/ptah-resume <n>` does.

Like `/ptah-resume`, this is a meta-command: **read-only**. It does not run the next workflow command and does not append to `LOGS.md`.

**This command depends on [`scripts/resolve.sh`](scripts/resolve.sh)**, which runs as this skill loads and injects its result below. There is no fallback if it fails. Without it, use `/ptah-resume <n>`.

Use `/ptah-continue` when you don't remember (or don't care) which spec number you were on. Use `/ptah-resume <n>` directly when you want a *specific* spec, especially if more than one is in flight.

---

## Step 1 — Resolve the target spec

The resolver's output, injected when this skill loaded:

!`.claude/skills/ptah-continue/scripts/resolve.sh`

- **Starts with `Resolved /ptah-continue target:` and names a folder** → use it directly as `<feature-name>` for Step 2 below.
- **Starts with `Resolved /ptah-continue target: none`** (no specs, or nothing in flight) → relay its message to the user verbatim and stop here.
- **Anything else** (empty, an error, a permission denial) → the resolver failed. Don't scan `.claude/specs/` yourself and don't guess a cause. Stop and tell the user:

  > "⚠️ `/ptah-continue` couldn't resolve a target — its resolver script failed, and there is no fallback. Output: `<the output above, verbatim>`. Check that `.claude/skills/ptah-continue/scripts/resolve.sh` exists and is executable, or re-run `install-ptah.sh`. `/ptah-resume <n>` or `/ptah-status` still work directly in the meantime."

---

## Step 2 — Orient on the spec

With `<feature-name>` resolved, perform **Steps 2 through 4 of `/ptah-resume`** exactly (session history → artifact and refs inventory → summary) — see [`ptah-resume`](../ptah-resume/SKILL.md). The same read limits apply: `LOGS.md` only, no artifacts, refs, source files, or `CLAUDE.md`. The only difference is where `<feature-name>` came from: typed by the user there, resolved automatically here.

**Modify `/ptah-resume`'s Step 4 output** with one addition — a line explaining why this spec was picked, and a renamed header so it's clear this was automatic:

```
🔄 Continuing <n>
Auto-selected: most recently active spec not yet complete (last entry: <last LOGS.md heading, verbatim>)

History: LOGS.md (<count> command entries, <count> change entries)
Artifacts: <comma-separated artifact filenames>
Refs: <comma-separated refs/ filenames, or "none">

Last command:
## <heading line, verbatim>
- <fields, verbatim>

Changes since then:
- <HH:MM> <type> — <the entry's "What:" value>

(One line per change entry since the last command. If none: "None.")

Where you are: <one-line synthesis based on the last command's "Next step:" field>
```

If the workflow for the resolved spec is complete — which shouldn't normally happen, since the resolver skips completed specs, but could if `/ptah-continue` is run again in the same session right after finishing one — fall back to `/ptah-resume`'s own completed-workflow synthesis line.

---

## Step 3 — Hand off to user

End with:

> "Oriented on <n>. Run the next command yourself when you're ready — it loads the artifacts it needs.
>
> Working on something else? Run `/ptah-resume <n>` directly, or `/ptah-status` to see everything in flight."

Do **not** auto-run anything. Do **not** append to any `LOGS.md` — `/ptah-continue`, like `/ptah-resume`, is purely a read.

---

## Workflow

`/ptah-continue` is a meta-command, alongside `/ptah-status` and `/ptah-resume`:

```
/ptah-status              ← what's in flight?
/ptah-resume <n>          ← orient on a specific spec
/ptah-continue            ← orient on whatever's most recently active (you are here)
/ptah-spec, /ptah-design, ...  ← actual work commands
```

Use `/ptah-continue` when:
- Starting a new session and you don't remember (or don't care about) the spec number
- You know you want to pick back up wherever you left off, not a specific feature

Use `/ptah-resume <n>` instead when more than one spec is in flight and you want a specific one — `/ptah-continue` always picks the single most recently touched, non-completed spec.

`/ptah-continue` does not append to any `LOGS.md` — it's purely a read, same as `/ptah-resume`.

`/ptah-continue` is the one Ptah meta-command that runs a script, which must stay executable.
