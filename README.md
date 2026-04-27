# Idle Dot Shooter

Godot project for an idle/action hybrid where a turret and drones handle combat while the player manages orb collection, upgrades, and card draws.

## Project Structure

- `project.godot`: Godot project entry.
- `scenes/game/main.tscn` / `scripts/core/main.gd`: Main runtime scene and controller.
- `addons/`: Editor and runtime plugins.
- `assets/`: App-facing imported assets such as the project icon.
- `data/`: Runtime data files and authored source data.
- `docs/`: Notes, logs, and non-runtime documentation.
- `gameplay/`: Reusable components and gameplay actors.
- `systems/`: Autoloads and game-wide manager scripts.
- `tools/`: Project support scripts, including spreadsheet export tooling.
- `ui/`: HUD, overlays, and menu screens.

## Card Data Pipeline

- Author cards in `data/source/CardDatabase.xlsx`.
- Export runtime JSON with `python tools/python/cards_to_json.py`.
- The game reads `data/runtime/cards.json` at runtime.
