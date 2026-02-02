extends Control

## Options Menu - Game settings and configuration.
## Uses SettingsManager autoload for centralized settings management.

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var _settings: Node = get_node("/root/SettingsManager")
@onready var master_slider: HSlider = $Panel/VBoxContainer/MasterVolume/Slider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXVolume/Slider
@onready var music_slider: HSlider = $Panel/VBoxContainer/MusicVolume/Slider
@onready var fullscreen_check: CheckButton = $Panel/VBoxContainer/Fullscreen/CheckButton
@onready var vsync_check: CheckButton = $Panel/VBoxContainer/VSync/CheckButton
@onready var back_button: Button = $Panel/VBoxContainer/BackButton


func _ready() -> void:
	_sync_ui_from_settings()
	_connect_signals()
	back_button.grab_focus()


func _sync_ui_from_settings() -> void:
	master_slider.value = _settings.master_volume
	sfx_slider.value = _settings.sfx_volume
	music_slider.value = _settings.music_volume
	fullscreen_check.button_pressed = _settings.fullscreen
	vsync_check.button_pressed = _settings.vsync


func _connect_signals() -> void:
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	back_button.pressed.connect(_on_back_pressed)


func _on_master_volume_changed(value: float) -> void:
	_settings.set_master_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	_settings.set_sfx_volume(value)


func _on_music_volume_changed(value: float) -> void:
	_settings.set_music_volume(value)


func _on_fullscreen_toggled(pressed: bool) -> void:
	_settings.set_fullscreen(pressed)


func _on_vsync_toggled(pressed: bool) -> void:
	_settings.set_vsync(pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
