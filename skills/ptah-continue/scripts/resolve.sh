#!/bin/bash
#
# .claude/skills/ptah-continue/scripts/resolve.sh
#
# Resolves the target for /ptah-continue: the most recently active,
# not-yet-completed spec, found via filesystem mtime plus a cheap
# last-heading read. Runs as the skill loads; its stdout is injected into
# the skill's instructions, which parse the "Resolved /ptah-continue
# target:" prefix.
#
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

SPECS_DIR=".claude/specs"

emit_none() {
  # $1 = message to relay to the user
  printf 'Resolved /ptah-continue target: none. Tell the user: "%s"\n' "$1"
}

# No specs directory, or empty -> nothing to resolve
if [ ! -d "$SPECS_DIR" ] || [ -z "$(ls -A "$SPECS_DIR" 2>/dev/null)" ]; then
  emit_none "No specs found. Run /ptah-spec <name> to start one."
  exit 0
fi

# Sort LOGS.md files by mtime, newest first. Filesystem metadata only —
# no file content is read at this stage.
mapfile -t LOGS_FILES < <(ls -t "$SPECS_DIR"/*/LOGS.md 2>/dev/null || true)

if [ "${#LOGS_FILES[@]}" -eq 0 ]; then
  emit_none "No specs found. Run /ptah-spec <name> to start one."
  exit 0
fi

TARGET=""
TARGET_HEADING=""

for f in "${LOGS_FILES[@]}"; do
  # Last "## " heading line in this LOGS.md — a tail-style check, not a
  # full-file read.
  last_heading=$(grep '^## ' "$f" | tail -n 1 || true)
  [ -z "$last_heading" ] && continue

  # Skip fully completed specs; keep walking toward older ones. Entries
  # written with the unprefixed command name (/document) count too — see
  # logs-format.md.
  if echo "$last_heading" | grep -qE -- '— /(ptah-)?document completed'; then
    continue
  fi

  TARGET="$f"
  TARGET_HEADING="$last_heading"
  break
done

if [ -z "$TARGET" ]; then
  emit_none "Nothing in flight. Run /ptah-status --all to see completed work too, or /ptah-spec <name> to start something new."
  exit 0
fi

FOLDER=$(basename "$(dirname "$TARGET")")

printf 'Resolved /ptah-continue target: %s. Last LOGS.md entry: %s. Use this folder directly as <feature-name> — do not re-scan .claude/specs/.\n' "$FOLDER" "$TARGET_HEADING"
