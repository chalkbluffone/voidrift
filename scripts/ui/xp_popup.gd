class_name XpPopup
extends RichTextLabel

## Floating "+X.X XP" popup that appears near the player ship when XP is collected.
## Positioned at a configurable angle and radius from the ship center.
## Uses object pooling via ObjectPool.

const XP_POPUP_FONT: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")


func _ready() -> void:
	add_to_group("damage_numbers")


func reset() -> void:
	modulate = Color.WHITE
	modulate.a = 1.0
	self_modulate = Color.WHITE
	scale = Vector2.ONE
	text = ""
	visible = true
	bbcode_enabled = true
	if not is_in_group("damage_numbers"):
		add_to_group("damage_numbers")


func setup(amount: float, player_pos: Vector2) -> void:
	## Position at the configured angle and radius from the player.
	var angle_rad: float = deg_to_rad(GameConfig.XP_POPUP_ANGLE_DEG)
	var offset: Vector2 = Vector2(cos(angle_rad), sin(angle_rad)) * GameConfig.XP_POPUP_RADIUS
	global_position = player_pos + offset

	# Font styling
	add_theme_font_override("bold_font", XP_POPUP_FONT)
	add_theme_font_override("normal_font", XP_POPUP_FONT)
	add_theme_font_size_override("bold_font_size", GameConfig.XP_POPUP_FONT_SIZE)
	add_theme_font_size_override("normal_font_size", GameConfig.XP_POPUP_FONT_SIZE)
	add_theme_constant_override("outline_size", GameConfig.XP_POPUP_OUTLINE_SIZE)
	add_theme_color_override("font_outline_color", Color.BLACK)

	self_modulate = GameConfig.XP_POPUP_COLOR
	z_index = 98  # Below damage numbers

	# Format: "+1.2 XP" or "+1 XP" for whole numbers
	var display: String = ""
	if absf(amount - roundf(amount)) < 0.01:
		display = "+%d XP" % int(amount)
	else:
		display = "+%.1f XP" % amount
	text = "[b]" + display + "[/b]"

	_animate()


func _animate() -> void:
	var duration: float = GameConfig.XP_POPUP_DURATION
	var rise: float = GameConfig.XP_POPUP_RISE_DISTANCE

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - rise, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.5) \
		.set_delay(duration * 0.5)
	tween.set_parallel(false)
	tween.tween_callback(_return_to_pool)


func _return_to_pool() -> void:
	if is_in_group("damage_numbers"):
		remove_from_group("damage_numbers")
	var pool: Node = get_node_or_null("/root/ObjectPool")
	if pool:
		pool.release("xp_popup", self)
	else:
		queue_free()
