#!/usr/bin/env bash
# SessionEnd hook: writes a .md note summarising the work done in the session.
# Path: <NOTES_DIR>/<NOTES_SUMMARY_DIR>/YYYY-MM-DD/session_YYYY-MM-DD_HH-MM-SS_UTC.md
# (session end time, UTC; one directory per day).
# NOTES_DIR, NOTES_SUMMARY_DIR and NOTES_LANG come from notes-sync.conf.

# Never write a note for the session this script starts itself.
[ -n "$CLAUDE_SESSION_NOTE_CHILD" ] && exit 0

if [ "$1" = "--worker" ]; then
  prompt="From the Claude Code session transcript below, write a concise Markdown
note about the work that was done. Write the note in $NOTE_LANG_NAME. Use these
sections, translated into $NOTE_LANG_NAME: \"Goal\", \"What was done\" (bullet list
with concrete paths, commands and results), \"Final state / to do\". Return the
note body only, with no preamble."
  summary=$(CLAUDE_SESSION_NOTE_CHILD=1 timeout 300 claude -p --model haiku \
    --no-session-persistence --settings '{"disableAllHooks":true}' \
    "$prompt" < "$NOTE_CONVO" 2>/dev/null)
  if [ -z "$summary" ]; then
    summary="## $NOTE_L_FALLBACK
$(grep '^user: ' "$NOTE_CONVO" | sed 's/^user: /- /' | cut -c1-500)"
  fi
  {
    echo "# Claude Code session — $NOTE_TS"
    echo
    echo "- $NOTE_L_ENDED: $NOTE_TS"
    echo "- $NOTE_L_DIR: \`$NOTE_CWD\`"
    echo "- $NOTE_L_SESSION: \`$NOTE_SID\`"
    echo "- $NOTE_L_REASON: $NOTE_REASON"
    echo
    echo "$summary"
  } > "$NOTE_OUT"
  rm -f "$NOTE_CONVO"
  exit 0
fi

input=$(cat)
transcript=$(jq -r '.transcript_path // empty' <<<"$input")
session_id=$(jq -r '.session_id // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
reason=$(jq -r '.reason // empty' <<<"$input")
[ -f "$transcript" ] || exit 0

now=$(date -u +%s)
ts=$(date -u -d "@$now" +%Y-%m-%d_%H-%M-%S)
ts_human=$(date -u -d "@$now" '+%Y-%m-%d %H:%M:%S UTC')
day=$(date -u -d "@$now" +%Y-%m-%d)
# shellcheck source=../lib/config.sh
. "$(dirname "$(readlink -f "$0")")/../lib/config.sh" ""
notes_dir="${NOTES_DIR/#\~/$HOME}/$NOTES_SUMMARY_DIR/$day"
out="$notes_dir/session_${ts}_UTC.md"
mkdir -p "$notes_dir"

# Condensed transcript: user and Claude text plus tool calls.
convo=$(jq -r '
  select((.type == "user" or .type == "assistant") and (.isMeta != true))
  | .type as $who
  | .message.content
  | if type == "string" then "\($who): \(.)"
    else .[]
      | if .type == "text" then "\($who): \(.text)"
        elif .type == "tool_use" then "[tool \(.name)] \(.input | tostring | .[0:300])"
        else empty end
    end
' "$transcript" 2>/dev/null | tail -c 150000)

# Skip empty sessions (for example opened and closed right away).
grep -q '^user: ' <<<"$convo" || exit 0

# The summary runs in its own process session (setsid) so that it neither
# blocks the client shutting down nor dies with it.
convo_file=$(mktemp)
printf '%s\n' "$convo" > "$convo_file"
NOTE_OUT="$out" NOTE_TS="$ts_human" NOTE_CWD="$cwd" NOTE_SID="$session_id" \
NOTE_REASON="$reason" NOTE_CONVO="$convo_file" \
NOTE_LANG_NAME="$NOTES_LANG_NAME" NOTE_L_ENDED="$NS_L_ENDED" NOTE_L_DIR="$NS_L_DIR" \
NOTE_L_SESSION="$NS_L_SESSION" NOTE_L_REASON="$NS_L_REASON" NOTE_L_FALLBACK="$NS_L_FALLBACK" \
  setsid -f "$0" --worker </dev/null >/dev/null 2>&1
exit 0
