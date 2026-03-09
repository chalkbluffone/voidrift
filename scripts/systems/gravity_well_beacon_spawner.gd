class_name GravityWellBeaconSpawner
extends RefCounted

## GravityWellBeaconSpawner - Places Gravity Well beacons at run start.
## Uses GameSeed for deterministic placement.

const BEACON_SCENE: PackedScene = preload("res://scenes/gameplay/gravity_well_beacon.tscn")

var _spawned_beacons: Array[Node2D] = []


## Spawn all beacons for the run.
func spawn_beacons(parent: Node, obstacle_positions: Array[Vector2] = []) -> void:
	var game_seed: Node = parent.get_node_or_null("/root/GameSeed")
	var rng: RandomNumberGenerator
	if game_seed and game_seed.has_method("rng"):
		rng = game_seed.rng("gravity_well_beacons")
	else:
		rng = RandomNumberGenerator.new()
		rng.seed = 1

	var positions: Array[Vector2] = _generate_positions(rng, obstacle_positions)

	for pos: Vector2 in positions:
		var beacon: Node2D = BEACON_SCENE.instantiate()
		beacon.global_position = pos
		parent.add_child(beacon)
		_spawned_beacons.append(beacon)


func _generate_positions(rng: RandomNumberGenerator, obstacle_positions: Array[Vector2]) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var count: int = GameConfig.GRAVITY_WELL_BEACON_COUNT
	var min_radius: float = GameConfig.GRAVITY_WELL_BEACON_SPAWN_MIN_RADIUS
	var max_radius: float = GameConfig.GRAVITY_WELL_BEACON_SPAWN_MAX_RADIUS
	var min_separation: float = GameConfig.GRAVITY_WELL_BEACON_MIN_SEPARATION
	var max_attempts: int = 80

	for i: int in range(count):
		var attempts: int = 0
		var valid: bool = false
		var pos: Vector2 = Vector2.ZERO

		while not valid and attempts < max_attempts:
			attempts += 1
			var angle: float = rng.randf() * TAU
			var distance: float = rng.randf_range(min_radius, max_radius)
			pos = Vector2.from_angle(angle) * distance

			valid = true
			# Check separation from other beacons
			for existing: Vector2 in positions:
				if pos.distance_to(existing) < min_separation:
					valid = false
					break

			# Check separation from obstacles (asteroids + stations)
			if valid:
				for obs_pos: Vector2 in obstacle_positions:
					if pos.distance_to(obs_pos) < min_separation:
						valid = false
						break

		if valid:
			positions.append(pos)

	return positions
