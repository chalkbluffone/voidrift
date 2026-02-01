extends CanvasLayer

## Pause Menu - Shows when ESC is pressed during gameplay.
## Pauses the game and provides navigation options.

signal resumed

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAME_SCENE := "res://scenes/gameplay/world.tscn"

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
	var game_manager = get_node("/root/GameManager")
	game_manager.current_state = game_manager.GameState.MAIN_MENU
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


# --- Options handlers ---

func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	_save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	_save_settings()


func _on_music_volume_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	_save_settings()


func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _on_vsync_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_save_settings()


const SAVE_PATH := "user://settings.cfg"

func _save_settings() -> void:
	var master_slider = options_container.get_node_or_null("Panel/VBoxContainer/MasterVolume/Slider")
	var sfx_slider = options_container.get_node_or_null("Panel/VBoxContainer/SFXVolume/Slider")
	var music_slider = options_container.get_node_or_null("Panel/VBoxContainer/MusicVolume/Slider")
	var fullscreen_check = options_container.get_node_or_null("Panel/VBoxContainer/Fullscreen/CheckButton")
	var vsync_check = options_container.get_node_or_null("Panel/VBoxContainer/VSync/CheckButton")
	
	var config = ConfigFile.new()
	if master_slider:
		config.set_value("audio", "master", master_slider.value)
	if sfx_slider:
		config.set_value("audio", "sfx", sfx_slider.value)
	if music_slider:
		config.set_value("audio", "music", music_slider.value)
	if fullscreen_check:
		config.set_value("display", "fullscreen", fullscreen_check.button_pressed)
	if vsync_check:
		config.set_value("display", "vsync", vsync_check.button_pressed)
	config.save(SAVE_PATH)


func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	
	var master_slider = options_container.get_node_or_null("Panel/VBoxContainer/MasterVolume/Slider")
	var sfx_slider = options_container.get_node_or_null("Panel/VBoxContainer/SFXVolume/Slider")
	var music_slider = options_container.get_node_or_null("Panel/VBoxContainer/MusicVolume/Slider")
	var fullscreen_check = options_container.get_node_or_null("Panel/VBoxContainer/Fullscreen/CheckButton")
	var vsync_check = options_container.get_node_or_null("Panel/VBoxContainer/VSync/CheckButton")
	
	if master_slider:
		master_slider.value = config.get_value("audio", "master", 1.0)
	if sfx_slider:
		sfx_slider.value = config.get_value("audio", "sfx", 1.0)
	if music_slider:
		music_slider.value = config.get_value("audio", "music", 1.0)
	if fullscreen_check:
		fullscreen_check.button_pressed = config.get_value("display", "fullscreen", false)
	if vsync_check:
		vsync_check.button_pressed = config.get_value("display", "vsync", true)


func _connect_options_signals() -> void:
	var master_slider = options_container.get_node_or_null("Panel/VBoxContainer/MasterVolume/Slider")
	var sfx_slider = options_container.get_node_or_null("Panel/VBoxContainer/SFXVolume/Slider")
	var music_slider = options_container.get_node_or_null("Panel/VBoxContainer/MusicVolume/Slider")
	var fullscreen_check = options_container.get_node_or_null("Panel/VBoxContainer/Fullscreen/CheckButton")
	var vsync_check = options_container.get_node_or_null("Panel/VBoxContainer/VSync/CheckButton")
	var back_btn = options_container.get_node_or_null("Panel/VBoxContainer/BackButton")
	
	if master_slider and not master_slider.value_changed.is_connected(_on_master_volume_changed):
		master_slider.value_changed.connect(_on_master_volume_changed)
	if sfx_slider and not sfx_slider.value_changed.is_connected(_on_sfx_volume_changed):
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	if music_slider and not music_slider.value_changed.is_connected(_on_music_volume_changed):
		music_slider.value_changed.connect(_on_music_volume_changed)
	if fullscreen_check and not fullscreen_check.toggled.is_connected(_on_fullscreen_toggled):
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if vsync_check and not vsync_check.toggled.is_connected(_on_vsync_toggled):
		vsync_check.toggled.connect(_on_vsync_toggled)
	if back_btn and not back_btn.pressed.is_connected(_on_options_back_pressed):
		back_btn.pressed.connect(_on_options_back_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		call_deferred("_deferred_setup")


func _deferred_setup() -> void:
	_connect_options_signals()
	_load_settings()
