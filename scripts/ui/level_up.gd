extends CanvasLayer

## LevelUp UI - Shows upgrade choices when player levels up.
## Displays 3 cards with upgrade options. Player can select, reroll, or skip.

# Synthwave colors — sourced from UiColors shared constants
const COLOR_COMMON: Color = UiColors.RARITY_COMMON
const COLOR_UNCOMMON: Color = UiColors.RARITY_UNCOMMON
const COLOR_RARE: Color = UiColors.RARITY_RARE
const COLOR_EPIC: Color = UiColors.RARITY_EPIC
const COLOR_LEGENDARY: Color = UiColors.RARITY_LEGENDARY

const COLOR_WEAPON: Color = UiColors.TYPE_WEAPON
const COLOR_UPGRADE: Color = UiColors.TYPE_UPGRADE

const COLOR_PANEL_BG: Color = UiColors.PANEL_BG
const COLOR_PANEL_BORDER: Color = UiColors.HOT_PINK
const COLOR_BUTTON: Color = UiColors.BUTTON_PRIMARY

const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")
const CARD_HOVER_SHADER: Shader = preload("res://shaders/ui_upgrade_card_hover.gdshader")
const CARD_HOVER_FX_SCRIPT: Script = preload("res://scripts/ui/card_hover_fx.gd")

@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var ProgressionManager: Node = get_node("/root/ProgressionManager")
@onready var _settings: Node = get_node("/root/SettingsManager")
@onready var level_up_label: Label = $VBoxContainer/LevelUpLabel
@onready var choose_label: Label = $VBoxContainer/ChooseLabel
@onready var choices_container: VBoxContainer = $VBoxContainer/ChoicesContainer
@onready var actions_container: HBoxContainer = $VBoxContainer/ActionsContainer
@onready var refresh_button: Button = $VBoxContainer/ActionsContainer/RefreshButton
@onready var skip_button: Button = $VBoxContainer/ActionsContainer/SkipButton
@onready var background: ColorRect = $ColorRect
@onready var root_container: Control = $VBoxContainer

@onready var UpgradeService: Node = get_node("/root/UpgradeService")
@onready var FileLogger: Node = get_node("/root/FileLogger")

# Card references (3 cards)
var _cards: Array[PanelContainer] = []
var _current_options: Array = []
var _is_showing: bool = false
var _is_selecting: bool = false
var _card_hover_tweens: Dictionary = {}
var _button_hover_tweens: Dictionary = {}


func _ready() -> void:
	# Get card references
	_cards = [
		$VBoxContainer/ChoicesContainer/Choice1,
		$VBoxContainer/ChoicesContainer/Choice2,
		$VBoxContainer/ChoicesContainer/Choice3,
	]
	
	# Make entire cards clickable and focusable
	for i: int in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		card.gui_input.connect(_on_card_input.bind(i))
		card.mouse_entered.connect(_on_card_mouse_entered.bind(i))
		card.mouse_exited.connect(_on_card_mouse_exited.bind(i))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		CARD_HOVER_FX_SCRIPT.setup_card_focus(card, _card_hover_tweens, i)
		# Let clicks pass through children to the card
		for child: Control in card.get_children():
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for grandchild: Node in child.get_children():
				if grandchild is Control:
					(grandchild as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
					for great_grandchild: Node in grandchild.get_children():
						if great_grandchild is Control:
							(great_grandchild as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	refresh_button.pressed.connect(_on_refresh_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	
	# Connect to ProgressionManager signals
	ProgressionManager.level_up_triggered.connect(_on_level_up_triggered)
	
	# Apply synthwave styling
	_apply_synthwave_theme()
	
	# Hide initially
	hide()
	set_process_input(false)


func _apply_synthwave_theme() -> void:
	# Background overlay
	background.color = Color(0, 0, 0, 0.85)
	
	# Level up label - big neon yellow
	level_up_label.add_theme_color_override("font_color", UiColors.NEON_YELLOW)
	level_up_label.add_theme_font_override("font", FONT_HEADER)
	level_up_label.add_theme_font_size_override("font_size", 72)
	
	# Choose label - cyan
	choose_label.add_theme_color_override("font_color", UiColors.CYAN)
	choose_label.add_theme_font_override("font", FONT_HEADER)
	choose_label.add_theme_font_size_override("font_size", 32)
	
	# Style the cards with gradient overlays (matching loadout screen)
	for card in _cards:
		_style_card(card)
	
	# Add starfield backgrounds to icon areas (matching loadout screen)
	for i: int in range(_cards.size()):
		var icon_area: Control = _cards[i].find_child("IconArea%d" % (i + 1)) as Control
		if icon_area:
			_add_icon_starfield_bg(icon_area)
	
	# Style action buttons (shared synthwave button helper)
	CARD_HOVER_FX_SCRIPT.style_synthwave_button(refresh_button, COLOR_BUTTON, _button_hover_tweens, 4, 16, 8)
	CARD_HOVER_FX_SCRIPT.style_synthwave_button(skip_button, UiColors.BUTTON_NEUTRAL, _button_hover_tweens, 4, 16, 8)
	refresh_button.add_theme_font_override("font", FONT_HEADER)
	refresh_button.add_theme_font_size_override("font_size", 24)
	refresh_button.custom_minimum_size.x = 200
	skip_button.add_theme_font_override("font", FONT_HEADER)
	skip_button.add_theme_font_size_override("font_size", 24)
	skip_button.custom_minimum_size.x = 200
	skip_button.text = "SKIP"

	# Focus neighbors: last card → buttons, buttons → first card
	if _cards.size() > 0:
		_cards[_cards.size() - 1].focus_neighbor_bottom = refresh_button.get_path()
		refresh_button.focus_neighbor_top = _cards[0].get_path()
		skip_button.focus_neighbor_top = _cards[0].get_path()


func _style_card(card: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = UiColors.PANEL_BORDER
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Add gradient overlay (matching loadout screen style)
	var gradient_key: String = "_gradient_rect"
	if not card.has_meta(gradient_key):
		var grad_rect: ColorRect = ColorRect.new()
		grad_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grad_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var grad_mat: ShaderMaterial = ShaderMaterial.new()
		var grad_shader: Shader = Shader.new()
		grad_shader.code = "shader_type canvas_item;\n" \
			+ "uniform vec4 color_edge : source_color = vec4(0.0);\n" \
			+ "void fragment() {\n" \
			+ "    COLOR = vec4(color_edge.rgb, color_edge.a * (1.0 - UV.x));\n" \
			+ "}\n"
		grad_mat.shader = grad_shader
		var default_color: Color = Color(UiColors.PANEL_BORDER.r, UiColors.PANEL_BORDER.g, UiColors.PANEL_BORDER.b, 0.35)
		grad_mat.set_shader_parameter("color_edge", default_color)
		grad_rect.material = grad_mat
		card.add_child(grad_rect)
		card.set_meta(gradient_key, grad_rect)

	var hover_key: String = "_hover_rect"
	if not card.has_meta(hover_key):
		CARD_HOVER_FX_SCRIPT.ensure_hover_overlay(
			card,
			CARD_HOVER_SHADER,
			UiColors.PARTICLE_PINK,
			UiColors.PARTICLE_CYAN,
			UiColors.CLICK_FLASH
		)


func _style_button(_button: Button, _base_color: Color) -> void:
	# DEPRECATED: Use CARD_HOVER_FX_SCRIPT.style_synthwave_button() instead.
	# Kept as no-op stub in case any external callers remain.
	pass


func _on_button_mouse_entered(_button: Button) -> void:
	# Now handled by CARD_HOVER_FX_SCRIPT.style_synthwave_button() focus/hover connections.
	pass


func _on_button_mouse_exited(_button: Button) -> void:
	# Now handled by CARD_HOVER_FX_SCRIPT.style_synthwave_button() focus/hover connections.
	pass


func _set_button_hover_state(_button: Button, _hovered: bool) -> void:
	# Now handled by CARD_HOVER_FX_SCRIPT.tween_button_scale().
	pass


func _on_level_up_triggered(current_level: int, available_upgrades: Array) -> void:
	FileLogger.log_info("LevelUpUI", "Level up triggered! Level: %d, Options: %d" % [current_level, available_upgrades.size()])
	
	_current_options = available_upgrades
	_is_selecting = false
	level_up_label.text = "LEVEL %d!" % current_level
	
	_populate_cards()
	_update_refresh_button()
	
	# Show with animation
	show()
	_is_showing = true
	set_process_input(true)
	
	# Animate cards appearing
	_animate_cards_in()

	# Focus the first visible card for controller navigation
	for card: PanelContainer in _cards:
		if card.visible:
			card.call_deferred("grab_focus")
			break


func _populate_cards() -> void:
	for i in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		_reset_card_hover_visual(card, i)
		
		if i < _current_options.size():
			card.visible = true
			_update_card(i, _current_options[i])
		else:
			card.visible = false


func _update_card(index: int, option: Dictionary) -> void:
	var card: PanelContainer = _cards[index]
	
	var _icon: TextureRect = card.find_child("Icon%d" % (index + 1)) as TextureRect
	var name_label: Label = card.find_child("Name%d" % (index + 1)) as Label
	var desc_label: Label = card.find_child("Desc%d" % (index + 1)) as Label
	
	var data: Dictionary = option.get("data", {})
	var option_type: String = option.get("type", "upgrade")
	var option_id: String = option.get("id", "")
	var rarity: String = option.get("rarity", "common")
	var rarity_color: Color = _get_rarity_color(rarity)
	
	# Set name — upgrades use "name", weapons use "display_name"
	var display_name: String = data.get("name", data.get("display_name", option_id))
	name_label.text = display_name
	
	# Set description based on type
	var description: String = data.get("description", "No description")
	
	# Determine current level / stacks (unified for both types)
	var current_level: int = 0
	var is_new: bool = false
	if option_type == "upgrade":
		current_level = _get_current_stacks(option_id)
	else:
		current_level = int(option.get("current_level", 0))
		is_new = bool(option.get("is_new", false))
	
	# Level line (skip for brand-new items — NEW tag handles that)
	if not is_new and current_level > 0:
		description = "%s\nLevel: %d → %d" % [description, current_level, current_level + 1]
	
	# Effects line (same format for both types)
	var effects: Array = option.get("effects", [])
	var bonus_line: String = _format_weapon_effects_line(effects)
	if bonus_line != "":
		description = "%s\n%s" % [description, bonus_line]
	
	_update_card_border(card, rarity_color)
	
	desc_label.text = description
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	desc_label.add_theme_font_size_override("font_size", 16)
	
	# Style name label — white title
	name_label.add_theme_font_override("font", FONT_HEADER)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Add/update rarity subtitle and NEW tag
	var info_box: VBoxContainer = card.find_child("InfoBox%d" % (index + 1)) as VBoxContainer
	if info_box:
		# Remove ALL old dynamic labels immediately (queue_free defers, causing duplicates)
		var to_remove: Array[Node] = []
		for child: Node in info_box.get_children():
			if child.name == &"RaritySubtitle" or child.name == &"NewTag":
				to_remove.append(child)
		for node: Node in to_remove:
			info_box.remove_child(node)
			node.free()
		
		# Rarity subtitle — smaller, rarity-colored, inserted after name label
		var rarity_label: Label = Label.new()
		rarity_label.name = "RaritySubtitle"
		rarity_label.text = rarity.capitalize()
		rarity_label.add_theme_color_override("font_color", rarity_color)
		rarity_label.add_theme_font_override("font", FONT_HEADER)
		rarity_label.add_theme_font_size_override("font_size", 14)
		rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Insert after name label (index 0) so it appears between name and description
		var name_idx: int = name_label.get_index()
		info_box.add_child(rarity_label)
		info_box.move_child(rarity_label, name_idx + 1)
		
		# Add NEW tag if this is a new item
		if is_new:
			var new_tag: Label = Label.new()
			new_tag.name = "NewTag"
			new_tag.text = "NEW"
			new_tag.add_theme_color_override("font_color", UiColors.NEON_YELLOW)
			new_tag.add_theme_font_override("font", FONT_HEADER)
			new_tag.add_theme_font_size_override("font_size", 18)
			new_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info_box.add_child(new_tag)


func _update_card_border(card: PanelContainer, color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Update gradient overlay color to match rarity
	var gradient_key: String = "_gradient_rect"
	if card.has_meta(gradient_key):
		var grad_rect: ColorRect = card.get_meta(gradient_key) as ColorRect
		if grad_rect and grad_rect.material is ShaderMaterial:
			var mat: ShaderMaterial = grad_rect.material as ShaderMaterial
			mat.set_shader_parameter("color_edge", Color(color.r, color.g, color.b, 0.35))

	var hover_key: String = "_hover_rect"
	if card.has_meta(hover_key):
		var glow_color: Color = color.lerp(UiColors.PARTICLE_CYAN, 0.45)
		var click_color: Color = color.lerp(UiColors.CLICK_FLASH, 0.65)
		CARD_HOVER_FX_SCRIPT.set_hover_colors(card, color, glow_color, click_color)


## Add animated starfield background to an icon area control (matching loadout screen).
func _add_icon_starfield_bg(area: Control) -> void:
	var star_bg: ColorRect = ColorRect.new()
	star_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var star_mat: ShaderMaterial = ShaderMaterial.new()
	var star_shader: Shader = Shader.new()
	star_shader.code = "shader_type canvas_item;\n" \
		+ "uniform float scroll_speed = 0.15;\n" \
		+ "uniform float layer_scale = 40.0;\n" \
		+ "uniform float density = 0.35;\n" \
		+ "uniform float star_size = 0.04;\n" \
		+ "uniform vec3 bg_color = vec3(0.04, 0.02, 0.1);\n" \
		+ "float hash21(vec2 p) {\n" \
		+ "    vec3 p3 = fract(vec3(p.xyx) * 0.1031);\n" \
		+ "    p3 += dot(p3, p3.yzx + 33.33);\n" \
		+ "    return fract((p3.x + p3.y) * p3.z);\n" \
		+ "}\n" \
		+ "vec2 hash22(vec2 p) {\n" \
		+ "    return vec2(hash21(p), hash21(p + 19.19));\n" \
		+ "}\n" \
		+ "float star_layer(vec2 uv, float scale, float spd, float seed_off) {\n" \
		+ "    vec2 scroll_uv = uv * scale + vec2(TIME * spd, TIME * spd * 0.3) + seed_off;\n" \
		+ "    vec2 cell = floor(scroll_uv);\n" \
		+ "    vec2 f = fract(scroll_uv);\n" \
		+ "    float r = hash21(cell + seed_off);\n" \
		+ "    float has_star = step(r, density);\n" \
		+ "    vec2 center = hash22(cell + 7.7 + seed_off) * 0.8 + 0.1;\n" \
		+ "    float sz = star_size * mix(0.5, 1.5, hash21(cell + 13.13 + seed_off));\n" \
		+ "    float d = distance(f, center);\n" \
		+ "    float core = smoothstep(sz, 0.0, d);\n" \
		+ "    float glow = smoothstep(sz * 2.5, 0.0, d) * 0.3;\n" \
		+ "    float twinkle = 1.0 + sin(TIME * mix(1.0, 3.0, r) + r * 6.28) * 0.3;\n" \
		+ "    return (core + glow) * has_star * twinkle;\n" \
		+ "}\n" \
		+ "void fragment() {\n" \
		+ "    float s1 = star_layer(UV, layer_scale, scroll_speed, 0.0);\n" \
		+ "    float s2 = star_layer(UV, layer_scale * 0.6, scroll_speed * 0.5, 42.0) * 0.5;\n" \
		+ "    float s3 = star_layer(UV, layer_scale * 1.4, scroll_speed * 1.5, 99.0) * 0.7;\n" \
		+ "    float stars = s1 + s2 + s3;\n" \
		+ "    vec3 col = bg_color + vec3(0.8, 0.85, 1.0) * stars;\n" \
		+ "    COLOR = vec4(col, 1.0);\n" \
		+ "}\n"
	star_mat.shader = star_shader
	star_bg.material = star_mat
	# Insert behind the Icon TextureRect
	area.add_child(star_bg)
	area.move_child(star_bg, 0)


func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return COLOR_LEGENDARY
		"epic":
			return COLOR_EPIC
		"rare":
			return COLOR_RARE
		"uncommon":
			return COLOR_UNCOMMON
		_:
			return COLOR_COMMON


func _get_current_stacks(upgrade_id: String) -> int:
	for upgrade in RunManager.run_data.ship_upgrades:
		if upgrade.id == upgrade_id:
			return upgrade.stacks
	return 0


func _format_stat_name(stat: String) -> String:
	# Convert snake_case to Title Case
	return stat.replace("_", " ").capitalize()


func _format_weapon_effects_line(effects: Array) -> String:
	# Returns a single readable line like: "Bonus: +8% Damage / +1 Projectile"
	if effects.is_empty():
		return ""

	var parts: Array[String] = []
	for effect_any in effects:
		if not (effect_any is Dictionary):
			continue
		var effect: Dictionary = effect_any
		var stat: String = String(effect.get("stat", ""))
		if stat == "":
			continue
		var kind: String = String(effect.get("kind", "mult"))
		var amount: float = float(effect.get("amount", 0.0))
		if amount == 0.0:
			continue

		if kind == "mult":
			parts.append("+%.0f%% %s" % [amount * 100.0, _format_stat_name(stat)])
		else:
			if stat in ["armor", "evasion", "crit_chance", "luck", "difficulty"]:
				parts.append("+%.1f%% %s" % [amount, _format_stat_name(stat)])
			elif stat == "crit_damage":
				parts.append("+%.2f %s" % [amount, _format_stat_name(stat)])
			else:
				parts.append("+%.0f %s" % [amount, _format_stat_name(stat)])

	if parts.is_empty():
		return ""
	return "Bonus: %s" % " / ".join(parts)


func _update_refresh_button() -> void:
	var current_credits: int = RunManager.run_data.credits
	
	# Clear default text so we can use custom layout inside
	refresh_button.text = ""
	
	# Ensure custom layout exists
	var hbox: HBoxContainer = refresh_button.find_child("ContentBox", false, false) as HBoxContainer
	var label_refresh: Label
	var label_cost: Label
	
	if not hbox:
		hbox = HBoxContainer.new()
		hbox.name = "ContentBox"
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 8)
		refresh_button.add_child(hbox)
		
		label_refresh = Label.new()
		label_refresh.name = "LabelRefresh"
		label_refresh.text = "REFRESH"
		label_refresh.add_theme_font_override("font", FONT_HEADER)
		label_refresh.add_theme_font_size_override("font_size", 22)
		label_refresh.add_theme_color_override("font_color", Color.WHITE)
		label_refresh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_refresh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(label_refresh)
		
		label_cost = Label.new()
		label_cost.name = "LabelCost"
		label_cost.add_theme_font_override("font", FONT_HEADER)
		label_cost.add_theme_font_size_override("font_size", 14) # Smaller
		label_cost.add_theme_color_override("font_color", UiColors.NEON_YELLOW) # Synthwave yellow
		label_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(label_cost)
	else:
		label_refresh = hbox.get_node("LabelRefresh")
		label_cost = hbox.get_node("LabelCost")
	
	# Update cost text
	label_cost.text = "⟐%d" % GameConfig.LEVEL_UP_REFRESH_COST
	
	refresh_button.disabled = current_credits < GameConfig.LEVEL_UP_REFRESH_COST
	
	if refresh_button.disabled:
		refresh_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
		refresh_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		refresh_button.modulate = Color.WHITE
		refresh_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _animate_cards_in() -> void:
	for i in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		if card.visible:
			card.modulate.a = 0.0
			card.scale = Vector2(0.8, 0.8)
			card.pivot_offset = card.size / 2
			
			var tween: Tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(i * 0.1)
			tween.tween_property(card, "scale", Vector2.ONE, 0.3).set_delay(i * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_card_mouse_entered(index: int) -> void:
	if _is_selecting:
		return
	if index < 0 or index >= _cards.size():
		return
	var card: PanelContainer = _cards[index]
	if not card.visible:
		return
	_set_card_hover_state(card, index, true)


func _on_card_mouse_exited(index: int) -> void:
	if _is_selecting:
		return
	if index < 0 or index >= _cards.size():
		return
	var card: PanelContainer = _cards[index]
	if not card.visible:
		return
	_set_card_hover_state(card, index, false)


func _set_card_hover_state(card: PanelContainer, index: int, hovered: bool) -> void:
	CARD_HOVER_FX_SCRIPT.tween_hover_state(card, _card_hover_tweens, index, hovered, 0.0, Vector2(1.03, 1.03), 0.16, 0.12)


func _reset_card_hover_visual(card: PanelContainer, index: int) -> void:
	CARD_HOVER_FX_SCRIPT.reset_hover(card, _card_hover_tweens, index, 0.0)


## Handle click/accept on entire card area.
func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_card_selected(index)
	elif event.is_action_pressed("ui_accept"):
		_on_card_selected(index)


func _on_card_selected(index: int) -> void:
	if _is_selecting:
		return
	if index < 0 or index >= _cards.size():
		return
	if index >= _current_options.size():
		return

	_is_selecting = true
	set_process_input(false)
	_is_showing = false
	
	var selected_option: Dictionary = _current_options[index]
	FileLogger.log_info("LevelUpUI", "Selected option %d: %s" % [index, selected_option.get("id", "unknown")])

	for i: int in range(_cards.size()):
		if i == index:
			continue
		if i < _current_options.size() and _cards[i].visible:
			_play_card_reject_particles(_cards[i])

	var select_tween: Tween = create_tween()
	select_tween.tween_interval(0.2)
	select_tween.tween_callback(func() -> void:
		_hide_ui()
		ProgressionManager.select_level_up_option(selected_option)
	)


func _play_card_reject_particles(card: PanelContainer) -> void:
	var card_rect: Rect2 = card.get_global_rect()
	var card_center: Vector2 = card_rect.position + (card_rect.size * 0.5)

	var pop_tween: Tween = create_tween()
	pop_tween.set_parallel(true)
	pop_tween.tween_property(card, "modulate:a", 0.0, 0.13)
	pop_tween.tween_property(card, "scale", Vector2(0.88, 0.88), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	var density_mult: float = _settings.get_particle_density_multiplier()
	if density_mult <= 0.0:
		return  # Particles disabled

	var synth_colors: Array[Color] = [
		UiColors.PARTICLE_PINK,
		UiColors.PARTICLE_PURPLE,
		UiColors.PARTICLE_CYAN,
	]

	var base_amount: int = 42
	var scaled_amount: int = maxi(1, int(float(base_amount) * density_mult))

	for i: int in range(synth_colors.size()):
		var particles: CPUParticles2D = CPUParticles2D.new()
		particles.one_shot = true
		particles.amount = scaled_amount
		particles.lifetime = 0.46
		particles.explosiveness = 1.0
		particles.randomness = 0.45
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = card_rect.size * 0.42
		particles.direction = Vector2.UP
		particles.spread = 180.0
		particles.gravity = Vector2(0.0, 192.0)
		particles.initial_velocity_min = 136.0 + (i * 16.0)
		particles.initial_velocity_max = 288.0 + (i * 24.0)
		particles.angular_velocity_min = -280.0
		particles.angular_velocity_max = 280.0
		particles.scale_amount_min = 1.35
		particles.scale_amount_max = 2.4
		particles.color = synth_colors[i].lightened(0.12)
		particles.global_position = card_center
		particles.z_index = 200
		add_child(particles)
		particles.emitting = true

		var cleanup_timer: SceneTreeTimer = get_tree().create_timer(0.82)
		cleanup_timer.timeout.connect(func() -> void:
			if is_instance_valid(particles):
				particles.queue_free()
		)


func _on_refresh_pressed() -> void:
	if ProgressionManager.spend_credits(GameConfig.LEVEL_UP_REFRESH_COST):
		FileLogger.log_info("LevelUpUI", "Refreshing options (spent %d credits)" % GameConfig.LEVEL_UP_REFRESH_COST)
		
		# Generate new options
		_current_options = UpgradeService.generate_level_up_options()
		_populate_cards()
		_update_refresh_button()
		_animate_cards_in()
	else:
		FileLogger.log_debug("LevelUpUI", "Cannot afford refresh")


func _on_skip_pressed() -> void:
	FileLogger.log_info("LevelUpUI", "Skipping level up")
	_hide_ui()
	RunManager.resume_game()


func _hide_ui() -> void:
	_is_showing = false
	set_process_input(false)
	
	# Animate out
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	# CanvasLayer has no modulate; fade CanvasItem children instead.
	tween.tween_property(root_container, "modulate:a", 0.0, 0.2)
	tween.tween_property(background, "modulate:a", 0.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(hide)
	tween.tween_callback(func() -> void:
		root_container.modulate.a = 1.0
		background.modulate.a = 1.0
	)


func _input(event: InputEvent) -> void:
	if not _is_showing:
		return
	
	# Keyboard shortcuts for card selection
	if event.is_action_pressed("ui_accept") or event is InputEventKey:
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_1:
					if _current_options.size() > 0:
						_on_card_selected(0)
				KEY_2:
					if _current_options.size() > 1:
						_on_card_selected(1)
				KEY_3:
					if _current_options.size() > 2:
						_on_card_selected(2)
				KEY_R:
					_on_refresh_pressed()
				# Intentionally no keyboard/controller shortcut for skipping.
				# Use the on-screen Skip button to avoid accidental dismissals.
