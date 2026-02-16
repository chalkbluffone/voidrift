extends CanvasLayer

## Pause Menu - Shows when ESC is pressed during gameplay.
## Pauses the game and provides navigation options.
## Uses SettingsManager autoload for centralized settings management.

signal resumed

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAME_SCENE := "res://scenes/gameplay/world.tscn"

@onready var _settings: Node = get_node("/root/SettingsManager")
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var options_button: Button = $Panel/VBoxContainer/OptionsButton
@onready var quit_run_button: Button = $Panel/VBoxContainer/QuitRunButton
@onready var exit_button: Button = $Panel/VBoxContainer/ExitButton
@onready var panel: PanelContainer = $Panel
@onready var options_container: Control = $OptionsContainer

var _is_paused: bool = false
var _options_visible: bool = false


func _ready() -> void:
	# Connect buttons
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_run_button.pressed.connect(_on_quit_run_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Start hidden
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _options_visible:
			_close_options()
		elif _is_paused:
			_unpause()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	_is_paused = true
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func _unpause() -> void:
	_is_paused = false
	visible = false
	get_tree().paused = false
	resumed.emit()


func _on_resume_pressed() -> void:
	_unpause()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	# Reset run state so world.gd reinitializes properly
	RunManager.current_state = RunManager.GameState.MAIN_MENU
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_options_pressed() -> void:
	_show_options()


func _on_quit_run_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()


# --- Inline Options Menu ---

func _show_options() -> void:
	_options_visible = true
	panel.visible = false
	options_container.visible = true
	_sync_ui_from_settings()
	
	# Focus back button in options
	var back_btn = options_container.get_node_or_null("Panel/VBoxContainer/BackButton")
	if back_btn:
		back_btn.grab_focus()


func _close_options() -> void:
	_options_visible = false
	panel.visible = true
	options_container.visible = false
	options_button.grab_focus()


func _on_options_back_pressed() -> void:
	_close_options()


# --- Options UI Sync ---

func _sync_ui_from_settings() -> void:
	var master_slider = options_container.get_node_or_null("Panel/VBoxContainer/MasterVolume/Slider")
	var sfx_slider = options_container.get_node_or_null("Panel/VBoxContainer/SFXVolume/Slider")
	var music_slider = options_container.get_node_or_null("Panel/VBoxContainer/MusicVolume/Slider")
	var fullscreen_check = options_container.get_node_or_null("Panel/VBoxContainer/Fullscreen/CheckButton")
	var vsync_check = options_container.get_node_or_null("Panel/VBoxContainer/VSync/CheckButton")
	
	if master_slider:
		master_slider.value = _settings.master_volume
	if sfx_slider:
		sfx_slider.value = _settings.sfx_volume
	if music_slider:
		music_slider.value = _settings.music_volume
	if fullscreen_check:
		fullscreen_check.button_pressed = _settings.fullscreen
	if vsync_check:
		vsync_check.button_pressed = _settings.vsync


func _connect_options_signals() -> void:
	var master_slider = options_container.get_node_or_null("Panel/VBoxContainer/MasterVolume/Slider")
	var sfx_slider = options_container.get_node_or_null("Panel/VBoxContainer/SFXVolume/Slider")
	var music_slider = options_container.get_node_or_null("Panel/VBoxContainer/MusicVolume/Slider")
	var fullscreen_check = options_container.get_node_or_null("Panel/VBoxContainer/Fullscreen/CheckButton")
	var vsync_check = options_container.get_node_or_null("Panel/VBoxContainer/VSync/CheckButton")
	var back_btn = options_container.get_node_or_null("Panel/VBoxContainer/BackButton")

	if master_slider and not master_slider.value_changed.is_connected(_settings.set_master_volume):
		master_slider.value_changed.connect(_settings.set_master_volume)
	if sfx_slider and not sfx_slider.value_changed.is_connected(_settings.set_sfx_volume):
		sfx_slider.value_changed.connect(_settings.set_sfx_volume)
	if music_slider and not music_slider.value_changed.is_connected(_settings.set_music_volume):
		music_slider.value_changed.connect(_settings.set_music_volume)
	if fullscreen_check and not fullscreen_check.toggled.is_connected(_settings.set_fullscreen):
		fullscreen_check.toggled.connect(_settings.set_fullscreen)
	if vsync_check and not vsync_check.toggled.is_connected(_settings.set_vsync):
		vsync_check.toggled.connect(_settings.set_vsync)
	if back_btn and not back_btn.pressed.is_connected(_on_options_back_pressed):
		back_btn.pressed.connect(_on_options_back_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		call_deferred("_deferred_setup")


func _deferred_setup() -> void:
	_connect_options_signals()
