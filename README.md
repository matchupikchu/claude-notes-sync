# notes-sync

Notes from Claude Code sessions: written automatically at the end of every session
and pushed to GitHub with [AutoGit-o-Matic](https://github.com/FPGArtktic/AutoGit-o-Matic).

A `SessionEnd` hook condenses the transcript, has Haiku summarise it, and drops a
Markdown note into a per-day directory. `push-notes` commits those notes and pushes
them to a repository of your own.

Setting up the whole Claude Code environment this repository is a part of (Claude Code,
the jCodeMunch and WEFT MCP servers, RAG over PDFs, these notes): [SETUP.md](SETUP.md),
written as a runbook an agent can execute on a fresh machine.

## Contents

| file | what it does |
|------|--------------|
| `hooks/session-note.sh` | `SessionEnd` hook: after each session writes a summary (Haiku) to `<NOTES_DIR>/<NOTES_SUMMARY_DIR>/YYYY-MM-DD/session_<UTC time>_UTC.md` |
| `push-notes.sh` | commits the notes in `NOTES_DIR`, fetches through AutoGit-o-Matic, rebases onto `origin/<branch>` and runs `git push` |
| `AutoGit-o-Matic/` | submodule, pinned to `v3.0.0` |
| `notes-sync.conf` | configuration: notes directory, summary directory, note language, remote URL, branch |
| `lib/config.sh` | shared configuration loading (hook and push) |
| `skills/summarize-day/` | the `/summarize-day [YYYY-MM-DD]` skill: a summary of one day, written into that day's directory as `summary_<day>.md` |
| `notes-day.sh` | prints the notes of a single day (used by the skill) |
| `install.sh` | fetches the submodule, links the hook, the skill and the `push-notes` command |

## Layout of the notes

```
~/notatki-claude/              (a separate git repo, pushed to your remote)
└── podsumowania/              (name: NOTES_SUMMARY_DIR)
    ├── 2026-10-16/
    │   ├── session_2026-10-16_11-21-23_UTC.md
    │   ├── session_2026-10-16_11-32-07_UTC.md
    │   └── summary_2026-10-16.md      (/summarize-day)
    └── 2026-10-17/
        └── ...
```

The directory names above are the defaults shipped in `notes-sync.conf` and are
only defaults — point them anywhere you like.

## Usage

```bash
./install.sh          # once
push-notes            # push the notes
push-notes --dry-run  # only show what would happen
push-notes --help
```

Then add the hook to `~/.claude/settings.json` — `install.sh` links the script but
does not edit your settings:

```json
"SessionEnd": [
  { "matcher": "",
    "hooks": [{ "type": "command", "command": "~/.claude/hooks/session-note.sh", "timeout": 30 }] }
]
```

## Configuration

Edit `notes-sync.conf`:

```sh
NOTES_DIR="$HOME/notatki-claude"
NOTES_SUMMARY_DIR="podsumowania"
NOTES_LANG="pl"
NOTES_REMOTE="git@github.com:you/your-notes.git"
NOTES_BRANCH="main"
```

`NOTES_SUMMARY_DIR` is a directory name inside `NOTES_DIR`; it may be nested, for
example `claude/summaries`. Changing it only affects new notes — move the existing
ones yourself (`git mv`) if they should end up together.

`NOTES_LANG` is the language **the notes themselves** are written in: a code such as
`pl` or `en`, or a language name such as `Brazilian Portuguese`. The code, comments
and messages are English regardless. It steers both the session notes and
`/summarize-day`, and it also picks the language of the fixed labels in a note's
header. The default is `pl`, because that is what this repository's author writes in.

The `SessionEnd` hook reads `NOTES_DIR` from the same file, so new notes land where
they are pushed from. Everything can be overridden for a single run
(highest precedence first):

1. options: `push-notes --notes-dir DIR --remote URL --branch NAME --config FILE`
2. environment: `NOTES_DIR`, `NOTES_SUMMARY_DIR`, `NOTES_LANG`, `NOTES_REMOTE`, `NOTES_BRANCH`, `NOTES_SYNC_CONFIG`
3. the `notes-sync.conf` file

Changing `NOTES_REMOTE` repoints `origin` in the notes repository on the next run.
AutoGit-o-Matic log: `~/.local/state/notes-sync/autogit.log`.

AutoGit-o-Matic cannot push (it does pull/fetch/mirror/bundle), so the commit and
the push are done by `push-notes.sh`, while AutoGit-o-Matic handles the fetch, the
logging and the `--status` report.

## File names

Notes written before the rename to English were called `sesja_*.md` and
`podsumowanie_<day>.md`. `notes-day.sh` reads both schemes, so an existing archive
keeps working with `/summarize-day`; only new files use `session_*` and `summary_*`.
After updating, run `./install.sh` once — it links the renamed skill and removes the
dangling symlink left by the old `podsumuj-dzien` one.

## Requirements

- `jq` and `git`
- `claude` on `PATH` (the hook calls it with `--model haiku` for the summary)
- an SSH key (`~/.ssh/id_ed25519.pub`) added on GitHub (Settings → SSH and GPG keys)
  with access to the notes repository

## Licence

The code in this repository: [MIT](LICENSE).

The `AutoGit-o-Matic/` submodule is not covered by that licence — it is a separate
[GPL-3.0](https://github.com/FPGArtktic/AutoGit-o-Matic) project, used as an external
command and fetched by `git submodule update --init`.
