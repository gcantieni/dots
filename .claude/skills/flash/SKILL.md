---
name: flash
description: Turns something from the conversation into flashcards and adds them to Anki through AnkiConnect, or to another store that a local extension defines. Use when the user invokes /flash.
disable-model-invocation: true
compatibility: Local Anki Desktop with AnkiConnect at 127.0.0.1:8765.
---

# Flashcard capture

Turn something from the current conversation into a few good cards, route each one to its store, and add them after the user approves.

Adapted from [djt97/anki-skill](https://github.com/djt97/anki-skill) (MIT, see `LICENSE-anki-skill`): the AnkiConnect client and reference, and the card-writing principles.

## Local extension

If `references/local.md` exists, read it before anything else. It may add stores and routing rules for this machine, and where it conflicts with this file, it wins. Without it, every card goes to Anki.

## Rules

1. **Explicit only.** Make cards only when the user asks.
2. **Preview, then add.** Show every drafted card with its destination before adding anything. Add only what the user approves.
3. **Never touch scheduling** in any store. No reviewing, rating, rescheduling, or editing scheduler state.
4. **The user picks the target.** Decide *how* a card asks, not *what* is worth remembering. If what they want to retain is unclear, ask.

## Capture flow

1. **Identify the target.** From the request and recent conversation, work out the fact(s) the user wants to retain. "Card that" refers to the most recent relevant point.
2. **Route** each fact to a store. The user's explicit choice overrides any routing rule.
3. **Look around the stores you'll use**, per each store's reference. Cache what you learn for the rest of the session.
4. **Draft minimally.** Write the 1–2 cards that matter most, following [references/card-writing.md](references/card-writing.md). Every card must make sense months later without this conversation. Apply the store's format limits.
5. **Duplicate check** in the destination store. If a close match exists, show it alongside the draft.
6. **Preview compactly.** Number the cards. For each show the destination first (e.g. `Anki: <deck>, <note type>`), then the fields. After the cards, list optional extras in one line (e.g. "Also possible: reverse card, worked-example card") without drafting them in full.
7. **Wait for the reply.** "ok"/"yes" approves all. The user may approve by number, edit, drop, reroute, change deck, or ask for an extra. Re-preview only cards that changed.
8. **Add and verify** per the store's reference, then report one line per card: added (store and ID) or failed (reason).

## References

- **Card-writing rubric shared by all stores:** [references/card-writing.md](references/card-writing.md)
- **AnkiConnect, decks, note types, tags, HTML and cloze:** [references/anki.md](references/anki.md)
- **Machine-specific stores and routing, if present:** `references/local.md`
