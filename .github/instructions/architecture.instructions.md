---
applyTo: "**"
---

# Architecture — Voidrift Project Structure

## Directory Layout

```
data/           9 JSON files — all game content (weapons, ships, captains, enemies, etc.)
globals/        11 autoloads (GameConfig → SettingsManager)
scripts/        GDScript organized by domain (core/, combat/, player/, systems/, ui/, pickups/, enemies/)
scenes/         .tscn files (gameplay/, ui/, pickups/, enemies/)
effects/        17 weapon effect directories, each with .gd + .tscn + .gdshader
shaders/        Global shaders (starfield, fog_of_war, radiation_belt, circle_mask, station_charge)
tools/          headless_sanity_check.ps1, weapon_test_lab/, build_megabonk_csv.py
```

## Autoloads (load order)

| #   | Autoload             | Purpose                                            |
| --- | -------------------- | -------------------------------------------------- |
| 1   | `GameConfig`         | Centralized tuning constants (balance, combat, UI) |
| 2   | `GameSeed`           | Deterministic randomness                           |
| 3   | `DataLoader`         | JSON loading + mod merge                           |
| 4   | `PersistenceManager` | Save/load persistent data                          |
| 5   | `RunManager`         | Run lifecycle, scene transitions                   |
| 6   | `ProgressionManager` | XP tracking + level-up flow                        |
| 7   | `UpgradeService`     | Level-up option generation                         |
| 8   | `StationService`     | Space station buff generation + application        |
| 9   | `GameManager`        | Legacy compatibility facade                        |
| 10  | `FileLogger`         | Debug logging to `debug_log.txt`                   |
| 11  | `SettingsManager`    | Audio/display/monitor selection                    |

## Data Files (`data/`)

| File                     | Content                                      |
| ------------------------ | -------------------------------------------- |
| `base_player_stats.json` | Universal default stats                      |
| `weapons.json`           | Weapon definitions + visual config           |
| `weapon_upgrades.json`   | Per-weapon rarity tier stat tables           |
| `ships.json`             | Ship definitions (speed, stats, phase shift) |
| `captains.json`          | Captain passive + active ability             |
| `synergies.json`         | Ship+Captain combo bonuses                   |
| `ship_upgrades.json`     | Passive upgrade definitions (tomes)          |
| `items.json`             | Pickup items + effects                       |
| `enemies.json`           | Enemy types, stats, behaviors                |

Mods load from `user://mods/` and merge with base data.

## GameConfig Rule (Mandatory)

**Never hardcode balance or tuning values directly in scripts.** All numeric constants that affect gameplay feel, progression, combat, camera, or UI timing belong in `globals/game_config.gd` (the `GameConfig` autoload).

### How to Reference GameConfig

```gdscript
# In autoloads (loaded after GameConfig in the autoload order):
var run_duration: float = GameConfig.DEFAULT_RUN_DURATION

# In scene scripts (use @onready):
@onready var GameConfig: Node = get_node("/root/GameConfig")

# In class-level var initializers (autoload name is globally available):
var _targeting_range: float = GameConfig.WEAPON_TARGETING_RANGE
```

### What Belongs in GameConfig

- Player movement, turn rate
- Enemy stat scaling, spawn rates, elite thresholds
- Phase shift timing (duration, cooldown, recharge, i-frames)
- Knockback forces, damage intervals, i-frame durations
- Shield recharge timing, diminishing returns formula parameters
- XP curve parameters, loadout slot counts
- Camera zoom behavior
- Upgrade offer weights (weapon vs module frequency)
- Pickup scatter offsets, credit drop chance/scaling
- UI timing (game over delay, level-up queue flash)
- Ability defaults, ship visual fallbacks
- Rarity weights, weapon tier upgrade parameters
- Arena/boundary constants, minimap/fog of war settings
- Space station constants, asteroid parameters, flow field tuning

### What Does NOT Belong in GameConfig

- Per-weapon or per-ship data → stays in `data/*.json`
- Purely structural constants (file paths, scene paths, stat names)
- UI layout sizes set in `.tscn` files

## Collision Layers Reference

| Layer | Name        | Used By                   |
| ----- | ----------- | ------------------------- |
| 1     | Player      | Ship (CharacterBody2D)    |
| 2     | Obstacles   | Asteroids (StaticBody2D)  |
| 4     | Projectiles | Player projectiles        |
| 8     | Enemies     | All enemy types           |
| 16    | Pickups     | XP pickups, items         |
| 32    | PickupRange | Ship's PickupRange Area2D |
| 64    | Stations    | Space station BuffZone    |

### Collision Masks

| Node        | Layer | Mask      | Detects                   |
| ----------- | ----- | --------- | ------------------------- |
| Ship        | 1     | 8+2       | Enemies + Obstacles       |
| Projectile  | 4     | 8         | Enemies                   |
| BaseEnemy   | 8     | 5 (1+4)   | Player + Projectiles      |
| XPPickup    | 16    | 33 (1+32) | Player body + PickupRange |
| PickupRange | 32    | 16        | Pickups                   |
| BuffZone    | 64    | 1         | Player                    |
| Asteroid    | 2     | 0         | Nothing (static obstacle) |
