---
applyTo: "**/*.gd"
---

# GDScript Logic — Voidrift Conventions

## Explicit Typing (Required)

- Always explicitly type variables, function parameters, and return types.
- **Never** use `:=` for type inference. Always use `: Type =`.
- Prefer typed containers: `Array[Dictionary]`, `Array[String]`, `Dictionary`, etc.
- If a value is Variant/untyped (e.g. from JSON), cast immediately with `String(...)`, `int(...)`, `float(...)`, and use `get()` instead of dot-access.

```gdscript
# WRONG
var speed := 100.0
var direction := get_direction()

# RIGHT
var speed: float = 100.0
var direction: Vector2 = get_direction()
var candidates: Array[Dictionary] = []
var weapon_id: String = String(weapon_id_any)
func _pick_weighted_index(items: Array[Dictionary]) -> int:
```

## Doc Comments (`##` not `"""`)

GDScript uses `##` for doc comments. Triple-quoted strings are Python-style and generate no documentation in GDScript.

```gdscript
# WRONG
func take_damage(amount: float) -> float:
    """Apply damage after armor/evasion."""
    ...

# RIGHT
## Apply damage after armor/evasion. Returns actual damage taken.
func take_damage(amount: float) -> float:
    ...
```

## JSON Value Casting (Required)

When reading values from `Dictionary.get()` on parsed JSON data, always cast immediately. JSON numbers are Variant and may be int or float unpredictably.

```gdscript
# WRONG
damage = stats.get("damage", damage)

# RIGHT
damage = float(stats.get("damage", damage))
count = int(stats.get("count", count))
enabled = bool(stats.get("enabled", enabled))
```

## Naming Conventions

| Type      | Convention      | Example                          |
| --------- | --------------- | -------------------------------- |
| Classes   | PascalCase      | `PlayerShip`, `WeaponManager`    |
| Functions | snake_case      | `take_damage()`, `spawn_enemy()` |
| Variables | snake_case      | `max_hp`, `current_weapon`       |
| Constants | SCREAMING_SNAKE | `MAX_WEAPONS`, `DEFAULT_SPEED`   |
| Signals   | past_tense      | `died`, `level_up_completed`     |
| Files     | snake_case      | `ship_controller.gd`             |
| Nodes     | PascalCase      | `PlayerShip`, `WeaponManager`    |

## Signal Usage

- Use signals for decoupled communication between systems.
- Prefer signals over direct node references when possible.
- Document signal parameters with `##` doc comments.

```gdscript
## Emitted when the player takes damage.
## @param amount: The amount of damage taken
## @param source: The node that dealt the damage
signal damage_taken(amount: int, source: Node)
```

## GDScript Style Essentials

```gdscript
# @export for inspector-editable values
@export var max_hp: int = 100
@export var weapon_scene: PackedScene

# @onready for node references
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

# Autoload references via get_node_or_null
@onready var GameManager: Node = get_node_or_null("/root/GameManager")

# Signals for decoupled communication
signal died
signal damage_taken(amount: int)
```

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

### What Does NOT Belong in GameConfig

- Per-weapon or per-ship data → stays in `data/*.json`
- Purely structural constants (file paths, scene paths, stat names)
- UI layout sizes set in `.tscn` files

---

## Scaling Systems

### XP Curve (Player Leveling)

Uses polynomial formula for predictable, tunable progression:

```
threshold(level) = Σ XP_BASE * n^XP_EXPONENT  for n = 1 to level-1
```

**Constants:** `XP_BASE` (first level cost), `XP_EXPONENT` (curve steepness)

```gdscript
## Cumulative XP threshold to reach a given level.
func _xp_threshold(level: int) -> float:
    if level <= 1:
        return 0.0
    var total: float = 0.0
    for n: int in range(1, level):
        total += GameConfig.XP_BASE * pow(float(n), GameConfig.XP_EXPONENT)
    return total
```

### Enemy Scaling (Over Time)

Enemies scale with run time using polynomial HP and linear damage:

```gdscript
# HP: polynomial scaling
var time_hp_mult: float = 1.0 + pow(time_minutes, GameConfig.ENEMY_HP_EXPONENT)

# Damage: linear scaling
var time_damage_mult: float = 1.0 + (time_minutes * GameConfig.ENEMY_DAMAGE_SCALE_PER_MINUTE)
```

### Difficulty Stat Integration

Player's `difficulty` stat (0.0 = 0%, 1.0 = 100%) multiplies enemy scaling:

```gdscript
var diff_hp_mult: float = 1.0 + (difficulty_stat * GameConfig.DIFFICULTY_HP_WEIGHT)
var diff_damage_mult: float = 1.0 + (difficulty_stat * GameConfig.DIFFICULTY_DAMAGE_WEIGHT)
var final_hp_mult: float = time_hp_mult * diff_hp_mult
var final_damage_mult: float = time_damage_mult * diff_damage_mult
```

Also affects spawn rate in `_get_spawn_interval()`.

### Static XP Drops

XP drops are **not scaled** by time or difficulty:

```gdscript
enemy.xp_value = GameConfig.ENEMY_XP_ELITE if is_elite else GameConfig.ENEMY_XP_NORMAL
```

**Constants:** `ENEMY_XP_NORMAL = 1.0`, `ENEMY_XP_ELITE = 3.0`

### Elite Enemies

Rolled per spawn with player's `elite_spawn_rate` modifier:

```gdscript
func _roll_for_elite() -> bool:
    var base_chance: float = GameConfig.ELITE_BASE_CHANCE  # 0.05 = 5%
    var elite_mult: float = _get_player_elite_spawn_rate()
    return randf() < (base_chance * elite_mult)
```

Elites get:

- `ELITE_HP_MULT` (3×), `ELITE_DAMAGE_MULT` (2×)
- Visual: `ELITE_COLOR` (orange tint), `ELITE_SIZE_SCALE` (1.3×)
- `enemy_type = "elite"` for tracking

### Swarm Events

Temporary spawn rate boost at fixed times during the run:

```gdscript
const SWARM_TIMES: Array[float] = [240.0, 420.0]  # 4 min, 7 min
const SWARM_DURATION_MIN: float = 45.0
const SWARM_DURATION_MAX: float = 60.0
const SWARM_SPAWN_MULTIPLIER: float = 3.0
```

Signals: `swarm_warning_started`, `swarm_started`, `swarm_ended`

HUD displays "A MASSIVE FLEET IS INBOUND" during warning phase.

### Arena Boundary System

The play area is a circular arena with a radiation danger zone at the edge:

```gdscript
const ARENA_RADIUS: float = 4000.0         # Circular play area radius (pixels)
const RADIATION_BELT_WIDTH: float = 800.0   # Width of radiation zone at edge
const RADIATION_DAMAGE_PER_SEC: float = 10.0
const RADIATION_PUSH_FORCE: float = 150.0
```

Key files:

- `scripts/core/arena_utils.gd` — Static helper for boundary calculations
- `scripts/systems/arena_boundary.gd` — Visual + damage/push mechanics

```gdscript
# Check if position is in radiation belt
func is_in_radiation_belt(pos: Vector2) -> bool:
    var dist: float = pos.length()
    var inner_edge: float = GameConfig.ARENA_RADIUS - GameConfig.RADIATION_BELT_WIDTH
    return dist >= inner_edge and dist <= GameConfig.ARENA_RADIUS
```

### Fog of War System

Gradient-based fog with smooth dissipating edges around explored areas:

```gdscript
const FOG_GRID_SIZE: int = 128       # Resolution of fog grid
const FOG_REVEAL_RADIUS: float = 800.0  # Radius revealed around player
const FOG_GLOW_INTENSITY: float = 0.6   # Neon glow brightness
const FOG_OPACITY: float = 0.5          # Overall fog transparency
```

Key files:

- `scripts/systems/fog_of_war.gd` — RefCounted class managing exploration grid
- `shaders/fog_of_war.gdshader` — Neon purple gas effect with FBM noise

```gdscript
# Reveal area around player with gradient edges
func reveal_radius(world_pos: Vector2, radius: float) -> void:
    # Creates gradient falloff from full reveal to fog
    # Uses _fade_cells for smooth transitions
```

### Minimap System

Circular minimap showing player surroundings with fog overlay:

```gdscript
const MINIMAP_SIZE: float = 180.0        # Minimap diameter (pixels)
const MINIMAP_WORLD_RADIUS: float = 1200.0  # World radius visible (controls zoom)
const FULLMAP_SIZE: float = 800.0        # Full map overlay size
```

Key files:

- `scripts/ui/minimap.gd` — Minimap rendering (player, enemies, pickups, boundary)
- `scripts/ui/full_map_overlay.gd` — Large map visible when holding Tab/RT

---

## Common Gotchas & Solutions

### Area2D-to-Area2D Detection Not Working

Both Area2Ds need `monitoring = true`, `monitorable = true`, and correct collision layers/masks (one's layer must match other's mask).

### DataLoader Returns Array, Not Dictionary

`DataLoader.get_all_weapons()` returns Array, not Dictionary. Iterate directly:

```gdscript
# WRONG
var weapons: Dictionary = DataLoader.get_all_weapons()

# RIGHT
var weapons: Array = DataLoader.get_all_weapons()
for weapon in weapons:
    var weapon_id: String = weapon.get("id", "")
```

### "Can't change state while flushing queries" Error

Adding/removing nodes during physics callbacks causes this. Use `call_deferred`:

```gdscript
# WRONG
get_tree().current_scene.add_child(node)

# RIGHT
get_tree().current_scene.call_deferred("add_child", node)
```

### Weapon Stats Not Loading

Weapons use nested `base_stats` dict in JSON. Access the nested dictionary:

```gdscript
# WRONG
var damage: float = weapon_data.get("damage", 10)

# RIGHT
var base_stats: Dictionary = weapon_data.get("base_stats", {})
var damage: float = base_stats.get("damage", 10)
```

### Autoload Not Found at Runtime

Ensure autoload is registered in Project Settings. Use `@onready` to defer until tree is ready:

```gdscript
@onready var GameManager: Node = get_node("/root/GameManager")
```

### `grab_focus()` Triggers Hover/Scale Tweens on Load

Focusable cards with `focus_entered` → hover tween will visually appear hovered the moment `grab_focus()` is called in `_ready()`. The user's mouse is nowhere near the card, but it looks stuck in hover state.

**Fix:** Call `reset_hover()` immediately after `grab_focus()` to kill the tween and reset scale/shader:

```gdscript
var first_card: PanelContainer = list.get_child(0) as PanelContainer
if first_card:
    first_card.grab_focus()
    CARD_HOVER_FX_SCRIPT.reset_hover(first_card, _card_hover_tweens, first_card.get_instance_id())
```

### Array.filter() Lambda Typing Error

**Do not use typed parameters in filter/map lambdas.** Causes "Cannot convert argument" errors at runtime:

```gdscript
# WRONG — crashes at runtime
_active_instances = _active_instances.filter(func(inst: Node) -> bool: return is_instance_valid(inst))

# RIGHT — use untyped parameter
_active_instances = _active_instances.filter(func(inst) -> bool: return is_instance_valid(inst))
```

### Projectile/Node Not Visible

Checklist: `visible = true`? Texture assigned? `z_index` correct? `scale` non-zero? `modulate` alpha > 0?

---

## Collision Layers Reference

| Layer | Name        | Used By                   |
| ----- | ----------- | ------------------------- |
| 1     | Player      | Ship (CharacterBody2D)    |
| 4     | Projectiles | Player projectiles        |
| 8     | Enemies     | All enemy types           |
| 16    | Pickups     | XP pickups, items         |
| 32    | PickupRange | Ship's PickupRange Area2D |
| 64    | Stations    | Space station BuffZone    |

### Collision Masks

| Node        | Layer | Mask      | Detects                   |
| ----------- | ----- | --------- | ------------------------- |
| Ship        | 1     | 8         | Enemies                   |
| Projectile  | 4     | 8         | Enemies                   |
| BaseEnemy   | 8     | 5 (1+4)   | Player + Projectiles      |
| XPPickup    | 16    | 33 (1+32) | Player body + PickupRange |
| PickupRange | 32    | 16        | Pickups                   |
| BuffZone    | 64    | 1         | Player                    |

---

## Debugging: FileLogger

Always use the FileLogger system for debug output. It writes to `debug_log.txt` at the project root (deleted on each game startup).

```gdscript
@onready var FileLogger: Node = get_node("/root/FileLogger")

FileLogger.log_info("SourceName", "Information message")
FileLogger.log_debug("SourceName", "Debug details")
FileLogger.log_warn("SourceName", "Warning message")
FileLogger.log_error("SourceName", "Error message")
FileLogger.log_data("SourceName", "label", some_dictionary)
```

### Debugging Workflow

1. Add FileLogger reference to the script being debugged
2. Add log statements at key points (init, function entry, state changes, signal handlers)
3. Run the game and reproduce the issue
4. Read `debug_log.txt` from the workspace
5. Analyze logs to identify the issue

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

After any code or data change, run a headless Godot launch:

```powershell
& "C:\git\godot\Godot_v4.6-stable_win64\Godot_v4.6-stable_win64.exe" --headless --path "C:\git\voidrift" --import --quit
```

Or use VS Code task: `godot: headless sanity check` / script: `tools/headless_sanity_check.ps1`

- **Pass**: exit code `0`
- **Fail**: non-zero exit code or new error output

### Mandatory Weapon Implementation Verification

When adding or changing any weapon, verify ALL of:

- [ ] Weapon is `enabled` in `data/weapons.json`
- [ ] Unlock path is valid (default unlocks or migration in `PersistenceManager`)
- [ ] Weapon appears in run selection/equip flow
- [ ] Effect node actually spawns (verify via FileLogger in `debug_log.txt`)
- [ ] Effect is visibly rendered (z-index/layer/alpha/scale validated)
- [ ] Core behavior works in-game (damage, collision, movement/orbit)
- [ ] Stat scaling works (damage, projectile_count, size, speed, knockback, etc.)
- [ ] Persistent effects clean up correctly on unequip/remove
- [ ] `get_errors` shows no new script/JSON errors

---

## Weapon Test Lab Maintenance

When making changes to a weapon or its parameters:

1. Update the weapon's default config in `weapon_test_lab.gd` (`_get_default_config()`)
2. Add slider ranges for new parameters in `weapon_test_ui.gd` (`_get_slider_range()`)
3. Ensure parameter names match exactly between the weapon script's `@export` variables and test lab config keys
4. Test all new parameters in the weapon test lab before considering the feature complete
