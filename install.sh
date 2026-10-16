#!/usr/bin/env bash
# Instaluje notes-sync: pobiera submoduł AutoGit-o-Matic, podpina hook
# SessionEnd do ~/.claude/hooks i dodaje polecenie push-notes do ~/.local/bin.
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

git -C "$here" submodule update --init
chmod +x "$here/push-notes.sh" "$here/hooks/session-note.sh"

mkdir -p "$HOME/.claude/hooks" "$HOME/.local/bin"
ln -sfn "$here/hooks/session-note.sh" "$HOME/.claude/hooks/session-note.sh"
ln -sfn "$here/push-notes.sh" "$HOME/.local/bin/push-notes"

echo "Gotowe. Hook: ~/.claude/hooks/session-note.sh, polecenie: push-notes"
echo "Upewnij się, że ~/.claude/settings.json ma hook SessionEnd wskazujący na ten plik."
