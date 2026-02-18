extends CanvasLayer

## LevelUp UI - Shows upgrade choices when player levels up.
## Displays 3 cards with upgrade options. Player can select, reroll, or skip.

# Synthwave colors
const COLOR_COMMON: Color = Color(0.7, 0.7, 0.7, 1.0)       # Gray
const COLOR_UNCOMMON: Color = Color(0.2, 0.8, 0.2, 1.0)    # Green
const COLOR_RARE: Color = Color(0.2, 0.5, 1.0, 1.0)        # Blue
const COLOR_EPIC: Color = Color(0.67, 0.2, 0.95, 1.0)      # Purple
const COLOR_LEGENDARY: Color = Color(1.0, 0.8, 0.0, 1.0)   # Gold

const COLOR_WEAPON: Color = Color(1.0, 0.3, 0.3, 1.0)      # Red-ish for weapons
const COLOR_UPGRADE: Color = Color(0.0, 0.9, 0.8, 1.0)     # Cyan for upgrades

const COLOR_PANEL_BG: Color = Color(0.08, 0.05, 0.15, 0.95)
const COLOR_PANEL_BORDER: Color = Color(1.0, 0.08, 0.4, 1.0)  # Hot pink
const COLOR_BUTTON: Color = Color(0.67, 0.2, 0.95, 1.0)       # Neon purple
const COLOR_BUTTON_HOVER: Color = Color(1.0, 0.08, 0.4, 1.0)  # Hot pink

const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")

@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var ProgressionManager: Node = get_node("/root/ProgressionManager")
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


func _ready() -> void:
	# Get card references
	_cards = [
		$VBoxContainer/ChoicesContainer/Choice1,
		$VBoxContainer/ChoicesContainer/Choice2,
		$VBoxContainer/ChoicesContainer/Choice3,
	]
	
	# Make entire cards clickable
	for i: int in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		card.gui_input.connect(_on_card_input.bind(i))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.mouse_filter = Control.MOUSE_FILTER_STOP
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
	level_up_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2, 1.0))
	level_up_label.add_theme_font_override("font", FONT_HEADER)
	level_up_label.add_theme_font_size_override("font_size", 72)
	
	# Choose label - cyan
	choose_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.9, 1.0))
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
	
	# Style action buttons
	_style_button(refresh_button, COLOR_BUTTON)
	_style_button(skip_button, Color(0.5, 0.5, 0.5, 1.0))
	refresh_button.add_theme_font_override("font", FONT_HEADER)
	refresh_button.add_theme_font_size_override("font_size", 22)
	refresh_button.custom_minimum_size.x = 200
	skip_button.add_theme_font_override("font", FONT_HEADER)
	skip_button.add_theme_font_size_override("font_size", 22)
	skip_button.custom_minimum_size.x = 200
	skip_button.text = "SKIP"


func _style_card(card: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = Color(0.4, 0.2, 0.5, 1.0)
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
		var default_color: Color = Color(0.4, 0.2, 0.5, 0.35)
		grad_mat.set_shader_parameter("color_edge", default_color)
		grad_rect.material = grad_mat
		card.add_child(grad_rect)
		card.set_meta(gradient_key, grad_rect)


func _style_button(button: Button, base_color: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", normal)
	
	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = base_color.lightened(0.2)
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4
	hover.content_margin_left = 16
	hover.content_margin_right = 16
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8
	button.add_theme_stylebox_override("hover", hover)
	
	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = base_color.darkened(0.2)
	pressed.corner_radius_top_left = 4
	pressed.corner_radius_top_right = 4
	pressed.corner_radius_bottom_left = 4
	pressed.corner_radius_bottom_right = 4
	pressed.content_margin_left = 16
	pressed.content_margin_right = 16
	pressed.content_margin_top = 8
	pressed.content_margin_bottom = 8
	button.add_theme_stylebox_override("pressed", pressed)
	
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _on_level_up_triggered(current_level: int, available_upgrades: Array) -> void:
	FileLogger.log_info("LevelUpUI", "Level up triggered! Level: %d, Options: %d" % [current_level, available_upgrades.size()])
	
	_current_options = available_upgrades
	level_up_label.text = "LEVEL %d!" % current_level
	
	_populate_cards()
	_update_refresh_button()
	
	# Show with animation
	show()
	_is_showing = true
	set_process_input(true)
	
	# Animate cards appearing
	_animate_cards_in()


func _populate_cards() -> void:
	for i in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		
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
			new_tag.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2, 1.0))
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
		label_cost.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0)) # Synthwave yellow
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
	else:
		refresh_button.modulate = Color.WHITE


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


## Handle click on entire card area.
func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_card_selected(index)


func _on_card_selected(index: int) -> void:
	if index >= _current_options.size():
		return
	
	var selected_option: Dictionary = _current_options[index]
	FileLogger.log_info("LevelUpUI", "Selected option %d: %s" % [index, selected_option.get("id", "unknown")])
	
	_hide_ui()
	ProgressionManager.select_level_up_option(selected_option)


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
