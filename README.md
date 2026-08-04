# FATE EXECUTOR / 命运执行者

FATE EXECUTOR is a poker-driven roguelike card game built with Godot 4.x.

Version **v0.1** is a playable battle prototype focused on tactical hand building, poker combinations, and deterministic deck management.

## Features

- A standard 52-card deck with unique card instances
- Draw 8 cards and play up to 5
- Nine poker hands, from High Card to Straight Flush
- Live hand and damage previews
- A real draw pile, hand, discard pile, and reshuffle cycle
- Three partial refreshes per battle
- Animated card draws, discards, refreshes, and reshuffles
- English and Simplified Chinese interface

## How to Play

1. Select **Start Game**.
2. Choose one to five cards.
3. Select **Confirm** to play the hand and deal damage.
4. Select **Refresh** to replace the chosen cards without ending the turn.
5. Defeat the enemy before your health reaches zero.

Unplayed cards remain in your hand between rounds. The next round draws only enough cards to refill the hand to eight.

## Run the Game

1. Install [Godot 4.x](https://godotengine.org/).
2. Clone or download this repository.
3. Open `project.godot` in Godot.
4. Press **F6** or **F5** to play.

Tested with Godot 4.7.1.

## Development

Run the automated checks with:

```text
godot --headless --path . --script res://tests/test_runner.gd
```

## Documentation

- [Development Log](DEVLOG.md)
- [Architecture](docs/ARCHITECTURE.md)
- [v0.1 Release Notes](RELEASE_NOTES_v0.1.md)
- [Game Design Document](FATE_EXECUTOR_GDD_v1.1.md)
