extends CanvasLayer
class_name WeaponTestUI

## UI panel for the Weapon Test Lab.
## Provides controls for weapon selection, parameter adjustment, and testing.

signal weapon_selected(weapon_id: String)
signal config_changed(key: String, value: Variant)
signal fire_pressed()
signal auto_fire_toggled(enabled: bool)
signal spawn_targets_pressed()
signal clear_targets_pressed()
signal save_config_pressed()
signal load_config_pressed()
signal target_settings_changed(speed: float, spawn_rate: float, hp: float)
signal auto_spawn_toggled(enabled: bool)
signal show_hitboxes_toggled(enabled: bool)
signal boss_target_toggled(enabled: bool)

# UI Node references
var _main_panel: PanelContainer
var _weapon_list: ItemList
var _config_container: VBoxContainer
var _sliders: Dictionary = {}
var _labels: Dictionary = {}
var _color_pickers: Dictionary = {}
var _fire_rate_slider: HSlider
var _fire_rate_label: Label  # Separate reference to avoid being overwritten
var _auto_fire_check: CheckButton

# Target control references
var _target_speed_slider: HSlider
var _target_speed_label: Label
var _target_spawn_rate_slider: HSlider
var _target_spawn_rate_label: Label
var _target_hp_slider: HSlider
var _target_hp_label: Label
var _auto_spawn_check: CheckButton
var _show_hitboxes_check: CheckButton
var _boss_target_check: CheckButton

# State
var _weapons: Array[Dictionary] = []
var _current_weapon_id: String = ""
var _is_visible: bool = true


func _ready() -> void:
	layer = 100
	_build_ui()


func _build_ui() -> void:
	# Main panel - left side of screen
	_main_panel = PanelContainer.new()
	_main_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_main_panel.custom_minimum_size = Vector2(420, 0)
	_main_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_main_panel.focus_mode = Control.FOCUS_NONE
	add_child(_main_panel)
	
	# Main vertical layout with left padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_main_panel.add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.focus_mode = Control.FOCUS_NONE
	margin.add_child(main_vbox)
	
	# --- Header ---
	var header = Label.new()
	header.text = "🔧 WEAPON TEST LAB"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(header)
	
	var toggle_hint = Label.new()
	toggle_hint.text = "Press TAB to toggle UI"
	toggle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toggle_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main_vbox.add_child(toggle_hint)
	
	_add_separator(main_vbox)
	
	# --- Weapon Selection ---
	var weapon_label = Label.new()
	weapon_label.text = "Select Weapon:"
	main_vbox.add_child(weapon_label)
	
	_weapon_list = ItemList.new()
	_weapon_list.custom_minimum_size = Vector2(0, 120)
	_weapon_list.focus_mode = Control.FOCUS_CLICK  # Don't capture keyboard navigation
	_weapon_list.item_selected.connect(_on_weapon_item_selected)
	main_vbox.add_child(_weapon_list)
	
	_add_separator(main_vbox)
	
	# --- Fire Controls ---
	var fire_label = Label.new()
	fire_label.text = "Fire Controls:"
	main_vbox.add_child(fire_label)
	
	var fire_hbox = HBoxContainer.new()
	main_vbox.add_child(fire_hbox)
	
	var fire_btn = Button.new()
	fire_btn.text = "Fire (SPACE)"
	fire_btn.focus_mode = Control.FOCUS_CLICK
	fire_btn.pressed.connect(func(): fire_pressed.emit())
	fire_hbox.add_child(fire_btn)
	
	_auto_fire_check = CheckButton.new()
	_auto_fire_check.text = "Auto-Fire"
	_auto_fire_check.button_pressed = true
	_auto_fire_check.focus_mode = Control.FOCUS_CLICK
	_auto_fire_check.toggled.connect(func(pressed): auto_fire_toggled.emit(pressed))
	fire_hbox.add_child(_auto_fire_check)
	
	# Fire rate
	var rate_hbox = HBoxContainer.new()
	main_vbox.add_child(rate_hbox)
	
	var rate_label = Label.new()
	rate_label.text = "Fire Rate:"
	rate_label.custom_minimum_size = Vector2(80, 0)
	rate_hbox.add_child(rate_label)
	
	_fire_rate_slider = HSlider.new()
	_fire_rate_slider.min_value = 0.1
	_fire_rate_slider.max_value = 10.0
	_fire_rate_slider.step = 0.1
	_fire_rate_slider.value = 1.0
	_fire_rate_slider.custom_minimum_size = Vector2(150, 0)
	_fire_rate_slider.focus_mode = Control.FOCUS_CLICK
	_fire_rate_slider.value_changed.connect(_on_fire_rate_changed)
	rate_hbox.add_child(_fire_rate_slider)
	
	_fire_rate_label = Label.new()
	_fire_rate_label.text = "1.0/s"
	_fire_rate_label.custom_minimum_size = Vector2(50, 0)
	rate_hbox.add_child(_fire_rate_label)
	
	_add_separator(main_vbox)
	
	# --- Target Controls ---
	var target_label = Label.new()
	target_label.text = "Test Targets:"
	main_vbox.add_child(target_label)
	
	var target_hbox = HBoxContainer.new()
	main_vbox.add_child(target_hbox)
	
	var spawn_btn = Button.new()
	spawn_btn.text = "Spawn 5"
	spawn_btn.focus_mode = Control.FOCUS_CLICK
	spawn_btn.pressed.connect(func(): spawn_targets_pressed.emit())
	target_hbox.add_child(spawn_btn)
	
	var clear_btn = Button.new()
	clear_btn.text = "Clear All"
	clear_btn.focus_mode = Control.FOCUS_CLICK
	clear_btn.pressed.connect(func(): clear_targets_pressed.emit())
	target_hbox.add_child(clear_btn)
	
	_auto_spawn_check = CheckButton.new()
	_auto_spawn_check.text = "Auto"
	_auto_spawn_check.button_pressed = false
	_auto_spawn_check.focus_mode = Control.FOCUS_CLICK
	_auto_spawn_check.toggled.connect(func(pressed): auto_spawn_toggled.emit(pressed))
	target_hbox.add_child(_auto_spawn_check)
	
	# Target speed slider
	var speed_hbox = HBoxContainer.new()
	main_vbox.add_child(speed_hbox)
	
	var speed_label = Label.new()
	speed_label.text = "Target Speed:"
	speed_label.custom_minimum_size = Vector2(100, 0)
	speed_hbox.add_child(speed_label)
	
	_target_speed_slider = HSlider.new()
	_target_speed_slider.min_value = 0.0
	_target_speed_slider.max_value = 200.0
	_target_speed_slider.step = 5.0
	_target_speed_slider.value = 50.0
	_target_speed_slider.custom_minimum_size = Vector2(120, 0)
	_target_speed_slider.focus_mode = Control.FOCUS_CLICK
	_target_speed_slider.value_changed.connect(_on_target_settings_changed)
	speed_hbox.add_child(_target_speed_slider)
	
	_target_speed_label = Label.new()
	_target_speed_label.text = "50"
	_target_speed_label.custom_minimum_size = Vector2(40, 0)
	speed_hbox.add_child(_target_speed_label)
	
	# Target spawn rate slider
	var spawn_rate_hbox = HBoxContainer.new()
	main_vbox.add_child(spawn_rate_hbox)
	
	var spawn_rate_label = Label.new()
	spawn_rate_label.text = "Spawn Rate:"
	spawn_rate_label.custom_minimum_size = Vector2(100, 0)
	spawn_rate_hbox.add_child(spawn_rate_label)
	
	_target_spawn_rate_slider = HSlider.new()
	_target_spawn_rate_slider.min_value = 0.5
	_target_spawn_rate_slider.max_value = 5.0
	_target_spawn_rate_slider.step = 0.5
	_target_spawn_rate_slider.value = 2.0
	_target_spawn_rate_slider.custom_minimum_size = Vector2(120, 0)
	_target_spawn_rate_slider.focus_mode = Control.FOCUS_CLICK
	_target_spawn_rate_slider.value_changed.connect(_on_target_settings_changed)
	spawn_rate_hbox.add_child(_target_spawn_rate_slider)
	
	_target_spawn_rate_label = Label.new()
	_target_spawn_rate_label.text = "2.0/s"
	_target_spawn_rate_label.custom_minimum_size = Vector2(40, 0)
	spawn_rate_hbox.add_child(_target_spawn_rate_label)
	
	# Target HP slider
	var hp_hbox = HBoxContainer.new()
	main_vbox.add_child(hp_hbox)
	
	var hp_label = Label.new()
	hp_label.text = "Target HP:"
	hp_label.custom_minimum_size = Vector2(100, 0)
	hp_hbox.add_child(hp_label)
	
	_target_hp_slider = HSlider.new()
	_target_hp_slider.min_value = 10.0
	_target_hp_slider.max_value = 500.0
	_target_hp_slider.step = 10.0
	_target_hp_slider.value = 100.0
	_target_hp_slider.custom_minimum_size = Vector2(120, 0)
	_target_hp_slider.focus_mode = Control.FOCUS_CLICK
	_target_hp_slider.value_changed.connect(_on_target_settings_changed)
	hp_hbox.add_child(_target_hp_slider)
	
	_target_hp_label = Label.new()
	_target_hp_label.text = "100"
	_target_hp_label.custom_minimum_size = Vector2(40, 0)
	hp_hbox.add_child(_target_hp_label)
	
	# Debug options
	var debug_hbox = HBoxContainer.new()
	main_vbox.add_child(debug_hbox)
	
	_show_hitboxes_check = CheckButton.new()
	_show_hitboxes_check.text = "Show Hitboxes"
	_show_hitboxes_check.button_pressed = false
	_show_hitboxes_check.focus_mode = Control.FOCUS_CLICK
	_show_hitboxes_check.toggled.connect(func(pressed): show_hitboxes_toggled.emit(pressed))
	debug_hbox.add_child(_show_hitboxes_check)
	
	_boss_target_check = CheckButton.new()
	_boss_target_check.text = "Boss Targets"
	_boss_target_check.button_pressed = false
	_boss_target_check.focus_mode = Control.FOCUS_CLICK
	_boss_target_check.toggled.connect(func(pressed): boss_target_toggled.emit(pressed))
	debug_hbox.add_child(_boss_target_check)
	
	_add_separator(main_vbox)
	
	# --- Config Section (Scrollable) ---
	var config_label = Label.new()
	config_label.text = "Weapon Parameters:"
	main_vbox.add_child(config_label)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.focus_mode = Control.FOCUS_NONE
	main_vbox.add_child(scroll)
	
	_config_container = VBoxContainer.new()
	_config_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_config_container.focus_mode = Control.FOCUS_NONE
	scroll.add_child(_config_container)
	
	_add_separator(main_vbox)
	
	# --- Save/Load ---
	var save_label = Label.new()
	save_label.text = "Configuration:"
	main_vbox.add_child(save_label)
	
	var save_hbox = HBoxContainer.new()
	main_vbox.add_child(save_hbox)
	
	var save_btn = Button.new()
	save_btn.text = "💾 Save to JSON"
	save_btn.tooltip_text = "Save changes to data/weapons.json"
	save_btn.focus_mode = Control.FOCUS_CLICK
	save_btn.pressed.connect(func(): save_config_pressed.emit())
	save_hbox.add_child(save_btn)
	
	var load_btn = Button.new()
	load_btn.text = "📂 Reload JSON"
	load_btn.tooltip_text = "Reload from data/weapons.json (discard changes)"
	load_btn.focus_mode = Control.FOCUS_CLICK
	load_btn.pressed.connect(func(): load_config_pressed.emit())
	save_hbox.add_child(load_btn)
	
	# --- Instructions ---
	_add_separator(main_vbox)
	
	var instructions = Label.new()
	instructions.text = "Controls:\n• Mouse aims weapon\n• SPACE fires manually\n• Click targets to see damage"
	instructions.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main_vbox.add_child(instructions)


func _add_separator(parent: Control) -> void:
	var sep = HSeparator.new()
	parent.add_child(sep)


func initialize(weapons: Array[Dictionary]) -> void:
	_weapons = weapons
	_populate_weapon_list()


func _populate_weapon_list() -> void:
	_weapon_list.clear()
	
	for weapon in _weapons:
		var display_name = weapon.get("name", weapon.get("id", "Unknown"))
		var weapon_type = weapon.get("type", "unknown")
		_weapon_list.add_item("%s (%s)" % [display_name, weapon_type])
	
	if _weapons.size() > 0:
		_weapon_list.select(0)


func _on_weapon_item_selected(index: int) -> void:
	if index < 0 or index >= _weapons.size():
		return
	
	var weapon_id = _weapons[index].get("id", "")
	_current_weapon_id = weapon_id
	weapon_selected.emit(weapon_id)


func update_config_ui(weapon_id: String, config: Dictionary) -> void:
	_current_weapon_id = weapon_id
	
	# Clear existing config controls
	for child in _config_container.get_children():
		child.queue_free()
	
	_sliders.clear()
	_labels.clear()
	_color_pickers.clear()
	
	# Add controls for each config parameter
	for key in config:
		var value = config[key]
		_add_config_control(key, value)


func _add_config_control(key: String, value: Variant) -> void:
	if value is float or value is int:
		# Use spinbox for ring_thickness_ratio for precise entry
		if key == "ring_thickness_ratio":
			_add_spinbox_control(key, value)
		else:
			_add_slider_control(key, value)
	elif value is Color:
		_add_color_control(key, value)
	elif value is bool:
		_add_checkbox_control(key, value)


func _add_slider_control(key: String, value: Variant) -> void:
	var hbox = HBoxContainer.new()
	_config_container.add_child(hbox)
	
	# Label
	var label = Label.new()
	label.custom_minimum_size = Vector2(180, 0)
	label.text = _format_key_name(key)
	hbox.add_child(label)
	
	# Value label
	var value_label = Label.new()
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = _format_value(value)
	hbox.add_child(value_label)
	_labels[key] = value_label
	
	# Slider
	var slider = HSlider.new()
	slider.custom_minimum_size = Vector2(100, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_CLICK  # Don't capture keyboard navigation
	
	# Set appropriate ranges based on key name
	var ranges = _get_slider_ranges(key, value)
	slider.min_value = ranges[0]
	slider.max_value = ranges[1]
	slider.step = ranges[2]
	slider.value = value
	
	slider.value_changed.connect(_on_slider_value_changed.bind(key))
	hbox.add_child(slider)
	_sliders[key] = slider


func _add_spinbox_control(key: String, value: Variant) -> void:
	var hbox = HBoxContainer.new()
	_config_container.add_child(hbox)
	
	# Label
	var label = Label.new()
	label.custom_minimum_size = Vector2(180, 0)
	label.text = _format_key_name(key)
	hbox.add_child(label)
	
	# SpinBox for direct numeric input
	var spinbox = SpinBox.new()
	spinbox.custom_minimum_size = Vector2(150, 0)
	spinbox.alignment = HORIZONTAL_ALIGNMENT_LEFT
	spinbox.update_on_text_changed = true
	spinbox.select_all_on_focus = true
	
	# Set appropriate ranges based on key name
	var ranges = _get_slider_ranges(key, value)
	spinbox.min_value = ranges[0]
	spinbox.max_value = ranges[1]
	spinbox.step = ranges[2]
	spinbox.value = value
	
	spinbox.value_changed.connect(_on_spinbox_value_changed.bind(key))
	hbox.add_child(spinbox)
	_sliders[key] = spinbox  # Reuse _sliders dictionary for spinboxes too


func _add_color_control(key: String, value: Color) -> void:
	var hbox = HBoxContainer.new()
	_config_container.add_child(hbox)
	
	var label = Label.new()
	label.custom_minimum_size = Vector2(180, 0)
	label.text = _format_key_name(key)
	hbox.add_child(label)
	
	var picker = ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(80, 30)
	picker.color = value
	picker.color_changed.connect(_on_color_changed.bind(key))
	hbox.add_child(picker)
	_color_pickers[key] = picker


func _add_checkbox_control(key: String, value: bool) -> void:
	var hbox = HBoxContainer.new()
	_config_container.add_child(hbox)
	
	var check = CheckButton.new()
	check.text = _format_key_name(key)
	check.button_pressed = value
	check.toggled.connect(func(pressed): config_changed.emit(key, pressed))
	hbox.add_child(check)


func _get_slider_ranges(key: String, current_value: Variant) -> Array:
	## Pattern-based slider range inference. No hardcoded weapon-type detection.
	## New parameters from new weapons get sensible ranges automatically based on
	## naming conventions (e.g., any key with "radius" gets [0, 500, 5]).
	## Returns [min, max, step].
	
	# --- Exact key overrides for common parameters ---
	# These take priority when we know the exact semantics.
	match key:
		"damage":
			return [0.0, 500.0, 1.0]
		"cooldown":
			return [0.05, 10.0, 0.05]
		"launch_arc_min_deg":
			return [0.0, 90.0, 1.0]
		"launch_arc_max_deg":
			return [0.0, 90.0, 1.0]
		"taper":
			return [0.0, 1.0, 0.05]
		"length_scale":
			return [0.1, 3.0, 0.05]
		"distance":
			return [0.0, 150.0, 1.0]
		"projectile_speed":
			return [50.0, 2000.0, 10.0]
		"boss_damage_reduction":
			return [0.0, 1.0, 0.05]
		"knockback":
			return [0.0, 1500.0, 50.0]
		"ring_thickness_ratio":
			return [0.1, 0.5, 0.1]
		"pellet_radius":
			return [0.0, 500.0, 1.0]
	
	# --- Pattern-based inference (checked top-to-bottom, first match wins) ---
	
	# Degree/angle parameters
	if key.ends_with("_deg") or key.contains("angle"):
		return [0.0, 360.0, 5.0]
	
	# Radius parameters
	if key.contains("radius"):
		return [0.0, 500.0, 1.0]

	# Range parameters
	if key.contains("range"):
		return [0.0, 500.0, 5.0]
	
	# Fade parameters (0-1 range)
	if key.begins_with("fade_"):
		return [0.0, 1.0, 0.01]
	
	# Strength/intensity parameters
	if key.contains("strength") or key.contains("intensity"):
		return [0.0, 10.0, 0.1]
	
	# Count/amount parameters (integers)
	if key.contains("count") or key.contains("amount"):
		return [1, 200, 1]
	
	# Size/thickness/width parameters
	if key.contains("size") or key.contains("thickness") or key.contains("width"):
		return [1.0, 300.0, 1.0]
	
	# Speed parameters
	if key.contains("speed"):
		return [0.0, 100.0, 1.0]
	
	# Duration/lifetime/interval parameters
	if key.contains("duration") or key.contains("lifetime") or key.contains("interval"):
		return [0.05, 10.0, 0.05]
	
	# Delay/hold time parameters
	if key.contains("delay") or key.contains("hold"):
		return [0.01, 2.0, 0.01]
	
	# Offset parameters
	if key.contains("offset"):
		return [-1.0, 1.0, 0.05]
	
	# Spread/drag/outward parameters (0-2 range)
	if key.contains("spread") or key.contains("drag") or key.contains("outward"):
		return [0.0, 2.0, 0.05]
	
	# Jaggedness/taper-like (0-1 range)
	if key.contains("jagged") or key.contains("aberration"):
		return [0.0, 2.0, 0.05]
	
	# Piercing (integer)
	if key.contains("piercing"):
		return [0, 20, 1]
	
	# Frequency parameters
	if key.contains("frequency"):
		return [1.0, 50.0, 1.0]
	
	# Scale parameters
	if key.contains("scale"):
		return [0.1, 3.0, 0.05]
	
	# --- Default fallback based on value type ---
	if current_value is int:
		return [0, max(100, int(current_value) * 2), 1]
	else:
		return [0.0, max(10.0, float(current_value) * 2), 0.1]


func _format_key_name(key: String) -> String:
	# Convert snake_case to Title Case
	return key.replace("_", " ").capitalize()


func _format_value(value: Variant) -> String:
	if value is float:
		return "%.2f" % value
	elif value is int:
		return str(value)
	return str(value)


func _on_slider_value_changed(value: float, key: String) -> void:
	# Update label
	if _labels.has(key):
		_labels[key].text = _format_value(value)
	
	# Emit change
	config_changed.emit(key, value)


func _on_spinbox_value_changed(value: float, key: String) -> void:
	# SpinBox displays its own value, no need to update a separate label
	config_changed.emit(key, value)


func _on_color_changed(color: Color, key: String) -> void:
	config_changed.emit(key, color)


func _on_fire_rate_changed(value: float) -> void:
	if _fire_rate_label:
		_fire_rate_label.text = "%.1f/s" % value
	
	# Find parent lab and update fire rate
	var lab = get_parent()
	if lab and lab.has_method("set_fire_rate"):
		lab.set_fire_rate(value)


func _on_target_settings_changed(_value: float = 0.0) -> void:
	# Update labels
	if _target_speed_label:
		_target_speed_label.text = "%d" % int(_target_speed_slider.value)
	if _target_spawn_rate_label:
		_target_spawn_rate_label.text = "%.1f/s" % _target_spawn_rate_slider.value
	if _target_hp_label:
		_target_hp_label.text = "%d" % int(_target_hp_slider.value)
	
	# Emit settings to lab
	target_settings_changed.emit(
		_target_speed_slider.value,
		_target_spawn_rate_slider.value,
		_target_hp_slider.value
	)


func _input(event: InputEvent) -> void:
	# Release focus from any UI element when movement keys are pressed
	# This prevents WASD from affecting focused UI controls
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
	   event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_is_visible = not _is_visible
			_main_panel.visible = _is_visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			fire_pressed.emit()
			get_viewport().set_input_as_handled()


func set_visible_panel(panel_visible: bool) -> void:
	_is_visible = panel_visible
	_main_panel.visible = panel_visible
