extends Control

## Minimap - Circular minimap showing player surroundings with fog of war.
## Shows: player position, enemies (if explored), arena boundary, pickups.

const FogOfWarScript: GDScript = preload("res://scripts/systems/fog_of_war.gd")
const FogShader: Shader = preload("res://shaders/fog_of_war.gdshader")

# Colors for minimap elements
const COLOR_BACKGROUND: Color = Color(0.05, 0.05, 0.1, 0.8)
const COLOR_PLAYER: Color = Color(0.0, 1.0, 0.9, 1.0)  # Cyan
const COLOR_ENEMY: Color = Color(1.0, 0.2, 0.2, 1.0)   # Red
const COLOR_PICKUP: Color = Color(0.5, 1.0, 0.3, 1.0)  # Green
const COLOR_BOUNDARY: Color = Color(1.0, 0.0, 1.0, 0.6)  # Pink
const COLOR_FOG: Color = Color(0.0, 0.0, 0.0, 0.9)
const COLOR_EXPLORED: Color = Color(0.15, 0.15, 0.2, 0.6)

@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")

var _player: Node2D = null
var _fog_of_war: RefCounted = null
var _minimap_size: float = 180.0
var _world_radius: float = 1200.0  # World radius visible in minimap
var _world_to_minimap_scale: float = 0.05

var _fog_overlay: ColorRect = null
var _fog_material: ShaderMaterial = null


func _ready() -> void:
	_minimap_size = GameConfig.MINIMAP_SIZE
	_world_radius = GameConfig.MINIMAP_WORLD_RADIUS
	
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
	
	if FileLogger:
		FileLogger.log_info("Minimap", "Initialized (size: %.0f, world_radius: %.0f)" % [_minimap_size, _world_radius])


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


func _process(_delta: float) -> void:
	if _player == null:
		_find_player()
	
	if _player and _fog_of_war:
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
	
	# Draw enemies
	_draw_enemies(center, radius, player_pos)
	
	# Draw pickups
	_draw_pickups(center, radius, player_pos)
	
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
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	
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
	var pickups: Array[Node] = get_tree().get_nodes_in_group("pickups")
	
	for pickup: Node in pickups:
		if not pickup is Node2D:
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


func _find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D


## Returns the fog of war instance (for sharing with full map overlay).
func get_fog_of_war() -> RefCounted:
	return _fog_of_war
