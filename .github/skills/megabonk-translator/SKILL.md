---
name: megabonk-translator
description: Translates Megabonk game concepts to Voidrift equivalents. Activate when the user describes features using Megabonk terminology (pots, chests, tomes, characters, etc.).
---

# Megabonk Translator Skill

Voidrift is inspired by [Megabonk](https://megabonk.wiki/wiki/Main_Page). The user frequently describes features using Megabonk terminology. Use this skill to translate concepts and route to the correct Voidrift systems.

## When to Activate

- The user uses a Megabonk term (pots, chests, tomes, characters, charge shrines, etc.)
- The user says "like in Megabonk" or references Megabonk mechanics
- The user describes a feature that maps to a known Megabonk equivalent

## Concept Mapping Table

| Megabonk Term        | Voidrift Equivalent  | Data File                                              | Key Scripts                                              | Notes                                                                         |
| -------------------- | -------------------- | ------------------------------------------------------ | -------------------------------------------------------- | ----------------------------------------------------------------------------- |
| **Pots**             | Shipwrecks           | `data/items.json`                                      | `scripts/systems/`                                       | Static world objects the player flies to and opens for loot                   |
| **Chests**           | Jettisoned Cargo     | `data/items.json`                                      | `scripts/systems/`                                       | Higher-value world objects, rarer spawns, better loot tables                  |
| **Charge Shrines**   | Space Stations       | (stations use `StationService`)                        | `scripts/systems/space_station.gd`, `station_spawner.gd` | Proximity charge → buff selection UI. See `world.instructions.md`             |
| **Tomes**            | Ship Modules         | `data/ship_upgrades.json`                              | `globals/upgrade_service.gd`                             | Passive stat upgrades that stack per level. See `progression.instructions.md` |
| **Characters**       | Captains             | `data/captains.json`                                   | `scripts/player/ship.gd`                                 | Passive bonuses + active ability. See `player.instructions.md`                |
| **Heroes**           | Ships                | `data/ships.json`                                      | `scripts/player/ship.gd`                                 | Base stats + phase shift config. See `player.instructions.md`                 |
| **XP Orbs**          | XP Pickups           | —                                                      | `scripts/pickups/xp_pickup.gd`                           | Magnetic attraction, 1 XP normal / 3 XP elite                                 |
| **Gold**             | Credits              | —                                                      | `scripts/pickups/credit_pickup.gd`                       | Currency for meta-progression                                                 |
| **Arena**            | Arena                | —                                                      | `scripts/systems/arena_boundary.gd`                      | Circular 4000px radius with radiation belt                                    |
| **Waves**            | Enemy Spawning       | `data/enemies.json`                                    | `scripts/systems/enemy_spawner.gd`                       | Polynomial HP scaling + swarm events                                          |
| **Dash / Dodge**     | Phase Shift          | —                                                      | `scripts/player/ship.gd`                                 | 3-4 charges, i-frames, slides along asteroids                                 |
| **Upgrades**         | Level-Up Choices     | `data/ship_upgrades.json`, `data/weapon_upgrades.json` | `globals/upgrade_service.gd`, `scripts/ui/level_up.gd`   | Choose 1 of 3 per level                                                       |
| **Weapon Evolution** | Weapon Tier Upgrades | `data/weapon_upgrades.json`                            | `globals/upgrade_service.gd`                             | Common → Legendary rarity tiers with stat scaling                             |
| **Map Objects**      | World Interactables  | varies                                                 | `scripts/systems/`                                       | Asteroids, stations, shipwrecks, cargo — all placed via rejection sampling    |
| **Stardust**         | Stardust             | —                                                      | `scripts/pickups/stardust_pickup.gd`                     | Meta-progression currency dropped by loot enemies                             |
| **Elites**           | Elites               | `data/enemies.json`                                    | `scripts/systems/enemy_spawner.gd`                       | Scaled HP/damage/size, purple glow, 3 XP                                      |
| **Loot Goblins**     | Loot Freighters      | `data/enemies.json`                                    | `scripts/enemies/loot_freighter.gd`                      | Chase until hit → flee. Jackpot drops on kill                                 |

## Mechanic Mapping Details

### Pots → Shipwrecks

Megabonk pots are destructible world objects that drop items/XP. In Voidrift:

- **Placement**: Rejection-sampled positions at run start (like asteroids and stations)
- **Interaction**: Player flies near → break/open → loot scatter
- **Loot**: XP, credits, or items from `data/items.json`
- **Architecture pattern**: Follow `space_station.gd` (Area2D proximity detection) but simpler — instant interaction, no charge timer
- **Spawner pattern**: Follow `station_spawner.gd` (rejection sampling with asteroid avoidance)

### Chests → Jettisoned Cargo

Megabonk chests are rarer, higher-value containers. In Voidrift:

- **Placement**: Fewer than shipwrecks, placed further from center
- **Interaction**: May require brief proximity charge (like mini-stations) or instant open
- **Loot**: Guaranteed rare+ items, larger credit/XP bursts
- **Rarity**: Uses `GameConfig` rarity weights for loot rolls

### Charge Shrines → Space Stations

Already implemented. Key reference:

- `scripts/systems/space_station.gd` — BuffZone Area2D, charge timer, signal emission
- `globals/station_service.gd` — Buff generation with rarity rolls
- `scripts/ui/station_buff_popup.gd` — 3-choice buff selection UI

### Tomes → Ship Modules

Already implemented. Key reference:

- `data/ship_upgrades.json` — Module definitions with stat, per_level, rarity_weights
- `globals/upgrade_service.gd` — Generates level-up options mixing weapons + modules

## Research Protocol

If the user describes a Megabonk mechanic not listed above:

1. Check the [Megabonk Wiki](https://megabonk.wiki/wiki/Main_Page) for the mechanic details
2. Identify the closest Voidrift architectural pattern (signal flow, data file, scene hierarchy)
3. Map the mechanic to Voidrift's conventions before implementing
4. Add the new mapping to this table for future reference

## Routing

After translation, route to the appropriate domain:

| Voidrift Concept             | Instruction File              | Relevant Skill               |
| ---------------------------- | ----------------------------- | ---------------------------- |
| Ships, Captains, Phase Shift | `player.instructions.md`      | —                            |
| Weapons, Effects             | `combat.instructions.md`      | `weapon-effect-creator`      |
| Enemies, Spawning            | `enemies.instructions.md`     | `enemy-type-creator`         |
| Stations, Shipwrecks, Cargo  | `world.instructions.md`       | `world-interactable-creator` |
| Modules, Level-Up, Rarity    | `progression.instructions.md` | —                            |
| HUD, Cards, Popups           | `ui.instructions.md`          | `ui-screen-creator`          |
| Pickups (XP, Credits)        | `progression.instructions.md` | `pickup-type-creator`        |
