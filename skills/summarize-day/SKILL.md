---
name: summarize-day
description: Summarises the Claude Code session notes of a given day (today in UTC by default) and writes the summary into that day's directory. Use it when the user asks for a summary of the day or of today's notes.
argument-hint: "[YYYY-MM-DD]"
disable-model-invocation: true
allowed-tools: Bash(~/notes-sync/notes-day.sh:*), Write
---

## Notes for the chosen day

The notes directory, the summary directory and the summary language come from
`~/notes-sync/notes-sync.conf` (`NOTES_DIR`, `NOTES_SUMMARY_DIR`, `NOTES_LANG`).
Day directories are named with the UTC date.

!`~/notes-sync/notes-day.sh $ARGUMENTS`

## Task

Write a concise summary of the day from the notes above, **in the language given
above as "Summary language"**, with these sections (translated into that language):

1. **Overview** — 2-3 sentences: what the day was mostly spent on.
2. **Done** — concrete results, grouped by topic (not per session, when several sessions covered the same thing).
3. **Decisions** — conclusions that matter, approaches chosen.
4. **Open / to do** — unfinished work, problems, next steps.

Keep the specifics (paths, names, numbers) and leave out procedural detail. If there
are no notes, say so briefly and do nothing else.

Finally write the summary to the path given above as "Summary file" (that is
`<day directory>/summary_<day>.md`; overwrite it if it exists) and report the path.
