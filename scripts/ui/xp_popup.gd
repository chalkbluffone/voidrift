class_name XpPopup
extends RichTextLabel

## Persistent accumulated XP counter that follows the player ship.
## Lives in screen space (HUD CanvasLayer). Position is set externally by HUD.

const XP_POPUP_FONT: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")

var _accumulated_xp: float = 0.0
var _idle_timer: float = 0.0
var _is_active: bool = false
var _fade_tween: Tween = null
var _punch_tween: Tween = null
var _offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	var angle_rad: float = deg_to_rad(GameConfig.XP_POPUP_ANGLE_DEG)
	_offset = Vector2(cos(angle_rad), sin(angle_rad)) * GameConfig.XP_POPUP_RADIUS

	# Font styling (applied once)
	add_theme_font_override("bold_font", XP_POPUP_FONT)
	add_theme_font_override("normal_font", XP_POPUP_FONT)
	add_theme_font_size_override("bold_font_size", GameConfig.XP_POPUP_FONT_SIZE)
	add_theme_font_size_override("normal_font_size", GameConfig.XP_POPUP_FONT_SIZE)
	add_theme_constant_override("outline_size", GameConfig.XP_POPUP_OUTLINE_SIZE)
	add_theme_color_override("font_outline_color", Color.BLACK)
	self_modulate = GameConfig.XP_POPUP_COLOR
	visible = false
	set_process(false)


## Add XP to the accumulated counter. Resets idle timer and shows the label.
func add_xp(amount: float) -> void:
	_accumulated_xp += amount
	_idle_timer = GameConfig.XP_POPUP_IDLE_TIMEOUT

	var display_value: int = maxi(int(_accumulated_xp), 1)

	# Cancel any ongoing fade
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null

	# Show and reset opacity
	modulate.a = 1.0
	visible = true
	_is_active = true
	set_process(true)

	# Update text
	text = "[b]+%d[/b]" % display_value

	# Scale punch animation
	_play_punch()


## Position the popup at a fixed offset from screen center.
func update_screen_position() -> void:
	var screen_center: Vector2 = get_viewport_rect().size * 0.5
	position = (screen_center + _offset).round()


func _process(delta: float) -> void:
	if not _is_active:
		return
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_start_fade()


func _play_punch() -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	scale = Vector2.ONE
	_punch_tween = create_tween()
	var punch: float = GameConfig.XP_POPUP_PUNCH_SCALE
	_punch_tween.tween_property(self, "scale", Vector2(punch, punch), 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "scale", Vector2.ONE, 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _start_fade() -> void:
	_is_active = false
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, GameConfig.XP_POPUP_FADE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(_on_fade_complete)


func _on_fade_complete() -> void:
	visible = false
	set_process(false)
	_accumulated_xp = 0.0
	scale = Vector2.ONE
	text = ""
