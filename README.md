# notes-sync

Notatki z sesji Claude Code: zapis automatyczny i wysyłanie na GitHuba
(`matchupikchu/notes_work`) za pomocą [AutoGit-o-Matic](https://github.com/FPGArtktic/AutoGit-o-Matic).

## Zawartość

| plik | co robi |
|------|---------|
| `hooks/session-note.sh` | hook `SessionEnd`: po każdej sesji zapisuje podsumowanie (Haiku) do `<NOTES_DIR>/<NOTES_SUMMARY_DIR>/RRRR-MM-DD/sesja_<czas UTC>_UTC.md` |
| `push-notes.sh` | commituje notatki w `~/notatki-claude`, robi fetch przez AutoGit-o-Matic, rebase na `origin/main` i `git push` |
| `AutoGit-o-Matic/` | submoduł, przypięty do `v3.0.0` |
| `notes-sync.conf` | konfiguracja: katalog notatek, nazwa katalogu podsumowań, URL zdalnego repo, gałąź |
| `lib/config.sh` | wspólne wczytywanie konfiguracji (hook i push) |
| `install.sh` | pobiera submoduł, linkuje hook i polecenie `push-notes` |

## Układ notatek

```
~/notatki-claude/            (osobne repo git → notes_work)
└── podsumowania/          (nazwa: NOTES_SUMMARY_DIR)
    ├── 2026-10-16/
    │   ├── sesja_2026-10-16_11-21-23_UTC.md
    │   └── sesja_2026-10-16_11-32-07_UTC.md
    └── 2026-10-17/
        └── ...
```

## Użycie

```bash
./install.sh          # raz
push-notes            # wysyła notatki
push-notes --dry-run  # tylko pokazuje, co zostałoby zrobione
push-notes --help
```

## Konfiguracja

Edytuj `notes-sync.conf`:

```sh
NOTES_DIR="$HOME/notatki-claude"
NOTES_SUMMARY_DIR="podsumowania"
NOTES_REMOTE="git@github.com:matchupikchu/notes_work.git"
NOTES_BRANCH="main"
```

`NOTES_SUMMARY_DIR` to nazwa katalogu (wewnątrz `NOTES_DIR`) na podsumowania
sesji; może być zagnieżdżona, np. `claude/podsumowania`. Zmiana dotyczy tylko
nowych notatek — istniejące przenieś ręcznie (`git mv`), jeśli mają być razem.

Hook `SessionEnd` też czyta `NOTES_DIR` z tego pliku, więc nowe notatki trafiają
tam, skąd są wysyłane. Jednorazowo można to nadpisać (od najważniejszego):

1. opcje: `push-notes --notes-dir DIR --remote URL --branch NAZWA --config PLIK`
2. zmienne środowiskowe: `NOTES_DIR`, `NOTES_SUMMARY_DIR`, `NOTES_REMOTE`, `NOTES_BRANCH`, `NOTES_SYNC_CONFIG`
3. plik `notes-sync.conf`

Zmiana `NOTES_REMOTE` przy następnym uruchomieniu przestawia `origin` w repo notatek.
Log AutoGit-o-Matic: `~/.local/state/notes-sync/autogit.log`.

AutoGit-o-Matic nie umie robić pusha (obsługuje pull/fetch/mirror/bundle),
więc commit i push robi `push-notes.sh`, a AutoGit-o-Matic odpowiada za
fetch, logowanie i raport `--status`.

## Wymagania

Klucz SSH (`~/.ssh/id_ed25519.pub`) dodany na GitHubie
(Settings → SSH and GPG keys) z dostępem do `notes_work`.
