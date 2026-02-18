extends Control

## Options Menu - Game settings and configuration.
## Uses SettingsManager autoload for centralized settings management.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const CARD_HOVER_FX_SCRIPT: Script = preload("res://scripts/ui/card_hover_fx.gd")

@onready var _settings: Node = get_node("/root/SettingsManager")
@onready var master_slider: HSlider = $Panel/MarginContainer/VBoxContainer/MasterVolume/Slider
@onready var sfx_slider: HSlider = $Panel/MarginContainer/VBoxContainer/SFXVolume/Slider
@onready var music_slider: HSlider = $Panel/MarginContainer/VBoxContainer/MusicVolume/Slider
@onready var fullscreen_check: CheckButton = $Panel/MarginContainer/VBoxContainer/Fullscreen/CheckButton
@onready var vsync_check: CheckButton = $Panel/MarginContainer/VBoxContainer/VSync/CheckButton
@onready var back_button: Button = $Panel/MarginContainer/VBoxContainer/BackButton

var _button_hover_tweens: Dictionary = {}


func _ready() -> void:
	_sync_ui_from_settings()
	_connect_signals()

	# Style back button with synthwave focus/hover support
	CARD_HOVER_FX_SCRIPT.style_synthwave_button(back_button, UiColors.BUTTON_BACK, _button_hover_tweens, 4)

	# Focus the first slider so controller users start at the top
	master_slider.grab_focus()


func _sync_ui_from_settings() -> void:
	master_slider.value = _settings.master_volume
	sfx_slider.value = _settings.sfx_volume
	music_slider.value = _settings.music_volume
	fullscreen_check.button_pressed = _settings.fullscreen
	vsync_check.button_pressed = _settings.vsync


func _connect_signals() -> void:
	master_slider.value_changed.connect(_settings.set_master_volume)
	sfx_slider.value_changed.connect(_settings.set_sfx_volume)
	music_slider.value_changed.connect(_settings.set_music_volume)
	fullscreen_check.toggled.connect(_settings.set_fullscreen)
	vsync_check.toggled.connect(_settings.set_vsync)
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
