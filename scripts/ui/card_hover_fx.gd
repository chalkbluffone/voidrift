extends RefCounted

## Shared synthwave hover FX helper for PanelContainer cards.

const HOVER_META_KEY: String = "_hover_rect"


static func ensure_hover_overlay(
	card: PanelContainer,
	hover_shader: Shader,
	edge_color: Color,
	glow_color: Color,
	click_color: Color = Color(1.0, 0.95, 0.25, 1.0)
) -> void:
	if not card.has_meta(HOVER_META_KEY):
		var hover_rect: ColorRect = ColorRect.new()
		hover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hover_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var hover_mat: ShaderMaterial = ShaderMaterial.new()
		hover_mat.shader = hover_shader
		hover_mat.set_shader_parameter("hover_strength", 0.0)
		hover_mat.set_shader_parameter("click_strength", 0.0)
		hover_mat.set_shader_parameter("click_time", -10.0)
		hover_mat.set_shader_parameter("edge_color", edge_color)
		hover_mat.set_shader_parameter("glow_color", glow_color)
		hover_mat.set_shader_parameter("click_color", click_color)
		hover_rect.material = hover_mat
		card.add_child(hover_rect)
		card.set_meta(HOVER_META_KEY, hover_rect)
	else:
		set_hover_colors(card, edge_color, glow_color, click_color)


static func set_hover_colors(card: PanelContainer, edge_color: Color, glow_color: Color, click_color: Color = Color(1.0, 0.95, 0.25, 1.0)) -> void:
	var hover_mat: ShaderMaterial = _get_hover_material(card)
	if not hover_mat:
		return
	hover_mat.set_shader_parameter("edge_color", edge_color)
	hover_mat.set_shader_parameter("glow_color", glow_color)
	hover_mat.set_shader_parameter("click_color", click_color)


static func tween_hover_state(
	card: PanelContainer,
	hover_tweens: Dictionary,
	hover_key: Variant,
	hovered: bool,
	base_strength: float = 0.0,
	hover_scale: Vector2 = Vector2(1.03, 1.03),
	hover_in_duration: float = 0.16,
	hover_out_duration: float = 0.12
) -> void:
	if hover_tweens.has(hover_key):
		var existing_tween: Tween = hover_tweens[hover_key] as Tween
		if existing_tween and existing_tween.is_valid():
			existing_tween.kill()

	card.pivot_offset = card.size * 0.5

	var hover_mat: ShaderMaterial = _get_hover_material(card)
	if not hover_mat:
		return

	var tween: Tween = card.create_tween()
	tween.set_parallel(true)
	hover_tweens[hover_key] = tween

	var target_strength: float = 1.0 if hovered else base_strength
	var target_scale: Vector2 = hover_scale if hovered else Vector2.ONE
	var duration: float = hover_in_duration if hovered else hover_out_duration

	tween.tween_property(hover_mat, "shader_parameter/hover_strength", target_strength, duration)
	tween.tween_property(card, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func reset_hover(card: PanelContainer, hover_tweens: Dictionary, hover_key: Variant, base_strength: float = 0.0) -> void:
	if hover_tweens.has(hover_key):
		var existing_tween: Tween = hover_tweens[hover_key] as Tween
		if existing_tween and existing_tween.is_valid():
			existing_tween.kill()
		hover_tweens.erase(hover_key)

	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE

	var hover_mat: ShaderMaterial = _get_hover_material(card)
	if not hover_mat:
		return
	hover_mat.set_shader_parameter("hover_strength", base_strength)
	hover_mat.set_shader_parameter("click_strength", 0.0)


## Make a PanelContainer card focusable and trigger hover FX on focus_entered / focus_exited.
## Call AFTER ensure_hover_overlay() so the shader overlay already exists.
## Connects focus_entered → tween hover on, focus_exited → tween hover off.
## Also handles ui_accept to emit the card's gui_input with a synthetic action.
static func setup_card_focus(
	card: PanelContainer,
	hover_tweens: Dictionary,
	hover_key: Variant,
	base_strength: float = 0.0,
	hover_scale: Vector2 = Vector2(1.03, 1.03),
) -> void:
	card.focus_mode = Control.FOCUS_ALL
	card.focus_entered.connect(func() -> void:
		tween_hover_state(card, hover_tweens, hover_key, true, base_strength, hover_scale)
	)
	card.focus_exited.connect(func() -> void:
		tween_hover_state(card, hover_tweens, hover_key, false, base_strength, hover_scale)
	)


## Create a synthwave-styled button with normal / hover / pressed / focus StyleBoxFlat overrides.
## Focus StyleBox matches hover (lightened) so gamepad focus looks identical to mouse hover.
## Connects mouse_entered/exited AND focus_entered/exited to scale tween.
static func style_synthwave_button(
	button: Button,
	base_color: Color,
	hover_tweens: Dictionary,
	corner_radius: int = 4,
	content_margin_h: int = 0,
	content_margin_v: int = 0,
) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.corner_radius_top_left = corner_radius
	normal.corner_radius_top_right = corner_radius
	normal.corner_radius_bottom_left = corner_radius
	normal.corner_radius_bottom_right = corner_radius
	if content_margin_h > 0:
		normal.content_margin_left = content_margin_h
		normal.content_margin_right = content_margin_h
	if content_margin_v > 0:
		normal.content_margin_top = content_margin_v
		normal.content_margin_bottom = content_margin_v
	button.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = base_color.lightened(0.35)
	hover.corner_radius_top_left = corner_radius
	hover.corner_radius_top_right = corner_radius
	hover.corner_radius_bottom_left = corner_radius
	hover.corner_radius_bottom_right = corner_radius
	if content_margin_h > 0:
		hover.content_margin_left = content_margin_h
		hover.content_margin_right = content_margin_h
	if content_margin_v > 0:
		hover.content_margin_top = content_margin_v
		hover.content_margin_bottom = content_margin_v
	button.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = base_color.darkened(0.2)
	pressed.corner_radius_top_left = corner_radius
	pressed.corner_radius_top_right = corner_radius
	pressed.corner_radius_bottom_left = corner_radius
	pressed.corner_radius_bottom_right = corner_radius
	if content_margin_h > 0:
		pressed.content_margin_left = content_margin_h
		pressed.content_margin_right = content_margin_h
	if content_margin_v > 0:
		pressed.content_margin_top = content_margin_v
		pressed.content_margin_bottom = content_margin_v
	button.add_theme_stylebox_override("pressed", pressed)

	# Focus looks the same as hover — visible indicator for gamepad navigation
	var focus: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	button.add_theme_stylebox_override("focus", focus)

	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Connect hover + focus → scale tween (both trigger same visual)
	button.mouse_entered.connect(func() -> void:
		tween_button_scale(button, hover_tweens, true)
	)
	button.mouse_exited.connect(func() -> void:
		tween_button_scale(button, hover_tweens, false)
	)
	button.focus_entered.connect(func() -> void:
		tween_button_scale(button, hover_tweens, true)
	)
	button.focus_exited.connect(func() -> void:
		tween_button_scale(button, hover_tweens, false)
	)


## Scale tween for button hover / focus. Shared logic for mouse and gamepad.
static func tween_button_scale(
	button: Button,
	hover_tweens: Dictionary,
	hovered: bool,
	target_scale: Vector2 = Vector2(1.05, 1.05),
	in_duration: float = 0.14,
	out_duration: float = 0.10,
) -> void:
	if not is_instance_valid(button):
		return
	if button.disabled:
		return
	var btn_key: int = button.get_instance_id()
	button.pivot_offset = button.size * 0.5

	if hover_tweens.has(btn_key) and is_instance_valid(hover_tweens[btn_key]):
		hover_tweens[btn_key].kill()

	var scale_target: Vector2 = target_scale if hovered else Vector2.ONE
	var tw: Tween = button.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(button, "scale", scale_target, in_duration if hovered else out_duration)
	hover_tweens[btn_key] = tw


static func _get_hover_material(card: PanelContainer) -> ShaderMaterial:
	if not card.has_meta(HOVER_META_KEY):
		return null
	var hover_rect: ColorRect = card.get_meta(HOVER_META_KEY) as ColorRect
	if not hover_rect or not (hover_rect.material is ShaderMaterial):
		return null
	return hover_rect.material as ShaderMaterial
