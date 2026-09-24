#!/usr/bin/env bash
#
# install-ptah.sh — install the Ptah spec-driven workflow into a project's .claude/ folder.
#
# Run this from a checkout of ptah-workflow-claude (or point --source-path at one).
# The repo ships a flat layout (commands/, agents/, hooks/, README.md, RULES.md, ...)
# but Ptah expects a reshaped layout inside the target project:
#
#   .claude/commands/ptah/*.md                   <- commands/*.md
#   .claude/agents/ptah/*.md                     <- agents/*.md
#   .claude/ptah/README.md                       <- README.md
#   .claude/ptah/RULES.md                        <- RULES.md
#   .claude/ptah/guides/logs-format.md           <- logs-format.md
#   .claude/ptah/guides/knowledge-format.md      <- knowledge-format.md
#   .claude/ptah/ptah_knowledge.py               <- ptah_knowledge.py
#   .claude/ptah/ptah.example.yml                <- ptah_example.yml
#   .claude/ptah/hooks/ptah-continue-resolve.sh  <- hooks/ptah-continue-resolve.sh
#   CLAUDE.md                                    <- Ptah section merged in from CLAUDE-snippet.md
#
# Safe to re-run: existing files are left alone unless --force is passed.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-ptah.sh [options]

Options:
  -p, --project-path PATH    Root of the project to install Ptah into.
                             Default: the current directory.
  -s, --source-path PATH     Root of the ptah-workflow-claude checkout.
                             Default: the folder this script lives in.
  -c, --create-config        Also copy ptah_example.yml to ptah.yml (the file the
                             commands read for JIRA/Linear/GitHub wiring and /fix
                             defaults). Skipped by default since it's optional and
                             project-specific.
  -r, --register-continue-hook
                             Also wire the /continue UserPromptExpansion hook into
                             .claude/settings.local.json. Merges into an existing
                             "hooks" key and leaves every other key untouched.
                             Requires jq.
  -f, --force                Overwrite files that already exist at the destination.
  -h, --help                 Show this help.

Examples:
  ./install-ptah.sh -p ~/code/my-app
  ./install-ptah.sh -p ~/code/my-app -c -r -f
EOF
}

if [[ -t 1 ]]; then
  C_CYAN=$'\e[36m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_ORANGE=$'\e[38;5;208m'; C_RESET=$'\e[0m'
else
  C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_ORANGE=''; C_RESET=''
fi

step() { printf '%s==> %s%s\n' "$C_CYAN" "$1" "$C_RESET"; }
ok()   { printf '%s    OK    %s%s\n' "$C_GREEN" "$1" "$C_RESET"; }
skip() { printf '%s    SKIP  %s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }
warn() { printf '%s    WARN  %s%s\n' "$C_ORANGE" "$1" "$C_RESET"; }
die()  { printf 'install-ptah.sh: %s\n' "$1" >&2; exit 1; }

PROJECT_PATH=$PWD
SOURCE_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CREATE_CONFIG=0
REGISTER_HOOK=0
FORCE=0

while (( $# )); do
  case $1 in
    -p|--project-path) [[ $# -ge 2 ]] || die "$1 needs a value"; PROJECT_PATH=$2; shift 2 ;;
    --project-path=*)  PROJECT_PATH=${1#*=}; shift ;;
    -s|--source-path)  [[ $# -ge 2 ]] || die "$1 needs a value"; SOURCE_PATH=$2; shift 2 ;;
    --source-path=*)   SOURCE_PATH=${1#*=}; shift ;;
    -c|--create-config) CREATE_CONFIG=1; shift ;;
    -r|--register-continue-hook) REGISTER_HOOK=1; shift ;;
    -f|--force)        FORCE=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
done

# Copy one file, creating parent dirs. Returns 0 if copied, 1 if skipped because
# the destination already exists and --force wasn't passed.
copy_ptah_file() {
  local from=$1 to=$2
  mkdir -p "$(dirname "$to")"
  if [[ -e $to && $FORCE -eq 0 ]]; then
    skip "$to (already exists, use --force to overwrite)"
    return 1
  fi
  cp -f "$from" "$to"
  ok "$to"
}

# ---------------------------------------------------------------------------
# 0. Validate source + target
# ---------------------------------------------------------------------------
step "Validating source checkout at $SOURCE_PATH"

REQUIRED_SOURCE_ITEMS=(
  commands
  agents/ptah-code-reviewer.md
  agents/ptah-reviewer.md
  hooks/ptah-continue-resolve.sh
  README.md
  RULES.md
  logs-format.md
  knowledge-format.md
  ptah_knowledge.py
  ptah_example.yml
  CLAUDE-snippet.md
)
for item in "${REQUIRED_SOURCE_ITEMS[@]}"; do
  [[ -e $SOURCE_PATH/$item ]] ||
    die "expected '$item' under --source-path ($SOURCE_PATH) but did not find it. Pass --source-path pointing at a ptah-workflow-claude checkout."
done

[[ -d $PROJECT_PATH ]] || die "project path '$PROJECT_PATH' does not exist."
PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd)
SOURCE_PATH=$(cd "$SOURCE_PATH" && pwd)
CLAUDE_DIR=$PROJECT_PATH/.claude

# Fail before touching anything, rather than leaving a half-finished install.
if (( REGISTER_HOOK )) && ! command -v jq >/dev/null 2>&1; then
  die "--register-continue-hook needs jq to edit settings.local.json (the hook itself needs jq at runtime too). Install jq and re-run."
fi

ok "Source: $SOURCE_PATH"
ok "Target: $PROJECT_PATH"

shopt -s nullglob

# ---------------------------------------------------------------------------
# 1. Slash commands -> .claude/commands/ptah/
# ---------------------------------------------------------------------------
step "Installing slash commands to .claude/commands/ptah/"

for f in "$SOURCE_PATH"/commands/*.md; do
  copy_ptah_file "$f" "$CLAUDE_DIR/commands/ptah/$(basename "$f")" || true
done

# ---------------------------------------------------------------------------
# 2. Subagents -> .claude/agents/ptah/
# ---------------------------------------------------------------------------
step "Installing subagents to .claude/agents/ptah/"

for f in "$SOURCE_PATH"/agents/*.md; do
  copy_ptah_file "$f" "$CLAUDE_DIR/agents/ptah/$(basename "$f")" || true
done

# ---------------------------------------------------------------------------
# 3. Ptah's own docs + config -> .claude/ptah/
# ---------------------------------------------------------------------------
step "Installing Ptah docs and config to .claude/ptah/"

PTAH_DIR=$CLAUDE_DIR/ptah
copy_ptah_file "$SOURCE_PATH/README.md"           "$PTAH_DIR/README.md"                 || true
copy_ptah_file "$SOURCE_PATH/RULES.md"            "$PTAH_DIR/RULES.md"                  || true
copy_ptah_file "$SOURCE_PATH/logs-format.md"      "$PTAH_DIR/guides/logs-format.md"      || true
copy_ptah_file "$SOURCE_PATH/knowledge-format.md" "$PTAH_DIR/guides/knowledge-format.md" || true
copy_ptah_file "$SOURCE_PATH/ptah_knowledge.py"   "$PTAH_DIR/ptah_knowledge.py"          || true
copy_ptah_file "$SOURCE_PATH/ptah_example.yml"    "$PTAH_DIR/ptah.example.yml"           || true

if (( CREATE_CONFIG )); then
  if copy_ptah_file "$SOURCE_PATH/ptah_example.yml" "$PTAH_DIR/ptah.yml"; then
    ok "edit ptah.yml to wire up JIRA/Linear/GitHub, or set /fix defaults"
  fi
else
  skip "ptah.yml not created (pass --create-config to generate it from the template)"
fi

# ---------------------------------------------------------------------------
# 4. /continue hook script -> .claude/ptah/hooks/
# ---------------------------------------------------------------------------
step "Installing the /continue hook script"

HOOK_DEST=$PTAH_DIR/hooks/ptah-continue-resolve.sh
if copy_ptah_file "$SOURCE_PATH/hooks/ptah-continue-resolve.sh" "$HOOK_DEST"; then
  # A checkout made with CRLF line endings (e.g. on Windows) would make bash
  # reject the hook, so normalize it to LF.
  tr -d '\r' < "$HOOK_DEST" > "$HOOK_DEST.tmp" && mv "$HOOK_DEST.tmp" "$HOOK_DEST"
fi
chmod +x "$HOOK_DEST"

# Filesystems that don't keep a real +x bit (NTFS via WSL/Git Bash) lose it, so
# also set it in git's index, where it survives for teammates on Unix.
REL_HOOK=.claude/ptah/hooks/ptah-continue-resolve.sh
if command -v git >/dev/null 2>&1 && git -C "$PROJECT_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "$PROJECT_PATH" update-index --add --chmod=+x -- "$REL_HOOK" >/dev/null 2>&1; then
    ok "Marked $REL_HOOK executable in the git index"
  else
    warn "git update-index failed for $REL_HOOK - set it manually with: git update-index --chmod=+x $REL_HOOK"
  fi
else
  warn "Not a git repo (or git not on PATH) - the executable bit on $REL_HOOK isn't tracked; run 'chmod +x $REL_HOOK' wherever teammates check this out."
fi

# ---------------------------------------------------------------------------
# 4b. Bootstrap the knowledge base (requires python3, stdlib only)
# ---------------------------------------------------------------------------
step "Bootstrapping the knowledge base"

# ptah_knowledge.py resolves its paths relative to the project root, so run it from there.
PY_HINT="python3 .claude/ptah/ptah_knowledge.py init"
if command -v python3 >/dev/null 2>&1; then
  if (cd "$PROJECT_PATH" && python3 "$PTAH_DIR/ptah_knowledge.py" init >/dev/null); then
    ok "Initialized .claude/ptah/knowledge/knowledge.db"
  else
    warn "$PY_HINT failed - run it manually once python3 is confirmed working."
  fi
else
  warn "python3 not found on PATH - /learn and /recall need it. Every other Ptah command still works without it; run '$PY_HINT' once python3 is installed."
fi

# ---------------------------------------------------------------------------
# 5. (Optional) Register the /continue hook in .claude/settings.local.json
# ---------------------------------------------------------------------------
if (( REGISTER_HOOK )); then
  step "Registering the /continue hook in .claude/settings.local.json"

  SETTINGS=$CLAUDE_DIR/settings.local.json
  # Single-quoted on purpose: ${CLAUDE_PROJECT_DIR} must reach settings.json literally,
  # for Claude Code to expand.
  # shellcheck disable=SC2016
  HOOK_ENTRY='{"matcher":"continue","hooks":[{"type":"command","command":"${CLAUDE_PROJECT_DIR}/.claude/ptah/hooks/ptah-continue-resolve.sh","args":[]}]}'

  if [[ -e $SETTINGS ]]; then
    jq -e . "$SETTINGS" >/dev/null 2>&1 || die "$SETTINGS is not valid JSON - fix it or remove it, then re-run."

    if jq -e '(.hooks.UserPromptExpansion // []) | any(.matcher == "continue")' "$SETTINGS" >/dev/null && (( ! FORCE )); then
      skip "settings.local.json already has a 'continue' matcher (use --force to replace it)"
    else
      jq --argjson entry "$HOOK_ENTRY" '
        .hooks //= {}
        | .hooks.UserPromptExpansion //= []
        | .hooks.UserPromptExpansion |= (map(select(.matcher != "continue")) + [$entry])
      ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
      ok "$SETTINGS (merged)"
    fi
  else
    mkdir -p "$CLAUDE_DIR"
    jq -n --argjson entry "$HOOK_ENTRY" '{hooks: {UserPromptExpansion: [$entry]}}' > "$SETTINGS"
    ok "$SETTINGS (created)"
  fi

  warn "Verify the matcher: open the /hooks menu in Claude Code after installing and confirm it fires on /continue. Adjust 'matcher' in settings.local.json if the menu shows a different name."
else
  skip "/continue hook not registered in settings.local.json (pass --register-continue-hook to wire it up; /continue has no fallback without it)"
fi

# ---------------------------------------------------------------------------
# 6. Merge the CLAUDE.md snippet
# ---------------------------------------------------------------------------
step "Merging the Ptah snippet into CLAUDE.md"

# The block to insert is the first fenced ```markdown block in CLAUDE-snippet.md.
# (Command substitution also trims trailing blank lines.)
BLOCK=$(tr -d '\r' < "$SOURCE_PATH/CLAUDE-snippet.md" | awk '
  !in_block && /^```markdown[[:space:]]*$/ { in_block = 1; next }
  in_block && /^```[[:space:]]*$/          { exit }
  in_block
')
[[ -n $BLOCK ]] || die "could not find the fenced markdown block inside CLAUDE-snippet.md."

CLAUDE_MD=$PROJECT_PATH/CLAUDE.md
if [[ -e $CLAUDE_MD ]]; then
  if grep -q '## Ptah workflow' "$CLAUDE_MD"; then
    skip "CLAUDE.md already has a '## Ptah workflow' section - left untouched"
  else
    {
      if grep -q '[^[:space:]]' "$CLAUDE_MD"; then
        # Finish an unterminated last line, then leave one blank line before the block.
        [[ $(tail -c1 "$CLAUDE_MD" | wc -l) -eq 0 ]] && printf '\n'
        printf '\n'
      fi
      printf '%s\n' "$BLOCK"
    } >> "$CLAUDE_MD"
    ok "$CLAUDE_MD (appended Ptah section)"
  fi
else
  printf '%s\n' "$BLOCK" > "$CLAUDE_MD"
  ok "$CLAUDE_MD (created)"
fi

# ---------------------------------------------------------------------------
# 7. Summary
# ---------------------------------------------------------------------------
printf '\n%sPtah installed.%s\n\n' "$C_GREEN" "$C_RESET"
echo "Next steps:"
echo "  1. Restart your Claude Code session so the new commands, subagents, and CLAUDE.md rules load."
echo "  2. Run /status   -> should say 'No specs found.'"
echo "  3. Run /spec <your-first-feature> to start."
if (( ! CREATE_CONFIG )); then
  echo "  4. (optional) Copy .claude/ptah/ptah.example.yml to ptah.yml to wire up JIRA/Linear/GitHub or set /fix defaults."
fi
if (( REGISTER_HOOK )); then
  echo "  5. Open the /hooks menu in Claude Code and confirm the 'continue' matcher actually fires."
else
  echo "  5. (optional) Re-run with --register-continue-hook if you want /continue to work without typing a spec number."
fi
echo "  6. Try /learn to capture something, then /recall to look it up - confirms the knowledge base is wired up."
