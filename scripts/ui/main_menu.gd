extends Control

## Main Menu - Entry point for the game.
## Provides navigation to Play, Options, and Weapons Lab.
## Features animated starfield background, random nebula, and title image with
## scanline/glow/float effects.

const SHIP_SELECT_SCENE: String = "res://scenes/ui/ship_select.tscn"
const OPTIONS_SCENE: String = "res://scenes/ui/options_menu.tscn"
const WEAPONS_LAB_SCENE: String = "res://tools/weapon_test_lab/weapon_test_lab.tscn"

const CARD_HOVER_FX_SCRIPT: Script = preload("res://scripts/ui/card_hover_fx.gd")
const TITLE_GLOW_SHADER: Shader = preload("res://shaders/title_glow.gdshader")

## Pool of nebula textures to randomly pick from on each menu load.
const NEBULA_PATHS: Array[String] = [
	"res://assets/backgrounds/Blue Nebula/Blue_Nebula_01-1024x1024.png",
	"res://assets/backgrounds/Blue Nebula/Blue_Nebula_02-1024x1024.png",
	"res://assets/backgrounds/Blue Nebula/Blue_Nebula_03-1024x1024.png",
	"res://assets/backgrounds/Blue Nebula/Blue_Nebula_04-1024x1024.png",
	"res://assets/backgrounds/Blue Nebula/Blue_Nebula_05-1024x1024.png",
	"res://assets/backgrounds/Blue Nebula/Blue_Nebula_06-1024x1024.png",
	"res://assets/backgrounds/Blue Nebula/Blue_Nebula_08-1024x1024.png",

	"res://assets/backgrounds/Purple Nebula/Purple_Nebula_01-1024x1024.png",
	"res://assets/backgrounds/Purple Nebula/Purple_Nebula_02-1024x1024.png",
	"res://assets/backgrounds/Purple Nebula/Purple_Nebula_03-1024x1024.png",
	"res://assets/backgrounds/Purple Nebula/Purple_Nebula_04-1024x1024.png",
	"res://assets/backgrounds/Purple Nebula/Purple_Nebula_05-1024x1024.png",
	"res://assets/backgrounds/Purple Nebula/Purple_Nebula_06-1024x1024.png",
	"res://assets/backgrounds/Purple Nebula/Purple_Nebula_07-1024x1024.png",
	"res://assets/backgrounds/Purple Nebula/Purple_Nebula_08-1024x1024.png",
]

## Title image sizing as fraction of viewport height.
const TITLE_HEIGHT_FRACTION: float = 0.3

## Entrance animation timing.
const ENTRANCE_DURATION: float = 0.8
const ENTRANCE_START_SCALE: float = 1.15
const BUTTON_FADE_DELAY: float = 0.1

## Float bob parameters are now in the title_glow shader (vertex offset).

## Gap between title image bottom edge and button container top.
const TITLE_BUTTON_GAP: float = 50.0

@onready var play_button: Button = $ButtonContainer/PlayButton
@onready var options_button: Button = $ButtonContainer/OptionsButton
@onready var weapons_lab_button: Button = $ButtonContainer/WeaponsLabButton
@onready var quit_button: Button = $ButtonContainer/QuitButton
@onready var title_image: TextureRect = $TitleImage
@onready var nebula_sprite: Sprite2D = $Starfield/Nebula/NebulaSprite
@onready var stars_far_rect: ColorRect = $Starfield/StarsFar/StarsFarRect
@onready var stars_near_layer: Parallax2D = $Starfield/StarsNear

@onready var _settings: Node = get_node("/root/SettingsManager")

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

	# Randomize nebula texture
	_randomize_nebula()

	# Apply title glow shader
	_apply_title_shader()

	# Size and center the title image
	_layout_title_image()

	# Respect background quality setting
	_apply_background_quality()
	_settings.settings_changed.connect(_on_settings_changed)

	# Start entrance animation (title + buttons)
	_play_entrance_animation()


## Pick a random nebula texture and assign it to the nebula sprite.
func _randomize_nebula() -> void:
	var idx: int = randi() % NEBULA_PATHS.size()
	var tex: Texture2D = load(NEBULA_PATHS[idx]) as Texture2D
	if tex:
		nebula_sprite.texture = tex


## Create and assign the title glow ShaderMaterial.
func _apply_title_shader() -> void:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = TITLE_GLOW_SHADER
	title_image.material = mat


## Size the title image to 30% of viewport height, fully centered.
func _layout_title_image() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var target_h: float = vp_size.y * TITLE_HEIGHT_FRACTION

	# Calculate width from texture aspect ratio
	var tex: Texture2D = title_image.texture
	if not tex:
		return
	var aspect: float = float(tex.get_width()) / float(tex.get_height())
	var target_w: float = target_h * aspect

	# Position centered horizontally, shifted up so buttons fit below
	title_image.custom_minimum_size = Vector2(target_w, target_h)
	title_image.size = Vector2(target_w, target_h)
	title_image.pivot_offset = Vector2(target_w * 0.5, target_h * 0.5)
	title_image.position = Vector2(
		(vp_size.x - target_w) * 0.5,
		(vp_size.y - target_h) * 0.5 - vp_size.y * 0.1
	)

	# Position button container directly below title with gap
	var btn_container: VBoxContainer = $ButtonContainer
	var btn_x: float = (vp_size.x - btn_container.size.x) * 0.5
	var btn_y: float = title_image.position.y + target_h + TITLE_BUTTON_GAP
	btn_container.position = Vector2(btn_x, btn_y)


## Show/hide near-star layer and disable twinkle based on background_quality.
func _apply_background_quality() -> void:
	var quality: int = _settings.background_quality  # 0=Low, 1=High
	stars_near_layer.visible = (quality >= 1)

	var mat: ShaderMaterial = stars_far_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("twinkle", 0.1 if quality >= 1 else 0.0)


func _on_settings_changed() -> void:
	_apply_background_quality()


## Entrance animation: title scales/fades in, then buttons fade in staggered.
func _play_entrance_animation() -> void:
	# Hide everything initially
	title_image.scale = Vector2(ENTRANCE_START_SCALE, ENTRANCE_START_SCALE)
	title_image.modulate.a = 0.0

	var buttons: Array[Button] = [play_button, options_button, weapons_lab_button, quit_button]
	for btn: Button in buttons:
		btn.modulate.a = 0.0

	# Title entrance
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(title_image, "scale", Vector2.ONE, ENTRANCE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(title_image, "modulate:a", 1.0, ENTRANCE_DURATION * 0.75) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Buttons fade in staggered after title
	for i: int in range(buttons.size()):
		var delay: float = ENTRANCE_DURATION * 0.6 + float(i) * BUTTON_FADE_DELAY
		tween.tween_property(buttons[i], "modulate:a", 1.0, 0.3) \
			.set_delay(delay)

	# After entrance, focus first button
	tween.chain().tween_callback(play_button.grab_focus)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(SHIP_SELECT_SCENE)


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)


func _on_weapons_lab_pressed() -> void:
	get_tree().change_scene_to_file(WEAPONS_LAB_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
