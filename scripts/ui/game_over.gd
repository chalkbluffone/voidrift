extends CanvasLayer

## Game Over screen - Shows run stats and allows retry or return to menu.
## Listens for RunManager.run_ended signal.

@onready var game_over_label: Label = $VBoxContainer/GameOverLabel
@onready var time_label: Label = $VBoxContainer/StatsContainer/TimeLabel
@onready var level_label: Label = $VBoxContainer/StatsContainer/LevelLabel
@onready var kills_label: Label = $VBoxContainer/StatsContainer/KillsLabel
@onready var credits_label: Label = $VBoxContainer/StatsContainer/CreditsLabel
@onready var stardust_label: Label = $VBoxContainer/StatsContainer/StardustLabel
@onready var retry_button: Button = $VBoxContainer/ButtonsContainer/RetryButton
@onready var main_menu_button: Button = $VBoxContainer/ButtonsContainer/MainMenuButton

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var GameManager: Node = get_node("/root/GameManager")
@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect buttons
	retry_button.pressed.connect(_on_retry_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	# Listen for run end
	RunManager.run_ended.connect(_on_run_ended)

	# Start hidden
	visible = false


func _on_run_ended(victory: bool, stats: Dictionary) -> void:
	if FileLogger:
		FileLogger.log_info("GameOver", "Run ended. Victory: %s" % victory)

	# Set title
	if victory:
		game_over_label.text = "VICTORY"
		game_over_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2, 1.0))
	else:
		game_over_label.text = "GAME OVER"
		game_over_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.3, 1.0))

	# Populate stats
	var elapsed: float = stats.get("time_elapsed", 0.0)
	var total_seconds: int = int(elapsed)
	@warning_ignore("integer_division")
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	time_label.text = "Time Survived: %02d:%02d" % [minutes, seconds]

	level_label.text = "Level Reached: %d" % stats.get("level", 1)
	kills_label.text = "Enemies Killed: %d" % stats.get("enemies_killed", 0)
	credits_label.text = "⟐ Intergalactic Space Credits Earned: %d" % stats.get("credits_collected", 0)
	stardust_label.text = "✦ Stardust Earned: 0"  # TODO: track stardust earned

	# Style labels
	_apply_synthwave_theme()

	# Show with brief delay so death animation plays
	await get_tree().create_timer(0.6).timeout
	visible = true


func _apply_synthwave_theme() -> void:
	# Title
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.add_theme_color_override("font_outline_color", Color(0.4, 0, 0.1, 1.0))
	game_over_label.add_theme_constant_override("outline_size", 4)

	# Stats labels - cyan
	for label: Label in [time_label, level_label, kills_label, credits_label, stardust_label]:
		label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.9, 1.0))
		label.add_theme_font_size_override("font_size", 20)

	# Buttons - synthwave style
	for button: Button in [retry_button, main_menu_button]:
		button.add_theme_font_size_override("font_size", 22)


func _on_retry_pressed() -> void:
	visible = false
	get_tree().paused = false
	# Match pause menu restart: reset state then reload scene
	RunManager.current_state = RunManager.GameState.MAIN_MENU
	get_tree().change_scene_to_file("res://scenes/gameplay/world.tscn")


func _on_main_menu_pressed() -> void:
	visible = false
	get_tree().paused = false
	RunManager.go_to_main_menu()
