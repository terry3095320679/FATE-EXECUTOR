# FATE EXECUTOR / 命运执行者

> Version **v0.1** — playable Godot 4.x battle-core vertical slice.

FATE EXECUTOR is a poker-driven roguelike card game prototype. This release focuses on one complete, testable combat loop: a player, one standard enemy, a real 52-card deck, draw-pile and discard-pile ownership, eight-card hands, selection of up to five cards, poker-hand evaluation, damage resolution, partial refreshes, and victory or defeat.

The repository is English-first. The original game design document remains in Chinese, and the playable build supports both English and Simplified Chinese.

## v0.1 scope

Included:

- One player and one normal enemy.
- A standard 52-card deck with unique card instance IDs.
- A real combat deck cycle: draw pile → hand → discard pile → deterministic reshuffle.
- An eight-card hand with one-to-five-card selection.
- Nine poker hands: High Card, Pair, Two Pair, Three of a Kind, Straight, Flush, Full House, Four of a Kind, and Straight Flush.
- Live hand-type and damage previews.
- Player attack, enemy counterattack, victory, defeat, and retry.
- Three partial refreshes per battle; a refresh replaces the selected one to five cards without advancing the turn.
- Read-only draw-pile and discard-pile browsers.
- English and Simplified Chinese UI with persistent language settings.
- Deterministic random seeds and automated domain/UI checks.

Not included in v0.1:

- Map progression, rewards, shops, accessories/relics, special poker cards, wild cards, elites, or bosses.

## Current combat rules

1. At battle start, all 52 card instances enter the draw pile and are shuffled with the battle RNG.
2. Eight cards are drawn from the top of the real draw pile.
3. The player selects one to five cards.
4. **Confirm** evaluates the best poker hand and applies damage.
5. Only the played cards enter the discard pile. Unplayed cards remain in hand across rounds.
6. If both combatants survive, the enemy acts and the next player round draws only enough cards to refill the hand to eight.
7. **Refresh** discards the selected cards and immediately draws the same number. It does not advance the round or trigger the enemy.
8. When the draw pile is empty, the discard pile is shuffled back into it using the same deterministic RNG stream.

The following invariant is checked by the domain layer:

```text
draw pile count + hand count + discard pile count = battle card count
```

A card instance can belong to only one battle zone at a time.

## Display and interaction rules

- Hand display order is descending from left to right: K → A.
- Equal ranks use stable suit ID order: Clubs → Diamonds → Hearts → Spades (`0 → 1 → 2 → 3`).
- Pile browsers use fixed rows: Spades, Hearts, Clubs, Diamonds. Cards within each row are displayed K → A.
- Display sorting always works on read-only copies. It never changes the real draw order, internal hand order, selection order, or RNG state.
- Card visual priority is Disabled → Selected → Hovered → Normal.
- Hovering an unselected card changes only its border, brightness, and shadow. A selected card keeps its fixed selected appearance and does not receive an additional hover highlight.

## Run the project

Requirements:

- Godot 4.x. The v0.1 release was validated with Godot 4.7.1.

Open `project.godot` in Godot and press **F6** or **F5**, or run from a terminal:

```powershell
godot --path "C:\Users\HP\Documents\Codex\FATE EXECUTOR"
```

In Windows Command Prompt, do not use PowerShell-only syntax such as `&` or `$env:TEMP`.

## How to play

1. Select **Start Game**.
2. Select one to five cards.
3. Select **Confirm** to play the selected cards and resolve damage.
4. Alternatively, select **Refresh (3)** to replace the selected cards. Each successful refresh consumes one charge.
5. Select **Discard Pile** or **Draw Pile** to inspect a read-only snapshot of that pile.
6. Close a pile browser with **Close**, **Esc**, or by selecting outside the panel.

## Localization

The first launch defaults to English. **Settings** switches the entire current UI between English and Simplified Chinese without restarting.

The saved language setting is stored at:

```text
user://fate_executor/settings.json
```

On Windows, this normally resolves to:

```text
%APPDATA%\Godot\app_userdata\FATE EXECUTOR - Battle Prototype\fate_executor\settings.json
```

## Automated checks

Run the full suite:

```powershell
godot --headless --path . --script res://tests/test_runner.gd
```

The v0.1 suite contains **476 checks** covering poker evaluation, damage, unique zone ownership, retained cards, refill behavior, refresh limits, reshuffles, deterministic results, ordering, hover states, input locks, animation endpoints, pile browsing, and live language switching.

If Godot cannot write to its default log directory, provide a project-local absolute log path:

```powershell
godot --headless --path . --log-file "C:/Users/HP/Documents/Codex/FATE EXECUTOR/test-artifacts/tests.log" --script res://tests/test_runner.gd
```

Reproduce the documented seed trace:

```powershell
godot --headless --path . --script res://tests/fixed_seed_trace.gd
```

## Documentation

- [Development log](DEVLOG.md)
- [Architecture](docs/ARCHITECTURE.md)
- [v0.1 release notes](RELEASE_NOTES_v0.1.md)
- [Game Design Document v1.1 — Chinese](FATE_EXECUTOR_GDD_v1.1.md)

This is a source release of an early playable prototype, not the complete game.
