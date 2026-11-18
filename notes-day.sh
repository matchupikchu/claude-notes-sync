#!/usr/bin/env bash
# Prints the session notes of one day (used by the /summarize-day skill).
# Usage: notes-day.sh [YYYY-MM-DD]   (defaults to today, UTC - the same clock
# the hook names day directories with). Reads NOTES_DIR, NOTES_SUMMARY_DIR and
# NOTES_LANG from notes-sync.conf.
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# shellcheck source=lib/config.sh
. "$here/lib/config.sh" ""

d="${1:-$(date -u +%F)}"
if ! [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Invalid date: '$d' (expected YYYY-MM-DD)" >&2
  exit 1
fi
day_dir="${NOTES_DIR/#\~/$HOME}/$NOTES_SUMMARY_DIR/$d"

echo "Day (UTC): $d"
echo "Day directory: $day_dir"
echo "Summary file: $day_dir/summary_$d.md"
echo "Summary language: $NOTES_LANG_NAME"
[ -f "$day_dir/podsumowanie_$d.md" ] &&
  echo "Legacy summary present (pre-rename): $day_dir/podsumowanie_$d.md"

# Both naming schemes are read: session_* (current) and sesja_* (pre-rename),
# sorted by the timestamp that follows the prefix.
mapfile -t files < <(
  shopt -s nullglob
  for f in "$day_dir"/session_*.md "$day_dir"/sesja_*.md; do
    b="${f##*/}"
    printf '%s\t%s\n' "${b#*_}" "$f"
  done | sort | cut -f2-
)
if [ ${#files[@]} -eq 0 ]; then
  echo
  echo "NO NOTES FOR THIS DAY"
  exit 0
fi
for f in "${files[@]}"; do
  echo
  echo "=================== $(basename "$f") ==================="
  cat "$f"
done
