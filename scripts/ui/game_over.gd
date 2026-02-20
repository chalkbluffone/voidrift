extends CanvasLayer

## Game Over screen - Shows run stats and allows retry or return to menu.
## Listens for RunManager.run_ended signal.

const CARD_HOVER_FX_SCRIPT: Script = preload("res://scripts/ui/card_hover_fx.gd")

@onready var game_over_label: Label = $VBoxContainer/GameOverLabel
@onready var time_label: Label = $VBoxContainer/StatsContainer/TimeLabel
@onready var level_label: Label = $VBoxContainer/StatsContainer/LevelLabel
@onready var kills_label: Label = $VBoxContainer/StatsContainer/KillsLabel
@onready var credits_label: Label = $VBoxContainer/StatsContainer/CreditsLabel
@onready var stardust_label: Label = $VBoxContainer/StatsContainer/StardustLabel
@onready var retry_button: Button = $VBoxContainer/ButtonsContainer/RetryButton
@onready var main_menu_button: Button = $VBoxContainer/ButtonsContainer/MainMenuButton

const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")

var _button_hover_tweens: Dictionary = {}


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
		game_over_label.add_theme_color_override("font_color", UiColors.NEON_YELLOW)
	else:
		game_over_label.text = "GAME OVER"
		game_over_label.add_theme_color_override("font_color", UiColors.DEFEAT_TITLE)

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
	await get_tree().create_timer(GameConfig.GAME_OVER_DELAY).timeout
	visible = true
	retry_button.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_main_menu_pressed()
		get_viewport().set_input_as_handled()


func _apply_synthwave_theme() -> void:
	# Title
	game_over_label.add_theme_font_override("font", FONT_HEADER)
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.add_theme_color_override("font_outline_color", UiColors.DEFEAT_OUTLINE)
	game_over_label.add_theme_constant_override("outline_size", 4)

	# Stats labels - cyan
	for label: Label in [time_label, level_label, kills_label, credits_label, stardust_label]:
		label.add_theme_color_override("font_color", UiColors.CYAN)
		label.add_theme_font_size_override("font_size", 20)

	# Buttons - synthwave style with focus support
	for button: Button in [retry_button, main_menu_button]:
		CARD_HOVER_FX_SCRIPT.style_synthwave_button(button, UiColors.BUTTON_PRIMARY, _button_hover_tweens, 4)


func _on_retry_pressed() -> void:
	visible = false
	get_tree().paused = false
	# Re-launch with the same ship and captain from the current run
	var ship_id: String = String(RunManager.run_data.get("ship_id", ""))
	var captain_id: String = String(RunManager.run_data.get("captain_id", ""))
	if ship_id != "" and captain_id != "":
		RunManager.start_run(ship_id, captain_id)
	else:
		# Fallback: send to selection screen if no loadout stored
		RunManager.current_state = RunManager.GameState.MAIN_MENU
		get_tree().change_scene_to_file("res://scenes/ui/ship_select.tscn")


func _on_main_menu_pressed() -> void:
	visible = false
	get_tree().paused = false
	RunManager.go_to_main_menu()
