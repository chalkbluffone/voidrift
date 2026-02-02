extends Node

## RunManager - Handles run lifecycle, timing, scene transitions, and pause state.
## Autoload singleton: RunManager

signal run_started
signal run_ended(victory: bool, stats: Dictionary)
signal pause_toggled(is_paused: bool)
signal time_updated(elapsed: float, remaining: float)

# --- Scenes ---
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAMEPLAY_SCENE := "res://scenes/gameplay/world.tscn"
const GAME_OVER_SCENE := "res://scenes/ui/game_over.tscn"

# --- Game State ---
enum GameState {
	MAIN_MENU,
	PLAYING,
	PAUSED,
	LEVEL_UP,
	GAME_OVER
}

var current_state: GameState = GameState.MAIN_MENU

# --- Run Configuration ---
const DEFAULT_RUN_DURATION := 600.0  # 10 minutes
var run_duration: float = DEFAULT_RUN_DURATION

# --- Run Data ---
var run_data: Dictionary = {}

# --- Node References ---
var _player: Node = null

@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var FileLogger: Node = get_node("/root/FileLogger")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_run_data()


func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		run_data.time_elapsed += delta
		run_data.time_remaining = max(0.0, run_duration - run_data.time_elapsed)
		time_updated.emit(run_data.time_elapsed, run_data.time_remaining)


# --- Scene Management ---

func go_to_main_menu() -> void:
	current_state = GameState.MAIN_MENU
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func start_run(character_id: String) -> void:
	"""Begin a new run with the specified character."""
	_reset_run_data()
	
	# Load character
	var character: Dictionary = DataLoader.get_character(character_id)
	if character.is_empty():
		push_error("RunManager: Invalid character ID: " + character_id)
		return
	
	run_data.character_id = character_id
	run_data.character_data = character
	
	# Add starting weapon
	var starting_weapon: String = character.get("starting_weapon", "plasma_cannon")
	run_data.weapons.append(starting_weapon)
	
	current_state = GameState.PLAYING
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)
	run_started.emit()


func end_run(victory: bool) -> void:
	"""End the current run."""
	current_state = GameState.GAME_OVER
	get_tree().paused = true
	run_ended.emit(victory, run_data.duplicate())


func _reset_run_data() -> void:
	run_data = {
		# Character
		"character_id": "",
		"character_data": {},
		
		# Progression (managed by ProgressionManager but stored here)
		"level": 1,
		"xp": 0.0,
		"xp_required": 100.0,
		"time_elapsed": 0.0,
		"time_remaining": run_duration,
		
		# Currency
		"credits": 0,
		
		# Weapons & Upgrades
		"weapons": [],
		"ship_upgrades": [],
		"items": [],
		
		# Stats
		"enemies_killed": 0,
		"elites_killed": 0,
		"bosses_killed": 0,
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
		"credits_collected": 0,
		"xp_collected": 0.0,
		"distance_traveled": 0.0,
		"phases_performed": 0,
	}


# --- Pause ---

func pause_game() -> void:
	if current_state != GameState.PLAYING:
		return
	current_state = GameState.PAUSED
	get_tree().paused = true
	pause_toggled.emit(true)


func resume_game() -> void:
	if current_state != GameState.PAUSED and current_state != GameState.LEVEL_UP:
		return
	current_state = GameState.PLAYING
	get_tree().paused = false
	pause_toggled.emit(false)


func set_level_up_state() -> void:
	"""Called by ProgressionManager when level up is triggered."""
	current_state = GameState.LEVEL_UP
	get_tree().paused = true


# --- Player Reference ---

func register_player(player_node: Node) -> void:
	_player = player_node
	if _player.has_signal("died"):
		_player.died.connect(_on_player_died)


func get_player() -> Node:
	return _player


func _on_player_died() -> void:
	end_run(false)


# --- Stats Recording ---

func record_kill(enemy_type: String) -> void:
	run_data.enemies_killed += 1
	if enemy_type == "elite":
		run_data.elites_killed += 1
	elif enemy_type == "boss":
		run_data.bosses_killed += 1


func record_damage_dealt(amount: float) -> void:
	run_data.damage_dealt += amount


func record_damage_taken(amount: float) -> void:
	run_data.damage_taken += amount


func record_phase() -> void:
	run_data.phases_performed += 1


# --- Getters ---

func get_run_time_formatted() -> String:
	var total_seconds: int = int(run_data.time_elapsed)
	@warning_ignore("integer_division")
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func get_equipped_weapons() -> Array:
	return run_data.weapons.duplicate()


func get_ship_upgrades() -> Array:
	return run_data.ship_upgrades.duplicate()
