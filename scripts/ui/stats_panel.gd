extends PanelContainer

## StatsPanel - Compact, right-aligned overlay showing all player stats grouped
## by category with Megabonk-style formatting and change arrows.
## Instanced in: pause menu, full map overlay, level-up screen, station buff popup.

const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")

## Format types for stat display.
enum StatFormat { FLAT, PERCENT, MULTIPLIER }

## Single stat row definition.
const STAT_DEFS: Array[Dictionary] = [
	# --- Defensive ---
	{"key": "max_hp", "name": "Max HP", "format": StatFormat.FLAT, "group": 0},
	{"key": "shield", "name": "Shield", "format": StatFormat.FLAT, "group": 0},
	{"key": "armor", "name": "Armor", "format": StatFormat.PERCENT, "group": 0},
	{"key": "evasion", "name": "Evasion", "format": StatFormat.PERCENT, "group": 0},
	{"key": "hp_regen", "name": "HP Regen", "format": StatFormat.FLAT, "group": 0},
	{"key": "overheal", "name": "Overheal", "format": StatFormat.FLAT, "group": 0},
	{"key": "lifesteal", "name": "Lifesteal", "format": StatFormat.PERCENT, "group": 0},
	{"key": "hull_shock", "name": "Hull Shock", "format": StatFormat.FLAT, "group": 0},
	# --- Offensive ---
	{"key": "damage", "name": "Damage", "format": StatFormat.MULTIPLIER, "group": 1},
	{"key": "attack_speed", "name": "Attack Speed", "format": StatFormat.MULTIPLIER, "group": 1},
	{"key": "crit_chance", "name": "Crit Chance", "format": StatFormat.PERCENT, "group": 1},
	{"key": "crit_damage", "name": "Crit Damage", "format": StatFormat.MULTIPLIER, "group": 1},
	{"key": "projectile_count", "name": "Projectile Count", "format": StatFormat.FLAT, "group": 1},
	{"key": "projectile_bounces", "name": "Projectile Bounces", "format": StatFormat.FLAT, "group": 1},
	# --- Scaling ---
	{"key": "movement_speed", "name": "Movement Speed", "format": StatFormat.MULTIPLIER, "group": 2},
	{"key": "size", "name": "Size", "format": StatFormat.MULTIPLIER, "group": 2},
	{"key": "projectile_speed", "name": "Projectile Speed", "format": StatFormat.MULTIPLIER, "group": 2},
	{"key": "duration", "name": "Duration", "format": StatFormat.MULTIPLIER, "group": 2},
	{"key": "knockback", "name": "Knockback", "format": StatFormat.MULTIPLIER, "group": 2},
	{"key": "damage_to_elites", "name": "Damage to Elites", "format": StatFormat.MULTIPLIER, "group": 2},
	# --- Phase Shift ---
	{"key": "extra_phase_shifts", "name": "Extra Phase Shifts", "format": StatFormat.FLAT, "group": 3},
	{"key": "phase_shift_distance", "name": "Phase Shift Dist", "format": StatFormat.FLAT, "group": 3},
	# --- Meta ---
	{"key": "luck", "name": "Luck", "format": StatFormat.PERCENT, "group": 4},
	{"key": "difficulty", "name": "Difficulty", "format": StatFormat.PERCENT, "group": 4},
	# --- Economy ---
	{"key": "xp_gain", "name": "XP Gain", "format": StatFormat.MULTIPLIER, "group": 5},
	{"key": "credits_gain", "name": "Credits Gain", "format": StatFormat.MULTIPLIER, "group": 5},
	{"key": "stardust_gain", "name": "Stardust Gain", "format": StatFormat.MULTIPLIER, "group": 5},
	{"key": "pickup_range", "name": "Pickup Range", "format": StatFormat.MULTIPLIER, "group": 5},
	{"key": "elite_spawn_rate", "name": "Elite Spawn Rate", "format": StatFormat.MULTIPLIER, "group": 5},
	{"key": "powerup_drop_chance", "name": "Powerup Drop Chance", "format": StatFormat.MULTIPLIER, "group": 5},
	{"key": "powerup_multiplier", "name": "Powerup Multiplier", "format": StatFormat.MULTIPLIER, "group": 5},
]

const COLOR_INCREASE: Color = Color(0.2, 1.0, 0.4, 1.0)
const COLOR_DECREASE: Color = Color(1.0, 0.08, 0.4, 1.0)
const ROW_FONT_SIZE: int = 15
const HEADER_FONT_SIZE: int = 20
const PANEL_WIDTH: float = 280.0

var _player: Node = null
var _stats: Node = null
var _value_labels: Dictionary = {}  # stat_key -> Label
var _previous_values: Dictionary = {}  # stat_key -> float (snapshot on show)
var _vbox: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = PANEL_WIDTH
	size.x = PANEL_WIDTH

	_apply_panel_style()
	_build_ui()


func _apply_panel_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = UiColors.PANEL_BG
	style.border_color = UiColors.PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)


func _build_ui() -> void:
	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_theme_constant_override("separation", 2)
	add_child(_vbox)

	# Header
	var header: Label = Label.new()
	header.text = "STATS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_override("font", FONT_HEADER)
	header.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
	header.add_theme_color_override("font_color", UiColors.CYAN)
	header.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	header.add_theme_constant_override("outline_size", 2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(header)

	_add_separator()

	var last_group: int = -1
	for def: Dictionary in STAT_DEFS:
		var group: int = int(def["group"])
		if group != last_group and last_group != -1:
			_add_separator()
		last_group = group

		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var name_label: Label = Label.new()
		name_label.text = String(def["name"])
		name_label.add_theme_font_override("font", FONT_HEADER)
		name_label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		name_label.add_theme_color_override("font_color", UiColors.TEXT_PRIMARY)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)

		var value_label: Label = Label.new()
		value_label.text = "—"
		value_label.add_theme_font_override("font", FONT_HEADER)
		value_label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		value_label.add_theme_color_override("font_color", UiColors.TEXT_STAT_VALUE)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(value_label)

		_vbox.add_child(row)
		_value_labels[String(def["key"])] = value_label


func _add_separator() -> void:
	var sep: HSeparator = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep_style: StyleBoxLine = StyleBoxLine.new()
	sep_style.color = UiColors.PANEL_BORDER
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	_vbox.add_child(sep)


## Call when the panel becomes visible. Snapshots previous values and refreshes display.
func refresh() -> void:
	_find_player()
	if not _stats:
		return

	for def: Dictionary in STAT_DEFS:
		var key: String = String(def["key"])
		var value: float = _stats.get_stat(key)
		var fmt: int = int(def["format"])
		var label: Label = _value_labels.get(key) as Label
		if not label:
			continue

		var formatted: String = _format_value(value, fmt)
		var arrow: String = _get_arrow(key, value)

		if arrow != "":
			label.text = arrow + " " + formatted
		else:
			label.text = formatted

		# Color the value based on change direction
		if _previous_values.has(key):
			var prev: float = float(_previous_values[key])
			if value > prev + 0.001:
				label.add_theme_color_override("font_color", COLOR_INCREASE)
			elif value < prev - 0.001:
				label.add_theme_color_override("font_color", COLOR_DECREASE)
			else:
				label.add_theme_color_override("font_color", UiColors.TEXT_STAT_VALUE)
		else:
			label.add_theme_color_override("font_color", UiColors.TEXT_STAT_VALUE)


## Snapshot current stat values as the baseline for arrow comparisons.
func snapshot() -> void:
	_find_player()
	if not _stats:
		return
	_previous_values.clear()
	for def: Dictionary in STAT_DEFS:
		var key: String = String(def["key"])
		_previous_values[key] = _stats.get_stat(key)


## Live-update a single stat row (called from stat_changed signal).
func _on_stat_changed(stat_name: String, _old_value: float, new_value: float) -> void:
	if not visible:
		return
	var label: Label = _value_labels.get(stat_name) as Label
	if not label:
		return

	# Find format for this stat
	var fmt: int = StatFormat.FLAT
	for def: Dictionary in STAT_DEFS:
		if String(def["key"]) == stat_name:
			fmt = int(def["format"])
			break

	var formatted: String = _format_value(new_value, fmt)
	var arrow: String = _get_arrow(stat_name, new_value)

	if arrow != "":
		label.text = arrow + " " + formatted
	else:
		label.text = formatted

	# Color based on change from snapshot
	if _previous_values.has(stat_name):
		var prev: float = float(_previous_values[stat_name])
		if new_value > prev + 0.001:
			label.add_theme_color_override("font_color", COLOR_INCREASE)
		elif new_value < prev - 0.001:
			label.add_theme_color_override("font_color", COLOR_DECREASE)
		else:
			label.add_theme_color_override("font_color", UiColors.TEXT_STAT_VALUE)


func _format_value(value: float, fmt: int) -> String:
	match fmt:
		StatFormat.FLAT:
			if absf(value - roundf(value)) < 0.01:
				return "%d" % int(value)
			return "%.1f" % value
		StatFormat.PERCENT:
			if absf(value - roundf(value)) < 0.01:
				return "%d%%" % int(value)
			return "%.1f%%" % value
		StatFormat.MULTIPLIER:
			return "%.1fx" % value
	return str(value)


func _get_arrow(key: String, current: float) -> String:
	if not _previous_values.has(key):
		return ""
	var prev: float = float(_previous_values[key])
	if current > prev + 0.001:
		return "▲"
	elif current < prev - 0.001:
		return "▼"
	return ""


func _find_player() -> void:
	if _player and is_instance_valid(_player):
		return
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		if _player.has_method("get_stats"):
			_stats = _player.get_stats()
		elif _player.has_node("StatsComponent"):
			_stats = _player.get_node("StatsComponent")
		# Connect for live updates
		if _stats and not _stats.stat_changed.is_connected(_on_stat_changed):
			_stats.stat_changed.connect(_on_stat_changed)
