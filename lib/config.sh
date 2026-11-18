# Loads the notes-sync configuration. Usage: . lib/config.sh [file]
# Precedence: already-set variables (environment/CLI) > file > defaults.
_ns_env_dir="${NOTES_DIR-}" _ns_env_remote="${NOTES_REMOTE-}" _ns_env_branch="${NOTES_BRANCH-}" _ns_env_summary="${NOTES_SUMMARY_DIR-}" _ns_env_lang="${NOTES_LANG-}"
_ns_conf="${1:-${NOTES_SYNC_CONFIG:-$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../notes-sync.conf}}"
# shellcheck disable=SC1090
[ -f "$_ns_conf" ] && . "$_ns_conf"
NOTES_DIR="${_ns_env_dir:-${NOTES_DIR:-$HOME/notatki-claude}}"
NOTES_REMOTE="${_ns_env_remote:-${NOTES_REMOTE:-}}"
NOTES_BRANCH="${_ns_env_branch:-${NOTES_BRANCH:-main}}"
NOTES_SUMMARY_DIR="${_ns_env_summary:-${NOTES_SUMMARY_DIR:-podsumowania}}"
NOTES_LANG="${_ns_env_lang:-${NOTES_LANG:-pl}}"
NOTES_DIR="${NOTES_DIR%/}"
# The summary directory is relative to NOTES_DIR: no leading or trailing "/".
NOTES_SUMMARY_DIR="${NOTES_SUMMARY_DIR#/}" NOTES_SUMMARY_DIR="${NOTES_SUMMARY_DIR%/}"
case "/$NOTES_SUMMARY_DIR/" in
  //|*/../*) echo "notes-sync: invalid NOTES_SUMMARY_DIR, falling back to 'podsumowania'" >&2
            NOTES_SUMMARY_DIR="podsumowania" ;;
esac

# Spell the note language out for the model, and keep the fixed labels in the
# note consistent with it. An unknown value is passed through verbatim.
case "$NOTES_LANG" in
  pl|PL|pl_PL*|polish|Polish)
    NOTES_LANG_NAME="Polish"
    NS_L_ENDED="Zakończenie" NS_L_DIR="Katalog" NS_L_SESSION="Sesja" NS_L_REASON="Powód zakończenia"
    NS_L_FALLBACK="Polecenia użytkownika (podsumowanie AI niedostępne)" ;;
  en|EN|en_*|english|English)
    NOTES_LANG_NAME="English"
    NS_L_ENDED="Ended" NS_L_DIR="Directory" NS_L_SESSION="Session" NS_L_REASON="Exit reason"
    NS_L_FALLBACK="User prompts (AI summary unavailable)" ;;
  *)
    NOTES_LANG_NAME="$NOTES_LANG"
    NS_L_ENDED="Ended" NS_L_DIR="Directory" NS_L_SESSION="Session" NS_L_REASON="Exit reason"
    NS_L_FALLBACK="User prompts (AI summary unavailable)" ;;
esac
unset _ns_env_dir _ns_env_remote _ns_env_branch _ns_env_summary _ns_env_lang _ns_conf
