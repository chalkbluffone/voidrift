extends Control

## Minimap - Circular minimap showing player surroundings with fog of war.
## Shows: player position, enemies (if explored), arena boundary, pickups.

const FogOfWarScript: GDScript = preload("res://scripts/systems/fog_of_war.gd")
const FogShader: Shader = preload("res://shaders/fog_of_war.gdshader")

# Colors for minimap elements
const COLOR_BACKGROUND: Color = Color(0.05, 0.05, 0.1, 0.8)
const COLOR_PLAYER: Color = UiColors.MAP_PLAYER
const COLOR_ENEMY: Color = UiColors.MAP_ENEMY
const COLOR_PICKUP: Color = UiColors.MAP_PICKUP
const COLOR_STATION: Color = UiColors.MAP_STATION
const COLOR_ASTEROID: Color = UiColors.MAP_ASTEROID
const COLOR_POWERUP_HEALTH: Color = UiColors.MAP_POWERUP_HEALTH
const COLOR_POWERUP_SPEED: Color = UiColors.MAP_POWERUP_SPEED
const COLOR_POWERUP_STOPWATCH: Color = UiColors.MAP_POWERUP_STOPWATCH
const COLOR_POWERUP_GRAVITY: Color = UiColors.MAP_POWERUP_GRAVITY
const COLOR_BEACON: Color = UiColors.MAP_BEACON
const COLOR_BOUNDARY: Color = UiColors.MAP_BOUNDARY
const COLOR_FOG: Color = Color(0.0, 0.0, 0.0, 0.9)
const COLOR_EXPLORED: Color = Color(0.15, 0.15, 0.2, 0.6)

@onready var FrameCache: Node = get_node("/root/FrameCache")

var _player: Node2D = null
var _fog_of_war: RefCounted = null
var _minimap_size: float = 180.0
var _world_radius: float = 1200.0  # World radius visible in minimap
var _world_to_minimap_scale: float = 0.05

var _fog_overlay: ColorRect = null
var _fog_material: ShaderMaterial = null


func _ready() -> void:
	_minimap_size = GameConfig.MINIMAP_SIZE
	_world_radius = GameConfig.ARENA_RADIUS * GameConfig.MINIMAP_WORLD_RADIUS_COVERAGE
	_world_radius = maxf(_world_radius, 1.0)
	
	# Calculate scale: world units to minimap pixels
	# world_radius controls zoom - smaller value = more zoomed in
	_world_to_minimap_scale = (_minimap_size * 0.5) / _world_radius
	
	# Initialize fog of war
	_fog_of_war = FogOfWarScript.new()
	
	# Set fixed size
	custom_minimum_size = Vector2(_minimap_size, _minimap_size)
	size = Vector2(_minimap_size, _minimap_size)
	
	# Clip all drawing to minimap bounds
	clip_contents = true
	
	# Create fog overlay with shader
	_setup_fog_overlay()


func _setup_fog_overlay() -> void:
	_fog_overlay = ColorRect.new()
	_fog_overlay.name = "FogOverlay"
	_fog_overlay.size = Vector2(_minimap_size, _minimap_size)
	_fog_overlay.color = Color(0, 0, 0, 0)  # Transparent base
	_fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_fog_material = ShaderMaterial.new()
	_fog_material.shader = FogShader
	_fog_overlay.material = _fog_material
	
	# Create initial placeholder fog texture (all unexplored)
	var placeholder: Image = Image.create(64, 64, false, Image.FORMAT_L8)
	placeholder.fill(Color.BLACK)
	var placeholder_tex: ImageTexture = ImageTexture.create_from_image(placeholder)
	_fog_material.set_shader_parameter("fog_texture", placeholder_tex)
	_fog_material.set_shader_parameter("glow_intensity", GameConfig.FOG_GLOW_INTENSITY)
	_fog_material.set_shader_parameter("fog_opacity", GameConfig.FOG_OPACITY)
	_fog_material.set_shader_parameter("mask_radius", 0.5)
	
	add_child(_fog_overlay)


var _fog_frame_counter: int = 0
const _FOG_UPDATE_INTERVAL: int = 3  ## Update fog every N frames


func _process(_delta: float) -> void:
	if _player == null:
		_player = FrameCache.player
	
	if _player and _fog_of_war:
		_fog_frame_counter += 1
		if _fog_frame_counter >= _FOG_UPDATE_INTERVAL:
			_fog_frame_counter = 0
			# Reveal fog around player
			_fog_of_war.reveal_radius(_player.global_position, GameConfig.FOG_REVEAL_RADIUS)
			# Update fog texture for shader
			if _fog_material:
				var fog_tex: ImageTexture = _fog_of_war.get_texture(_player.global_position, _world_radius)
				_fog_material.set_shader_parameter("fog_texture", fog_tex)
	
	# Redraw every frame
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = _minimap_size * 0.5
	
	# Draw circular background
	draw_circle(center, radius, COLOR_BACKGROUND)
	
	if _player == null:
		return
	
	var player_pos: Vector2 = _player.global_position
	
	# Draw arena boundary ring (relative to player)
	_draw_arena_boundary(center, radius, player_pos)
	
	# Draw asteroids
	_draw_asteroids(center, radius, player_pos)
	
	# Draw stations (always visible on minimap)
	_draw_stations(center, radius, player_pos)
	
	# Draw enemies
	_draw_enemies(center, radius, player_pos)

	# Draw power-ups with unique icon/color markers
	_draw_powerups(center, radius, player_pos)

	# Draw gravity well beacons
	_draw_beacons(center, radius, player_pos)

	# Draw player (always at center)
	draw_circle(center, 4.0, COLOR_PLAYER)
	
	# Draw player direction indicator
	var player_dir: Vector2 = Vector2.from_angle(_player.rotation)
	draw_line(center, center + player_dir * 8.0, COLOR_PLAYER, 2.0)
	
	# Draw circular border
	draw_arc(center, radius - 1.0, 0.0, TAU, 64, Color(0.0, 1.0, 0.9, 0.8), 2.0)


## Draw the arena boundary ring on the minimap.
func _draw_arena_boundary(center: Vector2, radius: float, player_pos: Vector2) -> void:
	var arena_center_offset: Vector2 = -player_pos * _world_to_minimap_scale
	var arena_radius_scaled: float = GameConfig.ARENA_RADIUS * _world_to_minimap_scale
	
	# Only draw if boundary is within view
	var boundary_distance: float = arena_center_offset.length() + arena_radius_scaled
	if boundary_distance < radius * 0.2:
		return  # Too small/far to see
	
	# Draw boundary arc (portion visible in minimap)
	var arc_center: Vector2 = center + arena_center_offset
	
	# Clamp drawing to minimap circle
	if arena_radius_scaled > 5.0:
		draw_arc(arc_center, arena_radius_scaled, 0.0, TAU, 64, COLOR_BOUNDARY, 2.0)


## Draw enemy dots on the minimap.
func _draw_enemies(center: Vector2, radius: float, player_pos: Vector2) -> void:
	var enemies: Array[Node] = FrameCache.enemies
	
	for enemy: Node in enemies:
		if not enemy is Node2D:
			continue
		var enemy_2d: Node2D = enemy as Node2D
		var offset: Vector2 = (enemy_2d.global_position - player_pos) * _world_to_minimap_scale
		
		# Skip if outside minimap circle
		if offset.length() > radius - 4.0:
			continue
		
		# Skip if in unexplored area
		if _fog_of_war and not _fog_of_war.is_explored(enemy_2d.global_position):
			continue
		
		draw_circle(center + offset, 3.0, COLOR_ENEMY)


## Draw pickup dots on the minimap.
func _draw_pickups(center: Vector2, radius: float, player_pos: Vector2) -> void:
	var pickups: Array[Node] = FrameCache.pickups
	
	for pickup: Node in pickups:
		if not pickup is Node2D:
			continue
		if pickup.is_in_group("powerups"):
			continue
		var pickup_2d: Node2D = pickup as Node2D
		var offset: Vector2 = (pickup_2d.global_position - player_pos) * _world_to_minimap_scale
		
		# Skip if outside minimap circle
		if offset.length() > radius - 4.0:
			continue
		
		# Skip if in unexplored area (pickups in fog are hidden)
		if _fog_of_war and not _fog_of_war.is_explored(pickup_2d.global_position):
			continue
		
		draw_circle(center + offset, 2.0, COLOR_PICKUP)


## Draw power-up markers with type-specific icon and color.
func _draw_powerups(center: Vector2, radius: float, player_pos: Vector2) -> void:
	var powerups: Array[Node] = FrameCache.powerups

	for powerup: Node in powerups:
		if not powerup is Node2D:
			continue
		var powerup_2d: Node2D = powerup as Node2D
		var offset: Vector2 = (powerup_2d.global_position - player_pos) * _world_to_minimap_scale

		# Skip if outside minimap circle
		if offset.length() > radius - 6.0:
			continue

		# Skip if in unexplored area
		if _fog_of_war and not _fog_of_war.is_explored(powerup_2d.global_position):
			continue

		var marker_info: Dictionary = _get_powerup_marker_info(powerup_2d)
		var marker_type: String = String(marker_info.get("marker_type", "unknown"))
		var marker_color: Color = Color(marker_info.get("color", COLOR_PICKUP))
		var marker_pos: Vector2 = center + offset

		# Colored outer ring + icon gives quick readability at small minimap sizes.
		draw_circle(marker_pos, 4.0, marker_color)
		draw_circle(marker_pos, 2.2, Color(0.05, 0.05, 0.08, 0.95))
		_draw_powerup_icon(marker_pos, marker_type, marker_color, 1.0)


func _draw_powerup_icon(marker_pos: Vector2, marker_type: String, marker_color: Color, icon_scale: float) -> void:
	if marker_type == "health":
		draw_line(marker_pos + Vector2(-1.6, 0.0) * icon_scale, marker_pos + Vector2(1.6, 0.0) * icon_scale, Color.WHITE, 1.2)
		draw_line(marker_pos + Vector2(0.0, -1.6) * icon_scale, marker_pos + Vector2(0.0, 1.6) * icon_scale, Color.WHITE, 1.2)
	elif marker_type == "speed":
		var bolt_points: PackedVector2Array = PackedVector2Array([
			marker_pos + Vector2(-1.2, -1.6) * icon_scale,
			marker_pos + Vector2(0.2, -1.6) * icon_scale,
			marker_pos + Vector2(-0.5, 0.1) * icon_scale,
			marker_pos + Vector2(1.1, 0.1) * icon_scale,
			marker_pos + Vector2(-0.3, 1.8) * icon_scale,
			marker_pos + Vector2(0.1, 0.5) * icon_scale
		])
		draw_polyline(bolt_points, Color.WHITE, 1.2)
	elif marker_type == "stopwatch":
		draw_circle(marker_pos, 1.7 * icon_scale, Color.WHITE)
		draw_line(marker_pos + Vector2(0.0, -2.4) * icon_scale, marker_pos + Vector2(0.0, -1.6) * icon_scale, marker_color, 1.0)
		draw_line(marker_pos, marker_pos + Vector2(0.0, -0.9) * icon_scale, marker_color, 1.0)
		draw_line(marker_pos, marker_pos + Vector2(0.7, 0.5) * icon_scale, marker_color, 1.0)
	elif marker_type == "gravity":
		draw_arc(marker_pos, 1.8 * icon_scale, 0.0, TAU, 16, Color.WHITE, 1.0)
		draw_circle(marker_pos, 0.55 * icon_scale, Color.WHITE)
	else:
		draw_circle(marker_pos, 1.1 * icon_scale, Color.WHITE)


func _get_powerup_marker_info(powerup: Node2D) -> Dictionary:
	var script_path: String = ""
	var script_ref: Script = powerup.get_script() as Script
	if script_ref:
		script_path = String(script_ref.resource_path)

	if script_path.ends_with("health_powerup.gd"):
		return {"marker_type": "health", "color": COLOR_POWERUP_HEALTH}
	if script_path.ends_with("speed_powerup.gd"):
		return {"marker_type": "speed", "color": COLOR_POWERUP_SPEED}
	if script_path.ends_with("stopwatch_powerup.gd"):
		return {"marker_type": "stopwatch", "color": COLOR_POWERUP_STOPWATCH}
	if script_path.ends_with("gravity_well_pickup.gd"):
		return {"marker_type": "gravity", "color": COLOR_POWERUP_GRAVITY}

	return {"marker_type": "unknown", "color": COLOR_PICKUP}


## Draw gravity well beacon circles on the minimap (purple, 20% larger than enemies).
func _draw_beacons(center: Vector2, radius: float, player_pos: Vector2) -> void:
	var beacons: Array[Node] = get_tree().get_nodes_in_group("gravity_well_beacons")

	for beacon: Node in beacons:
		if not beacon is Node2D:
			continue
		var beacon_2d: Node2D = beacon as Node2D

		# Skip depleted beacons
		if "_is_depleted" in beacon_2d and beacon_2d._is_depleted:
			continue

		var offset: Vector2 = (beacon_2d.global_position - player_pos) * _world_to_minimap_scale

		# Skip if outside minimap circle
		if offset.length() > radius - 5.0:
			continue

		# Skip if in unexplored area
		if _fog_of_war and not _fog_of_war.is_explored(beacon_2d.global_position):
			continue

		# Draw as purple circle, 20% larger than enemy dots (3.0 * 1.2 = 3.6)
		var marker_pos: Vector2 = center + offset
		draw_arc(marker_pos, 3.6, 0.0, TAU, 16, COLOR_BEACON, 1.5)
		draw_circle(marker_pos, 1.2, COLOR_BEACON)


## Draw space station icons on the minimap (active stations only).
func _draw_stations(center: Vector2, radius: float, player_pos: Vector2) -> void:
	var stations: Array[Node] = FrameCache.stations
	
	for station: Node in stations:
		if not station is Node2D:
			continue
		
		# Skip depleted stations — they disappear from the map
		if station.has_method("is_depleted") and station.is_depleted():
			continue
		
		var station_2d: Node2D = station as Node2D
		var offset: Vector2 = (station_2d.global_position - player_pos) * _world_to_minimap_scale
		
		# Skip if outside minimap circle
		if offset.length() > radius - 6.0:
			continue
		
		# Draw station as a larger dot (size 5) to distinguish from other elements
		draw_circle(center + offset, 5.0, COLOR_STATION)


## Draw asteroid shapes on the minimap (scaled polygons, not dots).
func _draw_asteroids(center: Vector2, radius: float, player_pos: Vector2) -> void:
	var asteroids: Array[Node] = FrameCache.asteroids

	for asteroid: Node in asteroids:
		if not asteroid is Node2D:
			continue
		var asteroid_2d: Node2D = asteroid as Node2D
		var offset: Vector2 = (asteroid_2d.global_position - player_pos) * _world_to_minimap_scale

		# Skip if outside minimap circle (use effective_radius for early-out)
		var bounding: float = 0.0
		if "effective_radius" in asteroid_2d:
			bounding = float(asteroid_2d.get("effective_radius")) * _world_to_minimap_scale
		if offset.length() - bounding > radius:
			continue

		# Skip if in unexplored area
		if _fog_of_war and not _fog_of_war.is_explored(asteroid_2d.global_position):
			continue

		# Get actual polygon and color from the asteroid
		if asteroid_2d.has_method("get_polygon_points"):
			var points: PackedVector2Array = asteroid_2d.get_polygon_points()
			if points.size() < 3:
				continue
			var color: Color = COLOR_ASTEROID
			if asteroid_2d.has_method("get_polygon_color"):
				var base_color: Color = asteroid_2d.get_polygon_color()
				color = Color(base_color.r, base_color.g, base_color.b, 0.7)

			# Scale polygon points to minimap space
			var scaled_points: PackedVector2Array = PackedVector2Array()
			scaled_points.resize(points.size())
			var any_clamped: bool = false
			for i: int in range(points.size()):
				var pt: Vector2 = center + offset + points[i] * _world_to_minimap_scale
				var to_pt: Vector2 = pt - center
				if to_pt.length() > radius - 1.0:
					pt = center + to_pt.normalized() * (radius - 1.0)
					any_clamped = true
				scaled_points[i] = pt

			# Keep shape readability at minimap edge instead of degrading to circles.
			if any_clamped:
				draw_polyline(scaled_points, color, 1.4, true)
			else:
				draw_colored_polygon(scaled_points, color)
		else:
			# Fallback: draw dot for non-Asteroid nodes in group
			draw_circle(center + offset, 4.0, COLOR_ASTEROID)


func _find_player() -> void:
	_player = FrameCache.player


## Returns the fog of war instance (for sharing with full map overlay).
func get_fog_of_war() -> RefCounted:
	return _fog_of_war
