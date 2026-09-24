# /continue

Resume whatever you were last actively working on — no spec number required. `/continue` auto-resolves the target spec, then orients on it exactly like `/resume <n>` does.

Like `/resume`, this is a meta-command: **read-only**. It does not run the next workflow command and does not append to `LOGS.md`.

**This command depends on the `ptah-continue-resolve.sh` hook.** Unlike the rest of Ptah's config, there is no fallback if it isn't registered — register it by running `install-ptah.sh --register-continue-hook`. Without it, use `/resume <n>` or `/status` instead.

Use `/continue` when you don't remember (or don't care) which spec number you were on. Use `/resume <n>` directly when you want a *specific* spec, especially if more than one is in flight.

---

## Step 1 — Resolve the target spec

Check the current context for injected content starting with `Resolved /continue target:` (delivered by the hook alongside this prompt).

- **Present and names a folder** → use it directly as `<feature-name>` for Step 2 below.
- **Present and says `none`** (hook ran but found no specs, or nothing in flight) → relay that message to the user verbatim and stop here.
- **Absent entirely** → `/continue` can't tell *why*. The hook may not be installed, or it may be installed and failed silently — wrong matcher, timeout, or bad JSON output all fail open per Claude Code's hook docs, so nothing else would have surfaced the problem. Don't assert a cause. Stop and tell the user:

  > "⚠️ No acceleration-hook resolution detected — `/continue` depends on it and has no fallback. If you've registered the hook, check `/hooks` in Claude Code to see if it's firing; otherwise re-run `install-ptah.sh --register-continue-hook` to set it up. `/resume <n>` or `/status` still work directly in the meantime."

---

## Step 2 — Orient on the spec

With `<feature-name>` resolved, perform **Steps 2 through 4 of `/resume`** exactly (session history → artifact and refs inventory → summary) — see [`resume.md`](./resume.md). The same read limits apply: `LOGS.md` only, no artifacts, refs, source files, or `CLAUDE.md`. The only difference is where `<feature-name>` came from: typed by the user there, resolved automatically here.

**Modify `/resume`'s Step 4 output** with one addition — a line explaining why this spec was picked, and a renamed header so it's clear this was automatic:

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

If the workflow for the resolved spec is complete — which shouldn't normally happen, since the hook skips completed specs, but could if `/continue` is run again in the same session right after finishing one — fall back to `/resume`'s own completed-workflow synthesis line.

---

## Step 3 — Hand off to user

End with:

> "Oriented on <n>. Run the next command yourself when you're ready — it loads the artifacts it needs.
>
> Working on something else? Run `/resume <n>` directly, or `/status` to see everything in flight."

Do **not** auto-run anything. Do **not** append to any `LOGS.md` — `/continue`, like `/resume`, is purely a read.

---

## Workflow

`/continue` is a meta-command, alongside `/status` and `/resume`:

```
/status              ← what's in flight?
/resume <n>          ← orient on a specific spec
/continue            ← orient on whatever's most recently active (you are here)
/spec, /design, ...  ← actual work commands
```

Use `/continue` when:
- Starting a new session and you don't remember (or don't care about) the spec number
- You know you want to pick back up wherever you left off, not a specific feature

Use `/resume <n>` instead when more than one spec is in flight and you want a specific one — `/continue` always picks the single most recently touched, non-completed spec.

`/continue` does not append to any `LOGS.md` — it's purely a read, same as `/resume`.

`/continue` is the one Ptah meta-command that requires setup beyond dropping in a file — install with `install-ptah.sh --register-continue-hook`.
