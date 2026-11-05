---
name: anki-add
description: Adds well-constructed flashcards to the user's Anki collection through AnkiConnect when the user asks to card something from the conversation. Use when the user says to make a card, add something to Anki, or invokes /anki-add. Do not suggest cards unprompted, and do not use for generic flashcard advice unrelated to their collection.
compatibility: Requires local Anki Desktop with AnkiConnect reachable at 127.0.0.1:8765.
---

# Anki ad-hoc card capture

Turn something from the current conversation into a few good Anki cards and add them to the user's collection via AnkiConnect.

Adapted from [djt97/anki-skill](https://github.com/djt97/anki-skill) (MIT, see `LICENSE-anki-skill`): the AnkiConnect client and reference, and the card-writing principles.

## Rules

1. **Explicit only.** Make cards only when the user asks. Never suggest cards unprompted.
2. **Preview, then add.** Show every drafted card before calling `addNotes`. Add only what the user approves.
3. **Never touch scheduling.** Do not answer, reschedule, forget, or change due dates, ease, or deck options.
4. **The user picks the target.** Decide *how* a card asks, not *what* is worth remembering. If what they want to retain is unclear, ask.
5. **Standard library only.** Use the bundled `scripts/anki_client.py`; install nothing.

## Capture flow

1. **Identify the target.** From the request and recent conversation, work out the fact(s) the user wants to retain. "Card that" refers to the most recent relevant point.
2. **Connect and look around.** Run `python3 scripts/anki_client.py version`. Then fetch `deckNames` and `modelNames`, plus `modelFieldNames` for any note type you'll use. Cache these for the rest of the session.
3. **Draft minimally.** Write the 1–2 cards that matter most, following [references/card-writing.md](references/card-writing.md). Every card must make sense months later without this conversation.
   - **Note type, per fact:** Basic for a question→answer fact; Cloze when the fact lives naturally in a sentence or term; Basic (and reversed card) only when both directions are genuinely useful.
   - **Deck:** pick the best-fitting existing deck. Do not create decks unless the user asks. If nothing fits, say so and propose the closest or ask.
   - **Tags:** exactly one tag, `claude`. No topic tags.
   - **No source field content.** Leave Extra/Source fields empty unless they carry part of the card (e.g. cloze `Back Extra` context the user wants).
4. **Duplicate check.** Search existing notes for the key terms. If a close match exists, show it alongside the draft.
5. **Preview compactly.** For each card show deck, note type, fields, and tag in a tight block, numbered. After the cards, list optional extras in one line (e.g. "Also possible: reverse card, worked-example card") without drafting them in full.
6. **Wait for the reply.** "ok"/"yes" approves all; the user may approve by number, edit, drop, change deck, or ask for an extra. Re-preview only cards that changed.
7. **Add and verify.** Call `addNotes` with approved cards, check each result for `None`/errors, re-read with `notesInfo`, and report one line per card: added (note ID, deck) or failed (reason). Do not trigger sync.

## References

- **Connecting, searching, adding notes, IDs, HTML/cloze safety:** [references/ankiconnect.md](references/ankiconnect.md)
- **What makes a good card, with rules and examples:** [references/card-writing.md](references/card-writing.md)
