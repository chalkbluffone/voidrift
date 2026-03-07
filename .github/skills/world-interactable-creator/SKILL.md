---
name: world-interactable-creator
description: Step-by-step procedure for creating world-placed interactable objects in Super Cool Space Game — shipwrecks, jettisoned cargo, beacons, and other objects the player can interact with.
---

# World Interactable Creator Skill

Use this skill when asked to create a new world object that the player can interact with. These are placed around the arena at run start and discovered through exploration.

## When to Activate

- Creating shipwrecks, jettisoned cargo, beacons, or similar world objects
- Adding a new interactable structure to the arena
- Creating objects the player flies to and interacts with via proximity

## Existing World Interactables (Reference)

| Object        | Script             | Interaction                       | Spawner               |
| ------------- | ------------------ | --------------------------------- | --------------------- |
| Space Station | `space_station.gd` | Proximity charge → buff selection | `station_spawner.gd`  |
| Asteroid      | `asteroid.gd`      | Static obstacle (no interaction)  | `asteroid_spawner.gd` |

## Interaction Models

Choose the interaction model before starting:

| Model           | Description                                  | Example                  | Complexity |
| --------------- | -------------------------------------------- | ------------------------ | ---------- |
| **Instant**     | Player enters zone → immediate effect        | Shipwrecks (pots)        | Low        |
| **Charge**      | Player stays in zone → progress bar → effect | Space Stations (shrines) | Medium     |
| **Multi-stage** | Multiple steps to interact                   | Boss beacon              | High       |
| **Passive**     | Always-on area effect                        | Radiation belt           | Low        |

## Step-by-Step Procedure

### Step 1: Create Interactable Script

Place in `scripts/systems/{object_name}.gd`.

**Template (Instant Interaction):**

```gdscript
class_name {ObjectName}
extends Node2D

## {ObjectName} - {Description of the world object}.

signal interacted(object: {ObjectName}, position: Vector2)

@export var interaction_radius: float = 80.0

var _is_used: bool = false
var _player_ref: Node2D = null

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var _interaction_zone: Area2D = $InteractionZone
@onready var _sprite: CanvasItem = $Sprite2D


func _ready() -> void:
	add_to_group("{object_name}s")
	add_to_group("minimap_objects")

	_interaction_zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _is_used:
		return
	if not body.is_in_group("player"):
		return

	_player_ref = body
	_interact()


func _interact() -> void:
	_is_used = true
	interacted.emit(self, global_position)

	# Spawn loot, apply effect, etc.
	_spawn_loot()

	# Visual feedback — dim/hide
	_update_depleted_visual()


func _spawn_loot() -> void:
	# Override or customize loot spawning logic here
	pass


func _update_depleted_visual() -> void:
	if _sprite:
		_sprite.modulate = Color(0.4, 0.4, 0.4, 0.6)


func is_used() -> bool:
	return _is_used
```

**Template (Charge Interaction — like Space Stations):**

```gdscript
class_name {ObjectName}
extends Node2D

## {ObjectName} - {Description}. Charges when player is nearby.

signal charging_started
signal charging_stopped
signal charge_completed

@export var zone_radius: float = 80.0
@export var charge_time: float = 2.0
@export var decay_time: float = 4.0

var _charge: float = 0.0
var _is_player_inside: bool = false
var _is_used: bool = false
var _player_ref: Node2D = null

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var _interaction_zone: Area2D = $InteractionZone
@onready var _sprite: CanvasItem = $Sprite2D


func _ready() -> void:
	add_to_group("{object_name}s")
	add_to_group("minimap_objects")

	_interaction_zone.body_entered.connect(_on_body_entered)
	_interaction_zone.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _is_used:
		return
	if RunManager.current_state != RunManager.GameState.PLAYING:
		return

	if _is_player_inside:
		var charge_rate: float = 1.0 / charge_time
		_charge = minf(_charge + charge_rate * delta, 1.0)
		if _charge >= 1.0:
			_on_charge_complete()
	else:
		if _charge > 0.0:
			var decay_rate: float = 1.0 / decay_time
			_charge = maxf(_charge - decay_rate * delta, 0.0)


func _on_body_entered(body: Node2D) -> void:
	if _is_used or not body.is_in_group("player"):
		return
	_is_player_inside = true
	_player_ref = body
	charging_started.emit()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_is_player_inside = false
		charging_stopped.emit()


func _on_charge_complete() -> void:
	if _is_used:
		return
	_is_used = true
	charge_completed.emit()
	# Trigger loot/buff/effect here


func is_used() -> bool:
	return _is_used
```

**Key rules for interactable scripts:**

- Always `add_to_group("minimap_objects")` for minimap/fog of war visibility
- Add to a named group for easy querying (e.g., `"shipwrecks"`, `"cargo"`)
- Check `RunManager.current_state == RunManager.GameState.PLAYING` before processing
- Emit signals for cross-system communication (world orchestrator, HUD, etc.)
- Use `is_used()` / `is_depleted()` to prevent re-triggering

### Step 2: Create Scene

Save as `scenes/gameplay/{object_name}.tscn`.

**Scene hierarchy:**

```
Node2D ({ObjectName}.gd)
├── InteractionZone (Area2D)     # Proximity detection
│   └── CollisionShape2D         # CircleShape2D with interaction_radius
├── Sprite2D                     # Visual representation
└── ProgressRing (ColorRect)     # Optional: charge progress visual (for charge model)
```

**Collision layer setup for InteractionZone:**

- Create a new collision layer if needed, or reuse Layer 64 (Stations) if similar behavior
- **Mask**: 1 (Player) — only detect the player

### Step 3: Create Spawner

Place in `scripts/systems/{object_name}_spawner.gd`.

**Template (Rejection Sampling — standard pattern):**

```gdscript
class_name {ObjectName}Spawner
extends Node

## {ObjectName}Spawner - Places {object_name}s at random positions at run start.

const SCENE: PackedScene = preload("res://scenes/gameplay/{object_name}.tscn")

var _spawned_objects: Array[Node2D] = []
var _rng: RandomNumberGenerator = null
var _obstacle_positions: Array[Vector2] = []


## Spawn all objects for the run.
func spawn(parent: Node, obstacle_positions: Array[Vector2] = []) -> void:
	_obstacle_positions = obstacle_positions

	var game_seed: Node = parent.get_node_or_null("/root/GameSeed")
	if game_seed and game_seed.has_method("rng"):
		_rng = game_seed.rng("{object_name}s")
	else:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()

	var positions: Array[Vector2] = _generate_positions()

	for pos: Vector2 in positions:
		var obj: Node2D = SCENE.instantiate()
		obj.global_position = pos
		parent.add_child(obj)
		_spawned_objects.append(obj)


func _generate_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var count: int = 20  # TODO: Move to GameConfig
	var min_radius: float = GameConfig.ARENA_RADIUS * 0.15
	var max_radius: float = GameConfig.ARENA_RADIUS * 0.85
	var min_separation: float = 150.0  # TODO: Move to GameConfig
	var max_attempts: int = 100

	for i: int in range(count):
		var attempts: int = 0
		var valid: bool = false
		var pos: Vector2 = Vector2.ZERO

		while not valid and attempts < max_attempts:
			attempts += 1

			var angle: float = _rng.randf() * TAU
			var distance: float = _rng.randf_range(min_radius, max_radius)
			pos = Vector2.from_angle(angle) * distance

			valid = true

			# Check separation from existing objects
			for existing: Vector2 in positions:
				if pos.distance_to(existing) < min_separation:
					valid = false
					break

			# Check separation from obstacles (asteroids)
			if valid:
				for obstacle_pos: Vector2 in _obstacle_positions:
					if pos.distance_to(obstacle_pos) < min_separation:
						valid = false
						break

		if valid:
			positions.append(pos)
		else:
			# Fallback: place anyway with warning
			push_warning("{ObjectName}Spawner: Failed to find valid position for object %d" % i)
			var angle: float = _rng.randf() * TAU
			var distance: float = _rng.randf_range(min_radius, max_radius)
			positions.append(Vector2.from_angle(angle) * distance)

	return positions


func get_objects() -> Array[Node2D]:
	return _spawned_objects
```

**Key spawner rules:**

- Use `GameSeed.rng("{category}")` for deterministic seeded randomness
- Rejection sampling with 100 max attempts per object
- Check separation from both existing objects AND obstacle positions (asteroids)
- Fallback placement with `push_warning()` if all attempts fail
- Move count/radius/separation constants to `GameConfig` for tuning

### Step 4: Add GameConfig Constants

Add tuning constants to `globals/game_config.gd`:

```gdscript
# {Object Name}
const {OBJECT}_COUNT: int = 20
const {OBJECT}_SPAWN_MIN_RADIUS: float = 600.0
const {OBJECT}_SPAWN_MAX_RADIUS: float = 3400.0
const {OBJECT}_MIN_SEPARATION: float = 150.0
const {OBJECT}_ZONE_RADIUS: float = 80.0
# For charge-based: charge time, decay time
```

### Step 5: Add Data Entries (if needed)

If the interactable has data-driven loot or properties, add entries to the appropriate JSON file:

- **Loot tables:** `data/items.json` (for item drops)
- **New data file:** `data/{object_name}s.json` if the object needs its own data definitions
- **Register in DataLoader:** Add loading call in `globals/data_loader.gd` if new JSON file

### Step 6: Integrate with World.gd

Add spawner instantiation in `scripts/systems/world.gd`:

```gdscript
var _{object_name}_spawner: {ObjectName}Spawner = {ObjectName}Spawner.new()

func _spawn_world_objects() -> void:
	# ... existing asteroid/station spawning ...
	_{object_name}_spawner.spawn(self, _obstacle_positions)
```

Pass `_obstacle_positions` (asteroid positions) so spawner can avoid them.

### Step 7: Add Minimap/Fog of War Icons

If the object should appear on the minimap:

1. Add to `"minimap_objects"` group (done in Step 1)
2. Add icon rendering in `scripts/ui/minimap.gd` and `scripts/ui/full_map_overlay.gd`
3. Objects in fog of war are hidden until the player reveals their cell

## Checklist

- [ ] Interactable script: `scripts/systems/{object_name}.gd`
- [ ] Scene: `scenes/gameplay/{object_name}.tscn`
- [ ] InteractionZone Area2D with correct collision mask (detect player)
- [ ] Added to groups: `"{object_name}s"` and `"minimap_objects"`
- [ ] Spawner script: `scripts/systems/{object_name}_spawner.gd`
- [ ] GameSeed used for deterministic placement
- [ ] Rejection sampling with asteroid avoidance
- [ ] GameConfig constants added for count, radius, separation
- [ ] Integrated in `world.gd` spawn sequence
- [ ] Minimap icon added (if visible on map)
- [ ] Headless sanity check passes
