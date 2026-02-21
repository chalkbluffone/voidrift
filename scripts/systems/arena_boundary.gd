extends Node2D

## ArenaBoundary - Manages the circular arena boundary and radiation belt.
## Applies damage and push force to player when in the radiation zone.

signal player_entered_radiation
signal player_exited_radiation

@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")

var _player: Node2D = null
var _was_in_radiation: bool = false
var _radiation_visual: ColorRect = null
var _radiation_material: ShaderMaterial = null


func _ready() -> void:
	_find_player()
	_setup_visual()
	if FileLogger:
		FileLogger.log_info("ArenaBoundary", "Arena boundary initialized (radius: %.0f, belt: %.0f)" % [
			GameConfig.ARENA_RADIUS, GameConfig.RADIATION_BELT_WIDTH
		])


func _physics_process(delta: float) -> void:
	if _player == null:
		_find_player()
		return
	
	var is_in_radiation: bool = ArenaUtils.is_in_radiation_belt(_player.global_position)
	
	# Emit signals on state change
	if is_in_radiation and not _was_in_radiation:
		player_entered_radiation.emit()
		if FileLogger:
			FileLogger.log_debug("ArenaBoundary", "Player entered radiation belt")
	elif not is_in_radiation and _was_in_radiation:
		player_exited_radiation.emit()
		if FileLogger:
			FileLogger.log_debug("ArenaBoundary", "Player exited radiation belt")
	
	_was_in_radiation = is_in_radiation
	
	if is_in_radiation:
		_apply_radiation_effects(delta)


## Apply radiation damage and push force to player.
func _apply_radiation_effects(delta: float) -> void:
	var intensity: float = ArenaUtils.get_radiation_intensity(_player.global_position)
	
	# Apply damage scaled by intensity (more damage deeper in belt)
	var damage: float = GameConfig.RADIATION_DAMAGE_PER_SEC * intensity * delta
	if damage > 0 and _player.has_method("take_damage"):
		_player.take_damage(damage, self)
	
	# Apply push force toward center
	var push_direction: Vector2 = ArenaUtils.get_direction_to_center(_player.global_position)
	var push_force: Vector2 = push_direction * GameConfig.RADIATION_PUSH_FORCE * intensity
	
	if _player.has_method("apply_external_force"):
		_player.apply_external_force(push_force)


func _find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D


## Create the radiation belt visual (large ColorRect with shader).
func _setup_visual() -> void:
	_radiation_visual = ColorRect.new()
	_radiation_visual.name = "RadiationVisual"
	
	# Make base color fully transparent (shader handles all rendering)
	_radiation_visual.color = Color(0, 0, 0, 0)
	
	# Size to viewport - this will follow the camera and we'll pass world coords
	# We'll update position each frame to follow the player
	_radiation_visual.size = Vector2(4096, 4096)  # Large enough to cover screen at any zoom
	
	# Apply radiation belt shader
	var shader: Shader = preload("res://shaders/radiation_belt.gdshader")
	_radiation_material = ShaderMaterial.new()
	_radiation_material.shader = shader
	_radiation_material.set_shader_parameter("arena_radius", GameConfig.ARENA_RADIUS)
	_radiation_material.set_shader_parameter("belt_width", GameConfig.RADIATION_BELT_WIDTH)
	_radiation_material.set_shader_parameter("rect_size", _radiation_visual.size)
	_radiation_visual.material = _radiation_material
	
	# Set z_index to render behind most game objects but above starfield
	_radiation_visual.z_index = -50
	
	add_child(_radiation_visual)


func _process(_delta: float) -> void:
	if _player == null or _radiation_visual == null:
		return
	
	# Keep the ColorRect centered on player so radiation belt renders correctly
	var half_size: Vector2 = _radiation_visual.size * 0.5
	_radiation_visual.global_position = _player.global_position - half_size
	
	# Pass player world position to shader so it can calculate distances from arena center
	if _radiation_material:
		_radiation_material.set_shader_parameter("camera_world_pos", _player.global_position)
