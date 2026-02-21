class_name ArenaUtils
extends RefCounted

## ArenaUtils - Shared utility functions for arena boundary calculations.
## Used by: ArenaBoundary, EnemySpawner, Minimap, World (player spawn).

## Returns the distance from a world position to arena center (0, 0).
static func get_distance_from_center(pos: Vector2) -> float:
	return pos.length()


## Returns normalized direction from a position toward arena center.
static func get_direction_to_center(pos: Vector2) -> Vector2:
	if pos.length_squared() < 0.001:
		return Vector2.ZERO
	return -pos.normalized()


## Returns true if position is within the safe play zone (inside radiation belt).
static func is_in_safe_zone(pos: Vector2) -> bool:
	var safe_radius: float = GameConfig.ARENA_RADIUS - GameConfig.RADIATION_BELT_WIDTH
	return pos.length() < safe_radius


## Returns true if position is inside the radiation belt (danger zone).
static func is_in_radiation_belt(pos: Vector2) -> bool:
	var distance: float = pos.length()
	var inner_edge: float = GameConfig.ARENA_RADIUS - GameConfig.RADIATION_BELT_WIDTH
	return distance >= inner_edge and distance <= GameConfig.ARENA_RADIUS


## Returns true if position is completely outside the arena.
static func is_outside_arena(pos: Vector2) -> bool:
	return pos.length() > GameConfig.ARENA_RADIUS


## Returns radiation intensity (0.0 to 1.0) based on depth into the belt.
## 0.0 = at inner edge, 1.0 = at outer edge or beyond.
static func get_radiation_intensity(pos: Vector2) -> float:
	var distance: float = pos.length()
	var inner_edge: float = GameConfig.ARENA_RADIUS - GameConfig.RADIATION_BELT_WIDTH
	
	if distance <= inner_edge:
		return 0.0
	if distance >= GameConfig.ARENA_RADIUS:
		return 1.0
	
	return (distance - inner_edge) / GameConfig.RADIATION_BELT_WIDTH


## Returns a random spawn position within the safe zone.
static func get_random_spawn_position() -> Vector2:
	var max_spawn_radius: float = GameConfig.ARENA_RADIUS - GameConfig.PLAYER_SPAWN_SAFE_MARGIN
	var angle: float = randf() * TAU
	var distance: float = randf() * max_spawn_radius
	return Vector2.from_angle(angle) * distance


## Clamps a position to stay within the arena radius.
static func clamp_to_arena(pos: Vector2) -> Vector2:
	var distance: float = pos.length()
	if distance <= GameConfig.ARENA_RADIUS:
		return pos
	return pos.normalized() * GameConfig.ARENA_RADIUS
