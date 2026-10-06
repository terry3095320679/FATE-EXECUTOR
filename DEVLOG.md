# Development Log

## 2026-10-05 — Player-first distribution

- Replaced the developer-oriented public README with two primary player actions: browser play and a direct Windows executable download.
- Added Godot 4.7.1 single-threaded Web and embedded-PCK Windows export presets.
- Added a GitHub Actions publishing workflow that deploys the Web build to GitHub Pages from `main` and attaches a single-file Windows build to version releases.
- Kept generated builds out of source control through the `build/` ignore rule.
- Re-ran the complete automated suite: 1065 passed, 0 failed, and 0 skipped; headless main-scene startup also passed.

## 2026-08-04 — Three-node map and special nodes

- Added a deterministic three-choice route after each completed node using independent 35% Battle, 10% Shop, 20% Elite, 15% Fountain, and 20% Treasure rolls; duplicate choices remain legal.
- Added saved `NodeState`, `ShopState`, and `TreasureState` transactions so map candidates, shop purchases, mandatory card choices, and opened treasure choices survive reloads unchanged.
- Added Elite encounters with 1.5× rounded health and attack, 1.5× rounded Gold, and independent 60% / 90% / 100% optional reward chances.
- Added per-visit shops with two 15-Gold removals, three 5-Gold forced card choices, one 20-Gold 30%-max-health heal, and six unique priced trinkets.
- Added free 30%-max-health Fountains and optional-before-opening, mandatory-after-opening three-trinket Treasures.
- Expanded the trinket pool from six to twelve and implemented Twin Lens, Silver Compass, Funeral Cup, Black Wax Seal, Razor Ribbon, and Fourfold Crown.
- Added persistent run Health and node progress; every Battle, Elite, Shop, Fountain, and Treasure completion advances the global stage.
- Added map seed `7` for `[Shop, Fountain, Treasure]`, shop inventory seed `90001`, and the complete battle-reward → map → shop → next-map trace.
- Expanded the automated suite from 890 to 1065 checks; 1065 passed, 0 failed, and 0 skipped.

## 2026-08-04 — Normal stages, enemy growth, and victory rewards

- Added persistent run progression beginning at Stage 1 and a localized Continue flow between normal battles.
- Replaced the fixed Debt Gambler values with configurable quadratic health and attack formulas plus a 40-damage normal-enemy cap.
- Added a separate deterministic reward RNG stream with automatic 5–15 Gold and independent 40% remove-card, 60% trinket, and 80% card-choice rolls.
- Added reversible reward navigation, confirmed permanent card removal, a minimum 20-card run deck, six trinket slots, and explicit full-slot replacement.
- Added six data-driven common trinkets and their battle effects: Sharpened Clip, Split Coin, Straight Ruler, Velvet Thread, Cracked Hourglass, and Hunter's Mark.
- Added an irrevocable five-card choice after opening; exact candidates and `must_choose` state persist in `user://fate_executor/run.json`.
- Added the read-only `RewardState` serialization boundary and a reward overlay that never draws random outcomes.
- Expanded the automated suite from 552 to 890 checks; 890 passed, 0 failed, and 0 skipped.
- Added reward seed `8` as the all-three-offers reproduction trace and seed `62` as the no-optional-reward case.

## 2026-08-04 — Ace-high rules and in-battle rules page

- Changed Ace from 1 to 14 across deck data, evaluation, scoring, previews, hand display, and pile browsing.
- Made 10-J-Q-K-A a valid Straight and Straight Flush.
- Removed A-2-3-4-5 and Q-K-A-2-3 from the legal Straight set; straights cannot wrap.
- Replaced the permanent two-line rule hint in the player panel with a localized **Rules** button.
- Added a read-only, scrollable rules page covering card values, a consolidated play/refresh/pile section, all nine poker hands, scoring cards, multipliers, and damage calculation.
- Simplified the rules page by removing redundant Ace, selection, turn-flow, and pile-view explanations in both languages.
- Rules can be closed with Close, Back, Esc, or a click outside the panel and do not pause or mutate combat state.
- Expanded the automated suite from 476 to 552 checks; 552 passed, 0 failed, and 0 skipped.

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
- Cards in a row use descending rank order with equal-rank duplicates stabilized by `instance_id` (later revised to A → 2 when Ace became 14).
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
