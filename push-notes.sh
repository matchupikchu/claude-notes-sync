#!/usr/bin/env bash
# Wysyła notatki z katalogu NOTES_DIR do zdalnego repozytorium NOTES_REMOTE.
#
# Kroki:
#   1. przy pierwszym uruchomieniu zakłada repo git w katalogu notatek,
#   2. commituje wszystkie nowe/zmienione notatki,
#   3. AutoGit-o-Matic pobiera stan zdalnego repo (sekcja [FETCH]),
#   4. lokalne commity są przenoszone na origin/<gałąź> (rebase),
#   5. git push, a na koniec AutoGit-o-Matic --status pokazuje stan.
#
# Konfiguracja (od najważniejszej):
#   1. opcje:   --notes-dir DIR  --remote URL  --branch NAZWA  --config PLIK
#   2. zmienne: NOTES_DIR, NOTES_REMOTE, NOTES_BRANCH, NOTES_SYNC_CONFIG
#   3. plik:    notes-sync.conf obok skryptu
#
# Inne opcje: --dry-run  pokaż, co zostałoby zrobione, nic nie zmieniaj.
#             -h, --help

set -euo pipefail

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

usage() { sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; }

dry_run=0 conf_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --notes-dir) NOTES_DIR="${2:?--notes-dir wymaga ścieżki}"; shift ;;
    --remote)    NOTES_REMOTE="${2:?--remote wymaga adresu URL}"; shift ;;
    --branch)    NOTES_BRANCH="${2:?--branch wymaga nazwy}"; shift ;;
    --config)    conf_file="${2:?--config wymaga pliku}"; shift ;;
    --dry-run)   dry_run=1 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Nieznana opcja: $1 (zobacz --help)" >&2; exit 1 ;;
  esac
  shift
done

# shellcheck source=lib/config.sh
. "$here/lib/config.sh" "$conf_file"
NOTES_DIR="${NOTES_DIR/#\~/$HOME}"
[ -n "$NOTES_REMOTE" ] || { echo "Nie ustawiono NOTES_REMOTE (notes-sync.conf lub --remote)." >&2; exit 1; }
autogit="$here/AutoGit-o-Matic/autogit-o-matic.sh"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/notes-sync"
log_file="$state_dir/autogit.log"

run() {
  if [ "$dry_run" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi
}

if [ ! -x "$autogit" ]; then
  echo "Brak AutoGit-o-Matic — uruchom: git -C '$here' submodule update --init" >&2
  exit 1
fi
[ -d "$NOTES_DIR" ] || { echo "Brak katalogu notatek: $NOTES_DIR" >&2; exit 1; }
mkdir -p "$state_dir"

# 1. Repo notatek.
if [ ! -d "$NOTES_DIR/.git" ]; then
  if [ "$dry_run" = 1 ]; then
    echo "[dry-run] $NOTES_DIR nie jest jeszcze repozytorium. Zostałoby wykonane:"
    echo "[dry-run]   git init -b $NOTES_BRANCH; git remote add origin $NOTES_REMOTE"
    echo "[dry-run]   git add -A; git commit ($(find "$NOTES_DIR" -type f | wc -l) plików)"
    echo "[dry-run]   AutoGit-o-Matic [FETCH]; git push -u origin $NOTES_BRANCH"
    exit 0
  fi
  echo "Zakładam repozytorium git w $NOTES_DIR"
  run git -C "$NOTES_DIR" init -q -b "$NOTES_BRANCH"
fi
if [ -d "$NOTES_DIR/.git" ]; then
  if git -C "$NOTES_DIR" remote get-url origin >/dev/null 2>&1; then
    [ "$(git -C "$NOTES_DIR" remote get-url origin)" = "$NOTES_REMOTE" ] \
      || run git -C "$NOTES_DIR" remote set-url origin "$NOTES_REMOTE"
  else
    run git -C "$NOTES_DIR" remote add origin "$NOTES_REMOTE"
  fi
fi

# 2. Commit nowych notatek.
if [ -n "$(git -C "$NOTES_DIR" status --porcelain 2>/dev/null)" ]; then
  git -C "$NOTES_DIR" status --short
  run git -C "$NOTES_DIR" add -A
  run git -C "$NOTES_DIR" commit -q -m "Notatki: $(date '+%Y-%m-%d %H:%M')"
else
  echo "Brak nowych notatek do commitu."
fi

# 3. AutoGit-o-Matic: fetch zdalnego repo notatek.
config="$state_dir/autogit-o-matic.ini"
cat >"$config" <<EOF
[SETTINGS]
log_format = TXT

[DEFAULTS]
max_depth = 0
timeout = 120

[FETCH]
path = $NOTES_DIR
EOF

ag_flags=(--config "$config" --log-file "$log_file")
[ "$dry_run" = 1 ] && ag_flags+=(--dry-run)
if ! "$autogit" "${ag_flags[@]}"; then
  echo "AutoGit-o-Matic: fetch się nie powiódł (log: $log_file)." >&2
  echo "Sprawdź dostęp: ssh -T git@github.com" >&2
  exit 2
fi

[ "$dry_run" = 1 ] && { echo "[dry-run] git push -u origin $NOTES_BRANCH"; exit 0; }

# 4. Dopasowanie do zdalnej gałęzi (jeśli już istnieje).
if git -C "$NOTES_DIR" rev-parse --verify -q "origin/$NOTES_BRANCH" >/dev/null; then
  if ! git -C "$NOTES_DIR" rebase -q "origin/$NOTES_BRANCH"; then
    git -C "$NOTES_DIR" rebase --abort || true
    echo "Konflikt przy rebase na origin/$NOTES_BRANCH — rozwiąż ręcznie w $NOTES_DIR." >&2
    exit 2
  fi
fi

# 5. Push i stan końcowy.
if ! git -C "$NOTES_DIR" rev-parse -q --verify HEAD >/dev/null; then
  echo "Repo notatek nie ma jeszcze żadnego commitu — nic do wysłania."
  exit 0
fi
git -C "$NOTES_DIR" push -q -u origin "$NOTES_BRANCH"
echo "Wysłano notatki do $NOTES_REMOTE ($NOTES_BRANCH)."
"$autogit" --config "$config" --status
