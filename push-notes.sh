#!/usr/bin/env bash
# Pushes the notes in NOTES_DIR to the remote repository NOTES_REMOTE.
#
# Steps:
#   1. on first run, initialise a git repo in the notes directory,
#   2. commit every new or changed note,
#   3. AutoGit-o-Matic fetches the state of the remote ([FETCH] section),
#   4. local commits are replayed onto origin/<branch> (rebase),
#   5. git push, then AutoGit-o-Matic --status reports the result.
#
# Configuration (highest precedence first):
#   1. options:   --notes-dir DIR  --remote URL  --branch NAME  --config FILE
#   2. variables: NOTES_DIR, NOTES_REMOTE, NOTES_BRANCH, NOTES_SYNC_CONFIG
#   3. file:      notes-sync.conf next to this script
#
# Other options: --dry-run  show what would happen, change nothing.
#                -h, --help

set -euo pipefail

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

usage() { sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; }

dry_run=0 conf_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --notes-dir) NOTES_DIR="${2:?--notes-dir needs a path}"; shift ;;
    --remote)    NOTES_REMOTE="${2:?--remote needs a URL}"; shift ;;
    --branch)    NOTES_BRANCH="${2:?--branch needs a name}"; shift ;;
    --config)    conf_file="${2:?--config needs a file}"; shift ;;
    --dry-run)   dry_run=1 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
  shift
done

# shellcheck source=lib/config.sh
. "$here/lib/config.sh" "$conf_file"
NOTES_DIR="${NOTES_DIR/#\~/$HOME}"
[ -n "$NOTES_REMOTE" ] || { echo "NOTES_REMOTE is not set (notes-sync.conf or --remote)." >&2; exit 1; }
autogit="$here/AutoGit-o-Matic/autogit-o-matic.sh"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/notes-sync"
log_file="$state_dir/autogit.log"

run() {
  if [ "$dry_run" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi
}

if [ ! -x "$autogit" ]; then
  echo "AutoGit-o-Matic is missing - run: git -C '$here' submodule update --init" >&2
  exit 1
fi
[ -d "$NOTES_DIR" ] || { echo "No such notes directory: $NOTES_DIR" >&2; exit 1; }
mkdir -p "$state_dir"

# 1. The notes repository.
if [ ! -d "$NOTES_DIR/.git" ]; then
  if [ "$dry_run" = 1 ]; then
    echo "[dry-run] $NOTES_DIR is not a repository yet. This would run:"
    echo "[dry-run]   git init -b $NOTES_BRANCH; git remote add origin $NOTES_REMOTE"
    echo "[dry-run]   git add -A; git commit ($(find "$NOTES_DIR" -type f | wc -l) files)"
    echo "[dry-run]   AutoGit-o-Matic [FETCH]; git push -u origin $NOTES_BRANCH"
    exit 0
  fi
  echo "Initialising a git repository in $NOTES_DIR"
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

# 2. Commit the new notes.
if [ -n "$(git -C "$NOTES_DIR" status --porcelain 2>/dev/null)" ]; then
  git -C "$NOTES_DIR" status --short
  run git -C "$NOTES_DIR" add -A
  run git -C "$NOTES_DIR" commit -q -m "Notes: $(date '+%Y-%m-%d %H:%M')"
else
  echo "No new notes to commit."
fi

# 3. AutoGit-o-Matic: fetch the remote notes repository.
config="$state_dir/autogit-o-matic.ini"
cat >"$config" <<INI
[SETTINGS]
log_format = TXT

[DEFAULTS]
max_depth = 0
timeout = 120

[FETCH]
path = $NOTES_DIR
INI

ag_flags=(--config "$config" --log-file "$log_file")
[ "$dry_run" = 1 ] && ag_flags+=(--dry-run)
if ! "$autogit" "${ag_flags[@]}"; then
  echo "AutoGit-o-Matic: fetch failed (log: $log_file)." >&2
  echo "Check access: ssh -T git@github.com" >&2
  exit 2
fi

[ "$dry_run" = 1 ] && { echo "[dry-run] git push -u origin $NOTES_BRANCH"; exit 0; }

# 4. Catch up with the remote branch (when it already exists).
if git -C "$NOTES_DIR" rev-parse --verify -q "origin/$NOTES_BRANCH" >/dev/null; then
  if ! git -C "$NOTES_DIR" rebase -q "origin/$NOTES_BRANCH"; then
    git -C "$NOTES_DIR" rebase --abort || true
    echo "Conflict while rebasing onto origin/$NOTES_BRANCH - resolve it by hand in $NOTES_DIR." >&2
    exit 2
  fi
fi

# 5. Push and report.
if ! git -C "$NOTES_DIR" rev-parse -q --verify HEAD >/dev/null; then
  echo "The notes repository has no commits yet - nothing to push."
  exit 0
fi
git -C "$NOTES_DIR" push -q -u origin "$NOTES_BRANCH"
echo "Pushed the notes to $NOTES_REMOTE ($NOTES_BRANCH)."
"$autogit" --config "$config" --status
