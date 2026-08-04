# Development Log

## 2026-08-04 — v0.1 source release

- Established the first public version as **v0.1**.
- Prepared the repository as an English-first source release.
- Added a concise release note and refreshed the README and architecture guide.
- Kept the Chinese GDD as the authoritative long-form design reference.
- Release scope remains the battle-core vertical slice only; no map, reward, shop, accessory, special-card, wild-card, elite, or boss systems were added.
- Release validation completed with 476 / 476 automated checks, 0 failures, 0 skips, and successful headless and rendered startup checks.

## 2026-07-30 — Persistent hands and four-suit pile browser

This revision superseded the earlier rule that discarded all eight cards after judgment.

### Rules

- Judgment now discards only the one to five cards actually played.
- Unplayed card instance IDs remain in `HAND` across enemy actions and rounds.
- A new player round draws `max_hand_size - current_hand_size` cards instead of always drawing eight.
- The hand limit is provided by `BattleState.player_hand_size`; the current value is eight.
- Refresh still discards only the selected cards, immediately draws the same amount, and does not advance the round.
- Missing, corrupt, or unsupported language settings consistently fall back to English.

### Pile browsing

- Added the read-only `PileSnapshot` domain projection.
- Draw and discard browsers always render four rows: Spades, Hearts, Clubs, and Diamonds.
- Empty rows remain visible and use localized empty-state text.
- English singular/plural counts distinguish `Card` and `Cards`; Chinese uses `张`.
- Cards in a row are ordered K → A, with equal-rank duplicates stabilized by `instance_id`.
- Selecting a browser card opens read-only details and cannot affect hand selection.
- Browser creation neither changes the internal pile order nor consumes RNG state.

### Validation

- Before this revision: 267 / 267 checks passed.
- After this revision: 476 / 476 checks passed; 0 failed and 0 skipped.
- Added coverage for playing one, three, and five cards; retaining seven, five, and three; refilling one, three, and five; excluding retained cards from reshuffles; suit grouping; empty rows; duplicate cards; count grammar; and immediate language switching.
- Updated the fixed seed `424242` trace to demonstrate playing three cards, retaining five, and refilling three.

## 2026-07-25 — Real combat deck, shared selection, refresh, and animation

### Domain rules

- Added `BattleDeckState` as the sole owner of draw-pile, hand, and discard-pile zones.
- Battle initialization shuffles the complete combat deck and draws from the array tail.
- When the draw pile runs out, the discard pile is moved back, shuffled with the same RNG stream, and drawing continues.
- Normal play and refresh share the same one-to-five-card `HandSelection` rule.
- Refresh uses the normal selection directly; selected cards enter the discard pile and the same number is drawn.
- Every battle starts with three refresh charges. A successful refresh consumes exactly one charge.
- Input is locked during refresh animation and enemy resolution.

### Command results and presentation

- Added `CardDisplayOrder`, `BattleDeckState`, `DrawCommandResult`, `DiscardCommandResult`, and `RefreshCommandResult`.
- Domain commands produce complete results synchronously before animation begins.
- Animation consumes the command result and never calls RNG or changes card ownership.
- Added clickable discard and draw piles with real domain counts.
- Added read-only, scrollable pile browsing and empty states.
- Initial/new cards animate from the draw pile and turn face up.
- Refreshed and played cards animate toward the discard pile.
- Reshuffling shows concise discard-to-draw feedback.
- Selected visual state overrides hover state, and hover does not change card layout.

### Validation

- Confirmed the 145-check pre-change baseline.
- Expanded the suite to 267 checks; all passed with 0 failures and 0 skips.
- Added the deterministic `tests/fixed_seed_trace.gd` scenario using seed `424242`.
- Headless main-scene startup passed.
- A real OpenGL Compatibility window rendered successfully on an NVIDIA GeForce RTX 5060 Laptop GPU.

## 2026-07-25 — Localization and selection rule

- Added the English main menu, Settings screen, and immediate Simplified Chinese switching.
- Persisted language choice to `user://fate_executor/settings.json`.
- Moved the maximum five-card selection rule into `HandSelection` so non-UI callers also receive the same rejection.
- Reached a 145 / 145 passing test baseline.

## 2026-07-25 — Card readability

- Added stable rank/suit hand display ordering.
- Unselected cards use a subdued presentation; selected cards use a fixed gold outline and raised position.
- Added brightness, ordering, and position checks.

## 2026-07-25 — Initial battle-core vertical slice

- Created the Godot 4.x project and 1280×720 combat scene.
- Defined the standard 52-card deck, nine poker-hand multipliers, and one normal enemy in JSON.
- Implemented draw eight, select one to five, poker evaluation, damage, enemy counterattack, victory, defeat, and retry.
- Kept domain logic independent of UI nodes and provided data-driven seams for future systems.
