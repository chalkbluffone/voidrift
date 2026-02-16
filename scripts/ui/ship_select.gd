extends Control

## Ship & Captain selection screen.
## Two-column layout: ships on the left, captains on the right.
## Player must select one of each before launching a run.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

# Synthwave palette
const COLOR_PANEL_BG: Color = Color(0.08, 0.05, 0.15, 0.95)
const COLOR_PANEL_BORDER: Color = Color(0.4, 0.2, 0.5, 1.0)         # Dim purple (unselected)
const COLOR_PANEL_SELECTED: Color = Color(1.0, 0.08, 0.4, 1.0)      # Hot pink (selected)
const COLOR_BUTTON: Color = Color(0.67, 0.2, 0.95, 1.0)             # Neon purple
const COLOR_BUTTON_HOVER: Color = Color(1.0, 0.08, 0.4, 1.0)        # Hot pink
const COLOR_BUTTON_DISABLED: Color = Color(0.3, 0.15, 0.4, 0.6)     # Dim purple
const COLOR_TITLE: Color = Color(0.0, 1.0, 0.9, 1.0)                # Cyan
const COLOR_HEADER: Color = Color(1.0, 0.95, 0.2, 1.0)              # Neon yellow
const COLOR_NAME: Color = Color(1.0, 1.0, 1.0, 1.0)                 # White
const COLOR_DESC: Color = Color(0.75, 0.7, 0.85, 1.0)               # Light lavender
const COLOR_STAT_LABEL: Color = Color(0.5, 0.5, 0.6, 1.0)           # Dim gray
const COLOR_STAT_VALUE: Color = Color(0.0, 1.0, 0.9, 1.0)           # Cyan
const COLOR_LOCKED: Color = Color(0.4, 0.4, 0.4, 0.6)               # Dim gray for locked

const CARD_CORNER_RADIUS: int = 8
const CARD_BORDER_WIDTH: int = 2
const BUTTON_CORNER_RADIUS: int = 4

@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")

# Containers populated in _ready
@onready var ship_list: VBoxContainer = $MarginContainer/VBoxContainer/ContentRow/ShipColumn/ShipScroll/ShipList
@onready var captain_list: VBoxContainer = $MarginContainer/VBoxContainer/ContentRow/CaptainColumn/CaptainScroll/CaptainList
@onready var launch_button: Button = $MarginContainer/VBoxContainer/BottomBar/LaunchButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/BottomBar/BackButton

var _selected_ship_id: String = ""
var _selected_captain_id: String = ""

## Maps ship/captain id → PanelContainer card node for highlight updates.
var _ship_cards: Dictionary = {}
var _captain_cards: Dictionary = {}


func _ready() -> void:
	if FileLogger:
		FileLogger.log_info("ShipSelect", "Initializing ship & captain selection screen")

	launch_button.pressed.connect(_on_launch_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_style_button(launch_button, COLOR_BUTTON)
	_style_button(back_button, Color(0.4, 0.3, 0.5, 1.0))
	launch_button.disabled = true
	_update_launch_button_style()

	_populate_ships()
	_populate_captains()

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
	_style_card(card, false)

	# Make clickable
	card.gui_input.connect(_on_ship_card_input.bind(ship_id))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	# Ship sprite
	var sprite_path: String = String(data.get("sprite", ""))
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(64, 64)
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(sprite_path):
		tex_rect.texture = load(sprite_path)
	hbox.add_child(tex_rect)

	# Info column
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	# Name
	var name_label: Label = Label.new()
	name_label.text = String(data.get("name", ship_id))
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
	_style_card(card, false)

	card.gui_input.connect(_on_captain_card_input.bind(captain_id))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	# Captain sprite
	var sprite_path: String = String(data.get("sprite", ""))
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(64, 64)
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(sprite_path):
		tex_rect.texture = load(sprite_path)
	hbox.add_child(tex_rect)

	# Info column
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	# Name
	var name_label: Label = Label.new()
	name_label.text = String(data.get("name", captain_id))
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
		active_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2, 1.0))
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
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COLOR_STAT_LABEL)
	pair.add_child(lbl)

	var val: Label = Label.new()
	val.text = value_text
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


func _on_captain_card_input(event: InputEvent, captain_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_captain(captain_id)


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
		_style_button(launch_button, COLOR_BUTTON_DISABLED)
		launch_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.8))
	else:
		_style_button(launch_button, COLOR_BUTTON)
		launch_button.add_theme_color_override("font_color", Color.WHITE)


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


func _style_button(button: Button, base_color: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.corner_radius_top_left = BUTTON_CORNER_RADIUS
	normal.corner_radius_top_right = BUTTON_CORNER_RADIUS
	normal.corner_radius_bottom_left = BUTTON_CORNER_RADIUS
	normal.corner_radius_bottom_right = BUTTON_CORNER_RADIUS
	button.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = base_color.lightened(0.2)
	hover.corner_radius_top_left = BUTTON_CORNER_RADIUS
	hover.corner_radius_top_right = BUTTON_CORNER_RADIUS
	hover.corner_radius_bottom_left = BUTTON_CORNER_RADIUS
	hover.corner_radius_bottom_right = BUTTON_CORNER_RADIUS
	button.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = base_color.darkened(0.2)
	pressed.corner_radius_top_left = BUTTON_CORNER_RADIUS
	pressed.corner_radius_top_right = BUTTON_CORNER_RADIUS
	pressed.corner_radius_bottom_left = BUTTON_CORNER_RADIUS
	pressed.corner_radius_bottom_right = BUTTON_CORNER_RADIUS
	button.add_theme_stylebox_override("pressed", pressed)

	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
