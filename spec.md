# /spec

Create a new feature spec folder and guide the user through defining a solid use case before moving to design.

If the project has a **Ptah config** (`.claude/ptah/ptah.yml`) with external context sources configured (e.g. JIRA, Linear, GitHub), this command can pre-fill parts of the spec from a linked ticket.

## Step 1 — Parse command arguments

The command accepts one positional argument (the feature name) plus optional source flags defined in `ptah.yml`.

Examples:
- `/spec user-login` — plain feature, no external ticket
- `/spec user-login --jira PROJ-1234` — pulls context from JIRA ticket PROJ-1234
- `/spec user-login --linear ENG-42` — pulls from Linear (if configured)

To know which flags are valid, read `ptah.yml` (see Step 2). Any flag not declared in `ptah.yml` should produce an error:

> "⚠️ Unknown flag `--xyz`. Configured sources: <list from ptah.yml>. See `.claude/ptah/ptah.yml`."

---

## Step 2 — Load Ptah config and fetch external context (if any)

### 2a. Load Ptah config
Read `.claude/ptah/ptah.yml` from the project root.

- If the file does not exist → skip straight to Step 3 (manual mode, same as before).
- If `ptah.yml` exists but `context_sources` is empty → also skip to Step 3.

### 2b. Validate the provided flag
If the user passed a source flag (e.g. `--jira PROJ-1234`):

1. Find the matching source in `ptah.yml` by its `flag` field.
2. Validate the ticket ID against `id_pattern`. If it doesn't match, stop:
   > "⚠️ `<value>` doesn't look like a valid <source> ID (expected pattern: `<pattern>`)."
3. Proceed to fetch.

If no flag was passed but sources are configured, don't prompt — just proceed in manual mode. Flags are opt-in.

### 2c. Fetch the ticket
Call the MCP server named in `fetch_via` to retrieve the ticket content.

**If the fetch fails** (bad ID, no access, MCP unavailable, network error), stop and tell the user exactly what went wrong:

> "❌ Failed to fetch `<source>` ticket `<id>`: <error message>.
>
> Fix the issue and re-run the command, or run `/spec <feature-name>` without the flag to proceed manually."

**Do not fall back silently.** If the user asked for the flag, they want the data — not a silent shrug.

### 2d. Map fetched fields
Once fetched, use the `field_mapping.spec` section of `ptah.yml` to map ticket fields onto spec sections. Keep the mapping in memory — it will be used in Step 4 to pre-fill answers.

Report back to the user what was pulled in:

> "📋 Loaded <source> ticket `<id>`: <ticket title>
>
> The following spec fields will be pre-filled from the ticket:
> - Description ← ticket summary
> - Problem ← ticket description
> - Acceptance criteria ← ticket acceptance criteria
>
> I'll show each one during the spec conversation so you can confirm or edit."

---

## Step 3 — Create the folder structure

Create the following structure:

```
.claude/specs/<feature-name>/
  LOGS.md           ← running session journal, appended by every command
  SPEC.md           ← will be filled via conversation
  DESIGN.md         ← empty, filled by /design
  IMPLEMENTATION.md ← empty, filled by /implement
  CODE-REVIEW.md    ← empty, filled by /code-review
  TEST.md           ← empty, filled by /test
  refs/             ← empty folder for screenshots, mockups, references
```

Create each file with just a `# <filename>` heading. Confirm to the user that the folder was created.

---

## Step 4 — Start the spec conversation

Tell the user:

> "Folder created at `.claude/specs/<feature-name>/`. Let's build out the spec together — I'll ask you a few questions to define a solid use case before moving to design."

Then guide the user through the following sections **one at a time** — wait for their answer before asking the next question.

### If external context was loaded (Step 2):
For any question whose answer is pre-filled from the ticket, present the pre-filled value and ask for confirmation:

> "From the ticket: _<mapped value>_.
>
> Keep as-is, or rewrite?"

Accept edits. Don't force the user to retype something that's already good.

For sections without a mapping, ask normally.

### Questions to ask (in order):

1. **Description**
   > "In one sentence — what is this feature?"

2. **Problem**
   > "What problem does this solve for the user? Why does it matter?"

3. **Use case**
   > "Walk me through the user flow step by step. What does the user do, what does the app do, what's the end result?"

4. **Acceptance criteria**
   > "How do we know this feature is done? List the conditions that must be true for it to be considered complete."

5. **References**
   > "Are there any screenshots, mockups, or other files I should put in `/refs`? If so, describe them or share them now."

6. **Out of scope**
   > "What is explicitly NOT part of this feature? What are we leaving for later?"

---

## Step 5 — Write SPEC.md

After all questions are answered, write the following to `SPEC.md`.

If external context was loaded and `backlink_header: true` is set in `ptah.yml`, include the source header at the top:

```markdown
# SPEC — <feature-name>

> **Source:** [<ticket-id>](<ticket-url>) — <ticket-title>

## Description
<one-line description>

## Problem
<why this feature matters>

## Use case
<step-by-step user flow>

## Acceptance criteria
- <criterion 1>
- <criterion 2>
- ...

## References
<list of files in /refs, or "none">

## Out of scope
- <item 1>
- <item 2>
- ...
```

If no external context was loaded, omit the `> **Source:**` line entirely.

---

## Step 6 — Append to LOGS.md

After writing SPEC.md, append the following entry to `LOGS.md`:

```markdown
## <YYYY-MM-DD HH:MM:SS> — /spec completed
- Feature: <one-line summary of the feature>
- Source: <ticket-id, or "none">
- Key decisions: <any important choices made during the conversation>
- Next step: /design
```

See **LOGS.md format** in the project `README.md` for the full schema.

---

## Step 7 — Hand off to user

After writing both files, tell the user:

> "✅ `SPEC.md` is ready. Review it at `.claude/specs/<feature-name>/SPEC.md` and add any files to `/refs` if needed.
>
> When you're happy with it, run `/design <feature-name>` to move to the design phase."

---

## Workflow

This command is part of the feature track of the Ptah workflow:

```
/spec → /design → /implement → /code-review → /fix → /test → /document
```

Each command appends a session entry to `LOGS.md`. When resuming after a break, read `LOGS.md` first to understand where the feature stands.

Always wait for the user to review and confirm before suggesting the next step.
