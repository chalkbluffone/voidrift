extends Control

## Options Menu - Game settings and configuration.

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var master_slider: HSlider = $Panel/VBoxContainer/MasterVolume/Slider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXVolume/Slider
@onready var music_slider: HSlider = $Panel/VBoxContainer/MusicVolume/Slider
@onready var fullscreen_check: CheckButton = $Panel/VBoxContainer/Fullscreen/CheckButton
@onready var vsync_check: CheckButton = $Panel/VBoxContainer/VSync/CheckButton
@onready var back_button: Button = $Panel/VBoxContainer/BackButton

const SAVE_PATH := "user://settings.cfg"


func _ready() -> void:
	_load_settings()
	_connect_signals()
	back_button.grab_focus()


func _connect_signals() -> void:
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	back_button.pressed.connect(_on_back_pressed)


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


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master", master_slider.value)
	config.set_value("audio", "sfx", sfx_slider.value)
	config.set_value("audio", "music", music_slider.value)
	config.set_value("display", "fullscreen", fullscreen_check.button_pressed)
	config.set_value("display", "vsync", vsync_check.button_pressed)
	config.save(SAVE_PATH)


func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	
	master_slider.value = config.get_value("audio", "master", 1.0)
	sfx_slider.value = config.get_value("audio", "sfx", 1.0)
	music_slider.value = config.get_value("audio", "music", 1.0)
	fullscreen_check.button_pressed = config.get_value("display", "fullscreen", false)
	vsync_check.button_pressed = config.get_value("display", "vsync", true)
	
	# Apply loaded settings
	_on_master_volume_changed(master_slider.value)
	_on_sfx_volume_changed(sfx_slider.value)
	_on_music_volume_changed(music_slider.value)
	_on_fullscreen_toggled(fullscreen_check.button_pressed)
	_on_vsync_toggled(vsync_check.button_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
