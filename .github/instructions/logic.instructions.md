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

### Collision Masks

| Node        | Layer | Mask      | Detects                   |
| ----------- | ----- | --------- | ------------------------- |
| Ship        | 1     | 8         | Enemies                   |
| Projectile  | 4     | 8         | Enemies                   |
| BaseEnemy   | 8     | 5 (1+4)   | Player + Projectiles      |
| XPPickup    | 16    | 33 (1+32) | Player body + PickupRange |
| PickupRange | 32    | 16        | Pickups                   |

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
