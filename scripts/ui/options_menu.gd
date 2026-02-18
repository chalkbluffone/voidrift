extends Control

## Options Menu - Thin wrapper around the shared OptionsPanel.
## Used from the main menu; navigates back to main menu on back.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

@onready var options_panel: OptionsPanel = $OptionsPanel


func _ready() -> void:
	options_panel.back_pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
