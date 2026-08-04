# FATE EXECUTOR v0.1 — Release Notes

**Release type:** Source release / playable battle-core vertical slice  
**Release date:** August 4, 2026  
**Engine:** Godot 4.x (validated with Godot 4.7.1)

## Overview

v0.1 is the first versioned release of FATE EXECUTOR. It delivers a compact but complete poker-combat encounter and the technical foundation for later roguelike progression systems.

The goal of this release is to validate the feel and correctness of drawing eight cards, choosing up to five, evaluating the best poker hand, applying damage, managing a real draw/discard cycle, and making tactical partial refresh decisions.

## Highlights

- Standard 52-card deck with unique, stable card instance IDs.
- Real draw pile, hand, discard pile, and deterministic reshuffle cycle.
- Eight-card hand; play one to five cards.
- Nine supported poker hands and data-driven damage multipliers.
- Live hand and damage preview.
- One player, one normal enemy, enemy intent, counterattack, and round flow.
- Three partial refreshes per battle without turn advancement.
- Unplayed cards persist across rounds; new rounds refill only missing slots.
- Animated draw, discard, refresh, and reshuffle feedback.
- Read-only pile inspection grouped by suit.
- English default UI and immediate Simplified Chinese switching.
- Persistent language selection.
- Deterministic test seed tooling.

## Verification

- Automated suite: **476 passed, 0 failed, 0 skipped**.
- Headless main-scene startup: passed.
- Rendered OpenGL Compatibility startup: passed on an NVIDIA GeForce RTX 5060 Laptop GPU.
- Fixed-seed reproduction script: `tests/fixed_seed_trace.gd`.

## Known scope limits

This release intentionally does not include map progression, combat rewards, shops, accessories/relics, special poker effects, wild cards, elite enemies, or bosses. Those systems remain design-stage work and are not represented by placeholder gameplay code in v0.1.

## Language setting

The selected language is stored at:

```text
user://fate_executor/settings.json
```

## Notes for players

This is an early source release. Open `project.godot` with Godot 4.x and run the main scene. See `README.md` for controls and test commands.
