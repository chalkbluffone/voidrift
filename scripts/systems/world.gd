extends Node2D

@export var stars_far_rect_path: NodePath
@export var stars_near_rect_path: NodePath

const ArenaBoundaryScene: PackedScene = preload("res://scenes/gameplay/arena_boundary.tscn")

@onready var _settings: Node = get_node("/root/SettingsManager")
@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")
var _stars_near_layer: Node = null
var _arena_boundary: Node2D = null

func _enter_tree() -> void:
	randomize()
	GameSeed.set_seed_from_int(randi())

func _ready() -> void:
	_set_star_seed(stars_far_rect_path, "stars_far")
	_set_star_seed(stars_near_rect_path, "stars_near")

	# Cache the StarsNear Parallax2D parent for quality toggling
	var near_rect: ColorRect = get_node_or_null(stars_near_rect_path) as ColorRect
	if near_rect:
		_stars_near_layer = near_rect.get_parent()

	_apply_background_quality()
	_settings.settings_changed.connect(_on_settings_changed)
	
	# Setup arena boundary
	_setup_arena_boundary()
	
	# Spawn player at random safe position
	_setup_player_spawn()

	# Start the run if no main menu launched it
	if RunManager.current_state != RunManager.GameState.PLAYING:
		RunManager.current_state = RunManager.GameState.PLAYING
		RunManager.run_data.time_elapsed = 0.0
		RunManager.run_data.time_remaining = RunManager.run_duration


## Setup the arena boundary (radiation belt).
func _setup_arena_boundary() -> void:
	_arena_boundary = ArenaBoundaryScene.instantiate()
	_arena_boundary.position = Vector2.ZERO
	# Insert before Ship so it renders behind gameplay elements
	add_child(_arena_boundary)
	move_child(_arena_boundary, 1)  # After Starfield
	if FileLogger:
		FileLogger.log_info("World", "Arena boundary added at origin")


## Move the player ship to a random safe spawn position.
func _setup_player_spawn() -> void:
	var ship: Node2D = get_node_or_null("Ship") as Node2D
	if ship:
		var spawn_pos: Vector2 = ArenaUtils.get_random_spawn_position()
		ship.global_position = spawn_pos
		if FileLogger:
			FileLogger.log_info("World", "Player spawned at: %s" % spawn_pos)


func _on_settings_changed() -> void:
	_apply_background_quality()


## Show/hide near-star layer and disable twinkle based on background_quality.
func _apply_background_quality() -> void:
	var quality: int = _settings.background_quality  # 0=Low, 1=High
	if _stars_near_layer and _stars_near_layer is CanvasItem:
		(_stars_near_layer as CanvasItem).visible = (quality >= 1)

	# Disable twinkle on far stars when Low
	var far_rect: ColorRect = get_node_or_null(stars_far_rect_path) as ColorRect
	if far_rect:
		var mat: ShaderMaterial = far_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("twinkle", 0.1 if quality >= 1 else 0.0)


func _set_star_seed(rect_path: NodePath, ns: String) -> void:
	var rect: ColorRect = get_node(rect_path) as ColorRect
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("seed", GameSeed.derive_seed(ns))
