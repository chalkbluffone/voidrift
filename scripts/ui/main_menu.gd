extends Control

## Main Menu - Entry point for the game.
## Provides navigation to Play, Options, and Weapons Lab.

const GAME_SCENE := "res://scenes/gameplay/world.tscn"
const OPTIONS_SCENE := "res://scenes/ui/options_menu.tscn"
const WEAPONS_LAB_SCENE := "res://tools/weapon_test_lab/weapon_test_lab.tscn"

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var options_button: Button = $VBoxContainer/OptionsButton
@onready var weapons_lab_button: Button = $VBoxContainer/WeaponsLabButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	# Connect button signals
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	weapons_lab_button.pressed.connect(_on_weapons_lab_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Focus first button for gamepad/keyboard nav
	play_button.grab_focus()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)


func _on_weapons_lab_pressed() -> void:
	get_tree().change_scene_to_file(WEAPONS_LAB_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
