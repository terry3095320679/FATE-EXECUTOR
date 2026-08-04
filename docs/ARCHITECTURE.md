# Architecture

## Repository layout

```text
FATE EXECUTOR/
├── project.godot
├── README.md
├── DEVLOG.md
├── RELEASE_NOTES_v0.1.md
├── FATE_EXECUTOR_GDD_v1.1.md
├── data/
│   ├── deck.json
│   ├── poker_hands.json
│   ├── enemies.json
│   └── localization.json
├── scenes/
│   ├── main.tscn
│   └── battle_screen.tscn
├── src/
│   ├── application/app_services.gd
│   ├── domain/
│   │   ├── card_data.gd
│   │   ├── deck.gd
│   │   ├── card_display_order.gd
│   │   ├── hand_selection.gd
│   │   ├── hand_state.gd
│   │   ├── battle_deck_state.gd
│   │   ├── draw_command_result.gd
│   │   ├── discard_command_result.gd
│   │   ├── refresh_command_result.gd
│   │   ├── pile_snapshot.gd
│   │   ├── poker_hand_result.gd
│   │   ├── poker_evaluator.gd
│   │   └── battle_state.gd
│   ├── infrastructure/
│   │   ├── data_repository.gd
│   │   ├── localization_service.gd
│   │   └── settings_repository.gd
│   └── ui/
│       ├── main_screen.gd
│       ├── battle_screen.gd
│       └── poker_card_button.gd
└── tests/
    ├── test_runner.gd
    └── fixed_seed_trace.gd
```

## Dependency direction

```text
MainScreen / BattleScreen / PokerCardButton
        → AppServices / LocalizationService / SettingsRepository
        → HandState / BattleState / PokerEvaluator
        → BattleDeckState / HandSelection / CardDisplayOrder
        → Deck / CardData / Command Results / PokerHandResult
```

The domain layer does not depend on scene-tree UI nodes. The UI submits commands and presents completed domain results. It does not generate random outcomes or directly change a card's zone ownership.

## Data-driven configuration

`DataRepository` loads the base deck, poker-hand definitions, enemy data, and localization strings from JSON. This keeps the prototype open to future cards, poker hands, enemies, and languages without coupling those definitions to the battle UI.

## Run deck versus combat deck

`Deck` owns the player's current 52 base card instances for the run. At battle start, `BattleDeckState.initialize()` registers those instances for the current fight without writing combat order back to the run deck.

`BattleDeckState` is the sole owner of:

- `all_cards`: registry of every legal card instance in the battle.
- `draw_pile`: true draw order.
- `hand`: true internal hand order.
- `discard_pile`: discarded instances.

The top of the draw pile is the array tail. All real draws use `pop_back()`. Browser and hand display sorting never write back to these arrays.

## Deterministic random stream

Each `BattleDeckState` owns one Godot `RandomNumberGenerator`:

1. The battle sets its seed once during initialization.
2. The initial deck uses Fisher–Yates shuffle.
3. Drawing from a non-empty pile consumes no random values.
4. When the discard pile must be shuffled back, the same RNG stream continues.

Runtime uses `fixed_battle_seed = 0`, which selects a new microsecond-based seed for each new battle/retry. Automated scenarios can assign a fixed seed for exact reproduction.

## Unified draw service

`BattleDeckState.draw_to_hand(count)`:

1. Draws from the array tail.
2. If more cards are needed and the draw pile is empty, moves the complete discard pile into the draw pile.
3. Clears the discard pile and shuffles with the battle RNG.
4. Continues until the request is satisfied or no cards remain.
5. Returns `DrawCommandResult`, including drawn instances, reshuffle batches, counts before/after, and shortage state.

Cards still in hand cannot participate in a reshuffle. If draw and discard piles are insufficient, the command returns every available card, logs the shortage, creates no duplicate, and terminates safely.

## Selection and refresh

Normal play and refresh share `HandState.selection`. `HandSelection` validates that each requested card belongs to the current hand and rejects a sixth selected card for UI, test, and future input callers alike.

`HandState.refresh_selected()` completes one synchronous domain transaction:

1. Locks the selected instance order.
2. Moves selected cards from hand to discard through `BattleDeckState.discard_cards()`.
3. Draws the same quantity; a reshuffle occurs if needed.
4. Clears selection and consumes one refresh charge.
5. Returns `RefreshCommandResult`.

The result records removed, drawn, and retained instances; refresh counts before and after; the final internal hand; and final display order. Animation only consumes this immutable outcome.

## Judgment and cross-round hand retention

Player and enemy resolution are separated so the UI can present the played cards before the enemy acts:

1. Evaluate the selected one to five cards and apply player damage.
2. `HandState.discard_selected_after_judgment()` moves only the played cards to discard.
3. Unplayed cards remain in `HAND`, visible but locked during enemy action.
4. If alive, the enemy acts.
5. If both sides survive, calculate `max_hand_size - current_hand_size`.
6. `HandState.start_new_round()` draws only that many cards.

Judgment discard and refresh discard both reuse `BattleDeckState.discard_cards()`. Judgment then advances to enemy action; refresh immediately refills and does not advance the round.

## Zone consistency

`BattleDeckState.consistency_errors()` and `is_consistent()` validate after initialization, draws, discards, refreshes, and retries:

- Registered instance IDs are unique.
- Draw pile, hand, and discard pile do not overlap.
- Every zoned instance exists in the battle registry.
- The union of all zones equals the registry.
- Hand count does not exceed the configured maximum.

Victory or defeat calls `HandState.clear_battle()`. Retry rebuilds a fresh combat state from the run deck and resets refresh charges.

## Display projections

`CardDisplayOrder.descending()` is the single rank-ordering entry point for hand display:

- Rank descending: K → A.
- Equal ranks by suit ID ascending: Clubs → Diamonds → Hearts → Spades.

`HandState.display_cards()` and pile views return new arrays. They preserve internal hand order, draw-pile top, selection order, and RNG state.

`BattleDeckState.pile_snapshot()` returns a read-only `PileSnapshot` grouped for the browser as Spades, Hearts, Clubs, and Diamonds. Each row is K → A and equal-rank duplicates use ascending `instance_id`. Empty standard-suit rows remain present. An extra Wild group is created only if an unknown suit actually exists; v0.1 does not create wild cards.

## Rules versus animation

Before animation starts, `BattleScreen` synchronously receives a complete draw, discard, or refresh result. Presentation reads:

- discarded instances and order;
- drawn instances and order;
- reshuffle batches;
- final display positions.

Animation never calls RNG and never changes domain ownership. Skipping animation or setting test duration to zero therefore cannot change the outcome. A synchronous input lock rejects repeated refreshes, judgment, card changes, and retry while an action is resolving.

## Localization

All visible English and Simplified Chinese strings come from `data/localization.json`. `AppServices` broadcasts immediate language changes and coordinates persistence.

`SettingsRepository` accepts only `en` and `zh_CN`. Missing, corrupt, or unsupported settings fall back to English. The save location is:

```text
user://fate_executor/settings.json
```

## Superseded prototype rules

The following early-design rules are no longer active in v0.1:

- Independently sample every hand from the full 52-card deck.
- Draws do not remove cards from an available pool.
- Refreshed cards immediately return to the current draw pile.
- Refresh requires a separate selection mode and confirm/cancel controls.
- Hand display is ascending A → K.
- Judgment discards the entire eight-card hand.
- Every new player round always draws eight cards.

The active model is a real draw-pile → hand → discard-pile → reshuffle cycle, with unplayed cards retained and only missing hand slots refilled.

## Fixed-seed reproduction

Seed `424242` currently reproduces:

```text
initial draw: [18, 27, 9, 14, 50, 26, 37, 24]
zones: draw=44, hand=8, discard=0
played: [26, 24, 37]
retained: [18, 27, 9, 14, 50]
after judgment: draw=44, hand=5, discard=3
refill requested: 3
drawn: [1, 48, 30]
final internal hand: [18, 27, 9, 14, 50, 1, 48, 30]
final display order: [50, 9, 48, 18, 30, 1, 14, 27]
final zones: draw=41, hand=8, discard=3
```

Run `res://tests/fixed_seed_trace.gd` for the complete trace.
