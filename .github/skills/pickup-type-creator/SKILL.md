---
name: pickup-type-creator
description: Step-by-step procedure for creating new pickup types in Super Cool Space Game following the BasePickup pattern — script, scene, and integration.
---

# Pickup Type Creator Skill

Use this skill when asked to create a new collectible pickup type. All pickups extend `BasePickup` and require very little unique code (~5 lines).

## When to Activate

- Creating a new pickup type (resource, buff, powerup)
- Adding a new collectible that enemies drop or world objects scatter

## Existing Pickup Types (Reference)

| Pickup          | Script               | Effect                                    | Magnet Behavior           |
| --------------- | -------------------- | ----------------------------------------- | ------------------------- |
| XP Pickup       | `xp_pickup.gd`       | `ProgressionManager.add_xp(amount)`       | Player's PickupRange area |
| Credit Pickup   | `credit_pickup.gd`   | `ProgressionManager.add_credits(amount)`  | Player's PickupRange area |
| Stardust Pickup | `stardust_pickup.gd` | `ProgressionManager.add_stardust(amount)` | Player's PickupRange area |

All three follow an identical pattern. The only differences are the `@export` type and the `_apply_effect()` call.

## Step-by-Step Procedure

### Step 1: Create Pickup Script

Place in `scripts/pickups/{pickup_name}_pickup.gd`.

```gdscript
extends BasePickup

## {PickupName}Pickup - {Description of what this pickup does}.

@export var {resource}_amount: float = 1.0


func _on_pickup_ready() -> void:
	pass


func initialize(amount: float) -> void:
	{resource}_amount = amount


func _apply_effect() -> void:
	# Apply the pickup's effect via the appropriate autoload
	ProgressionManager.add_{resource}({resource}_amount)
```

That's the entire script. The `BasePickup` base class handles:

- Magnetic attraction to player (`PICKUP_MAGNET_SPEED`, `PICKUP_MAGNET_ACCELERATION`)
- Collection on player body contact
- `queue_free()` after collection
- Group membership (`"pickups"`)
- Signal connections (`body_entered`, `area_entered`)

### Step 2: Create Pickup Scene

Save as `scenes/pickups/{pickup_name}_pickup.tscn`.

**Scene hierarchy:**

```
Area2D ({pickup_name}_pickup.gd)
├── CollisionShape2D     # CircleShape2D (radius ~8-12px)
└── Sprite2D             # Visual icon for the pickup
```

**Collision layer setup (mandatory):**

- **Layer**: 16 (Pickups)
- **Mask**: 33 (1 + 32 = Player body + PickupRange)

### Step 3: Add Visual Differentiation

Pickups need to be visually distinct. Options:

- Different `Sprite2D` texture
- Different `modulate` color on the sprite
- Procedural visuals via shader or `_draw()` override

For stardust pickup, a custom shader effect is used (`effects/stardust_pickup/`). For simpler pickups, a colored sprite suffices.

### Step 4: Wire Spawning

Pickups are spawned by the system that creates them:

**Enemy death drops** — handled in `scripts/systems/enemy_spawner.gd`:

```gdscript
# The spawner reads xp_value, credit_value, stardust_value from the enemy
# and spawns the appropriate pickup scenes with scatter offset
```

**World object loot** — handled in the interactable's `_spawn_loot()`:

```gdscript
var pickup: Node = PICKUP_SCENE.instantiate()
pickup.global_position = global_position + _scatter_offset()
pickup.initialize(amount)
parent.add_child(pickup)
```

**Scatter offsets** are defined in GameConfig:

```gdscript
const PICKUP_SCATTER_XP: float = 15.0
const PICKUP_SCATTER_CREDIT: float = 20.0
const PICKUP_SCATTER_BURST: float = 25.0
const PICKUP_SCATTER_STARDUST: float = 18.0
```

Add a new scatter constant for the new pickup type.

### Step 5: Fixed Magnet Radius (Optional)

If the pickup should attract from a fixed distance (ignoring player's PickupRange area), override:

```gdscript
func _get_fixed_magnet_radius() -> float:
	return 200.0  # Fixed attraction radius in pixels
```

And call `_check_fixed_radius_attraction(player)` from `_process()`:

```gdscript
func _process(delta: float) -> void:
	super._process(delta)
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_check_fixed_radius_attraction(players[0] as Node2D)
```

## Checklist

- [ ] Pickup script: `scripts/pickups/{pickup_name}_pickup.gd` extending `BasePickup`
- [ ] Scene: `scenes/pickups/{pickup_name}_pickup.tscn`
- [ ] Collision layers: Layer 16, Mask 33 (Player + PickupRange)
- [ ] `_apply_effect()` overridden with correct autoload call
- [ ] `initialize(amount)` method for setting value at spawn time
- [ ] Visual differentiation (sprite, color, or shader)
- [ ] Spawning wired (enemy death, world object, or other source)
- [ ] Scatter offset added to GameConfig (if used in burst drops)
- [ ] Headless sanity check passes
