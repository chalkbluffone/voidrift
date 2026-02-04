extends Node2D
class_name WeaponTestLab

## Weapon Test Lab - Development tool for testing and tuning weapons.
## Uses the REAL Ship scene for accurate testing.
## Loads weapon data from weapons.json and can save changes back.

signal weapon_changed(weapon_id: String)
signal config_saved(weapon_id: String)

# --- Preloads ---
const ShipScene := preload("res://scenes/gameplay/ship.tscn")
const TestTargetScene := preload("res://tools/weapon_test_lab/test_target.tscn")

# --- Node references ---
@onready var camera: Camera2D = $Camera2D
@onready var target_container: Node2D = $TargetContainer
@onready var ui_panel: CanvasLayer = $WeaponTestUI
@onready var DataLoader: Node = get_node("/root/DataLoader")

# Ship instance (real Ship scene)
var test_ship: Node2D = null

# --- State ---
var _current_weapon_id: String = ""
var _current_config: Dictionary = {}  # Flat config for UI
var _auto_fire_enabled: bool = true
var _fire_timer: float = 0.0
var _fire_rate: float = 1.0
var _target_spawn_timer: float = 0.0
var _auto_spawn_targets: bool = false

# Target settings
var _target_speed: float = 50.0
var _target_spawn_rate: float = 2.0
var _target_hp: float = 100.0

# Debug settings
var _show_hitboxes: bool = false

# Ship movement
var _ship_speed: float = 300.0
var _last_move_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	# Instantiate the real Ship scene in test mode
	test_ship = ShipScene.instantiate()
	test_ship.test_mode = true  # Disable GameManager integration
	test_ship.position = Vector2.ZERO
	add_child(test_ship)
	
	# Disable the ship's camera (we use our own)
	var ship_camera = test_ship.get_node_or_null("Camera2D")
	if ship_camera:
		ship_camera.enabled = false
	
	# Build weapon list from DataLoader
	var weapon_list: Array[Dictionary] = []
	for weapon_id in DataLoader.get_weapon_ids():
		var weapon_data = DataLoader.get_weapon(weapon_id)
		weapon_list.append({
			"id": weapon_id,
			"name": weapon_data.get("display_name", weapon_id),
			"type": weapon_data.get("type", "unknown")
		})
	
	# Connect UI signals
	if ui_panel:
		ui_panel.weapon_selected.connect(_on_weapon_selected)
		ui_panel.config_changed.connect(_on_config_changed)
		ui_panel.fire_pressed.connect(_on_fire_pressed)
		ui_panel.auto_fire_toggled.connect(_on_auto_fire_toggled)
		ui_panel.spawn_targets_pressed.connect(_on_spawn_targets_pressed)
		ui_panel.clear_targets_pressed.connect(_on_clear_targets_pressed)
		ui_panel.save_config_pressed.connect(_on_save_config_pressed)
		ui_panel.load_config_pressed.connect(_on_load_config_pressed)
		ui_panel.target_settings_changed.connect(_on_target_settings_changed)
		ui_panel.auto_spawn_toggled.connect(_on_auto_spawn_toggled)
		ui_panel.show_hitboxes_toggled.connect(_on_show_hitboxes_toggled)
		ui_panel.initialize(weapon_list)
	
	# Initialize with first weapon
	if weapon_list.size() > 0:
		select_weapon(weapon_list[0].id)


func _process(delta: float) -> void:
	_process_ship_movement(delta)
	_process_auto_fire(delta)
	_process_auto_spawn(delta)


func _process_ship_movement(delta: float) -> void:
	if not test_ship:
		return
	
	# Use the same input actions as the main game
	var move_input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if move_input.length() > 0.1:
		# Normalize for consistent speed in all directions
		var move_dir = move_input.normalized() if move_input.length() > 1.0 else move_input
		test_ship.position += move_dir * _ship_speed * delta
		_last_move_direction = move_dir.normalized()
		
		# Face the direction we're moving
		test_ship.rotation = _last_move_direction.angle()


func _process_auto_fire(delta: float) -> void:
	if not _auto_fire_enabled:
		return
	
	_fire_timer += delta
	var interval = 1.0 / max(0.1, _fire_rate)
	
	if _fire_timer >= interval:
		_fire_timer = 0.0
		fire_weapon()


func _process_auto_spawn(delta: float) -> void:
	if not _auto_spawn_targets:
		return
	
	_target_spawn_timer += delta
	if _target_spawn_timer >= _target_spawn_rate:
		_target_spawn_timer = 0.0
		spawn_target_at_random()


func select_weapon(weapon_id: String) -> void:
	_current_weapon_id = weapon_id
	_current_config = _flatten_weapon_config(DataLoader.get_weapon(weapon_id))
	
	# Equip the weapon on the ship
	if test_ship:
		test_ship.equip_weapon_for_test(weapon_id)
	
	weapon_changed.emit(weapon_id)
	
	if ui_panel:
		ui_panel.update_config_ui(_current_weapon_id, _current_config)


func fire_weapon() -> void:
	if not test_ship:
		return
	
	# Use the ship's weapon component to fire (same code path as the real game)
	test_ship.fire_weapon_manual(_current_weapon_id, _current_config)


func spawn_target_at_random() -> void:
	var radius = randf_range(200, 400)
	var angle = randf() * TAU
	var pos = test_ship.global_position + Vector2(cos(angle), sin(angle)) * radius
	spawn_target_at(pos)


func spawn_target_at(pos: Vector2) -> void:
	var target = TestTargetScene.instantiate()
	target.global_position = pos
	target.max_hp = _target_hp
	target.current_hp = _target_hp
	target.move_speed = _target_speed
	target.set_target(test_ship)
	target.add_to_group("enemies")
	target_container.add_child(target)


func clear_all_targets() -> void:
	for child in target_container.get_children():
		child.queue_free()


## Flatten nested JSON weapon data into a flat dict for UI sliders.
func _flatten_weapon_config(weapon_data: Dictionary) -> Dictionary:
	var flat: Dictionary = {}
	
	# Detect weapon type by checking for weapon-specific shape params
	var shape = weapon_data.get("shape", {})
	var is_ion_wake = shape.has("inner_radius") or shape.has("expansion_speed")
	
	# Stats (common)
	var stats = weapon_data.get("stats", {})
	flat["damage"] = stats.get("damage", 10.0)
	flat["duration"] = stats.get("duration", 1.0)
	
	# Motion (common)
	var motion = weapon_data.get("motion", {})
	flat["fade_in"] = motion.get("fade_in", 0.08)
	flat["fade_out"] = motion.get("fade_out", 0.15)
	
	if is_ion_wake:
		# === ION WAKE PARAMETERS ===
		# Shape
		flat["inner_radius"] = shape.get("inner_radius", 20.0)
		flat["outer_radius"] = shape.get("outer_radius", 200.0)
		flat["ring_thickness"] = shape.get("ring_thickness", 30.0)
		flat["expansion_speed"] = shape.get("expansion_speed", 300.0)
		
		# Visual
		var visual = weapon_data.get("visual", {})
		flat["color_inner"] = _hex_to_color(visual.get("color_inner", "#66ccff"))
		flat["color_outer"] = _hex_to_color(visual.get("color_outer", "#1a4d99"))
		flat["color_edge"] = _hex_to_color(visual.get("color_edge", "#e6f5ff"))
		flat["glow_strength"] = visual.get("glow_strength", 2.0)
		flat["edge_sharpness"] = visual.get("edge_sharpness", 2.0)
		flat["edge_glow"] = visual.get("edge_glow", 1.0)
	else:
		# === RADIANT ARC PARAMETERS ===
		# Shape
		flat["arc_angle_deg"] = shape.get("arc_angle_deg", 90.0)
		flat["radius"] = shape.get("radius", 42.0)
		flat["thickness"] = shape.get("thickness", 18.0)
		flat["taper"] = shape.get("taper", 0.5)
		flat["length_scale"] = shape.get("length_scale", 0.75)
		flat["distance"] = shape.get("distance", 25.0)
		
		# Motion
		flat["speed"] = motion.get("speed", 0.0)
		flat["sweep_speed"] = motion.get("sweep_speed", 1.2)
		flat["rotation_offset_deg"] = motion.get("rotation_offset_deg", 0.0)
		flat["seed_offset"] = motion.get("seed_offset", 0.0)
		
		# Visual
		var visual = weapon_data.get("visual", {})
		flat["color_a"] = _hex_to_color(visual.get("color_a", "#00ffff"))
		flat["color_b"] = _hex_to_color(visual.get("color_b", "#ff00ff"))
		flat["color_c"] = _hex_to_color(visual.get("color_c", "#0080ff"))
		flat["glow_strength"] = visual.get("glow_strength", 3.0)
		flat["core_strength"] = visual.get("core_strength", 1.2)
		flat["noise_strength"] = visual.get("noise_strength", 0.3)
		flat["uv_scroll_speed"] = visual.get("uv_scroll_speed", 3.0)
		flat["chromatic_aberration"] = visual.get("chromatic_aberration", 0.0)
		flat["pulse_strength"] = visual.get("pulse_strength", 0.0)
		flat["pulse_speed"] = visual.get("pulse_speed", 8.0)
		flat["electric_strength"] = visual.get("electric_strength", 0.0)
		flat["electric_frequency"] = visual.get("electric_frequency", 20.0)
		flat["electric_speed"] = visual.get("electric_speed", 15.0)
		flat["gradient_offset"] = visual.get("gradient_offset", 0.0)
		
		# Particles
		var particles = weapon_data.get("particles", {})
		flat["particles_enabled"] = particles.get("enabled", true)
		flat["particles_amount"] = particles.get("amount", 20)
		flat["particles_size"] = particles.get("size", 3.0)
		flat["particles_speed"] = particles.get("speed", 30.0)
		flat["particles_lifetime"] = particles.get("lifetime", 0.4)
		flat["particles_spread"] = particles.get("spread", 0.3)
		flat["particles_drag"] = particles.get("drag", 1.0)
		flat["particles_outward"] = particles.get("outward", 0.7)
		flat["particles_radius"] = particles.get("radius", 1.0)
		flat["particles_color"] = _hex_to_color(particles.get("color", "#ffffffcc"))
	
	return flat


## Convert flat UI config back to nested JSON structure.
func _unflatten_weapon_config(flat: Dictionary, original: Dictionary) -> Dictionary:
	var result = original.duplicate(true)
	
	# Check if this is an ion_wake by looking for ion_wake-specific params
	var is_ion_wake = flat.has("inner_radius") or flat.has("outer_radius") or flat.has("expansion_speed")
	
	# Stats (common)
	if not result.has("stats"):
		result["stats"] = {}
	result["stats"]["damage"] = flat.get("damage", 10.0)
	result["stats"]["duration"] = flat.get("duration", 1.0)
	
	# Shape - weapon-specific
	if not result.has("shape"):
		result["shape"] = {}
	
	if is_ion_wake:
		# Ion Wake shape params
		result["shape"]["inner_radius"] = flat.get("inner_radius", 20.0)
		result["shape"]["outer_radius"] = flat.get("outer_radius", 200.0)
		result["shape"]["ring_thickness"] = flat.get("ring_thickness", 30.0)
		result["shape"]["expansion_speed"] = flat.get("expansion_speed", 300.0)
	else:
		# Radiant Arc shape params
		result["shape"]["arc_angle_deg"] = flat.get("arc_angle_deg", 90.0)
		result["shape"]["radius"] = flat.get("radius", 42.0)
		result["shape"]["thickness"] = flat.get("thickness", 18.0)
		result["shape"]["taper"] = flat.get("taper", 0.5)
		result["shape"]["length_scale"] = flat.get("length_scale", 0.75)
		result["shape"]["distance"] = flat.get("distance", 25.0)
	
	# Motion
	if not result.has("motion"):
		result["motion"] = {}
	result["motion"]["fade_in"] = flat.get("fade_in", 0.08)
	result["motion"]["fade_out"] = flat.get("fade_out", 0.15)
	if not is_ion_wake:
		# Radiant Arc-specific motion params
		result["motion"]["seed_offset"] = flat.get("seed_offset", 0.0)
		result["motion"]["speed"] = flat.get("speed", 0.0)
		result["motion"]["sweep_speed"] = flat.get("sweep_speed", 1.2)
		result["motion"]["rotation_offset_deg"] = flat.get("rotation_offset_deg", 0.0)
	
	# Visual
	if not result.has("visual"):
		result["visual"] = {}
	
	if is_ion_wake:
		# Ion Wake colors and visual params
		result["visual"]["color_inner"] = _color_to_hex(flat.get("color_inner", Color(0.4, 0.8, 1.0)))
		result["visual"]["color_outer"] = _color_to_hex(flat.get("color_outer", Color(0.1, 0.3, 0.5)))
		result["visual"]["color_edge"] = _color_to_hex(flat.get("color_edge", Color(0.8, 0.9, 1.0)))
		result["visual"]["glow_strength"] = flat.get("glow_strength", 2.0)
		result["visual"]["edge_sharpness"] = flat.get("edge_sharpness", 2.0)
		result["visual"]["edge_glow"] = flat.get("edge_glow", 1.5)
	else:
		# Radiant Arc colors and visual params
		result["visual"]["color_a"] = _color_to_hex(flat.get("color_a", Color.CYAN))
		result["visual"]["color_b"] = _color_to_hex(flat.get("color_b", Color.MAGENTA))
		result["visual"]["color_c"] = _color_to_hex(flat.get("color_c", Color(0, 0.5, 1)))
		result["visual"]["uv_scroll_speed"] = flat.get("uv_scroll_speed", 3.0)
		result["visual"]["gradient_offset"] = flat.get("gradient_offset", 0.0)
		result["visual"]["glow_strength"] = flat.get("glow_strength", 3.0)
		result["visual"]["core_strength"] = flat.get("core_strength", 1.2)
		result["visual"]["noise_strength"] = flat.get("noise_strength", 0.3)
		result["visual"]["chromatic_aberration"] = flat.get("chromatic_aberration", 0.0)
		result["visual"]["pulse_strength"] = flat.get("pulse_strength", 0.0)
		result["visual"]["pulse_speed"] = flat.get("pulse_speed", 8.0)
		result["visual"]["electric_strength"] = flat.get("electric_strength", 0.0)
		result["visual"]["electric_frequency"] = flat.get("electric_frequency", 20.0)
		result["visual"]["electric_speed"] = flat.get("electric_speed", 15.0)
		
		# Radiant Arc particles only
		if not result.has("particles"):
			result["particles"] = {}
		result["particles"]["enabled"] = flat.get("particles_enabled", true)
		result["particles"]["amount"] = int(flat.get("particles_amount", 20))
		result["particles"]["size"] = flat.get("particles_size", 3.0)
		result["particles"]["speed"] = flat.get("particles_speed", 30.0)
		result["particles"]["lifetime"] = flat.get("particles_lifetime", 0.4)
		result["particles"]["spread"] = flat.get("particles_spread", 0.3)
		result["particles"]["drag"] = flat.get("particles_drag", 1.0)
		result["particles"]["outward"] = flat.get("particles_outward", 0.7)
		result["particles"]["radius"] = flat.get("particles_radius", 1.0)
		result["particles"]["color"] = _color_to_hex(flat.get("particles_color", Color(1, 1, 1, 0.8)))
	
	return result


func _hex_to_color(hex: String) -> Color:
	if hex.is_empty():
		return Color.WHITE
	return Color.from_string(hex, Color.WHITE)


func _color_to_hex(color: Color) -> String:
	if color.a < 1.0:
		return "#" + color.to_html(true)  # Include alpha
	return "#" + color.to_html(false)  # No alpha


# --- Signal handlers ---

func _on_weapon_selected(weapon_id: String) -> void:
	select_weapon(weapon_id)


func _on_config_changed(key: String, value: Variant) -> void:
	_current_config[key] = value


func _on_fire_pressed() -> void:
	fire_weapon()


func _on_auto_fire_toggled(enabled: bool) -> void:
	_auto_fire_enabled = enabled


func _on_spawn_targets_pressed() -> void:
	for i in range(5):
		spawn_target_at_random()


func _on_clear_targets_pressed() -> void:
	clear_all_targets()


func _on_save_config_pressed() -> void:
	save_to_weapons_json()


func _on_load_config_pressed() -> void:
	reload_from_weapons_json()


func _on_export_resource_pressed(_filename: String) -> void:
	push_warning("Resource export deprecated - use Save to save directly to weapons.json")


func set_fire_rate(rate: float) -> void:
	_fire_rate = max(0.1, rate)


func set_auto_spawn_targets(enabled: bool) -> void:
	_auto_spawn_targets = enabled


func _on_target_settings_changed(speed: float, spawn_rate: float, hp: float) -> void:
	_target_speed = speed
	_target_spawn_rate = spawn_rate
	_target_hp = hp


func _on_auto_spawn_toggled(enabled: bool) -> void:
	_auto_spawn_targets = enabled


func _on_show_hitboxes_toggled(enabled: bool) -> void:
	_show_hitboxes = enabled


# --- Save/Load to weapons.json ---

func save_to_weapons_json() -> void:
	"""Save current config back to weapons.json via DataLoader."""
	if _current_weapon_id.is_empty():
		return
	
	var original_data = DataLoader.get_weapon(_current_weapon_id)
	var updated_data = _unflatten_weapon_config(_current_config, original_data)
	
	if DataLoader.save_weapon(_current_weapon_id, updated_data):
		print("[WeaponTestLab] Saved %s to weapons.json" % _current_weapon_id)
		config_saved.emit(_current_weapon_id)
	else:
		push_error("[WeaponTestLab] Failed to save %s" % _current_weapon_id)


func reload_from_weapons_json() -> void:
	"""Reload current weapon config from weapons.json."""
	DataLoader.reload_data()
	select_weapon(_current_weapon_id)
	print("[WeaponTestLab] Reloaded %s from weapons.json" % _current_weapon_id)


func get_current_config() -> Dictionary:
	return _current_config.duplicate()


func get_current_weapon_id() -> String:
	return _current_weapon_id
