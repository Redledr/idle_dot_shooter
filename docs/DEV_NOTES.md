# Idle Dot Shooter Dev Notes

## Overview

This project is a Godot-based idle/action hybrid where the player steers orb collection while the turret and drones handle combat. The main loop is:

1. Turret and drones kill dots.
2. Dead dots spawn orbs.
3. The player collects orbs for currency.
4. Card draws trigger at orb thresholds.
5. Cards and upgrades permanently alter the current run.

## Core Runtime Structure

- `scripts/core/main.gd`
  - Owns the active run.
  - Starts and ends runs.
  - Tracks runtime state like `currency`, `run_timer`, card draw timing, and unlock flow.
  - Spawns dots, drones, and orbs.
  - Applies card-driven runtime flags such as `bullets_pierce`, `orbs_per_kill`, and `chain_pickup`.

- `systems/progression/UpgradeManager.gd`
  - Single source of truth for upgrade levels and cost scaling.
  - Computes derived stats for turret, economy, and drone systems.
  - Manual upgrades and card effects both mutate this shared levels dictionary.

- `systems/progression/CardDatabase.gd`
  - Loads cards from `res://data/runtime/cards.json`.
  - Draws weighted hands by rarity.
  - Applies implemented card effects directly to `UpgradeManager` or `main`.
  - Unimplemented effect keys fall through into `main.card_flags` for future systems.

- `systems/progression/RunManager.gd`
  - Tracks per-run metrics such as dots destroyed, orbs collected, idle time, reaction times, and shard payout.
  - Resets card state through `CardDatabase.reset_run()` at run start.

- `systems/progression/SaveManager.gd`
  - Saves upgrade progression and summary data.
  - Computes offline earnings using current fire-rate-based kill estimates.

## Entity Roles

- `gameplay/entities/turret/turret.gd`
  - Auto-targets the nearest dot and fires bullets through `ShooterComponent`.

- `gameplay/entities/bullet/bullet.gd`
  - Moves in a fixed direction, damages a dot on contact, then despawns.

- `gameplay/entities/dot/dot.gd`
  - HP-based target.
  - Spawns orbs on death and removes itself when offscreen.

- `gameplay/entities/orb/orb.gd`
  - Handles pickup radius, lifetime, bobbing, and pull behavior.
  - Reports collection back to `main`.

- `gameplay/entities/drone/drone.gd`
  - Has two states: orbiting and hunting.
  - Acquires the nearest dot, closes distance, and fires when in range.
  - Uses drone-related upgrade formulas from `UpgradeManager`.

## UI Flow

- `ui/screens/start_screen.gd`
  - Main menu and continue/new game/settings flow.

- `ui/widgets/hud.gd`
  - Displays currency, dots destroyed, timer, and transient notifications.

- `ui/screens/card_draw_screen.gd`
  - Pauses the game, presents the current hand, and emits the chosen card.
  - Has custom presentation and animation logic rather than standard Godot UI widgets.

- `ui/widgets/upgrade_panel.gd`
  - Manual upgrade tabs for defense, economy, and drone upgrades.
  - Drone tab unlocks when a drone exists in the scene.

- `ui/screens/end_of_run_screen.gd`
  - Displays run summary, shard payout, and replay/menu actions.

## Card System Notes

### Implemented Effect Families

These effect keys already have direct logic in `CardDatabase.gd`:

- Turret: `fire_rate_levels`, `damage_levels`, `balanced_boost`, `damage_and_rate`, `bullets_pierce`
- Drone: `drone_speed_levels`, `drone_damage_levels`, `drone_agility_levels`, `drone_size_levels`, `drone_cooldown_levels`, `spawn_drone`, `drone_combo`, `drone_all`
- Economy: `orbs_per_kill`, `pickup_radius_mul`, `chain_pickup`, `dot_value_levels`, `spawn_count_levels`, `orb_lifetime_add`, `orb_gravity`, `orb_nova`, `orb_speed_mul`, `orb_time_bonus`, `economy_combo`
- Wildcard: `run_duration_add`, `all_stats`, `turret_all`, `speed_combo`, `rate_and_value`, `time_and_dots`, `density_boost`, `efficient_trade`, `random_stat`, `random_three`

### Important Caveat

Many spreadsheet and JSON card entries use effect keys that are not fully implemented yet. Those keys currently fall into the default case and are stored in `main.card_flags`. That means they are data-defined, but not necessarily gameplay-active unless another script consumes those flags.

This is the most important thing to verify before adding new spreadsheet content.

### Combo Cards Fit Well

Combo cards are a strong fit for the current architecture because several implemented effects already blend systems cleanly:

- `balanced_boost`
- `damage_and_rate`
- `drone_combo`
- `drone_all`
- `economy_combo`
- `turret_all`
- `speed_combo`
- `rate_and_value`
- `time_and_dots`
- `density_boost`
- `efficient_trade`
- `random_three`

## Spreadsheet / Export Pipeline

- Source of truth for card authoring is `data/source/CardDatabase.xlsx`.
- Export script is `tools/python/cards_to_json.py`.
- Runtime card loading uses `data/runtime/cards.json`.

### Known Risks

- The exporter validates required columns, rarity, category, and duplicate IDs, but it does not deeply validate effect-key support or balance sanity.
- Float-valued card effects need extra care. For example, `orb_speed_mul` is intended to support decimal values.
- The workbook instruction sheet documents only a subset of the effect keys currently present in the card data.

## Behavioral Notes

- `scripts/core/main.gd` pauses the tree during card selection, but keeps the HUD and cursor alive with `PROCESS_MODE_ALWAYS`.
- Drone unlock is tied to `RunManager.dots_destroyed >= 100`.
- Card draws are based on orb collection thresholds, not elapsed time.
- Currency is earned through orb collection, not directly from dot death.
- Offline gains are estimated from current fire rate and assumed hit rate, not from full simulation.

## Good Next Steps

- Add a proper card validation pass that checks supported `effect_key` values against implemented handlers.
- Decide which flagged card effects should become real gameplay systems next.
- Keep combo cards focused on already-implemented handlers if the goal is fast content expansion.
