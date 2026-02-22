extends Node2D

## ArenaBoundary - Manages the circular arena boundary and radiation belt.
## Applies damage and push force to player when in the radiation zone.

signal player_entered_radiation
signal player_exited_radiation

var _player: Node2D = null
var _was_in_radiation: bool = false
var _radiation_visual: Sprite2D = null
var _radiation_material: ShaderMaterial = null


func _ready() -> void:
	_find_player()
	_setup_visual()


func _physics_process(delta: float) -> void:
	if _player == null:
		_find_player()
		return
	
	var is_in_radiation: bool = ArenaUtils.is_in_radiation_belt(_player.global_position)
	
	# Emit signals on state change
	if is_in_radiation and not _was_in_radiation:
		player_entered_radiation.emit()
	elif not is_in_radiation and _was_in_radiation:
		player_exited_radiation.emit()
	
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


## Create the radiation belt visual (Sprite2D with shader for proper z-ordering).
func _setup_visual() -> void:
	_radiation_visual = Sprite2D.new()
	_radiation_visual.name = "RadiationVisual"
	
	# Create a texture sized for proper UV mapping
	# Using a small texture but setting region to get proper UV coordinates
	var rect_size: Vector2 = Vector2(4096, 4096)
	var tex_size: int = 64  # Small texture, shader does the work
	var img: Image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_radiation_visual.texture = tex
	
	# Scale sprite to desired world size
	_radiation_visual.scale = rect_size / Vector2(tex_size, tex_size)
	_radiation_visual.centered = true
	
	# Apply radiation belt shader
	var shader: Shader = preload("res://shaders/radiation_belt.gdshader")
	_radiation_material = ShaderMaterial.new()
	_radiation_material.shader = shader
	_radiation_material.set_shader_parameter("arena_radius", GameConfig.ARENA_RADIUS)
	_radiation_material.set_shader_parameter("belt_width", GameConfig.RADIATION_BELT_WIDTH)
	_radiation_material.set_shader_parameter("rect_size", rect_size)
	_radiation_visual.material = _radiation_material
	
	# Set z_index to render above most game elements but below UI
	_radiation_visual.z_index = 10
	
	add_child(_radiation_visual)


func _process(_delta: float) -> void:
	if _player == null or _radiation_visual == null:
		return
	
	# Keep the Sprite2D centered on player so radiation belt renders correctly
	_radiation_visual.global_position = _player.global_position
	
	# Pass player world position to shader so it can calculate distances from arena center
	if _radiation_material:
		_radiation_material.set_shader_parameter("camera_world_pos", _player.global_position)
