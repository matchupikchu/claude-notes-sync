#!/usr/bin/env bash
# Installs notes-sync: fetches the AutoGit-o-Matic submodule, links the
# SessionEnd hook and the /summarize-day skill into ~/.claude, and the
# push-notes command into ~/.local/bin.
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

git -C "$here" submodule update --init
chmod +x "$here/push-notes.sh" "$here/notes-day.sh" "$here/hooks/session-note.sh"

mkdir -p "$HOME/.claude/hooks" "$HOME/.local/bin" "$HOME/.claude/skills"
ln -sfn "$here/hooks/session-note.sh" "$HOME/.claude/hooks/session-note.sh"
ln -sfn "$here/push-notes.sh" "$HOME/.local/bin/push-notes"
ln -sfn "$here/skills/summarize-day" "$HOME/.claude/skills/summarize-day"

# The skill used to be called podsumuj-dzien; drop the dangling link it left.
legacy="$HOME/.claude/skills/podsumuj-dzien"
if [ -L "$legacy" ] && [ ! -e "$legacy" ]; then
  rm -f "$legacy"
  echo "Removed the stale symlink $legacy (the skill is now /summarize-day)."
fi

echo "Done. Hook: ~/.claude/hooks/session-note.sh, command: push-notes"
echo "Make sure ~/.claude/settings.json has a SessionEnd hook pointing at that file."
