# Flashcard writing principles

## Contents

- Construction vs. target
- Card shape
- Quality bar: T0–T3
- Core principles
- Card-writing rules
- Memory aids for arbitrary facts
- Examples

Follow these principles when drafting cards for either store. They govern how a card asks; they do not decide what the user should remember.

## Construction vs. target

Two judgments stay distinct:

- **Construction:** Does the card cue one stable answer over long horizons? You own this.
- **Target:** Is this the fact worth remembering? The user owns this.

An isolated date, name, number, or command flag may be exactly what the user wants. Its arbitrariness is not a reason to steer them elsewhere. When the thing to remember is unclear from the conversation, ask before drafting.

## Card shape

Default to a question → answer card. Every store supports it, so the rubric applies to all of them.

- Write each side as plain text first. A side that needs line breaks or a code block is usually two cards.
- Cloze is an alternative for a fact that lives naturally in a sentence, only in stores that support it. Elsewhere, ask for the hidden term instead.
- Put brief disambiguating context in an Extra field if the store has one, or as a short given on the front if not.

## Quality bar: T0–T3

Adapted from [memory-machines.com/report](https://memory-machines.com/report). Only propose T3 cards; use the lower grades to diagnose a draft.

- **T3 — ready.** The prompt reliably cues the same answer after a long gap. Concrete, compact, one unambiguous answer.
- **T2 — needs polish.** Right target, but wordy or high-friction. Tighten; if the answer bundles separately recallable facts, split.
- **T1 — needs refactor.** Plausible prompt, but several answers fit, so recall drifts over months. Add scope, setup, units, timeframe, or context as givens on the front without telegraphing the answer. (Vague: "When did X begin?" Better: name the specific datable event, then ask for its date.)
- **T0 — possible target mismatch.** The card may test the wrong detail. Raise it as a question, never a verdict.

Fixes by type:

- **Ambiguous:** narrow the answer space until exactly one answer fits.
- **Bloated:** cut nonessential wording; split independent targets.
- **Atomic but arbitrary:** keep the question and offer a memory hook.
- **Conceptual:** prefer generative phrasing that asks the learner to produce the mechanism, rule, or construction. This is not a mandate to convert atomic facts.

## Core principles

1. **Atomicity:** One card tests one fact. Split independently recallable facts rather than padding the back.
2. **Univocality:** The front admits exactly one correct answer. If a tired learner could give two different but defensible answers, narrow the prompt without giving the answer away.
3. **Multiple angles without redundancy:** Forward/reverse, rule/example, and definition/application pairs can be useful; literal duplicates are not.
4. **Context-free on review.** The card is seen months later, out of this conversation. Don't rely on "this", "the above", or anything only the chat makes clear.

## Card-writing rules

1. **Match the user's style.** Look at a few existing cards in the destination store and match their phrasing, length, and conventions.
2. **Avoid yes/no answers.** Ask directly for the fact.
3. **Split lists.** Don't make "Name three…" one card when each item is independently recallable.
4. **Give acronyms their own card.** Ask what the acronym stands for.
5. **Avoid vague prompts.** No bare "What is X?", "Explain…", "Discuss…", or "Describe…". Prefer What, Which, When, Where, or Define with enough constraint to identify one answer.
6. **Constrain advantages, benefits, and reasons.** Ask for one canonical mechanism or an explicitly scoped answer.
7. **Back-length test.** If a back exceeds about 15 words, ask whether it can become two cards. If not, find a shorter expression without dropping needed meaning. This is a heuristic, not permission to cut a definition's load-bearing content.
8. **Give context without the answer.** Disambiguating context must not telegraph the answer, wherever it goes.
9. **Get cloze numbering right (Anki).** Separate numbers for facts that should be recalled separately. Use the same number only when they must be recalled together.

## Memory aids for arbitrary facts

When a fact resists understanding-based recall, offer one or two optional encoding aids. Don't force a contrived mnemonic.

- **Co-dated or co-located anchor:** tie the value to a familiar event or place.
- **Vivid image or story:** link cue and answer with a distinctive image.
- **Number techniques:** number-shape or Major System encoding for dates and figures.
- **Linking:** connect parts of a bundled fact (e.g. author and year), while still offering a split where each part should be recalled independently.

Keep the question unchanged. Put the hook on the back, or in an Extra/hint field in Anki.

## Examples

**Ambiguous advantage**
Poor: "What is an advantage of cloud computing?"
Better: "Which cloud pricing model shifts capital expenditure to operating expenditure?" → "Pay-as-you-go."

**Mechanism rather than essay**
Poor: "Explain how L2 regularization reduces overfitting."
Better: "By what mechanism does L2 regularization reduce overfitting?" → "It shrinks the weights, lowering variance."

**Add scope and units**
Poor: "Threshold for severe anemia?"
Better: "What is the severe-anemia threshold in g/dL for adult non-pregnant females?" → "<8 g/dL."

These examples illustrate construction only. Don't reuse their content.
