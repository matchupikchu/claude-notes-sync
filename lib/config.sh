# Wczytuje konfigurację notes-sync. Użycie: . lib/config.sh [plik]
# Pierwszeństwo: zmienne już ustawione (środowisko/CLI) > plik > domyślne.
_ns_env_dir="${NOTES_DIR-}" _ns_env_remote="${NOTES_REMOTE-}" _ns_env_branch="${NOTES_BRANCH-}"
_ns_conf="${1:-${NOTES_SYNC_CONFIG:-$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../notes-sync.conf}}"
# shellcheck disable=SC1090
[ -f "$_ns_conf" ] && . "$_ns_conf"
NOTES_DIR="${_ns_env_dir:-${NOTES_DIR:-$HOME/notatki-claude}}"
NOTES_REMOTE="${_ns_env_remote:-${NOTES_REMOTE:-}}"
NOTES_BRANCH="${_ns_env_branch:-${NOTES_BRANCH:-main}}"
NOTES_DIR="${NOTES_DIR%/}"
unset _ns_env_dir _ns_env_remote _ns_env_branch _ns_conf
