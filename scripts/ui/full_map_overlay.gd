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
const COLOR_BOUNDARY: Color = Color(1.0, 0.0, 1.0, 0.8)  # Pink
const COLOR_GRID: Color = Color(0.1, 0.1, 0.15, 0.5)

@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")

var _player: Node2D = null
var _fog_of_war: FogOfWar = null  # Reference from minimap (shared)
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
	
	if FileLogger:
		FileLogger.log_info("FullMapOverlay", "Initialized (size: %.0f)" % _map_size)


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
	
	# Draw pickups
	_draw_pickups(center)
	
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
	var ring_interval: float = 4000.0  # World units between rings
	var ring_count: int = ceili(GameConfig.ARENA_RADIUS / ring_interval)
	
	for i: int in range(1, ring_count):
		var ring_radius: float = float(i) * ring_interval * _world_to_map_scale
		if ring_radius < radius:
			draw_arc(center, ring_radius, 0.0, TAU, 32, COLOR_GRID, 1.0)
	
	# Draw cross lines
	draw_line(center + Vector2(-radius + 2, 0), center + Vector2(radius - 2, 0), COLOR_GRID, 1.0)
	draw_line(center + Vector2(0, -radius + 2), center + Vector2(0, radius - 2), COLOR_GRID, 1.0)


func _draw_enemies(center: Vector2) -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
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
	var pickups: Array[Node] = get_tree().get_nodes_in_group("pickups")
	var radius: float = _map_size * 0.5
	
	for pickup: Node in pickups:
		if not pickup is Node2D:
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


## Show the full map overlay.
func show_map() -> void:
	if _is_visible:
		return
	
	_is_visible = true
	visible = true
	
	if FileLogger:
		FileLogger.log_debug("FullMapOverlay", "Showing full map")


## Hide the full map overlay.
func hide_map() -> void:
	if not _is_visible:
		return
	
	_is_visible = false
	visible = false
	
	if FileLogger:
		FileLogger.log_debug("FullMapOverlay", "Hiding full map")


## Set the fog of war reference (shared with minimap).
func set_fog_of_war(fog: FogOfWar) -> void:
	_fog_of_war = fog


func _find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D
