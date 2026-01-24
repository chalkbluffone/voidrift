extends Node2D

@export var stars_far_rect_path: NodePath
@export var stars_near_rect_path: NodePath

@onready var GameManager: Node = get_node("/root/GameManager")

func _enter_tree() -> void:
	randomize()
	GameSeed.set_seed_from_int(randi())

func _ready() -> void:
	_set_star_seed(stars_far_rect_path, "stars_far")
	_set_star_seed(stars_near_rect_path, "stars_near")
	
	# Start the run if no main menu launched it
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.current_state = GameManager.GameState.PLAYING
		GameManager.run_data.time_elapsed = 0.0
		GameManager.run_data.time_remaining = GameManager.run_duration

func _set_star_seed(rect_path: NodePath, ns: String) -> void:
	var rect := get_node(rect_path) as ColorRect
	var mat := rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("seed", GameSeed.derive_seed(ns))
