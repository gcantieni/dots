# Anki reference

## Conventions

- **Note type, per fact:** Basic for a question→answer fact. Cloze when the fact lives naturally in a sentence or term. Basic (and reversed card) only when both directions are genuinely useful.
- **Deck:** pick the best-fitting existing deck. Do not create decks unless the user asks. If nothing fits, say so and propose the closest or ask.
- **Tags:** exactly one tag, `claude`. No topic tags.
- **No source field content.** Leave Extra/Source fields empty unless they carry part of the card (e.g. cloze `Back Extra` context the user wants).
- **Setup:** run `version`, then fetch `deckNames` and `modelNames`, plus `modelFieldNames` for any note type you'll use.
- **Add and verify:** call `addNotes` with the approved cards, check each result for `None`/errors, and re-read with `notesInfo`. Do not trigger sync.

## Contents

- Connection and capability checks
- Discovering decks, note types, and fields
- Searching (including duplicate checks)
- Adding notes
- Card IDs and note IDs
- Other mutations
- Forbidden scheduling operations
- Batch behavior
- HTML, media, and cloze safety
- Error handling

## Connection and capability checks

Before any collection operation, run the bundled client from the skill root:

```bash
python3 scripts/anki_client.py version
```

The client uses `http://127.0.0.1:8765`, AnkiConnect API version 6, a bounded timeout, JSON validation, and Python's standard library only. The environment variable `ANKI_CONNECT_URL` may override the URL when the user has deliberately configured a different local endpoint.

If the version call fails, tell the user:

> Anki doesn't seem to be running, or AnkiConnect isn't installed (add-on code `2055492159`). Please open Anki and try again.

Then stop, but keep the drafted cards in the conversation so they can be added once Anki is up. Do not install software or change AnkiConnect's configuration.

Before using an unfamiliar action, check it rather than inventing it:

```bash
python3 scripts/anki_client.py apiReflect \
  '{"scopes":["actions"],"actions":["addNote","canAddNotesWithErrorDetail"]}'
```

A missing action is unavailable. Do not substitute an undocumented action with a similar-sounding name.

Any action can be called from the CLI with a JSON params object:

```bash
python3 scripts/anki_client.py deckNames
python3 scripts/anki_client.py findCards '{"query":"deck:\"My Deck\" added:1"}'
```

From Python, import the helper:

```python
from scripts.anki_client import call

call("deckNames")
```

When a script is executed from `scripts/`, `from anki_client import call` also works.

## Discovering decks, note types, and fields

Never guess a deck, note type, or field name — field names are case-sensitive and vary by note type.

```python
call("deckNames")
call("modelNames")
call("modelFieldNames", {"modelName": "Basic"})
call("modelFieldNames", {"modelName": "Cloze"})
```

The stock note types are usually `Basic` (`Front`, `Back`), `Basic (and reversed card)`, and `Cloze` (`Text`, `Back Extra`), but the user's collection may rename or customize them.

## Searching

Use Anki's own search syntax. Quote values containing spaces or punctuation.

```python
call("findCards", {"query": 'deck:"My Deck"'})
call("findCards", {"query": 'note:"Basic (and reversed card)"'})
call("findCards", {"query": '"mitochondria"'})
call("findCards", {"query": "added:7"})
call("findNotes", {"query": 'Front:*regularization*'})
call("findNotes", {"query": "tag:my-tag"})
```

`quote_search_value(value)` in the client quotes a value safely.

### Duplicate check before adding

Before proposing a card, search for notes already covering the same fact (search key terms, not the whole prompt). If something close exists, show it and ask whether to skip, add anyway, or treat the new card as a different angle on it.

`canAddNotesWithErrorDetail` reports whether AnkiConnect would reject a note (empty first field or exact first-field duplicate) without adding it:

```python
call("canAddNotesWithErrorDetail", {"notes": [note]})
```

## Adding notes

Every add assumes the exact card was previewed and approved.

```python
note_id = call("addNote", {
    "note": {
        "deckName": "My Deck",
        "modelName": "Basic",
        "fields": {"Front": "Q", "Back": "A"},
        "tags": ["my-tag"],
    }
})
```

Several approved cards at once:

```python
results = call("addNotes", {"notes": [note1, note2]})
# results is a list; a None entry means that note failed.
```

Confirm the deck, model, every field, and every tag. `addNote` rejects empty notes and duplicates by default (`"duplicate"` error); do not set `options.allowDuplicate` unless the user chose to add a duplicate. After adding, re-read the note with `notesInfo` and confirm the stored fields match the approved preview.

To create a deck the user asked for:

```python
call("createDeck", {"deck": "Parent::Child"})
```

## Card IDs and note IDs

A **note** contains fields and tags. A **card** is a review item generated from a note. One note may generate multiple cards (a reversed note type makes two; each cloze number makes one).

| Operation | Identifier |
| --- | --- |
| `findCards`, `cardsInfo` | card IDs |
| `suspend`, `unsuspend`, `changeDeck` | card IDs |
| `findNotes`, `notesInfo`, `updateNoteFields`, `deleteNotes` | note IDs |
| `addTags`, `removeTags` | note IDs |

Convert card to note:

```python
card = call("cardsInfo", {"cards": [card_id]})[0]
note_id = int(card["note"])
```

`cardsInfo` returns `cardId`, `note` (an integer note ID), `fields`, `modelName`, `deckName`, `interval`, `reps`, `lapses`. `notesInfo` returns `noteId`, `fields`, `tags`, `modelName`, and `cards` (all generated card IDs). For long ID lists use `cards_info` / `notes_info` from the client, which batch in groups of 200.

## Other mutations

Only after explicit approval of the exact change. Useful for fixing a card just added:

```python
call("updateNoteFields", {"note": {"id": note_id, "fields": {"Back": "Approved answer"}}})
call("addTags", {"notes": [note_id], "tags": "tag-a tag-b"})
call("removeTags", {"notes": [note_id], "tags": "tag-a"})
call("changeDeck", {"cards": [card_id], "deck": "New Deck"})
call("deleteNotes", {"notes": [note_id]})  # removes every card of the note
```

A field edit changes every sibling card of the note. Deletion needs its own confirmation and is never combined with other operations.

## Forbidden scheduling operations

Do not call or emulate: `answerCards`, `forgetCards`, `relearnCards`, `setDueDate`, `setEaseFactors`, direct changes to `ivl`/`due`/`factor`/`queue`/`reps`/`lapses`, deck-option changes affecting scheduling or FSRS. Do not use `multi` to perform these indirectly.

## Batch behavior

`multi` and `addNotes` are **not transactional**. Earlier items may succeed when later ones fail. Inspect every result, report partial failure clearly, and re-read state to verify.

## HTML, media, and cloze safety

- Fields are HTML. Use `<br>` for line breaks, and escape literal `<`, `>`, `&` in content (e.g. code) as `&lt;`, `&gt;`, `&amp;`.
- When editing an existing note, re-fetch the raw field value; strip HTML only for display, never write stripped text back.
- Preserve `<img>`, `[sound:...]`, MathJax (`\(...\)`, `\[...\]`), and cloze markers.
- Cloze syntax is `{{c1::answer::optional hint}}`. Different numbers (`c1`, `c2`) make separate cards; the same number in two places makes one card hiding both.

## Error handling

- Do not retry a mutation automatically after an ambiguous network failure. Re-read state first (e.g. `findNotes` for the new content) to see whether it was added.
- A bounded retry is fine for read-only calls; report persistent failure.
- Do not silently drop API errors or partial failures.
