#!/bin/bash
#
# .claude/ptah/hooks/ptah-continue-resolve.sh
#
# UserPromptExpansion hook for /continue (Ptah). Resolves the most
# recently active, not-yet-completed spec via filesystem mtime plus a
# cheap last-heading read, and injects the result as additionalContext
# so /continue can skip scanning entirely.
#
# Register on the "UserPromptExpansion" event in .claude/settings.json
# with matcher "continue" — see the "Optional acceleration hook" step
# in INSTALL.md for the JSON snippet, and verify the matcher name
# against the /hooks menu after installing.
#
# Requires: jq. /continue has no fallback if this hook isn't registered
# or doesn't fire — it depends on this script entirely. See INSTALL.md.

set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

SPECS_DIR=".claude/specs"

emit_none() {
  # $1 = message to relay to the user
  jq -n --arg msg "$1" '{
    hookSpecificOutput: {
      hookEventName: "UserPromptExpansion",
      additionalContext: ("Resolved /continue target: none. Tell the user: \"" + $msg + "\"")
    }
  }'
}

# No specs directory, or empty -> nothing to resolve
if [ ! -d "$SPECS_DIR" ] || [ -z "$(ls -A "$SPECS_DIR" 2>/dev/null)" ]; then
  emit_none "No specs found. Run /spec <name> to start one."
  exit 0
fi

# Sort LOGS.md files by mtime, newest first. Filesystem metadata only —
# no file content is read at this stage.
mapfile -t LOGS_FILES < <(ls -t "$SPECS_DIR"/*/LOGS.md 2>/dev/null || true)

if [ "${#LOGS_FILES[@]}" -eq 0 ]; then
  emit_none "No specs found. Run /spec <name> to start one."
  exit 0
fi

TARGET=""
TARGET_HEADING=""

for f in "${LOGS_FILES[@]}"; do
  # Last "## " heading line in this LOGS.md — a tail-style check, not a
  # full-file read.
  last_heading=$(grep '^## ' "$f" | tail -n 1 || true)
  [ -z "$last_heading" ] && continue

  # Skip fully completed specs; keep walking toward older ones.
  if echo "$last_heading" | grep -q -- '— /document completed'; then
    continue
  fi

  TARGET="$f"
  TARGET_HEADING="$last_heading"
  break
done

if [ -z "$TARGET" ]; then
  emit_none "Nothing in flight. Run /status --all to see completed work too, or /spec <name> to start something new."
  exit 0
fi

FOLDER=$(basename "$(dirname "$TARGET")")

jq -n --arg folder "$FOLDER" --arg heading "$TARGET_HEADING" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptExpansion",
    additionalContext: ("Resolved /continue target: " + $folder + ". Last LOGS.md entry: " + $heading + ". Use this folder directly as <feature-name> — do not re-scan .claude/specs/.")
  }
}'
