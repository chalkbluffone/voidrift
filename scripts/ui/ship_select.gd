extends Control

## Ship & Captain selection screen.
## Two-column layout: ships on the left, captains on the right.
## Player must select one of each before launching a run.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

# Synthwave palette — sourced from UiColors shared constants
const COLOR_PANEL_BG: Color = UiColors.PANEL_BG
const COLOR_PANEL_BORDER: Color = UiColors.PANEL_BORDER
const COLOR_PANEL_SELECTED: Color = UiColors.PANEL_SELECTED
const COLOR_BUTTON: Color = UiColors.BUTTON_PRIMARY
const COLOR_BUTTON_DISABLED: Color = UiColors.BUTTON_DISABLED
const COLOR_TITLE: Color = UiColors.CYAN
const COLOR_HEADER: Color = UiColors.NEON_YELLOW
const COLOR_NAME: Color = UiColors.TEXT_PRIMARY
const COLOR_DESC: Color = UiColors.TEXT_DESC
const COLOR_STAT_LABEL: Color = UiColors.TEXT_STAT_LABEL
const COLOR_STAT_VALUE: Color = UiColors.TEXT_STAT_VALUE
const COLOR_LOCKED: Color = UiColors.TEXT_LOCKED

const CARD_CORNER_RADIUS: int = 8
const CARD_BORDER_WIDTH: int = 2
const BUTTON_CORNER_RADIUS: int = 4

const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")
const CARD_HOVER_SHADER: Shader = preload("res://shaders/ui_upgrade_card_hover.gdshader")
const CARD_HOVER_FX_SCRIPT: Script = preload("res://scripts/ui/card_hover_fx.gd")

@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")

# Containers populated in _ready
@onready var ship_list: VBoxContainer = $MarginContainer/VBoxContainer/ContentRow/ShipColumn/ShipScroll/ShipPadding/ShipList
@onready var captain_list: VBoxContainer = $MarginContainer/VBoxContainer/ContentRow/CaptainColumn/CaptainScroll/CaptainPadding/CaptainList
@onready var launch_button: Button = $MarginContainer/VBoxContainer/BottomBar/LaunchButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/BottomBar/BackButton

var _selected_ship_id: String = ""
var _selected_captain_id: String = ""

## Maps ship/captain id → PanelContainer card node for highlight updates.
var _ship_cards: Dictionary = {}
var _captain_cards: Dictionary = {}
var _card_hover_tweens: Dictionary = {}
var _button_hover_tweens: Dictionary = {}


func _ready() -> void:
	if FileLogger:
		FileLogger.log_info("ShipSelect", "Initializing ship & captain selection screen")

	launch_button.pressed.connect(_on_launch_pressed)
	back_button.pressed.connect(_on_back_pressed)

	CARD_HOVER_FX_SCRIPT.style_synthwave_button(launch_button, COLOR_BUTTON, _button_hover_tweens, BUTTON_CORNER_RADIUS)
	CARD_HOVER_FX_SCRIPT.style_synthwave_button(back_button, UiColors.BUTTON_BACK, _button_hover_tweens, BUTTON_CORNER_RADIUS)
	launch_button.disabled = true
	_update_launch_button_style()

	_populate_ships()
	_populate_captains()
	_setup_card_focus_neighbors()

	# Focus first ship card so controller users start in the content.
	# Immediately reset the hover visual so it doesn't appear hovered on load —
	# the focus_entered signal triggers the hover tween, but we want it neutral
	# until the player actively hovers or navigates with a gamepad.
	var first_ship: PanelContainer = ship_list.get_child(0) as PanelContainer if ship_list.get_child_count() > 0 else null
	if first_ship:
		first_ship.grab_focus()
		CARD_HOVER_FX_SCRIPT.reset_hover(first_ship, _card_hover_tweens, first_ship.get_instance_id())
	else:
		back_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Populate columns
# ---------------------------------------------------------------------------

func _populate_ships() -> void:
	var ships: Array = DataLoader.get_all_ships()
	for ship_data: Dictionary in ships:
		var ship_id: String = String(ship_data.get("id", ""))
		var card: PanelContainer = _build_ship_card(ship_data)
		ship_list.add_child(card)
		_ship_cards[ship_id] = card


func _populate_captains() -> void:
	var captains: Array = DataLoader.get_all_captains()
	for captain_data: Dictionary in captains:
		var captain_id: String = String(captain_data.get("id", ""))
		var card: PanelContainer = _build_captain_card(captain_data)
		captain_list.add_child(card)
		_captain_cards[captain_id] = card


# ---------------------------------------------------------------------------
# Card builders
# ---------------------------------------------------------------------------

func _build_ship_card(data: Dictionary) -> PanelContainer:
	var ship_id: String = String(data.get("id", ""))
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 120)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pivot_offset = card.size * 0.5
	card.set_meta("entry_type", "ship")
	card.set_meta("entry_id", ship_id)
	_style_card(card, false)

	# Make clickable + focusable for controller
	card.gui_input.connect(_on_ship_card_input.bind(ship_id))
	card.mouse_entered.connect(_on_loadout_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_loadout_card_mouse_exited.bind(card))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	CARD_HOVER_FX_SCRIPT.setup_card_focus(card, _card_hover_tweens, card.get_instance_id())

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	# Ship sprite (forced square container with aspect-centered content)
	var sprite_path: String = String(data.get("sprite", ""))
	var sprite_container: Control = Control.new()
	sprite_container.custom_minimum_size = Vector2(128, 128)
	sprite_container.clip_contents = true

	# Animated starfield background
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
		+ "\n" \
		+ "float hash21(vec2 p) {\n" \
		+ "    vec3 p3 = fract(vec3(p.xyx) * 0.1031);\n" \
		+ "    p3 += dot(p3, p3.yzx + 33.33);\n" \
		+ "    return fract((p3.x + p3.y) * p3.z);\n" \
		+ "}\n" \
		+ "\n" \
		+ "vec2 hash22(vec2 p) {\n" \
		+ "    return vec2(hash21(p), hash21(p + 19.19));\n" \
		+ "}\n" \
		+ "\n" \
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
		+ "\n" \
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
	sprite_container.add_child(star_bg)

	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.offset_left = 19.0
	tex_rect.offset_top = 19.0
	tex_rect.offset_right = -19.0
	tex_rect.offset_bottom = -19.0
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(sprite_path):
		tex_rect.texture = load(sprite_path)
	sprite_container.add_child(tex_rect)

	# Synthwave gradient border overlay
	var border_rect: ColorRect = ColorRect.new()
	border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var border_mat: ShaderMaterial = ShaderMaterial.new()
	var border_shader: Shader = Shader.new()
	border_shader.code = "shader_type canvas_item;\n" \
		+ "uniform float border_width = 2.0;\n" \
		+ "uniform vec2 rect_size = vec2(128.0, 128.0);\n" \
		+ "void fragment() {\n" \
		+ "    vec2 pixel = UV * rect_size;\n" \
		+ "    float d = min(min(pixel.x, rect_size.x - pixel.x), min(pixel.y, rect_size.y - pixel.y));\n" \
		+ "    float mask = 1.0 - smoothstep(border_width - 0.5, border_width + 0.5, d);\n" \
		+ "    vec3 c1 = vec3(1.0, 0.08, 0.58);\n" \
		+ "    vec3 c2 = vec3(0.0, 1.0, 0.9);\n" \
		+ "    vec3 grad = mix(c1, c2, UV.x + UV.y * 0.5);\n" \
		+ "    COLOR = vec4(grad, mask);\n" \
		+ "}\n"
	border_mat.shader = border_shader
	border_mat.set_shader_parameter("border_width", 2.0)
	border_mat.set_shader_parameter("rect_size", Vector2(128.0, 128.0))
	border_rect.material = border_mat
	sprite_container.add_child(border_rect)

	hbox.add_child(sprite_container)

	# Info column
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	# Name
	var name_label: Label = Label.new()
	name_label.text = String(data.get("name", ship_id))
	name_label.add_theme_font_override("font", FONT_HEADER)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", COLOR_NAME)
	vbox.add_child(name_label)

	# Description
	var desc_label: Label = Label.new()
	desc_label.text = String(data.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", COLOR_DESC)
	vbox.add_child(desc_label)

	# Stats row
	var stats_row: HBoxContainer = _build_ship_stats_row(data)
	vbox.add_child(stats_row)

	return card


func _build_ship_stats_row(data: Dictionary) -> HBoxContainer:
	var base_stats: Dictionary = data.get("base_stats", {})
	var phase: Dictionary = data.get("phase_shift", {})
	var speed: float = float(data.get("base_speed", 100.0))
	var hp: float = float(base_stats.get("max_hp", 100.0))
	var charges: float = float(phase.get("charges", 3.0))
	var weapon_id: String = String(data.get("starting_weapon", ""))

	# Look up weapon display name
	var weapon_name: String = weapon_id.replace("_", " ").capitalize()
	var weapon_data: Dictionary = DataLoader.get_weapon(weapon_id)
	if not weapon_data.is_empty():
		weapon_name = String(weapon_data.get("display_name", weapon_name))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	_add_stat_pair(row, "SPD", str(int(speed)))
	_add_stat_pair(row, "HP", str(int(hp)))
	_add_stat_pair(row, "PHASE", str(int(charges)))
	_add_stat_pair(row, "WEAPON", weapon_name)

	return row


func _build_captain_card(data: Dictionary) -> PanelContainer:
	var captain_id: String = String(data.get("id", ""))
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pivot_offset = card.size * 0.5
	card.set_meta("entry_type", "captain")
	card.set_meta("entry_id", captain_id)
	_style_card(card, false)

	card.gui_input.connect(_on_captain_card_input.bind(captain_id))
	card.mouse_entered.connect(_on_loadout_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_loadout_card_mouse_exited.bind(card))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	CARD_HOVER_FX_SCRIPT.setup_card_focus(card, _card_hover_tweens, card.get_instance_id())

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	# Captain sprite (forced square container with aspect-centered content)
	var sprite_path: String = String(data.get("sprite", ""))
	var sprite_container: Control = Control.new()
	sprite_container.custom_minimum_size = Vector2(128, 128)
	sprite_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sprite_container.clip_contents = true
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(sprite_path):
		tex_rect.texture = load(sprite_path)
	sprite_container.add_child(tex_rect)

	# Synthwave gradient border overlay
	var border_rect: ColorRect = ColorRect.new()
	border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var border_mat: ShaderMaterial = ShaderMaterial.new()
	var border_shader: Shader = Shader.new()
	border_shader.code = "shader_type canvas_item;\n" \
		+ "uniform float border_width = 2.0;\n" \
		+ "uniform vec2 rect_size = vec2(128.0, 128.0);\n" \
		+ "void fragment() {\n" \
		+ "    vec2 pixel = UV * rect_size;\n" \
		+ "    float d = min(min(pixel.x, rect_size.x - pixel.x), min(pixel.y, rect_size.y - pixel.y));\n" \
		+ "    float mask = 1.0 - smoothstep(border_width - 0.5, border_width + 0.5, d);\n" \
		+ "    vec3 c1 = vec3(1.0, 0.08, 0.58);\n" \
		+ "    vec3 c2 = vec3(0.0, 1.0, 0.9);\n" \
		+ "    vec3 grad = mix(c1, c2, UV.x + UV.y * 0.5);\n" \
		+ "    COLOR = vec4(grad, mask);\n" \
		+ "}\n"
	border_mat.shader = border_shader
	border_mat.set_shader_parameter("border_width", 2.0)
	border_mat.set_shader_parameter("rect_size", Vector2(128.0, 128.0))
	border_rect.material = border_mat
	sprite_container.add_child(border_rect)

	hbox.add_child(sprite_container)

	# Info column
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	# Name
	var name_label: Label = Label.new()
	name_label.text = String(data.get("name", captain_id))
	name_label.add_theme_font_override("font", FONT_HEADER)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", COLOR_NAME)
	vbox.add_child(name_label)

	# Description (truncated for card — full flavor text can be long)
	var desc_text: String = String(data.get("description", ""))
	var desc_label: Label = Label.new()
	desc_label.text = desc_text
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", COLOR_DESC)
	vbox.add_child(desc_label)

	# Passive
	var passive: Dictionary = data.get("passive", {})
	if not passive.is_empty():
		var passive_label: Label = Label.new()
		passive_label.text = "⬡ " + String(passive.get("name", "")) + " — " + String(passive.get("description", ""))
		passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		passive_label.add_theme_font_size_override("font_size", 14)
		passive_label.add_theme_color_override("font_color", COLOR_STAT_VALUE)
		vbox.add_child(passive_label)

	# Active ability
	var active: Dictionary = data.get("active_ability", {})
	if not active.is_empty():
		var active_label: Label = Label.new()
		var cooldown: float = float(active.get("cooldown", 0.0))
		active_label.text = "⚡ " + String(active.get("name", "")) + " — " + String(active.get("description", "")) + " (%ds)" % int(cooldown)
		active_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		active_label.add_theme_font_size_override("font_size", 14)
		active_label.add_theme_color_override("font_color", UiColors.NEON_YELLOW)
		vbox.add_child(active_label)

	return card


# ---------------------------------------------------------------------------
# Stat helper
# ---------------------------------------------------------------------------

func _add_stat_pair(parent: HBoxContainer, label_text: String, value_text: String) -> void:
	var pair: HBoxContainer = HBoxContainer.new()
	pair.add_theme_constant_override("separation", 4)

	var lbl: Label = Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_font_override("font", FONT_HEADER)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COLOR_STAT_LABEL)
	pair.add_child(lbl)

	var val: Label = Label.new()
	val.text = value_text
	val.add_theme_font_override("font", FONT_HEADER)
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", COLOR_STAT_VALUE)
	pair.add_child(val)

	parent.add_child(pair)


# ---------------------------------------------------------------------------
# Selection logic
# ---------------------------------------------------------------------------

func _on_ship_card_input(event: InputEvent, ship_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_ship(ship_id)
	elif event.is_action_pressed("ui_accept"):
		_select_ship(ship_id)


func _on_captain_card_input(event: InputEvent, captain_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_captain(captain_id)
	elif event.is_action_pressed("ui_accept"):
		_select_captain(captain_id)


func _on_loadout_card_mouse_entered(card: PanelContainer) -> void:
	if not is_instance_valid(card):
		return
	_set_loadout_card_hover_state(card, true)


func _on_loadout_card_mouse_exited(card: PanelContainer) -> void:
	if not is_instance_valid(card):
		return
	_set_loadout_card_hover_state(card, false)


func _set_loadout_card_hover_state(card: PanelContainer, hovered: bool) -> void:
	var card_key: int = card.get_instance_id()
	CARD_HOVER_FX_SCRIPT.tween_hover_state(card, _card_hover_tweens, card_key, hovered, 0.0, Vector2(1.03, 1.03), 0.16, 0.12)


func _select_ship(ship_id: String) -> void:
	_selected_ship_id = ship_id
	if FileLogger:
		FileLogger.log_info("ShipSelect", "Selected ship: %s" % ship_id)
	# Update card highlights
	for id: String in _ship_cards:
		var card: PanelContainer = _ship_cards[id]
		_style_card(card, id == _selected_ship_id)
	_update_launch_state()


func _select_captain(captain_id: String) -> void:
	_selected_captain_id = captain_id
	if FileLogger:
		FileLogger.log_info("ShipSelect", "Selected captain: %s" % captain_id)
	for id: String in _captain_cards:
		var card: PanelContainer = _captain_cards[id]
		_style_card(card, id == _selected_captain_id)
	_update_launch_state()


func _update_launch_state() -> void:
	var can_launch: bool = _selected_ship_id != "" and _selected_captain_id != ""
	launch_button.disabled = not can_launch
	_update_launch_button_style()


func _update_launch_button_style() -> void:
	if launch_button.disabled:
		CARD_HOVER_FX_SCRIPT.style_synthwave_button(launch_button, COLOR_BUTTON_DISABLED, _button_hover_tweens, BUTTON_CORNER_RADIUS)
		launch_button.add_theme_color_override("font_color", UiColors.TEXT_DISABLED)
		launch_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		CARD_HOVER_FX_SCRIPT.style_synthwave_button(launch_button, COLOR_BUTTON, _button_hover_tweens, BUTTON_CORNER_RADIUS)
		launch_button.add_theme_color_override("font_color", Color.WHITE)
		launch_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _on_launch_pressed() -> void:
	if _selected_ship_id == "" or _selected_captain_id == "":
		return
	if FileLogger:
		FileLogger.log_info("ShipSelect", "Launching run — Ship: %s, Captain: %s" % [_selected_ship_id, _selected_captain_id])
	RunManager.start_run(_selected_ship_id, _selected_captain_id)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# ---------------------------------------------------------------------------
# Styling helpers (matching project synthwave conventions)
# ---------------------------------------------------------------------------

func _style_card(card: PanelContainer, selected: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = COLOR_PANEL_SELECTED if selected else COLOR_PANEL_BORDER
	style.border_width_left = CARD_BORDER_WIDTH
	style.border_width_right = CARD_BORDER_WIDTH
	style.border_width_top = CARD_BORDER_WIDTH
	style.border_width_bottom = CARD_BORDER_WIDTH
	style.corner_radius_top_left = CARD_CORNER_RADIUS
	style.corner_radius_top_right = CARD_CORNER_RADIUS
	style.corner_radius_bottom_left = CARD_CORNER_RADIUS
	style.corner_radius_bottom_right = CARD_CORNER_RADIUS
	card.add_theme_stylebox_override("panel", style)

	# Add subtle gradient overlay (only once)
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
		var border_faded: Color = Color(COLOR_PANEL_BORDER.r, COLOR_PANEL_BORDER.g, COLOR_PANEL_BORDER.b, 0.35)
		grad_mat.set_shader_parameter("color_edge", border_faded)
		grad_rect.material = grad_mat

		card.add_child(grad_rect)
		card.set_meta(gradient_key, grad_rect)

	if card.has_meta(gradient_key):
		var grad_rect_existing: ColorRect = card.get_meta(gradient_key) as ColorRect
		if grad_rect_existing and grad_rect_existing.material is ShaderMaterial:
			var grad_mat_existing: ShaderMaterial = grad_rect_existing.material as ShaderMaterial
			var edge_color: Color = COLOR_PANEL_SELECTED if selected else COLOR_PANEL_BORDER
			grad_mat_existing.set_shader_parameter("color_edge", Color(edge_color.r, edge_color.g, edge_color.b, 0.35))

	var hover_key: String = "_hover_rect"
	if not card.has_meta(hover_key):
		CARD_HOVER_FX_SCRIPT.ensure_hover_overlay(
			card,
			CARD_HOVER_SHADER,
			COLOR_PANEL_SELECTED,
			UiColors.PARTICLE_CYAN,
			UiColors.CLICK_FLASH
		)

	if card.has_meta(hover_key):
		var card_edge_color: Color = COLOR_PANEL_SELECTED if selected else COLOR_PANEL_BORDER
		var glow_color: Color = card_edge_color.lerp(UiColors.PARTICLE_CYAN, 0.45)
		CARD_HOVER_FX_SCRIPT.set_hover_colors(card, card_edge_color, glow_color, UiColors.CLICK_FLASH)
		CARD_HOVER_FX_SCRIPT.reset_hover(card, _card_hover_tweens, card.get_instance_id(), 0.0)

	if not selected and card.scale != Vector2.ONE:
		card.scale = Vector2.ONE


## Configure focus neighbors so D-pad crosses between ship and captain columns
## and reaches the bottom-bar buttons.
func _setup_card_focus_neighbors() -> void:
	var ship_children: Array[Node] = ship_list.get_children()
	var captain_children: Array[Node] = captain_list.get_children()

	# Cross-column neighbors: ship right → first captain, captain left → first ship
	for child: Node in ship_children:
		if child is PanelContainer and captain_children.size() > 0:
			child.focus_neighbor_right = captain_children[0].get_path()
	for child: Node in captain_children:
		if child is PanelContainer and ship_children.size() > 0:
			child.focus_neighbor_left = ship_children[0].get_path()

	# Bottom of each column → buttons
	if ship_children.size() > 0:
		ship_children[-1].focus_neighbor_bottom = back_button.get_path()
	if captain_children.size() > 0:
		captain_children[-1].focus_neighbor_bottom = launch_button.get_path()

	# Buttons → top of columns
	if ship_children.size() > 0:
		back_button.focus_neighbor_top = ship_children[0].get_path()
	if captain_children.size() > 0:
		launch_button.focus_neighbor_top = captain_children[0].get_path()

	# Left/right between buttons
	back_button.focus_neighbor_right = launch_button.get_path()
	launch_button.focus_neighbor_left = back_button.get_path()
