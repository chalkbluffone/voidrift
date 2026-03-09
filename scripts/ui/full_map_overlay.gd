extends Control

## FullMapOverlay - Full arena map displayed when holding Tab/RT.
## Shows: player position, enemies, pickups, arena boundary, fog of war.
## Does NOT pause the game - player can still move while viewing.

const FogOfWarScript: GDScript = preload("res://scripts/systems/fog_of_war.gd")
const FogShader: Shader = preload("res://shaders/fog_of_war.gdshader")

# Colors for map elements (same as minimap for consistency)
const COLOR_BACKGROUND: Color = Color(0.02, 0.02, 0.05, 0.95)
const COLOR_PLAYER: Color = Color(0.0, 1.0, 0.9, 1.0)  # Cyan
const COLOR_ENEMY: Color = Color(1.0, 0.2, 0.2, 1.0)   # Red
const COLOR_PICKUP: Color = Color(0.5, 1.0, 0.3, 1.0)  # Green
const COLOR_STATION: Color = Color(1.0, 0.8, 0.2, 1.0) # Yellow/Gold
const COLOR_ASTEROID: Color = Color(0.45, 0.45, 0.5, 0.7) # Gray
const COLOR_POWERUP_HEALTH: Color = Color(1.0, 0.25, 0.25, 1.0)
const COLOR_POWERUP_SPEED: Color = Color(0.3, 0.7, 1.0, 1.0)
const COLOR_POWERUP_STOPWATCH: Color = Color(1.0, 0.85, 0.25, 1.0)
const COLOR_POWERUP_GRAVITY: Color = Color(0.75, 0.45, 1.0, 1.0)
const COLOR_BOUNDARY: Color = Color(1.0, 0.0, 1.0, 0.8)  # Pink
const COLOR_GRID: Color = Color(0.1, 0.1, 0.15, 0.5)

var _player: Node2D = null
var _fog_of_war: FogOfWar = null  # Reference from minimap (shared)
@onready var FrameCache: Node = get_node("/root/FrameCache")
var _map_size: float = 400.0  # Size of the map panel
var _world_to_map_scale: float = 0.01  # Arena radius to map radius scale
var _is_visible: bool = false

var _fog_overlay: ColorRect = null
var _fog_material: ShaderMaterial = null


func _ready() -> void:
	# Calculate scale: full arena should fit in map panel
	_map_size = GameConfig.FULLMAP_SIZE
	_world_to_map_scale = (_map_size * 0.5) / GameConfig.ARENA_RADIUS
	
	# Set size and position (left side of screen)
	custom_minimum_size = Vector2(_map_size, _map_size)
	size = Vector2(_map_size, _map_size)
	
	# Clip all drawing to map bounds
	clip_contents = true
	
	# Position on left side with margin, vertically centered
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = 20.0
	offset_right = 20.0 + _map_size
	offset_top = -_map_size * 0.5
	offset_bottom = _map_size * 0.5
	
	# Highest z-index to render on top of all UI
	z_index = 100
	
	# Setup fog overlay
	_setup_fog_overlay()
	
	# Start hidden
	visible = false


func _setup_fog_overlay() -> void:
	_fog_overlay = ColorRect.new()
	_fog_overlay.name = "FogOverlay"
	_fog_overlay.size = Vector2(_map_size, _map_size)
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


func _process(_delta: float) -> void:
	if not visible:
		return
	
	if _player == null:
		_find_player()
	
	# Update fog texture
	if _fog_of_war and _fog_material:
		_fog_material.set_shader_parameter("fog_texture", _fog_of_war.get_full_texture())
	
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	
	var center: Vector2 = size * 0.5
	var radius: float = _map_size * 0.5
	
	# Draw circular background
	draw_circle(center, radius, COLOR_BACKGROUND)
	
	# Draw grid lines
	_draw_grid(center, radius)
	
	# Draw arena boundary
	draw_arc(center, radius - 2.0, 0.0, TAU, 64, COLOR_BOUNDARY, 3.0)
	
	# Draw enemies
	_draw_enemies(center)
	
	# Draw asteroids (fog-restricted)
	_draw_asteroids(center)
	
	# Draw stations (only if revealed by fog of war)
	_draw_stations(center)

	# Draw power-ups with unique icon/color markers
	_draw_powerups(center)
	
	# Draw player
	if _player:
		var player_offset: Vector2 = _player.global_position * _world_to_map_scale
		var player_pos: Vector2 = center + player_offset
		
		# Player dot (larger than minimap)
		draw_circle(player_pos, 6.0, COLOR_PLAYER)
		
		# Player direction
		var player_dir: Vector2 = Vector2.from_angle(_player.rotation)
		draw_line(player_pos, player_pos + player_dir * 12.0, COLOR_PLAYER, 3.0)
	
	# Draw border
	draw_arc(center, radius - 1.0, 0.0, TAU, 64, Color(0.0, 1.0, 0.9, 1.0), 2.0)


func _draw_grid(center: Vector2, radius: float) -> void:
	# Draw concentric rings at intervals
	var ring_interval: float = GameConfig.ARENA_RADIUS * GameConfig.FULLMAP_GRID_RING_INTERVAL_COVERAGE
	ring_interval = maxf(ring_interval, 1.0)
	var ring_count: int = ceili(GameConfig.ARENA_RADIUS / ring_interval)
	
	for i: int in range(1, ring_count):
		var ring_radius: float = float(i) * ring_interval * _world_to_map_scale
		if ring_radius < radius:
			draw_arc(center, ring_radius, 0.0, TAU, 32, COLOR_GRID, 1.0)
	
	# Draw cross lines
	draw_line(center + Vector2(-radius + 2, 0), center + Vector2(radius - 2, 0), COLOR_GRID, 1.0)
	draw_line(center + Vector2(0, -radius + 2), center + Vector2(0, radius - 2), COLOR_GRID, 1.0)


func _draw_enemies(center: Vector2) -> void:
	var enemies: Array[Node] = FrameCache.enemies
	var radius: float = _map_size * 0.5
	
	for enemy: Node in enemies:
		if not enemy is Node2D:
			continue
		var enemy_2d: Node2D = enemy as Node2D
		var offset: Vector2 = enemy_2d.global_position * _world_to_map_scale
		
		# Skip if outside map
		if offset.length() > radius - 4.0:
			continue
		
		# Skip if in unexplored area
		if _fog_of_war and not _fog_of_war.is_explored(enemy_2d.global_position):
			continue
		
		draw_circle(center + offset, 3.0, COLOR_ENEMY)


func _draw_pickups(center: Vector2) -> void:
	var pickups: Array[Node] = FrameCache.pickups
	var radius: float = _map_size * 0.5
	
	for pickup: Node in pickups:
		if not pickup is Node2D:
			continue
		if pickup.is_in_group("powerups"):
			continue
		var pickup_2d: Node2D = pickup as Node2D
		var offset: Vector2 = pickup_2d.global_position * _world_to_map_scale
		
		# Skip if outside map
		if offset.length() > radius - 4.0:
			continue
		
		# Skip if in unexplored area
		if _fog_of_war and not _fog_of_war.is_explored(pickup_2d.global_position):
			continue
		
		draw_circle(center + offset, 2.0, COLOR_PICKUP)


func _draw_powerups(center: Vector2) -> void:
	var powerups: Array[Node] = FrameCache.powerups
	var radius: float = _map_size * 0.5

	for powerup: Node in powerups:
		if not powerup is Node2D:
			continue
		var powerup_2d: Node2D = powerup as Node2D
		var offset: Vector2 = powerup_2d.global_position * _world_to_map_scale

		# Skip if outside map
		if offset.length() > radius - 6.0:
			continue

		# Skip if in unexplored area
		if _fog_of_war and not _fog_of_war.is_explored(powerup_2d.global_position):
			continue

		var marker_info: Dictionary = _get_powerup_marker_info(powerup_2d)
		var marker_type: String = String(marker_info.get("marker_type", "unknown"))
		var marker_color: Color = Color(marker_info.get("color", COLOR_PICKUP))
		var marker_pos: Vector2 = center + offset

		draw_circle(marker_pos, 5.0, marker_color)
		draw_circle(marker_pos, 2.7, Color(0.05, 0.05, 0.08, 0.95))
		_draw_powerup_icon(marker_pos, marker_type, marker_color, 1.2)


func _draw_powerup_icon(marker_pos: Vector2, marker_type: String, marker_color: Color, icon_scale: float) -> void:
	if marker_type == "health":
		draw_line(marker_pos + Vector2(-2.0, 0.0) * icon_scale, marker_pos + Vector2(2.0, 0.0) * icon_scale, Color.WHITE, 1.4)
		draw_line(marker_pos + Vector2(0.0, -2.0) * icon_scale, marker_pos + Vector2(0.0, 2.0) * icon_scale, Color.WHITE, 1.4)
	elif marker_type == "speed":
		var bolt_points: PackedVector2Array = PackedVector2Array([
			marker_pos + Vector2(-1.4, -2.0) * icon_scale,
			marker_pos + Vector2(0.3, -2.0) * icon_scale,
			marker_pos + Vector2(-0.6, 0.2) * icon_scale,
			marker_pos + Vector2(1.4, 0.2) * icon_scale,
			marker_pos + Vector2(-0.4, 2.1) * icon_scale,
			marker_pos + Vector2(0.2, 0.6) * icon_scale
		])
		draw_colored_polygon(bolt_points, Color.WHITE)
	elif marker_type == "stopwatch":
		draw_circle(marker_pos, 2.0 * icon_scale, Color.WHITE)
		draw_line(marker_pos + Vector2(0.0, -2.8) * icon_scale, marker_pos + Vector2(0.0, -1.9) * icon_scale, marker_color, 1.1)
		draw_line(marker_pos, marker_pos + Vector2(0.0, -1.1) * icon_scale, marker_color, 1.1)
		draw_line(marker_pos, marker_pos + Vector2(0.9, 0.6) * icon_scale, marker_color, 1.1)
	elif marker_type == "gravity":
		draw_arc(marker_pos, 2.2 * icon_scale, 0.0, TAU, 16, Color.WHITE, 1.2)
		draw_circle(marker_pos, 0.65 * icon_scale, Color.WHITE)
	else:
		draw_circle(marker_pos, 1.3 * icon_scale, Color.WHITE)


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


## Draw space station icons (only if revealed by fog of war).
func _draw_stations(center: Vector2) -> void:
	var stations: Array[Node] = FrameCache.stations
	var radius: float = _map_size * 0.5
	
	for station: Node in stations:
		if not station is Node2D:
			continue
		var station_2d: Node2D = station as Node2D
		var offset: Vector2 = station_2d.global_position * _world_to_map_scale
		
		# Skip if outside map
		if offset.length() > radius - 6.0:
			continue
		
		# Skip depleted stations — they disappear from the map
		if station.has_method("is_depleted") and station.is_depleted():
			continue
		
		# Skip if in unexplored area (fog of war restriction for full map)
		if _fog_of_war and not _fog_of_war.is_explored(station_2d.global_position):
			continue
		
		# Draw station as a larger dot (size 6) to distinguish from other elements
		draw_circle(center + offset, 6.0, COLOR_STATION)


## Draw asteroid shapes on the full map (scaled polygons, not dots).
func _draw_asteroids(center: Vector2) -> void:
	var asteroids: Array[Node] = FrameCache.asteroids
	var radius: float = _map_size * 0.5

	for asteroid: Node in asteroids:
		if not asteroid is Node2D:
			continue
		var asteroid_2d: Node2D = asteroid as Node2D
		var offset: Vector2 = asteroid_2d.global_position * _world_to_map_scale

		# Skip if outside map (use effective_radius for early-out)
		var bounding: float = 0.0
		if "effective_radius" in asteroid_2d:
			bounding = float(asteroid_2d.get("effective_radius")) * _world_to_map_scale
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

			# Scale polygon points to map space and clamp to circle
			var scaled_points: PackedVector2Array = PackedVector2Array()
			scaled_points.resize(points.size())
			for i: int in range(points.size()):
				var pt: Vector2 = center + offset + points[i] * _world_to_map_scale
				var to_pt: Vector2 = pt - center
				if to_pt.length() > radius - 1.0:
					pt = center + to_pt.normalized() * (radius - 1.0)
				scaled_points[i] = pt

			draw_colored_polygon(scaled_points, color)
		else:
			# Fallback: draw dot for non-Asteroid nodes in group
			draw_circle(center + offset, 4.0, COLOR_ASTEROID)


## Show the full map overlay.
func show_map() -> void:
	if _is_visible:
		return
	
	_is_visible = true
	visible = true


## Hide the full map overlay.
func hide_map() -> void:
	if not _is_visible:
		return
	
	_is_visible = false
	visible = false


## Set the fog of war reference (shared with minimap).
func set_fog_of_war(fog: FogOfWar) -> void:
	_fog_of_war = fog


func _find_player() -> void:
	_player = FrameCache.player
