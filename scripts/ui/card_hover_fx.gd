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


static func _get_hover_material(card: PanelContainer) -> ShaderMaterial:
	if not card.has_meta(HOVER_META_KEY):
		return null
	var hover_rect: ColorRect = card.get_meta(HOVER_META_KEY) as ColorRect
	if not hover_rect or not (hover_rect.material is ShaderMaterial):
		return null
	return hover_rect.material as ShaderMaterial
