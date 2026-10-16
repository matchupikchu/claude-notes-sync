#!/usr/bin/env bash
# SessionEnd hook: zapisuje notatkę .md z podsumowaniem pracy wykonanej w sesji.
# Ścieżka: <NOTES_DIR>/podsumowania/RRRR-MM-DD/sesja_RRRR-MM-DD_GG-MM-SS_UTC.md
# (czas zakończenia sesji, UTC; każdy dzień w osobnym katalogu).
# NOTES_DIR pochodzi z notes-sync.conf (domyślnie ~/notatki-claude).

# Nie twórz notatek dla sesji uruchomionej przez sam ten skrypt.
[ -n "$CLAUDE_SESSION_NOTE_CHILD" ] && exit 0

if [ "$1" = "--worker" ]; then
  prompt='Na podstawie poniższego zapisu sesji Claude Code napisz po polsku zwięzłą notatkę w Markdown o wykonanej pracy. Sekcje: "## Cel", "## Co zrobiono" (lista punktów, konkretne ścieżki, polecenia i wyniki), "## Stan końcowy / do zrobienia". Zwróć wyłącznie treść notatki, bez wstępu.'
  summary=$(CLAUDE_SESSION_NOTE_CHILD=1 timeout 300 claude -p --model haiku \
    --no-session-persistence --settings '{"disableAllHooks":true}' \
    "$prompt" < "$NOTE_CONVO" 2>/dev/null)
  if [ -z "$summary" ]; then
    summary="## Polecenia użytkownika (podsumowanie AI niedostępne)
$(grep '^user: ' "$NOTE_CONVO" | sed 's/^user: /- /' | cut -c1-500)"
  fi
  {
    echo "# Sesja Claude Code — $NOTE_TS"
    echo
    echo "- Zakończenie: $NOTE_TS"
    echo "- Katalog: \`$NOTE_CWD\`"
    echo "- Sesja: \`$NOTE_SID\`"
    echo "- Powód zakończenia: $NOTE_REASON"
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
notes_dir="${NOTES_DIR/#\~/$HOME}/podsumowania/$day"
out="$notes_dir/sesja_${ts}_UTC.md"
mkdir -p "$notes_dir"

# Skrócony zapis rozmowy: teksty użytkownika i Claude'a + wywołania narzędzi.
convo=$(jq -r '
  select((.type == "user" or .type == "assistant") and (.isMeta != true))
  | .type as $who
  | .message.content
  | if type == "string" then "\($who): \(.)"
    else .[]
      | if .type == "text" then "\($who): \(.text)"
        elif .type == "tool_use" then "[narzędzie \(.name)] \(.input | tostring | .[0:300])"
        else empty end
    end
' "$transcript" 2>/dev/null | tail -c 150000)

# Pomiń puste sesje (np. otwarte i od razu zamknięte).
grep -q '^user: ' <<<"$convo" || exit 0

# Podsumowanie generujemy w osobnej sesji procesów (setsid), żeby nie blokować
# zamykania aplikacji i żeby proces przeżył jej zakończenie.
convo_file=$(mktemp)
printf '%s\n' "$convo" > "$convo_file"
NOTE_OUT="$out" NOTE_TS="$ts_human" NOTE_CWD="$cwd" NOTE_SID="$session_id" \
NOTE_REASON="$reason" NOTE_CONVO="$convo_file" \
  setsid -f "$0" --worker </dev/null >/dev/null 2>&1
exit 0
