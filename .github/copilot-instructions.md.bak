# Voidrift - Copilot Instructions

## Game Overview

Voidrift is a **top-down 2D sci-fi roguelike survival game** inspired by Megabonk. Players pilot a ship through space, auto-attacking waves of enemies while collecting XP, leveling up, and choosing upgrades during timed survival runs.

**Genre**: Action Roguelike / Bullet Survivor  
**Engine**: Godot 4.6  
**Platform**: Steam (Windows primary, potential Linux/Steam Deck)

---

## Core Mechanics

### Movement & Controls

- **Twin-stick controls**: Left stick/WASD moves ship (ship faces movement direction)
- **Camera orbit**: Right stick/mouse horizontal rotates camera around ship
- **Ship always at screen center**, world rotates around player's view

### Combat

- **Auto-attack**: ALL weapons fire automatically - there is NO manual firing
- **No manual aiming**: Focus is on positioning and build choices
- **Multiple weapons**: Can equip/upgrade multiple weapons simultaneously
- **Weapon types**: projectile, orbit, area, beam, melee - all auto-fire based on cooldown

### Phase Shift (Dash Ability)

Replaces Megabonk's jump mechanic. Ship briefly phases into another dimension:

| Aspect          | Design                                                                                          |
| --------------- | ----------------------------------------------------------------------------------------------- |
| **Visual**      | Ship becomes translucent/ghostly with particle trail                                            |
| **Mechanic**    | Short burst in movement direction, ~0.3s i-frames, passes through enemies AND obstacles         |
| **Resource**    | Phase Energy bar (3-4 charges, recharges over time)                                             |
| **Upgrades**    | Ship upgrades can modify: charge count, recharge rate, phase duration, Phase Damage, Phase Pull |
| **Risk/Reward** | Phasing into obstacle when energy depletes = briefly stuck, taking damage                       |

**Character variants** may have different Phase Shift behaviors (Blink, Afterburner, Gravity Sling, etc.)

### Progression (In-Run)

- **XP Collection**: Enemies drop XP shards, collect to fill XP bar
- **Level Up**: Choose 1 of 3 random upgrades (weapons or ship upgrades)
- **Rarity System**: Common → Uncommon → Rare → Epic → Legendary
- **Refresh/Skip/Banish**: Reroll options, skip level, permanently remove from pool

### Run Structure

- **Timed survival**: Default 12 minutes per run
- **Minibosses**: Spawn at intervals (e.g., 13 min left, 9 min left, 3 min left)
- **Final Boss**: Player must activate beacon to spawn
- **Final Swarm**: If timer expires without defeating final boss, endless escalating enemies

---

## Sci-Fi Theme Mapping (from Megabonk)

| Megabonk       | Voidrift                          | Description                                                         |
| -------------- | --------------------------------- | ------------------------------------------------------------------- |
| Tomes          | Ship Upgrades / Modules           | Passive stat bonuses (max level 99)                                 |
| Charge Shrines | Space Gas Stations                | Stand in zone to charge, receive stat bonus                         |
| Shady Guy      | Space Vendor / Trader Ship        | Purchase 1 of 3 items for Credits                                   |
| Chests         | Cargo Pods                        | Found around map, contain items                                     |
| Vases/Pots     | Minable Asteroids                 | Press button to mine, drops Intergalactic Space Credits/XP/Stardust |
| Gold (in-run)  | Intergalactic Space Credits (ISC) | Currency spent during run, symbol: ⟐                                |
| Silver (meta)  | Stardust                          | Permanent currency for unlocks, symbol: ✦                           |
| Trees/Towers   | Large Asteroids / Wrecks          | Static collision obstacles                                          |
| Forest/Desert  | Nebula sectors                    | Themed arena variants                                               |

---

## Stats System

### Ship Stats (Defensive)

| Stat       | Description                                             |
| ---------- | ------------------------------------------------------- |
| Max HP     | Maximum health pool                                     |
| HP Regen   | Health regenerated per minute                           |
| Overheal   | Extra HP allowed above Max HP (from healing/lifesteal)  |
| Shield     | Regenerating barrier, absorbs damage before HP          |
| Armor      | % damage reduction (diminishing returns)                |
| Evasion    | % chance to avoid damage entirely (diminishing returns) |
| Lifesteal  | % chance to heal 1 HP on hit                            |
| Hull Shock | Damage reflected to attackers on contact                |

### Weapon Stats (Offensive)

| Stat               | Description                                             |
| ------------------ | ------------------------------------------------------- |
| Damage             | Multiplier on base damage (e.g., 2x = 200%)             |
| Crit Chance        | % chance for critical hit (>100% = chance for Overcrit) |
| Crit Damage        | Multiplier on crits (e.g., 2x)                          |
| Attack Speed       | % of base attack speed                                  |
| Projectile Count   | Number of projectiles per attack                        |
| Projectile Speed   | Travel speed multiplier                                 |
| Projectile Bounces | Times projectile bounces between enemies                |
| Size               | Projectile/AOE size multiplier                          |
| Duration           | How long effects/projectiles last                       |
| Knockback          | Push force on hit                                       |

### Movement & Phase Shift Stats

| Stat                 | Description                                         |
| -------------------- | --------------------------------------------------- |
| Movement Speed       | Ship speed multiplier                               |
| Extra Phase Shifts   | Bonus phase shift charges (added to character base) |
| Phase Shift Distance | Dash distance in pixels                             |

### Meta & Economy Stats

| Stat                | Description                         |
| ------------------- | ----------------------------------- |
| Pickup Range        | XP/item collection radius (flat)    |
| XP Gain             | XP multiplier (capped at 10x)       |
| Credits Gain        | In-run currency multiplier          |
| Stardust Gain       | Meta currency multiplier            |
| Luck                | Affects rarity of drops/upgrades    |
| Difficulty          | Enemy quantity, HP, damage, speed   |
| Elite Spawn Rate    | Elite enemy frequency               |
| Powerup Multiplier  | Magnitude and duration of powerups  |
| Powerup Drop Chance | Enemy drop rate for powerups/chests |

---

## Ship + Captain System

Players select a **Ship** (vessel hardware) and a **Captain** (pilot) independently before each run. Ships and captains are defined in separate JSON files.

### Ship (vessel)

Owns the physical frame:

1. **Starting Weapon** — Unique weapon only this ship begins with
2. **Phase Shift Variant** — Modified dash behavior (charges, distance, cooldown)
3. **Base Speed** — Movement speed in pixels/sec (Scout 100, Interceptor 120, Fortress 80)
4. **Stat Overrides** — Override base_player_stats defaults (e.g. max_hp, armor)
5. **Sprite / Visual** — Ship art

### Captain (pilot)

Owns combat bonuses and one active ability:

1. **Passive** — Permanent stat bonuses applied as flat bonuses at run start
2. **Active Ability** — Powerful cooldown-based ability (Q key / LB button, 60-90s cooldown)

Active abilities use a **template system** (data-driven JSON + shared GDScript classes):

- `buff_self` — Temporary stat buffs, invulnerability, % heal
- `area_effect` — Screen-wide or radius-based enemy effects (slow, damage)

### Synergies

Hidden ship+captain combo bonuses, discovered in-game. Small stat nudges (5-8%). Tracked in PersistenceManager.discovered_synergies. Synergy key format: `"ship_id+captain_id"`.

### Archetypes (3 of each)

**Ships**: Scout (fast, fragile), Interceptor (balanced, fast), Fortress (slow, tanky)
**Captains**: Offense (crit/damage), Defense (armor/shield), Utility (luck/xp)

---

## Architecture

## GDScript Style Rules

### Explicit typing (required)

- Always explicitly type GDScript variables, function parameters, and return types.
- Avoid untyped `var foo = ...` and avoid `:=` type inference unless the type is already explicit.
- Prefer typed containers: `Array[Dictionary]`, `Array[String]`, `Dictionary`, etc.

Examples:

- `var candidates: Array[Dictionary] = []`
- `var weapon_id: String = String(weapon_id_any)`
- `func _pick_weighted_index(items: Array[Dictionary]) -> int:`
- `var chosen: Dictionary = candidates[idx]`

If a value is Variant/untyped (e.g. from JSON), cast it immediately with `String(...)`, `int(...)`, `float(...)`, and use `get()` instead of dot-access.

### Doc comments (## not """)

GDScript uses `##` for doc comments. Triple-quoted strings (`"""..."""`) are Python-style and are discarded string literals in GDScript — they generate no documentation.

```gdscript
# WRONG — Python-style docstring (ignored by GDScript)
func take_damage(amount: float) -> float:
    """Apply damage after armor/evasion. Returns actual damage taken."""
    ...

# RIGHT — GDScript doc comment (above the function)
## Apply damage after armor/evasion. Returns actual damage taken.
func take_damage(amount: float) -> float:
    ...
```

### JSON value casting (required)

When reading values from `Dictionary.get()` on parsed JSON data, always cast immediately with `float()`, `int()`, or `bool()`. JSON numbers are Variant and may be int or float unpredictably.

```gdscript
# WRONG — raw JSON value may be int when float is expected
damage = stats.get("damage", damage)

# RIGHT — explicit cast
damage = float(stats.get("damage", damage))
count = int(stats.get("count", count))
enabled = bool(stats.get("enabled", enabled))
```

### Data-Driven Design

All game content defined in **JSON files** under `data/`:

- `base_player_stats.json` — Universal default player stats (single source of truth)
- `weapons.json` — Weapon definitions, stats, upgrade paths
- `ships.json` — Ship definitions: base_speed, stat overrides, phase shift, starting weapon
- `captains.json` — Captain definitions: passive bonuses, active ability (template-based)
- `synergies.json` — Ship+Captain combo synergy bonuses (hidden, discoverable)
- `ship_upgrades.json` — Passive upgrade definitions (like Megabonk's tomes)
- `items.json` — Pickup items and their effects
- `enemies.json` — Enemy types, stats, behaviors

**Mod Support**: Mods load from `user://mods/` and merge with base data.

### Autoloads (globals/)

| Autoload             | Purpose                                                                  |
| -------------------- | ------------------------------------------------------------------------ |
| `GameConfig`         | Centralized tuning constants (speeds, spawn rates, rarity weights)       |
| `GameSeed`           | Deterministic randomness for procedural generation                       |
| `DataLoader`         | Loads and merges JSON data files, mod support                            |
| `PersistenceManager` | Save/load persistent data (unlocks, best times, synergies)               |
| `RunManager`         | Run lifecycle, scene transitions, run state (ship, captain, weapons)     |
| `ProgressionManager` | XP tracking, level-up flow, upgrade application                          |
| `UpgradeService`     | Level-up option generation, rarity rolling, stat picks                   |
| `GameManager`        | Legacy compatibility facade (delegates to RunManager/ProgressionManager) |
| `FileLogger`         | Debug logging to file (debug_log.txt)                                    |
| `SettingsManager`    | Audio volume, display settings (fullscreen/vsync), persistence           |

### Scene Structure

```
scenes/
├── main.tscn                    # Entry point, scene manager
├── gameplay/
│   ├── world.tscn               # Main gameplay arena
│   ├── ship.tscn                # Player ship
│   └── projectile.tscn          # Projectile instance
├── ui/
│   ├── main_menu.tscn
│   ├── options_menu.tscn
│   ├── hud.tscn
│   ├── pause_menu.tscn
│   ├── level_up.tscn
│   └── game_over.tscn
├── pickups/
│   ├── xp_pickup.tscn
│   └── credit_pickup.tscn
└── enemies/
    └── base_enemy.tscn
```

### Script Structure

```
scripts/
├── core/                        # Shared components & utilities
│   ├── stats_component.gd       # HP, stats, damage, crit
│   ├── effect_utils.gd          # Shared helpers (particles, gradients, enemy-find)
│   └── abilities/
│       ├── base_ability.gd      # Abstract captain ability base
│       └── buff_self_ability.gd  # Self-buff ability template
├── combat/
│   ├── weapon_component.gd      # Auto-fire orchestration, weapon lifecycle
│   ├── weapon_inventory.gd      # Equipped weapon tracking, summaries
│   ├── weapon_spawner_cache.gd  # Lazy spawner instantiation cache
│   ├── weapon_data_flattener.gd # Flatten/unflatten nested weapon JSON for UI
│   └── projectile.gd            # Projectile movement, hit detection
├── player/
│   └── ship.gd                  # Player movement, Phase Shift, input
├── systems/
│   ├── world.gd                 # Arena setup, starfield shaders
│   └── enemy_spawner.gd         # Spawn enemies, XP drops
├── ui/
│   ├── hud.gd                   # HP/XP bars, timer, credits, weapons list
│   ├── level_up.gd              # Level-up card UI
│   ├── main_menu.gd             # Main menu
│   ├── options_menu.gd          # Options menu (volume, display)
│   ├── pause_menu.gd            # Pause menu with inline options
│   └── game_over.gd             # Game over screen
├── pickups/
│   ├── base_pickup.gd           # Magnetic attraction base class
│   ├── xp_pickup.gd             # XP shard pickup
│   └── credit_pickup.gd         # Credit pickup
└── enemies/
    └── base_enemy.gd            # Enemy chase, damage, death
```

---

## Collision Layers Reference

| Layer | Name        | Used By                   |
| ----- | ----------- | ------------------------- |
| 1     | Player      | Ship (CharacterBody2D)    |
| 4     | Projectiles | Player projectiles        |
| 8     | Enemies     | All enemy types           |
| 16    | Pickups     | XP pickups, items         |
| 32    | PickupRange | Ship's PickupRange Area2D |

### Collision Masks

| Node        | Layer | Mask      | Detects                   |
| ----------- | ----- | --------- | ------------------------- |
| Ship        | 1     | 8         | Enemies                   |
| Projectile  | 4     | 8         | Enemies                   |
| BaseEnemy   | 8     | 5 (1+4)   | Player + Projectiles      |
| XPPickup    | 16    | 33 (1+32) | Player body + PickupRange |
| PickupRange | 32    | 16        | Pickups                   |

---

## Key Script Locations

| Script                | Path                                 | Purpose                              |
| --------------------- | ------------------------------------ | ------------------------------------ |
| `ship.gd`             | `scripts/player/ship.gd`             | Player movement, Phase Shift, stats  |
| `weapon_component.gd` | `scripts/combat/weapon_component.gd` | Auto-fire weapons, spawn projectiles |
| `projectile.gd`       | `scripts/combat/projectile.gd`       | Projectile movement, hit detection   |
| `stats_component.gd`  | `scripts/core/stats_component.gd`    | HP, stats, damage handling           |
| `base_enemy.gd`       | `scripts/enemies/base_enemy.gd`      | Enemy chase, damage, death           |
| `enemy_spawner.gd`    | `scripts/systems/enemy_spawner.gd`   | Spawn enemies, XP drops              |
| `xp_pickup.gd`        | `scripts/pickups/xp_pickup.gd`       | Magnetic attraction, collection      |
| `game_manager.gd`     | `globals/game_manager.gd`            | Game state, XP, level-up             |
| `data_loader.gd`      | `globals/data_loader.gd`             | Load JSON data, mod support          |
| `file_logger.gd`      | `globals/file_logger.gd`             | Debug logging to file                |

---

## Scene Node Hierarchy

### Ship (`scenes/gameplay/ship.tscn`)

```
Ship (CharacterBody2D) [layer=1, mask=8, group="player"]
├── StatsComponent (Node)
├── WeaponComponent (Node2D)
├── Sprite2D (AnimatedSprite2D)
├── CollisionShape2D (radius=24.08)
├── PickupRange (Area2D) [layer=32, mask=16]
│   └── PickupRangeShape (CollisionShape2D, radius=40)
└── Camera2D
```

### BaseEnemy (`scenes/enemies/base_enemy.tscn`)

```
BaseEnemy (CharacterBody2D) [layer=8, mask=5, group="enemies"]
├── Sprite2D
├── CollisionShape2D
└── HitboxArea (Area2D) [layer=8, mask=1]
    └── HitboxShape (CollisionShape2D)
```

### XPPickup (`scenes/pickups/xp_pickup.tscn`)

```
XPPickup (Area2D) [layer=16, mask=33]
├── CollisionShape2D
└── ColorRect (visual)
```

---

## Signal Flow

### Enemy Death → XP Collection → Level Up

```
Enemy dies
    ↓
enemy.died signal emitted
    ↓
EnemySpawner._on_enemy_died() → calls _spawn_xp()
    ↓
XPPickup instantiated at death position
    ↓
Player enters PickupRange
    ↓
XPPickup._on_area_entered() → attract_to(player)
    ↓
XP magnetically moves to player
    ↓
XPPickup collides with player body
    ↓
XPPickup._collect() → ProgressionManager.add_xp()
    ↓
ProgressionManager checks if xp >= xp_required
    ↓
ProgressionManager._level_up() → UpgradeService.generate_level_up_options()
    ↓
UpgradeService rolls rarity, picks stats → returns Array[Dictionary]
    ↓
RunManager.on_level_up_triggered() → emits level_up_started signal
    ↓
LevelUp UI shows options, player picks one
    ↓
ProgressionManager.apply_level_up_option() → applies stat/weapon changes
```

---

## Common Gotchas & Solutions

### Area2D-to-Area2D Detection Not Working

**Problem**: `area_entered` signal never fires between two Area2D nodes.

**Solution**: Both Area2Ds need:

- `monitoring = true`
- `monitorable = true`
- Correct collision layers/masks (one's layer must match other's mask)

### DataLoader Returns Array, Not Dictionary

**Problem**: `DataLoader.get_all_weapons()` returns Array, not Dictionary.

**Solution**: Iterate directly over array:

```gdscript
# WRONG
var weapons: Dictionary = DataLoader.get_all_weapons()
for weapon_id in weapons:
    var weapon = weapons[weapon_id]

# RIGHT
var weapons: Array = DataLoader.get_all_weapons()
for weapon in weapons:
    var weapon_id = weapon.get("id", "")
```

### "Can't change state while flushing queries" Error

**Problem**: Adding/removing nodes during physics callbacks (signals from collisions).

**Solution**: Use `call_deferred`:

```gdscript
# WRONG
get_tree().current_scene.add_child(node)

# RIGHT
get_tree().current_scene.call_deferred("add_child", node)
```

### Weapon Stats Not Loading

**Problem**: Weapons use nested `base_stats` dict in JSON.

**Solution**: Access nested dictionary:

```gdscript
# WRONG
var damage = weapon_data.get("damage", 10)

# RIGHT
var base_stats = weapon_data.get("base_stats", {})
var damage = base_stats.get("damage", 10)
```

### Autoload Not Found at Runtime

**Problem**: `get_node("/root/GameManager")` returns null.

**Solution**:

1. Ensure autoload is registered in Project Settings
2. Use `@onready` to defer until tree is ready:

```gdscript
@onready var GameManager: Node = get_node("/root/GameManager")
```

### Projectile/Node Not Visible

**Problem**: Node spawns but isn't visible.

**Checklist**:

1. Is `visible = true`?
2. Is texture assigned and valid?
3. Is z_index correct (not behind other nodes)?
4. Is scale non-zero?
5. Is modulate alpha > 0?

---

## Coding Conventions

### GDScript Style

```gdscript
# Use static typing everywhere - ALWAYS use explicit types, NEVER use := for type inference
var speed: float = 100.0
var enemies: Array[Enemy] = []
var direction: Vector2 = Vector2.ZERO

# WRONG - Do not use type inference
var speed := 100.0
var direction := get_direction()

# RIGHT - Always specify the type explicitly
var speed: float = 100.0
var direction: Vector2 = get_direction()

# Use @export for inspector-editable values
@export var max_hp: int = 100
@export var weapon_scene: PackedScene

# Use @onready for node references
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

# Signals for decoupled communication
signal died
signal damage_taken(amount: int)
```

**IMPORTANT**: Never use `:=` for type inference. Always declare variables with explicit types using `: Type =`. This prevents type inference errors and makes code more readable.

### Naming Conventions

| Type      | Convention                 | Example                                |
| --------- | -------------------------- | -------------------------------------- |
| Classes   | PascalCase                 | `PlayerShip`, `WeaponManager`          |
| Functions | snake_case                 | `take_damage()`, `spawn_enemy()`       |
| Variables | snake_case                 | `max_hp`, `current_weapon`             |
| Constants | SCREAMING_SNAKE            | `MAX_WEAPONS`, `DEFAULT_SPEED`         |
| Signals   | past_tense for events      | `died`, `level_up_completed`           |
| Signals   | present_tense for requests | `damage_requested`                     |
| Files     | snake_case                 | `ship_controller.gd`, `main_menu.tscn` |
| Nodes     | PascalCase                 | `PlayerShip`, `WeaponManager`          |

### Signal Usage

- Use signals for **decoupled communication** between systems
- Prefer signals over direct node references when possible
- Document signal parameters in comments

```gdscript
## Emitted when the player takes damage
## @param amount: The amount of damage taken
## @param source: The node that dealt the damage
signal damage_taken(amount: int, source: Node)
```

---

## JSON Data Schemas

### weapons.json

Stores visual/scene configuration for each weapon. Gameplay stats and upgrade scaling live in `weapon_upgrades.json`.

```json
{
  "radiant_arc": {
    "display_name": "Radiant Arc",
    "type": "melee",
    "scene": "res://effects/radiant_arc/RadiantArc.tscn",
    "spawner": "res://effects/radiant_arc/radiant_arc_spawner.gd",
    "stats": { "cooldown": 1.0, "damage": 10.0, "duration": 1.0 },
    "shape": { "arc_angle_deg": 310.0, "radius": 156.0, "thickness": 65.0 },
    "motion": { "fade_in": 0.18, "fade_out": 0.15, "sweep_speed": 1.0 },
    "visual": { "color_a": "#ff0000", "glow_strength": 10.0 },
    "unlock_condition": "default"
  }
}
```

### weapon_upgrades.json

Stores per-weapon, per-rarity-tier stat tables for the Megabonk hybrid upgrade model. Each weapon's `tier_stats` defines which stats are eligible for upgrades and their deterministic baseline deltas per rarity tier (Common/Uncommon/Rare/Epic/Legendary). Values are decimals (e.g., 20% → 0.20).

```json
{
  "radiant_arc": {
    "display_name": "Radiant Arc",
    "base_behavior": "Emits a short-range photonic slash...",
    "type": "melee",
    "element": "none",
    "special": "none",
    "tags": ["melee", "slash"],
    "strategy_synergies": "Prioritize damage/count then size...",
    "tier_stats": {
      "damage": { "common": 2.0, "uncommon": 2.4, "rare": 2.8, "epic": 3.2, "legendary": 4.0 },
      "projectile_count": { "common": 1.0, "uncommon": 1.2, "rare": 1.4, "epic": 1.6, "legendary": 2.0 },
      "size": { "common": 0.2, "uncommon": 0.24, "rare": 0.28, "epic": 0.32, "legendary": 0.4 }
    }
  }
}
```

#### Megabonk Hybrid Upgrade Model

When a player re-picks a weapon at level-up:

1. **Rarity roll**: Luck-weighted random roll determines rarity (common → legendary)
2. **Stat pick**: `WEAPON_STAT_PICK_COUNT[rarity]` determines how many stats improve (e.g., Common: 1–2, Legendary: 2–3)
3. **Stat selection**: Weighted random from the weapon's `tier_stats` keys using `WEAPON_UPGRADE_STAT_WEIGHTS`
4. **Delta computation**: Read `tier_stats[stat][rarity]`, multiply by `WEAPON_RARITY_FACTORS[rarity]` (if mode = `baseline_plus_factor`)
5. **Apply**: Returns `[{stat, kind, amount}]` array consumed by `WeaponComponent.apply_level_up_effects()`

Config toggles in `GameConfig`:

- `WEAPON_TIER_VALUE_MODE`: `"baseline_plus_factor"` (default) or `"direct"` (raw tier values)
- `WEAPON_STAT_PICK_COUNT`: min/max stat picks per rarity
- `WEAPON_RARITY_FACTORS`: multiplier per rarity tier
- `WEAPON_MIN_POSITIVE_DELTA`: floor for positive deltas

### ships.json

```json
{
  "scout": {
    "id": "scout",
    "name": "Scout",
    "description": "Fast and agile reconnaissance vessel",
    "sprite": "res://assets/ships/scout.png",
    "base_speed": 100,
    "base_stats": {
      "max_hp": 80,
      "evasion": 10
    },
    "starting_weapon": "plasma_cannon",
    "phase_shift": {
      "charges": 3,
      "variant": "blink"
    },
    "unlock_condition": "default"
  }
}
```

### captains.json

```json
{
  "captain_1": {
    "id": "captain_1",
    "name": "Captain 1",
    "description": "Offense-focused captain",
    "sprite": "res://assets/captains/captain_1.png",
    "passive": {
      "id": "combat_focus",
      "name": "Combat Focus",
      "description": "+5% crit chance, +10% damage",
      "effects": { "crit_chance": 5, "damage": 0.1 }
    },
    "active_ability": {
      "id": "overdrive",
      "name": "Overdrive",
      "description": "Weapons deal 2x damage for 5 seconds.",
      "template": "buff_self",
      "cooldown": 75.0,
      "duration": 5.0,
      "effects": { "damage": 1.0 },
      "vfx": "overdrive"
    },
    "unlock_condition": "default"
  }
}
```

### synergies.json

```json
{
  "scout+captain_1": {
    "ship_id": "scout",
    "captain_id": "captain_1",
    "name": "Precision Strike",
    "description": "Nimble frame lets overdrive target weak points.",
    "discovered_text": "Something clicks between the scout's agile frame and your combat instincts...",
    "effects": { "crit_chance": 3, "crit_damage": 0.05 }
  }
}
```

### ship_upgrades.json (Tomes equivalent)

```json
{
  "damage_module": {
    "id": "damage_module",
    "name": "Damage Module",
    "description": "Increases weapon damage",
    "icon": "res://assets/icons/damage_module.png",
    "stat": "damage",
    "per_level": 0.08,
    "max_level": 99,
    "rarity_weights": { "common": 60, "uncommon": 25, "rare": 10, "epic": 4, "legendary": 1 }
  }
}
```

### items.json

```json
{
  "shield_booster": {
    "id": "shield_booster",
    "name": "Shield Booster",
    "description": "+25 Shield",
    "icon": "res://assets/icons/shield_booster.png",
    "rarity": "common",
    "effects": {
      "shield": 25
    },
    "unlock_condition": "default",
    "stacks": true,
    "max_stacks": 5
  }
}
```

### enemies.json

```json
{
  "drone": {
    "id": "drone",
    "name": "Drone",
    "scene": "res://scenes/enemies/drone.tscn",
    "base_stats": {
      "hp": 10,
      "damage": 5,
      "speed": 100,
      "xp_value": 1
    },
    "behavior": "chase",
    "spawn_weight": 100,
    "min_difficulty": 0
  }
}
```

---

## Implementation Priority

### Phase 1: Core Foundation

1. [x] `DataLoader` autoload - JSON loading and mod merging
2. [x] `StatsComponent` - Stat tracking with modifiers
3. [x] `GameManager` autoload - State management, scene transitions
4. [x] Basic enemy with chase behavior
5. [x] Damage system (deal/receive damage)

### Phase 2: Combat Loop

6. [x] Weapon system - Auto-firing weapons from data
7. [x] XP system - Collection, level up trigger
8. [x] Level-up UI - Choose 1 of 3 upgrades
9. [x] Ship upgrades (tomes) implementation
10. [x] Phase Shift ability

### Phase 3: Run Structure

11. [x] Run timer and wave manager
12. [x] Enemy wave spawning (progressive difficulty)
13. [ ] Miniboss spawning at intervals
14. [ ] Final boss beacon mechanic
15. [ ] Final Swarm mode

### Phase 4: Content & Polish

16. [ ] Space Gas Stations (charge shrines)
17. [ ] Cargo Pods (chests), Space Vendors
18. [ ] Minable asteroids with loot
19. [ ] Multiple weapons and items
20. [ ] Multiple characters

### Phase 5: Meta & Steam

21. [ ] Meta-progression (Stardust unlocks)
22. [ ] Save/load system
23. [ ] Main menu, settings
24. [ ] Steam integration
25. [ ] Mod workshop support

---

## Map Generation

### Arena Structure

- **Fixed size arena** (configurable, e.g., 4096x4096 pixels)
- **Procedurally placed obstacles** at run start using `GameSeed`
- **Boundary enforcement** - invisible walls or damage zone at edges

### Obstacle Types

| Type              | Behavior                           | Placement                   |
| ----------------- | ---------------------------------- | --------------------------- |
| Large Asteroids   | Static collision, indestructible   | Map generator at run start  |
| Wrecked Ships     | Static collision, may contain loot | Map generator at run start  |
| Minable Asteroids | Interactive, respawns, drops loot  | Obstacle manager during run |
| Space Debris      | Small static collision             | Map generator scatter       |

---

## Audio Guidelines (Future)

- **Music**: Synthwave/electronic sci-fi ambient during gameplay
- **SFX**: Punchy weapon sounds, satisfying hit feedback
- **Adaptive**: Music intensity scales with enemy density/boss fights
- **Spatial**: Enemy sounds positioned in 2D space

---

## Testing Checklist

When implementing new features, verify:

- [ ] Works with `GameSeed` (deterministic if applicable)
- [ ] Stats properly apply modifiers
- [ ] JSON data loads correctly
- [ ] No memory leaks (nodes freed properly)
- [ ] Signals connected/disconnected appropriately
- [ ] Works at different zoom levels
- [ ] Performance acceptable with many enemies

### Mandatory Runtime Sanity Check (Headless Godot)

After any code or data change, run a headless Godot launch to catch integration/load/runtime startup issues that static checks can miss.

Command:

```powershell
& "C:\git\godot\Godot_v4.6-stable_win64\Godot_v4.6-stable_win64.exe" --headless --path "C:\git\voidrift" --import --quit
```

Preferred local workflow:

- Run VS Code task: `godot: headless sanity check`
- Or run script directly: `tools/headless_sanity_check.ps1`

Agent rule: After any non-trivial code or data change, always run this headless sanity check before reporting completion.

Pass/fail criteria:

- Pass: process exits with code `0`
- Fail: non-zero exit code, or new error output in startup logs

Recommended captured logs for debugging:

- `debug_log_headless_stdout.txt`
- `debug_log_headless_stderr.txt`

### Mandatory Weapon Implementation Verification (Do Not Skip)

When adding or changing any weapon, do **all** checks below before reporting completion:

- [ ] Weapon is `enabled` in `data/weapons.json` when intended for active testing
- [ ] Unlock path is valid for existing saves (default unlocks or migration in `PersistenceManager`)
- [ ] Weapon appears in run selection/equip flow (not just present in JSON)
- [ ] Effect node actually spawns (verify via `FileLogger` in `debug_log.txt`)
- [ ] Effect is visibly rendered (z-index/layer/alpha/scale validated)
- [ ] Core behavior works in-game (damage, collision/contact, movement/orbit)
- [ ] Stat scaling works (`damage`, `projectile_count`, `size`, `speed`, `knockback`, etc. as applicable)
- [ ] Persistent effects clean up correctly on unequip/remove
- [ ] `get_errors` shows no new script/JSON errors in edited files

Never mark a weapon task as done if any checkbox above is unverified.

---

## Debugging Technique: FileLogger

When debugging issues in Godot, **always use the FileLogger system** to write debug output to a file that can be read directly from the workspace.

### How It Works

The `FileLogger` autoload (`globals/file_logger.gd`) writes all log output to `debug_log.txt` at the project root (`c:\git\voidrift\debug_log.txt`). The file is **deleted on each game startup** so it only contains logs from the current session.

### Usage

```gdscript
# Add FileLogger reference in any script
@onready var FileLogger: Node = get_node("/root/FileLogger")

# Log methods available:
FileLogger.log_info("SourceName", "Information message")
FileLogger.log_debug("SourceName", "Debug details")
FileLogger.log_warn("SourceName", "Warning message")
FileLogger.log_error("SourceName", "Error message")
FileLogger.log_data("SourceName", "label", some_dictionary)  # Logs as formatted JSON
```

### Debugging Workflow

1. **Add FileLogger reference** to the script being debugged
2. **Add log statements** at key points (initialization, function entry, state changes, signal handlers)
3. **Run the game** and reproduce the issue
4. **Read `debug_log.txt`** from the workspace to see what happened
5. **Analyze the logs** to identify where the issue occurs

### Example Debug Session

```gdscript
func _ready() -> void:
    FileLogger.log_info("MyScript", "Initializing...")
    FileLogger.log_debug("MyScript", "collision_layer: %d, collision_mask: %d" % [collision_layer, collision_mask])

func _on_area_entered(area: Area2D) -> void:
    FileLogger.log_debug("MyScript", "Area entered: %s" % area.name)
```

### Why This Technique?

- **Copilot can read the log file** directly from the workspace without needing screenshots
- **Persistent output** - logs survive even if Godot crashes
- **Timestamped** - easy to correlate events
- **Structured** - source names make filtering easy
- **No console spam** - logs go to file, keeping Godot console cleaner

### Log File Location

The log file is always at: `res://debug_log.txt` (project root)

Absolute path: `c:\git\voidrift\debug_log.txt`

---

## Development Guidelines

### Weapon Test Lab Maintenance

**IMPORTANT**: When making any changes to a weapon or its parameters:

1. Always update the weapon's default config in `weapon_test_lab.gd` (`_get_default_config()`)
2. Always add slider ranges for new parameters in `weapon_test_ui.gd` (`_get_slider_range()`)
3. Ensure the parameter names match exactly between the weapon script's `@export` variables and the test lab config keys
4. Test all new parameters in the weapon test lab before considering the feature complete

This ensures the test lab remains a reliable tool for tuning and testing all weapon behaviors.

---

## Development Progress

**IMPORTANT**: Update this section when the user says "lock it in".

### ✅ Completed Features

- **Core Systems**: DataLoader, StatsComponent, GameManager autoloads
- **Player Ship**: Movement (WASD), Phase Shift with i-frames and energy charges
- **Weapons**: WeaponComponent with auto-fire, projectiles spawning and hitting enemies
- **Enemies**: BaseEnemy with chase behavior, contact damage, death handling
  - Red tint to differentiate from player
  - Contact damage uses `move_and_slide()` collision detection (continuous, not signal-based)
  - No knockback by default (can be added via weapons/items)
- **XP System**: XP pickups drop on enemy death, magnetic attraction to player within PickupRange
- **Credit System**: Gold credit pickups drop randomly (50% chance), magnetic attraction, collected to spend on rerolls
- **Enemy Spawner**: Spawns enemies around player, scales with time
- **FileLogger**: Debug logging system writes to `debug_log.txt` at project root
- **HUD**:
  - HP bar (top left), Level text (top center), Timer + FPS + Credits (top right)
  - XP bar full-width at bottom of screen
  - Synthwave color theme: Hot pink HP, neon purple XP, cyan countdown timer, yellow level text, gold credits
  - Level-up animation: Elastic bounce with pink flash
  - Timer flashes red when under 60 seconds
  - Credits display with pulse animation on pickup
- **Player Damage Feedback**:
  - White → Red flash + blinking during i-frames
  - Knockback away from damage source
  - 0.5s i-frames after taking damage
- **Timer**: Configurable countdown (default 10 minutes) via `GameManager.run_duration`
- **Level-up UI**:
  - 3 upgrade option cards with synthwave styling (320x420 each)
  - Shows ship upgrades (cyan border) and new weapons (red border)
  - Displays upgrade name, description, and stat bonus
  - Refresh button (costs 25 credits) to reroll options
  - Skip button to skip level-up
  - Keyboard shortcuts: 1/2/3 to select, R to refresh, ESC/S to skip
  - Cards animate in with scale+fade effect
  - Large readable fonts (72px title, 28px card names, 20px descriptions)
- **Configuration & Balancing**:
  - `GameConfig` autoload created for centralized tuning (globals/game_config.gd)
  - **Player Movement**: Base speed 150 (down from 250), added banking sway (15.0 speed) for smoother feel. Pivot offset adjusted (-6px).
  - **Enemy Scaling**: Base speed 100, scales +2.5 per player level. This ensures enemies are slower early on but catch up.
  - **Spawning**: "Slow burn" start (0.5 spawn rate) ramping up (+0.2/min). Makes early game less chaotic.
  - **Pickup Radius**: Reduced magnet range to 40px (50% reduction) requiring closer proximity to loot.
- **Ship + Captain System**: Ship selection with different base stats/weapons, Captain with passive bonuses and active abilities (buff_self template)
- **Synergies**: Ship+captain combo bonuses loaded from synergies.json, tracked in PersistenceManager
- **Weapon Effects (17)**: radiant_arc, snarky_comeback, nikolas_coil, nope_bubble, space_napalm, ion_wake, personal_space_violator, orbit_base, spin_cycle, straight_line_negotiator, timmy_gun, tothian_mines, space_nukes, broken_tractor_beam, aoe_base (+ beam_base, projectile_base stubs)
- **Weapon Test Lab**: Full editing UI with sliders, save/reload, hitbox debug overlay, target spawning
- **Options Menu**: Audio volume (master/SFX/music), fullscreen, vsync settings with persistence
- **Ability System**: Abstract base_ability.gd + buff_self_ability.gd template, data-driven from captains.json
- **Run Manager**: Run lifecycle (start/end), scene transitions, pause/resume
- **Progression Manager**: XP tracking, level-up flow, upgrade application delegates
- **Upgrade Service**: Level-up option generation with rarity rolling, weapon tier stat picks
- **Persistence Manager**: Save/load system for unlocks, best times, discovered synergies
- **Settings Manager**: Audio + display settings with ConfigFile persistence
- **Game Over Screen**: Stats display, restart/menu options

### 🔄 In Progress

- None

### 📋 TODO (Priority Order)

1. **Camera orbit** - Right stick/mouse rotates camera around ship
2. **More enemy variety** - Different enemy types with behaviors
3. **Miniboss spawning** - Boss enemies at timed intervals
4. **Final boss beacon** - End-game boss mechanic
5. **Sound effects** - Shooting, enemy death, XP pickup, level up
6. **Visual polish** - Screen shake, particles, damage numbers

### 🐛 Known Issues

- Godot shows "invalid UID" warnings on load (cosmetic, doesn't affect gameplay)

---

## Useful Resources

- [Megabonk Wiki](https://megabonk.wiki/wiki/Main_Page) - Reference for mechanics
- [Godot 4 Docs](https://docs.godotengine.org/en/stable/)
- [GDQuest](https://www.gdquest.com/) - Godot tutorials

---

_Last updated: February 14, 2026_
