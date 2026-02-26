class_name Asteroid
extends StaticBody2D

## Asteroid - Static, indestructible obstacle placed in the arena.
## Shape is procedurally generated from a RandomNumberGenerator for deterministic results.

## Effective bounding radius of this asteroid (set during generation).
## Used by enemy avoidance to know how far to steer around.
var effective_radius: float = 0.0

@onready var _polygon: Polygon2D = $Polygon2D
@onready var _collision: CollisionPolygon2D = $CollisionPolygon2D


## Generate the asteroid's shape procedurally.
## @param rng: Seeded RNG for deterministic generation.
## @param asteroid_size: Base radius of the asteroid in pixels.
func generate(rng: RandomNumberGenerator, asteroid_size: float) -> void:
	var vertex_count: int = rng.randi_range(
		GameConfig.ASTEROID_VERTEX_COUNT_MIN,
		GameConfig.ASTEROID_VERTEX_COUNT_MAX
	)
	var jitter: float = GameConfig.ASTEROID_RADIUS_JITTER

	# Build vertices around a circle with per-vertex radius jitter
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(vertex_count):
		var angle: float = (float(i) / float(vertex_count)) * TAU
		var radius: float = asteroid_size * (1.0 + rng.randf_range(-jitter, jitter))
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	# Assign to both visual and collision polygons
	_polygon.polygon = points
	_collision.polygon = points

	# Store the effective bounding radius (max vertex distance from center)
	var max_r: float = 0.0
	for pt: Vector2 in points:
		var r: float = pt.length()
		if r > max_r:
			max_r = r
	effective_radius = max_r

	# Randomize color: dark grays/browns with slight variation
	var base_r: float = rng.randf_range(0.18, 0.32)
	var base_g: float = rng.randf_range(0.16, 0.28)
	var base_b: float = rng.randf_range(0.14, 0.24)
	_polygon.color = Color(base_r, base_g, base_b, 1.0)


## Returns the polygon points (local space) for map rendering.
func get_polygon_points() -> PackedVector2Array:
	if _polygon:
		return _polygon.polygon
	return PackedVector2Array()


## Returns the asteroid's fill color for map rendering.
func get_polygon_color() -> Color:
	if _polygon:
		return _polygon.color
	return Color(0.25, 0.22, 0.19, 1.0)
