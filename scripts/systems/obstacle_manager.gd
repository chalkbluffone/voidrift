extends Node

## Manages spawning and cleanup of minable asteroids throughout the run.
## These are interactive objects that drop loot when destroyed.

@export var asteroid_scene: PackedScene
@export var ship_path: NodePath
@export var asteroid_container_path: NodePath

# IMPORTANT:
# This spawner no longer owns its own seed.
# It derives a deterministic system seed from the single global seed (GameSeed).
@export var seed_namespace: String = "asteroids"

@export var chunk_size: int = 1024
@export var view_chunks_radius: int = 2         # how many chunks around the ship to generate
@export var asteroids_per_chunk: int = 5        # density

@export var min_scale: float = 0.4
@export var max_scale: float = 2.6
@export var min_drift: float = 0.0
@export var max_drift: float = 0.0
@export var min_spin: float = -1.5
@export var max_spin: float = 1.5

var ship: Node2D
var container: Node2D

# Derived from GameSeed (single global seed)
var system_seed: int = 0

# Which chunks we've already generated (so we don't duplicate)
var generated_chunks: Dictionary = {}  # key: Vector2i -> true

func _ready() -> void:
	ship = get_node(ship_path) as Node2D
	container = get_node(asteroid_container_path) as Node2D

	# Pull the ONE global seed and derive this system's seed.
	# You must have GameSeed autoloaded and initialized before this runs.
	system_seed = GameSeed.derive_seed(seed_namespace)

	# Generate initial area
	_generate_around_ship()

func _physics_process(_delta: float) -> void:
	if is_instance_valid(ship):
		_generate_around_ship()

func _generate_around_ship() -> void:
	if not is_instance_valid(ship):
		return
	var ship_chunk := _world_to_chunk(ship.global_position)

	for cy in range(ship_chunk.y - view_chunks_radius, ship_chunk.y + view_chunks_radius + 1):
		for cx in range(ship_chunk.x - view_chunks_radius, ship_chunk.x + view_chunks_radius + 1):
			var c := Vector2i(cx, cy)
			if generated_chunks.has(c):
				continue
			_generate_chunk(c)
			generated_chunks[c] = true

	# Optional cleanup so nodes don't grow forever
	_cleanup_far_asteroids(ship_chunk)

func _generate_chunk(chunk: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(system_seed, chunk)

	var origin := Vector2(chunk.x * chunk_size, chunk.y * chunk_size)

	for i in range(asteroids_per_chunk):
		var a := asteroid_scene.instantiate() as Node2D
		container.add_child(a)

		# Position within chunk
		var pos := origin + Vector2(
			rng.randf_range(0.0, float(chunk_size)),
			rng.randf_range(0.0, float(chunk_size))
		)
		a.global_position = pos

		# Random look/behavior (deterministic because rng is deterministic)
		a.rotation = rng.randf_range(0.0, TAU)

		var s := rng.randf_range(min_scale, max_scale)
		a.scale = Vector2(s, s)

		# Set drift + spin if your asteroid script supports it
		# NOTE: 'set' exists on all Objects; these properties just need to exist on the asteroid instance.
		var drift_dir := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var drift_speed := rng.randf_range(min_drift, max_drift)
		a.set("drift_velocity", drift_dir * drift_speed)
		a.set("spin_speed", rng.randf_range(min_spin, max_spin))

func _cleanup_far_asteroids(ship_chunk: Vector2i) -> void:
	# Keep only asteroids within (view_chunks_radius + 1) chunks
	var keep_radius := view_chunks_radius + 1

	for child in container.get_children():
		var n := child as Node2D
		if n == null:
			continue
		var c := _world_to_chunk(n.global_position)
		if abs(c.x - ship_chunk.x) > keep_radius or abs(c.y - ship_chunk.y) > keep_radius:
			n.queue_free()

func _world_to_chunk(pos: Vector2) -> Vector2i:
	# floor division works correctly for negative coords too
	var cx := int(floor(pos.x / float(chunk_size)))
	var cy := int(floor(pos.y / float(chunk_size)))
	return Vector2i(cx, cy)

func _chunk_seed(seed0: int, chunk: Vector2i) -> int:
	# Combine system seed + chunk coords into a stable hash
	var h := int(seed0)
	h = _mix(h ^ int(chunk.x) * 374761393)
	h = _mix(h ^ int(chunk.y) * 668265263)
	return h & 0x7fffffff  # keep it positive for RNG

func _mix(x: int) -> int:
	# Simple integer hash mix (deterministic)
	x = (x ^ (x >> 16)) * 2246822519
	x = (x ^ (x >> 13)) * 3266489917
	x = x ^ (x >> 16)
	return x
