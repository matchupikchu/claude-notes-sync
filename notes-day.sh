#!/usr/bin/env bash
# Wypisuje notatki z sesji z jednego dnia (dla skilla /podsumuj-dzien).
# Użycie: notes-day.sh [RRRR-MM-DD]   (domyślnie dzisiaj, UTC — tak jak hook
# nazywa katalogi dni). Czyta NOTES_DIR i NOTES_SUMMARY_DIR z notes-sync.conf.
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# shellcheck source=lib/config.sh
. "$here/lib/config.sh" ""

d="${1:-$(date -u +%F)}"
if ! [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Niepoprawna data: '$d' (oczekiwano RRRR-MM-DD)" >&2
  exit 1
fi
day_dir="${NOTES_DIR/#\~/$HOME}/$NOTES_SUMMARY_DIR/$d"

echo "Dzień (UTC): $d"
echo "Katalog dnia: $day_dir"
echo "Plik podsumowania: $day_dir/podsumowanie_$d.md"

shopt -s nullglob
files=("$day_dir"/sesja_*.md)
if [ ${#files[@]} -eq 0 ]; then
  echo
  echo "BRAK NOTATEK Z TEGO DNIA"
  exit 0
fi
for f in "${files[@]}"; do
  echo
  echo "=================== $(basename "$f") ==================="
  cat "$f"
done
