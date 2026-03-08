---
applyTo: "**/*.gd"
---

# GDScript Logic — Super Cool Space Game Conventions

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

## Scaling Systems & Domain Mechanics

> **Moved**: GameConfig rule, collision layers, and most domain-specific mechanics now live in dedicated instruction files. See `architecture.instructions.md`, `gameconfig.instructions.md`, `combat.instructions.md`, `enemies.instructions.md`, `player.instructions.md`, `world.instructions.md`, `ui.instructions.md`, and `progression.instructions.md`.

## FrameCache Rule (Mandatory)

**Never call `get_nodes_in_group("enemies")` or `get_nodes_in_group("damage_numbers")` directly.** Use the `FrameCache` autoload instead. It rebuilds once per frame (`process_priority = -100`) so all systems share a single query.

### How to Reference FrameCache

```gdscript
# In scene scripts (effects, enemies, UI, etc.):
@onready var FrameCache: Node = get_node("/root/FrameCache")

# Then use cached arrays:
var enemies: Array[Node] = FrameCache.enemies
var damage_nums: Array[Node] = FrameCache.damage_numbers
var grid: SpatialHashGrid = FrameCache.enemy_grid

# In static utility functions (no @onready available):
var cache: Node = tree.root.get_node_or_null("/root/FrameCache")
if cache:
    return cache.enemies
return tree.get_nodes_in_group("enemies")  # fallback
```

### What FrameCache Provides

| Property         | Type              | Contents                                       |
| ---------------- | ----------------- | ---------------------------------------------- |
| `enemies`        | `Array[Node]`     | All nodes in `"enemies"` group                 |
| `damage_numbers` | `Array[Node]`     | All nodes in `"damage_numbers"` group          |
| `enemy_grid`     | `SpatialHashGrid` | Spatial hash grid rebuilt from enemy positions |

---

The following gotchas remain here because they are GDScript-engine-level issues, not domain-specific.

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

Adding/removing nodes or toggling physics properties during physics callbacks causes this. Use `call_deferred` or `set_deferred`:

```gdscript
# WRONG
get_tree().current_scene.add_child(node)
_hitbox.monitoring = false  # inside body_entered callback

# RIGHT
get_tree().current_scene.call_deferred("add_child", node)
_hitbox.set_deferred("monitoring", false)  # deferred property set
```

### `is_instance_valid()` Before `as` Cast (Critical)

Casting a freed object with `as Node2D` (or any type) crashes **immediately** — before any validity check can run. Always check `is_instance_valid()` first:

```gdscript
# WRONG — crashes if entity is freed
for entity: Variant in bucket:
    var node: Node2D = entity as Node2D
    if node and is_instance_valid(node):
        ...

# RIGHT — check validity before cast
for entity: Variant in bucket:
    if not is_instance_valid(entity):
        continue
    var node: Node2D = entity as Node2D
    if node:
        ...
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
& "C:\git\godot\Godot_v4.6-stable_win64\Godot_v4.6-stable_win64.exe" --headless --path "C:\git\Super Cool Space Game" --import --quit
```

Or use VS Code task: `godot: headless sanity check` / script: `tools/headless_sanity_check.ps1`

- **Pass**: exit code `0`
- **Fail**: non-zero exit code or new error output
