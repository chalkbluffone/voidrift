extends Node2D

@export var stars_far_rect_path: NodePath
@export var stars_near_rect_path: NodePath

@onready var _settings: Node = get_node("/root/SettingsManager")
var _stars_near_layer: Node = null

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

	# Start the run if no main menu launched it
	if RunManager.current_state != RunManager.GameState.PLAYING:
		RunManager.current_state = RunManager.GameState.PLAYING
		RunManager.run_data.time_elapsed = 0.0
		RunManager.run_data.time_remaining = RunManager.run_duration


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
