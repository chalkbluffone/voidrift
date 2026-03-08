class_name DamageNumber
extends RichTextLabel

## Floating damage number that rises and fades out.
## Spawned by enemies on take_damage(). Supports normal, crit, and overcrit styling.

const DAMAGE_NUMBER_FONT: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")

@onready var _game_config: Node = get_node("/root/GameConfig")


func _ready() -> void:
	add_to_group("damage_numbers")


func setup(amount: float, damage_info: Dictionary, world_pos: Vector2) -> void:
	## Configure text, style, and animation based on damage type.
	var is_crit: bool = damage_info.get("is_crit", false)
	var is_overcrit: bool = damage_info.get("is_overcrit", false)
	var is_heal: bool = damage_info.get("is_heal", false)

	# Random offset to prevent stacking
	var offset: Vector2 = Vector2(
		randf_range(-GameConfig.DAMAGE_NUMBER_OFFSET_RANGE, GameConfig.DAMAGE_NUMBER_OFFSET_RANGE),
		randf_range(-GameConfig.DAMAGE_NUMBER_OFFSET_RANGE, GameConfig.DAMAGE_NUMBER_OFFSET_RANGE)
	)
	global_position = world_pos + offset

	# Determine style and z-index layering
	var font_size: int = GameConfig.DAMAGE_NUMBER_FONT_SIZE_NORMAL
	var color: Color = Color.WHITE
	var prefix: String = ""

	if is_heal:
		color = Color(0.2, 1.0, 0.4, 1.0)  # Green
		prefix = "+"
		z_index = 99  # Below damage numbers
	elif is_overcrit:
		font_size = GameConfig.DAMAGE_NUMBER_FONT_SIZE_OVERCRIT
		color = UiColors.HOT_PINK
		z_index = 102  # Above crits
	elif is_crit:
		font_size = GameConfig.DAMAGE_NUMBER_FONT_SIZE_CRIT
		color = UiColors.GOLD
		z_index = 101  # Above normal
	else:
		z_index = 100  # Normal damage

	# Format display text — round to int for clean appearance
	var display_text: String = prefix + str(int(round(amount)))

	# Apply font settings via theme overrides
	add_theme_font_override("bold_font", DAMAGE_NUMBER_FONT)
	add_theme_font_override("normal_font", DAMAGE_NUMBER_FONT)
	add_theme_font_size_override("bold_font_size", font_size)
	add_theme_font_size_override("normal_font_size", font_size)

	# Dark outline for readability over space background
	add_theme_constant_override("outline_size", GameConfig.DAMAGE_NUMBER_OUTLINE_SIZE)
	add_theme_color_override("font_outline_color", Color.BLACK)

	# Apply color via self_modulate — guaranteed to tint regardless of theme/BBCode
	self_modulate = color

	# Build BBCode
	if is_overcrit:
		text = "[shake rate=20.0 level=5 connected=1][b]" + display_text + "[/b][/shake]"
	elif is_crit or is_heal:
		text = "[b]" + display_text + "[/b]"
	else:
		text = display_text

	# Animate: rise upward + fade out
	_animate(is_crit, is_overcrit)


func _animate(is_crit: bool, is_overcrit: bool) -> void:
	var duration: float = GameConfig.DAMAGE_NUMBER_DURATION
	var rise: float = GameConfig.DAMAGE_NUMBER_RISE_DISTANCE
	var tween: Tween = create_tween()

	# Bounce scale for crits
	if is_overcrit:
		pivot_offset = size * 0.5
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2.ONE * GameConfig.DAMAGE_NUMBER_OVERCRIT_SCALE, duration * 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(self, "scale", Vector2.ONE, duration * 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		# Rise and fade run in parallel after bounce
		tween = create_tween()
	elif is_crit:
		pivot_offset = size * 0.5
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2.ONE * GameConfig.DAMAGE_NUMBER_CRIT_SCALE, duration * 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(self, "scale", Vector2.ONE, duration * 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween = create_tween()

	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - rise, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.6) \
		.set_delay(duration * 0.4)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
