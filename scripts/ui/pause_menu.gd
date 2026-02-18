extends CanvasLayer

## Pause Menu - Shows when ESC is pressed during gameplay.
## Pauses the game and provides navigation options.
## Uses the shared OptionsPanel for settings.

signal resumed

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const CARD_HOVER_FX_SCRIPT: Script = preload("res://scripts/ui/card_hover_fx.gd")

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var options_button: Button = $Panel/VBoxContainer/OptionsButton
@onready var quit_run_button: Button = $Panel/VBoxContainer/QuitRunButton
@onready var exit_button: Button = $Panel/VBoxContainer/ExitButton
@onready var panel: PanelContainer = $Panel
@onready var options_panel: OptionsPanel = $OptionsPanel

var _is_paused: bool = false
var _options_visible: bool = false
var _button_hover_tweens: Dictionary = {}


func _ready() -> void:
	# Connect pause-menu buttons
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_run_button.pressed.connect(_on_quit_run_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Style all buttons with synthwave focus/hover support
	for button: Button in [resume_button, restart_button, options_button, quit_run_button, exit_button]:
		CARD_HOVER_FX_SCRIPT.style_synthwave_button(button, UiColors.BUTTON_PRIMARY, _button_hover_tweens, 4)

	# Connect shared options panel back signal
	options_panel.back_pressed.connect(_close_options)

	# Start hidden
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Start / Escape toggles pause from any sub-state
		if _is_paused:
			if _options_visible:
				_close_options()
			_unpause()
		else:
			_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _is_paused:
		# Circle / B goes back one level
		if _options_visible:
			_close_options()
		else:
			_unpause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	_is_paused = true
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func _unpause() -> void:
	_is_paused = false
	_options_visible = false
	visible = false
	panel.visible = true
	options_panel.visible = false
	get_tree().paused = false
	resumed.emit()


func _on_resume_pressed() -> void:
	_unpause()


func _on_restart_pressed() -> void:
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


func _on_options_pressed() -> void:
	_show_options()


func _on_quit_run_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()


# --- Inline Options ---

func _show_options() -> void:
	_options_visible = true
	panel.visible = false
	options_panel.visible = true
	options_panel.sync_from_settings()
	options_panel.focus_back_button()


func _close_options() -> void:
	_options_visible = false
	panel.visible = true
	options_panel.visible = false
	options_button.grab_focus()
