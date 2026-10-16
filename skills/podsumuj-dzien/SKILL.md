---
name: podsumuj-dzien
description: Podsumowuje notatki z sesji Claude Code z danego dnia (domyślnie dzisiaj, UTC) i zapisuje podsumowanie w katalogu tego dnia. Użyj, gdy użytkownik prosi o podsumowanie dnia lub dzisiejszych notatek.
argument-hint: "[RRRR-MM-DD]"
disable-model-invocation: true
allowed-tools: Bash(~/notes-sync/notes-day.sh:*), Write
---

## Notatki z wybranego dnia

Katalog notatek i nazwa katalogu podsumowań pochodzą z `~/notes-sync/notes-sync.conf`
(`NOTES_DIR`, `NOTES_SUMMARY_DIR`). Katalogi dni są nazwane datą UTC.

!`~/notes-sync/notes-day.sh $ARGUMENTS`

## Zadanie

Na podstawie powyższych notatek napisz po polsku zwięzłe podsumowanie dnia:

1. **Przegląd** — 2–3 zdania: nad czym głównie pracowano.
2. **Zrobione** — lista konkretnych efektów, pogrupowana tematycznie (nie per sesja, jeśli sesje dotyczyły tego samego).
3. **Decyzje i ustalenia** — ważne wnioski, wybrane rozwiązania.
4. **Otwarte sprawy / do zrobienia** — rzeczy niedokończone, problemy, kolejne kroki.

Zachowaj konkrety (ścieżki, nazwy, liczby), pomiń szczegóły proceduralne. Jeśli notatek brak, powiedz to krótko i nic więcej nie rób.

Na koniec zapisz podsumowanie do pliku podanego wyżej jako „Plik podsumowania” (czyli `<katalog dnia>/podsumowanie_<dzień>.md`; nadpisz, jeśli istnieje) i podaj ścieżkę.
