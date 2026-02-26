class_name AsteroidSpawner
extends RefCounted

## AsteroidSpawner - Places asteroids at run start using the run seed.
## Returns placed positions so downstream spawners (stations) can avoid them.

const ASTEROID_SCENE: PackedScene = preload("res://scenes/gameplay/asteroid.tscn")

var _spawned_positions: Array[Vector2] = []


## Spawn all asteroids for the run.
## @param parent: The node to add asteroids as children of.
## @return: Array of world-space positions where asteroids were placed.
func spawn_asteroids(parent: Node) -> Array[Vector2]:
	var game_seed: Node = parent.get_node_or_null("/root/GameSeed")
	var rng: RandomNumberGenerator
	if game_seed and game_seed.has_method("rng"):
		rng = game_seed.rng("asteroids")
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var count: int = GameConfig.ASTEROID_COUNT
	var min_radius: float = GameConfig.ASTEROID_SPAWN_MIN_RADIUS
	var max_radius: float = GameConfig.ASTEROID_SPAWN_MAX_RADIUS
	var min_sep: float = GameConfig.ASTEROID_MIN_SEPARATION
	var max_attempts: int = 100

	_spawned_positions.clear()

	for i: int in range(count):
		var pos: Vector2 = _find_valid_position(rng, min_radius, max_radius, min_sep, max_attempts)
		_spawned_positions.append(pos)

		var asteroid_size: float = rng.randf_range(
			GameConfig.ASTEROID_SIZE_MIN,
			GameConfig.ASTEROID_SIZE_MAX
		)

		var asteroid: StaticBody2D = ASTEROID_SCENE.instantiate()
		asteroid.global_position = pos
		parent.add_child(asteroid)
		asteroid.generate(rng, asteroid_size)

	return _spawned_positions.duplicate()


## Find a position that satisfies minimum separation from existing asteroids.
func _find_valid_position(
	rng: RandomNumberGenerator,
	min_radius: float,
	max_radius: float,
	min_sep: float,
	max_attempts: int
) -> Vector2:
	for attempt: int in range(max_attempts):
		var angle: float = rng.randf() * TAU
		var distance: float = rng.randf_range(min_radius, max_radius)
		var candidate: Vector2 = Vector2.from_angle(angle) * distance

		var valid: bool = true
		for existing: Vector2 in _spawned_positions:
			if candidate.distance_to(existing) < min_sep:
				valid = false
				break

		if valid:
			return candidate

	# Fallback: return last generated position even if separation violated
	var fallback_angle: float = rng.randf() * TAU
	var fallback_distance: float = rng.randf_range(min_radius, max_radius)
	return Vector2.from_angle(fallback_angle) * fallback_distance


## Get all positions where asteroids were placed.
func get_positions() -> Array[Vector2]:
	return _spawned_positions
