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
│   ├── rewards.json
│   ├── trinkets.json
│   ├── nodes.json
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
│   │   ├── battle_state.gd
│   │   ├── enemy_scaler.gd
│   │   ├── run_state.gd
│   │   ├── reward_state.gd
│   │   ├── reward_generator.gd
│   │   ├── trinket_runtime.gd
│   │   ├── node_state.gd
│   │   ├── shop_state.gd
│   │   ├── treasure_state.gd
│   │   ├── node_generator.gd
│   │   ├── card_offer_generator.gd
│   │   └── node_flow_service.gd
│   ├── infrastructure/
│   │   ├── data_repository.gd
│   │   ├── localization_service.gd
│   │   ├── settings_repository.gd
│   │   └── run_save_repository.gd
│   └── ui/
│       ├── main_screen.gd
│       ├── battle_screen.gd
│       ├── poker_card_button.gd
│       ├── rules_overlay.gd
│       ├── reward_overlay.gd
│       ├── map_overlay.gd
│       └── special_node_overlay.gd
└── tests/
    ├── test_runner.gd
    ├── fixed_seed_trace.gd
    ├── reward_seed_trace.gd
    └── node_seed_trace.gd
```

## Dependency direction

```text
MainScreen / BattleScreen / PokerCardButton / RulesOverlay / RewardOverlay / MapOverlay / SpecialNodeOverlay
        → AppServices / LocalizationService / SettingsRepository
        → RunSaveRepository / RunState / RewardState / RewardGenerator
        → NodeFlowService / NodeGenerator / NodeState / ShopState / TreasureState
        → EnemyScaler / TrinketRuntime / HandState / BattleState / PokerEvaluator
        → BattleDeckState / HandSelection / CardDisplayOrder
        → Deck / CardData / Command Results / PokerHandResult
```

The domain layer does not depend on scene-tree UI nodes. The UI submits commands and presents completed domain results. It does not generate random outcomes or directly change a card's zone ownership.

## Data-driven configuration

`DataRepository` loads the base deck, poker-hand definitions, enemy formulas, reward probabilities, node probabilities, shop rules, trinket definitions, and localization strings from JSON. The complete bilingual rules text also lives in localization data rather than UI scripts.

## Run progression and enemy scaling

`RunState` owns the current stage, Health, Gold, permanent run deck, owned trinket IDs, slot limits, minimum deck size, and unresolved reward or node state. A completed battle reward advances the stage exactly once before the next map is built.

`EnemyScaler.generate()` evaluates the formula fields in `data/enemies.json` for the requested stage. The current Debt Gambler uses:

```text
health = round(35 + 5 × (stage - 1) + 0.12 × (stage - 1)²)
attack = min(40, round(5 + 0.55 × (stage - 1) + 0.015 × (stage - 1)²))
```

The generated record carries `stage`, `base_health`, `final_health`, `base_attack`, `final_attack`, and `enemy_type`; `BattleState` consumes that record without knowing the formula.

## Victory reward transaction

`RewardGenerator` owns the separate reward RNG stream. For a fixed seed it performs the transaction in this order:

1. Uniform integer Gold roll in the inclusive 5–15 range.
2. Independent remove-card roll against 0.40.
3. Independent trinket roll against 0.60.
4. Independent five-card-choice roll against 0.80.
5. If offered, select one unowned trinket and five distinct standard rank/suit candidates.

The complete outcome is stored in `RewardState` before `RewardOverlay` opens. Gold is applied once. The overlay only emits claim, skip, open, choose, and continue commands; it never consumes RNG. Opening the card choice sets `must_choose` and persists immediately. Continue is valid only after every offered reward is claimed or explicitly skipped.

Permanent card removal and addition are methods on `Deck`. Card removal enforces the configured 20-card minimum and both operations preserve unique instance IDs. Candidate rank/suit combinations may duplicate cards already owned, but candidate instance IDs are new.

## Basic trinket runtime

`TrinketRuntime` is reconstructed from `RunState.trinket_ids` for each battle. It applies preview-safe or committed hand modifiers and exposes Block triggers for played hands and refreshes. Preview calls never consume first-use triggers. `BattleState` owns Block and absorbs it before player health damage.

Hunter's Mark is stored and implemented for `elite` and `boss` enemy types even though this stage only generates normal enemies.

## Run persistence

`RunSaveRepository` serializes the run to:

```text
user://fate_executor/run.json
```

The save contains stage, Gold, permanent card records, trinkets, and the complete unresolved reward state. Reloading an opened five-card choice restores the exact candidate instance IDs and `must_choose` flag instead of generating new candidates. Combat pile order and in-battle transient state are not written into the run save.

The same save now also includes persistent Health, `NodeState`, `ShopState`, and `TreasureState`. Paid shop card candidates and opened Treasure candidates therefore resume without a second charge or reroll.

## Deterministic map and node lifecycle

`data/nodes.json` is the single source for node probabilities, Elite multipliers, shop limits and prices, Fountain healing, and Treasure candidate count. `NodeGenerator` consumes only its dedicated map seed and performs three independent sequential rolls. It never removes duplicate results or consumes battle, reward, shop, or treasure RNG state.

`NodeState` records the current stage, all three candidates, seed, selected index and type, confirmation, entry, completion, and node resolution. Selection can be cancelled before confirmation. After confirmation, the other two candidates are invalidated.

```text
complete current node
→ increment global stage
→ generate and save three candidates
→ select and confirm one candidate
→ create and save node content
→ enter Battle, Elite, Shop, Fountain, or Treasure
```

The run still opens with the Stage 1 teaching battle. Its completed reward creates the first map for Stage 2. Every later node—including Shop, Fountain, and Treasure—advances the same global stage.

## Elite battle projection

`EnemyScaler.generate_elite()` starts from the normal enemy generated for the current stage, then applies and rounds the configured 1.5 health and attack multiplier. The generated `enemy_type` is `elite`, allowing the existing battle UI and Hunter's Mark to distinguish it without introducing a second behavior implementation.

`RewardGenerator.generate()` accepts a reward multiplier. Elite Gold is the seeded normal 5–15 result multiplied by 1.5 and rounded. Each optional probability is independently multiplied and clamped to 1.0, producing 0.60 remove, 0.90 trinket, and 1.00 card choice.

## Shop transaction

`ShopState` owns one visit's inventory seed, service uses, six unique unowned trinkets, sold flags, price snapshot, and any paid mandatory card choice.

- Removal validates Gold, remaining uses, and minimum deck size before atomically removing a card and charging 15 Gold.
- Card purchase atomically charges 5 Gold, decrements a use, creates five candidates from a shop-only derived seed, sets `must_choose_card`, and saves before selection.
- Healing charges only after a positive heal is calculated, restores 30% max Health, and clamps to maximum Health.
- Full trinket slots create a pending replacement without charging. Confirming a replacement charges once; cancelling charges nothing.

Black Wax Seal is evaluated when the shop is created. Every service and product price is rounded into `price_snapshot` at entry. Buying the seal cannot recursively reprice the current shop.

## Fountain and Treasure transactions

Fountain entry immediately records Health before, actual restored amount, and Health after. It spends no Gold. Continue completes the node.

`TreasureState` stores its independent seed and three unique unowned candidates. Before opening, the Treasure can be abandoned. Opening sets `must_choose` and saves immediately. After opening there is no cancel path; full slots require explicit replacement before completion.

## Extended trinket hooks

`TrinketRuntime` exposes committed-hand hooks for refresh restoration and limited healing in addition to damage and Block modifiers. Preview evaluation remains side-effect free. Persistent run healing uses the same Razor Ribbon penalty in Shops and Fountains.

## Ace-high poker rules

`data/deck.json` defines Ace as rank 14. The run deck and combat deck therefore carry the same value through grouping, highest-card selection, Base Power, damage previews, and final damage.

`PokerEvaluator._is_straight()` accepts exactly five unique, consecutive ranks in the inclusive range 2～14. This makes 10-J-Q-K-A valid while rejecting A-2-3-4-5, Q-K-A-2-3, rank wrapping, and any attempt to reinterpret Ace as 1.

## Run deck versus combat deck

`Deck` owns the player's permanent card instances for the run; a new run starts with 52. At battle start, `BattleDeckState.initialize()` registers the current instances for the fight without writing combat order back to the run deck.

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

- Rank descending: A → 2.
- Equal ranks by suit ID ascending: Clubs → Diamonds → Hearts → Spades.

`HandState.display_cards()` and pile views return new arrays. They preserve internal hand order, draw-pile top, selection order, and RNG state.

`BattleDeckState.pile_snapshot()` returns a read-only `PileSnapshot` grouped for the browser as Spades, Hearts, Clubs, and Diamonds. Each row is A → 2 and equal-rank duplicates use ascending `instance_id`. Empty standard-suit rows remain present. An extra Wild group is created only if an unknown suit actually exists; the current prototype does not create wild cards.

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

## Read-only rules page

`RulesOverlay` is a presentation-only component owned by `BattleScreen`. It builds a scrollable hierarchy of section and poker-hand entries from stable localization keys. Full English and Simplified Chinese text remains in `data/localization.json`.

Opening or closing the overlay changes only its visibility. It does not pause the scene tree, submit a domain command, inspect or consume RNG, or mutate the hand, selection, refresh count, battle state, draw pile, or discard pile. `BattleScreen` disables the Rules button while input is locked and rejects programmatic play/refresh/pile actions while the overlay is open.

## Superseded prototype rules

The following early-design rules are no longer active in v0.1:

- Independently sample every hand from the full 52-card deck.
- Draws do not remove cards from an available pool.
- Refreshed cards immediately return to the current draw pile.
- Refresh requires a separate selection mode and confirm/cancel controls.
- Hand display is ascending A → K.
- Judgment discards the entire eight-card hand.
- Every new player round always draws eight cards.
- Ace has rank 1 or can form A-2-3-4-5.
- 10-J-Q-K-A is not a Straight.

The active model is a real draw-pile → hand → discard-pile → reshuffle cycle, with unplayed cards retained and only missing hand slots refilled.

## Fixed-seed reproduction

Seed `424242` currently reproduces:

```text
initial draw: [18, 27, 9, 14, 50, 26, 37, 24]
zones: draw=44, hand=8, discard=0
played: [14, 27, 26]
retained: [18, 9, 50, 37, 24]
after judgment: draw=44, hand=5, discard=3
refill requested: 3
drawn: [1, 48, 30]
final internal hand: [18, 9, 50, 37, 24, 1, 48, 30]
final display order: [1, 24, 37, 50, 9, 48, 18, 30]
final zones: draw=41, hand=8, discard=3
```

Run `res://tests/fixed_seed_trace.gd` for the complete trace.

Reward seed `8` at Stage 1 reproduces all three optional offers:

```text
gold: 14
rolls: remove=0.3176708519, trinket=0.0908571184, card_choice=0.3534998894
trinket: sharpened_clip
candidates: [9♥#53, 6♦#54, 7♦#55, 7♥#56, 2♦#57]
```

Reward seed `62` produces no optional rewards. Run `res://tests/reward_seed_trace.gd` for the exact machine-readable reward trace.

Node seed `7` at Stage 2 reproduces:

```text
[shop, fountain, treasure]
```

Choosing Shop with inventory seed `90001` produces:

```text
[cracked_hourglass, razor_ribbon, silver_compass,
 split_coin, sharpened_clip, hunters_mark]
```

Completing that Shop and generating node seed `8` at Stage 3 produces:

```text
[shop, elite, battle]
```

Run `res://tests/node_seed_trace.gd` for the complete Stage 1 battle reward → Stage 2 map → Shop → Stage 3 map reproduction.
