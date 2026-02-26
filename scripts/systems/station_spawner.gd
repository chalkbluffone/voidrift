class_name StationSpawner
extends Node

## StationSpawner - Spawns space stations at random positions around the arena at run start.
## Uses GameSeed for deterministic placement based on run seed.

const SPACE_STATION_SCENE: PackedScene = preload("res://scenes/gameplay/space_station.tscn")

var _spawned_stations: Array[Node2D] = []
var _rng: RandomNumberGenerator = null
var _obstacle_positions: Array[Vector2] = []


## Spawn all stations for the run.
## @param parent: The node to add stations as children of
## @param obstacle_positions: Pre-placed obstacle positions to avoid (e.g. asteroids)
func spawn_stations(parent: Node, obstacle_positions: Array[Vector2] = []) -> void:
	_obstacle_positions = obstacle_positions
	# Get RNG from GameSeed autoload
	var game_seed: Node = parent.get_node_or_null("/root/GameSeed")
	if game_seed and game_seed.has_method("rng"):
		_rng = game_seed.rng("stations")
	else:
		# Fallback to unseeded RNG
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	
	var positions: Array[Vector2] = _generate_spawn_positions()
	
	for pos in positions:
		var station: Node2D = SPACE_STATION_SCENE.instantiate()
		station.global_position = pos
		parent.add_child(station)
		_spawned_stations.append(station)


## Generate random spawn positions with minimum separation.
func _generate_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var count: int = GameConfig.STATION_COUNT
	var min_radius: float = GameConfig.STATION_SPAWN_MIN_RADIUS
	var max_radius: float = GameConfig.STATION_SPAWN_MAX_RADIUS
	var min_separation: float = GameConfig.STATION_MIN_SEPARATION
	var max_attempts: int = 100  # Prevent infinite loops
	
	for i in range(count):
		var attempts: int = 0
		var valid_position: bool = false
		var pos: Vector2 = Vector2.ZERO
		
		while not valid_position and attempts < max_attempts:
			attempts += 1
			
			# Generate random position within arena bounds
			var angle: float = _rng.randf() * TAU
			var distance: float = _rng.randf_range(min_radius, max_radius)
			pos = Vector2.from_angle(angle) * distance
			
			# Check separation from existing stations
			valid_position = true
			for existing_pos in positions:
				if pos.distance_to(existing_pos) < min_separation:
					valid_position = false
					break
			
			# Check separation from obstacles (asteroids)
			if valid_position:
				for obstacle_pos: Vector2 in _obstacle_positions:
					if pos.distance_to(obstacle_pos) < min_separation:
						valid_position = false
						break
		
		if valid_position:
			positions.append(pos)
		else:
			# Fallback: place anyway if we couldn't find a valid spot
			push_warning("StationSpawner: Could not find valid position for station %d after %d attempts" % [i, max_attempts])
			var angle: float = _rng.randf() * TAU
			var distance: float = _rng.randf_range(min_radius, max_radius)
			positions.append(Vector2.from_angle(angle) * distance)
	
	return positions


## Get all spawned stations.
func get_stations() -> Array[Node2D]:
	return _spawned_stations


## Get the number of remaining (non-depleted) stations.
func get_remaining_count() -> int:
	var count: int = 0
	for station in _spawned_stations:
		if station and station.has_method("is_depleted") and not station.is_depleted():
			count += 1
	return count
