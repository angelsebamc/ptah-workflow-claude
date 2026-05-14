# /fix

Read the code review findings and fix all blocker and major issues. Document what was changed in CODE-REVIEW.md.

`/fix` supports three modes that control how much the agent asks before applying fixes. The default is `plan`. See **Modes & config** below for details.

## Step 1 — Parse command arguments

The command accepts one positional argument (the feature name) plus optional flags:

- `--auto` — apply all fixes without asking
- `--plan` — show the plan, wait for one confirmation, then apply
- `--interactive` — ask per finding before applying
- `--include-minor` — also fix 🟢 minor issues in this run
- `--blockers-only` — skip minors even if config has them enabled

Examples:
- `/fix user-login` — uses mode from `ptah.yml`, or `plan` if no config
- `/fix user-login --auto` — applies all fixes silently this run
- `/fix user-login --interactive --include-minor` — asks per finding, includes minors

**Mutually-exclusive flag pairs** produce an error and stop:
- `--auto`, `--plan`, `--interactive` (pick one)
- `--include-minor` and `--blockers-only`

If two conflicting flags are passed:

> "⚠️ Conflicting flags: `<flag1>` and `<flag2>`. Pick one."

**Unknown flags** produce an error consistent with `/spec`:

> "⚠️ Unknown flag `--xyz`. Supported flags: `--auto`, `--plan`, `--interactive`, `--include-minor`, `--blockers-only`."

---

## Step 2 — Resolve mode and scope

Determine the effective mode and scope for this run. Precedence is **flag > config > default**.

### 2a. Load Ptah config
Read `.claude/ptah/ptah.yml`.

- If the file doesn't exist, or `commands.fix` is missing → use defaults (`mode: plan`, `include_minor: false`)
- If `commands.fix.mode` is set, validate it's one of `auto`, `plan`, `interactive`. Anything else → stop:
  > "⚠️ Invalid `commands.fix.mode` value `<value>` in `ptah.yml`. Must be one of: `auto`, `plan`, `interactive`."

### 2b. Apply flag overrides
- `--auto` / `--plan` / `--interactive` override `commands.fix.mode`
- `--include-minor` forces `include_minor: true`
- `--blockers-only` forces `include_minor: false`

The config file is never modified by `/fix`. Flags only affect the current run.

### 2c. Compute in-scope findings
- Always in scope: 🔴 blockers and 🟡 major issues
- If `include_minor` is true: also 🟢 minor issues
- 💡 suggestions are never auto-fixed by `/fix` — they require a separate explicit request

---

## Step 3 — Read the context

Read the following files:

- `.claude/specs/<feature-name>/CODE-REVIEW.md` — all findings from the review
- `.claude/specs/<feature-name>/DESIGN.md` — original technical design
- `.claude/specs/<feature-name>/IMPLEMENTATION.md` — what was built
- `.claude/specs/<feature-name>/LOGS.md` — session history, to understand current state
- `CLAUDE.md` — project conventions, architecture decisions

If `CODE-REVIEW.md` has no in-scope issues (no blockers, no major, and minors aren't included), stop and tell the user. The suggested next step depends on whether testing is enabled — read `commands.test.enabled` from `.claude/ptah/ptah.yml` (defaults to `false`):

- Testing enabled → "✅ No in-scope issues to fix. Run `/test <feature-name>` directly."
- Testing disabled → "✅ No in-scope issues to fix. Run `/document <feature-name>` directly."

---

## Step 4 — Clarify before fixing

Apply the **Stop and ask** rule from [`.claude/ptah/RULES.md`](../../ptah/RULES.md). Review all in-scope findings; if any is ambiguous or could have side effects beyond this feature's scope, ask before touching code.

This applies in **all three modes** — modes control verbosity for routine fixes, not judgment for ambiguous ones.

---

## Step 5 — Apply fixes (mode-specific)

### `auto` mode
Apply every in-scope fix without asking. Do not narrate each fix as it happens — produce the Fix Summary at the end. The only interruption is the existing stop-and-ask rule from Step 4 for genuinely ambiguous fixes.

### `plan` mode (default)
Before touching any code, present a fix plan to the user:

```
📋 Fix plan — <feature-name>

🔴 <title>
   Change: <one-line summary of intended change>
   Files:  <comma-separated list of files to be modified>

🟡 <title>
   Change: <one-line summary>
   Files:  <files>

(🟢 included only if include_minor is true)

Mode: plan
Total: <X> blockers, <Y> major<, Z minor if included>

Apply all of these?
```

Wait for explicit confirmation (yes / proceed / similar). If the user declines, stop and ask what to do differently. If the user wants to skip specific findings, switch to `interactive` mode for the remainder and re-prompt per finding.

Once confirmed, apply all fixes in one pass without further narration.

### `interactive` mode
Work through findings one at a time. For each:

1. State the finding (icon, title, file:line)
2. Describe the intended change in one or two lines
3. Ask: "Apply this fix?"
4. Wait for confirmation
5. Apply, briefly note the result
6. Move to the next finding

The user can decline a finding (skip and continue), pause the loop, or change direction at any point.

---

## Step 6 — Rules while fixing

These apply regardless of mode:

- Fix only what is documented in CODE-REVIEW.md — do not refactor unrelated code
- If a fix requires a design change, stop and ask the user before proceeding
- If a fix introduces a new dependency not in the original design, ask first
- Keep fixes minimal and focused — don't improve things that aren't broken
- 💡 suggestions are never fixed automatically — only on explicit user request, and only via `interactive` mode for that suggestion

---

## Step 7 — Update CODE-REVIEW.md

After all fixes are applied, append a **Fix Summary** section to `.claude/specs/<feature-name>/CODE-REVIEW.md`:

```markdown
## Fix Summary — <date>

### Mode
<auto | plan | interactive>, include_minor: <true | false>

### Fixed
- [x] 🔴 <title> — <brief note on how it was fixed>
- [x] 🟡 <title> — <brief note on how it was fixed>
- [x] 🟢 <title> — <brief note> (only if include_minor was true)

### Skipped
<Findings the user declined during interactive mode, with their stated reason if given. "None" if all in-scope fixes were applied.>

### Deferred
- [ ] 🟢 <title> — deferred: not in scope this run
- [ ] 💡 <title> — deferred: suggestion, not auto-fixed

### New issues found during fix
<Any new issues discovered while fixing. "None" if clean.>
```

The Fix Summary section is structurally identical across all three modes — only the **Mode** line and **Skipped** content differ.

---

## Step 8 — Append to LOGS.md

After updating CODE-REVIEW.md, append the following entry to `.claude/specs/<feature-name>/LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /fix completed
- Mode: <auto | plan | interactive>
- 🔴 Blockers fixed: <count>
- 🟡 Major issues fixed: <count>
- 🟢 Minor fixed: <count> (or "skipped — not in scope")
- Skipped by user: <count, or "none">
- New issues found: <yes — brief note, or "no">
- Next step: <see routing rule below>
```

**`Next step:` routing rule.** Read `commands.test.enabled` from `.claude/ptah/ptah.yml` (defaults to `false` if missing or the file doesn't exist):

- Testing enabled → `/test`
- Testing disabled → `/document`

See **LOGS.md format** in the project `README.md` for the full schema.

---

## Step 9 — Hand off to user

After updating both files, tell the user. The suggested next step depends on whether testing is enabled:

- Testing enabled:
  > "✅ All in-scope fixes applied (mode: `<mode>`). Review the changes and the fix summary in `.claude/specs/<feature-name>/CODE-REVIEW.md`.
  >
  > When you're happy with it, run `/test <feature-name>` to run the tests."

- Testing disabled:
  > "✅ All in-scope fixes applied (mode: `<mode>`). Review the changes and the fix summary in `.claude/specs/<feature-name>/CODE-REVIEW.md`.
  >
  > When you're happy with it, run `/document <feature-name>` to finalize the feature."

---

## Modes & config

`/fix` has three modes:

| Mode | Behavior |
|------|----------|
| `auto` | Apply all in-scope fixes silently. Report at the end. |
| `plan` | Show a one-line-per-finding plan, wait for one confirmation, apply all in one pass. **Default.** |
| `interactive` | Ask per finding before applying. User can skip individual findings. |

Mode is resolved with precedence **flag > config > default (`plan`)**.

### Config (`.claude/ptah/ptah.yml`)

```yaml
commands:
  fix:
    mode: plan              # auto | plan | interactive
    include_minor: false    # also fix 🟢 minor issues by default?
```

Both keys are optional. Missing keys fall back to defaults.

### Flags (per-run override)

- `--auto`, `--plan`, `--interactive` — override `mode` for this run
- `--include-minor` — force `include_minor: true` for this run
- `--blockers-only` — force `include_minor: false` for this run

Conflicting flags produce an error and stop. The config file is never modified by `/fix`.

### The stop-and-ask rule always applies

Regardless of mode, the existing **Stop and ask** rule from `RULES.md` applies — if a fix is ambiguous, could have side effects beyond scope, requires a design change, or introduces a new dependency, the agent stops and asks. `auto` mode does not suppress this.

---

## Workflow

This command is part of the Ptah workflow:

```
/spec → /design → /implement → /code-review → /fix → [/test] → /document
```

`/test` is opt-in per project — controlled by `commands.test.enabled` in `.claude/ptah/ptah.yml`. When testing is disabled (the default), `/fix` hands off to `/document` instead.

When testing is enabled and `/test` fails, the test output is added to CODE-REVIEW.md and `/fix` is called again to handle the new issues. The loop continues until all tests pass.

Each command appends a session entry to `LOGS.md`. When resuming after a break, read `LOGS.md` first to understand where the feature stands.

Always wait for the user to review and confirm before suggesting the next step.
