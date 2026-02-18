extends Control

## Main Menu - Entry point for the game.
## Provides navigation to Play, Options, and Weapons Lab.

const SHIP_SELECT_SCENE: String = "res://scenes/ui/ship_select.tscn"
const OPTIONS_SCENE: String = "res://scenes/ui/options_menu.tscn"
const WEAPONS_LAB_SCENE: String = "res://tools/weapon_test_lab/weapon_test_lab.tscn"

const CARD_HOVER_FX_SCRIPT: Script = preload("res://scripts/ui/card_hover_fx.gd")

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var options_button: Button = $VBoxContainer/OptionsButton
@onready var weapons_lab_button: Button = $VBoxContainer/WeaponsLabButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

var _button_hover_tweens: Dictionary = {}


func _ready() -> void:
	# Connect button signals
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	weapons_lab_button.pressed.connect(_on_weapons_lab_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Style all buttons with synthwave focus/hover support
	for button: Button in [play_button, options_button, weapons_lab_button, quit_button]:
		CARD_HOVER_FX_SCRIPT.style_synthwave_button(button, UiColors.BUTTON_PRIMARY, _button_hover_tweens, 4)

	# Focus first button for gamepad/keyboard nav
	play_button.grab_focus()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(SHIP_SELECT_SCENE)


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)


func _on_weapons_lab_pressed() -> void:
	get_tree().change_scene_to_file(WEAPONS_LAB_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
