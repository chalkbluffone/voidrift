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
var _spawn_boss_target: bool = false

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
		ui_panel.boss_target_toggled.connect(_on_boss_target_toggled)
		ui_panel.initialize(weapon_list)
	
	# Initialize with first weapon
	if weapon_list.size() > 0:
		select_weapon(weapon_list[0].id)


func _process(delta: float) -> void:
	_process_ship_movement(delta)
	_process_auto_fire(delta)
	_process_auto_spawn(delta)
	if _show_hitboxes:
		_apply_hitbox_visibility()


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
	
	if _spawn_boss_target:
		target.enemy_type = "boss"
		target.max_hp = max(_target_hp * 5, 500.0)
		target.current_hp = target.max_hp
		target.move_speed = _target_speed * 0.6
	else:
		target.max_hp = _target_hp
		target.current_hp = _target_hp
		target.move_speed = _target_speed
	
	target.set_target(test_ship)
	target.add_to_group("enemies")
	target_container.add_child(target)
	
	# Boss targets get a distinct purple color
	if _spawn_boss_target and target.has_node("Visual"):
		var visual_node: ColorRect = target.get_node("Visual")
		visual_node.color = Color(0.6, 0.15, 0.8, 0.9)


func clear_all_targets() -> void:
	for child in target_container.get_children():
		child.queue_free()


## Flatten nested JSON weapon data into a flat dict for UI sliders.
func _flatten_weapon_config(weapon_data: Dictionary) -> Dictionary:
	var flat: Dictionary = {}
	
	# Detect weapon type by checking for weapon-specific shape params
	var shape = weapon_data.get("shape", {})
	var visual = weapon_data.get("visual", {})
	var motion = weapon_data.get("motion", {})
	var particles = weapon_data.get("particles", {})
	var is_ion_wake = shape.has("inner_radius") or shape.has("expansion_speed")
	var is_nikolas_coil = shape.has("arc_width") or shape.has("search_radius")
	var is_nope_bubble = shape.has("shockwave_range") or shape.has("shockwave_angle_deg")
	var is_radiant_arc = (shape.has("arc_angle_deg") or shape.has("thickness")) and not is_nikolas_coil
	var is_stub = not is_ion_wake and not is_radiant_arc and not is_nikolas_coil and not is_nope_bubble
	
	# Stats — only include stats that actually exist in the data
	var stats = weapon_data.get("stats", {})
	for stat_key in stats:
		flat[stat_key] = stats[stat_key]
	
	if is_nope_bubble:
		# === NOPE BUBBLE PARAMETERS ===
		flat["knockback"] = stats.get("knockback", 600.0)
		flat["particle_count"] = stats.get("particle_count", 48)
		flat["projectile_count"] = stats.get("projectile_count", 2)
		flat["boss_damage_reduction"] = stats.get("boss_damage_reduction", 0.5)
		flat["size"] = shape.get("size", 80.0)
		flat["shockwave_range"] = shape.get("shockwave_range", 200.0)
		flat["shockwave_angle_deg"] = shape.get("shockwave_angle_deg", 45.0)
		flat["color"] = _hex_to_color(visual.get("color", "#4d99ffaa"))
		return flat
	
	# For stub/unimplemented weapons, only show the stats that exist — no defaults
	if is_stub:
		# Include any non-empty motion/shape/visual values that are actually present
		for key in motion:
			flat[key] = motion[key]
		for key in shape:
			flat[key] = shape[key]
		for key in visual:
			if visual[key] is String:
				flat[key] = _hex_to_color(visual[key])
			else:
				flat[key] = visual[key]
		return flat
	
	# Motion (common for implemented weapons)
	flat["fade_in"] = motion.get("fade_in", 0.08)
	flat["fade_out"] = motion.get("fade_out", 0.15)
	
	if is_nikolas_coil:
		# === NIKOLA'S COIL PARAMETERS ===
		# Shape
		flat["arc_width"] = shape.get("arc_width", 8.0)
		flat["search_radius"] = shape.get("search_radius", 300.0)
		
		# Motion
		flat["cascade_delay"] = motion.get("cascade_delay", 0.08)
		flat["hold_time"] = motion.get("hold_time", 0.30)
		
		# Visual
		flat["color_core"] = _hex_to_color(visual.get("color_core", "#ffffff"))
		flat["color_glow"] = _hex_to_color(visual.get("color_glow", "#4488ff"))
		flat["color_fringe"] = _hex_to_color(visual.get("color_fringe", "#8844cc"))
		flat["glow_strength"] = visual.get("glow_strength", 4.0)
		flat["bolt_width"] = visual.get("bolt_width", 0.5)
		flat["jaggedness"] = visual.get("jaggedness", 0.7)
		flat["branch_intensity"] = visual.get("branch_intensity", 0.3)
		flat["flicker_speed"] = visual.get("flicker_speed", 30.0)
	elif is_ion_wake:
		# === ION WAKE PARAMETERS ===
		# Shape
		flat["inner_radius"] = shape.get("inner_radius", 20.0)
		flat["outer_radius"] = shape.get("outer_radius", 200.0)
		flat["ring_thickness"] = shape.get("ring_thickness", 30.0)
		flat["expansion_speed"] = shape.get("expansion_speed", 300.0)
		
		# Visual
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
	
	# Detect weapon type from flat config keys
	var is_ion_wake = flat.has("inner_radius") or flat.has("outer_radius") or flat.has("expansion_speed")
	var is_nikolas_coil = flat.has("arc_width") or flat.has("search_radius") or flat.has("cascade_delay")
	var is_nope_bubble = flat.has("shockwave_range") or flat.has("shockwave_angle_deg")
	
	# Stats (common) — only write stats that exist in flat
	if not result.has("stats"):
		result["stats"] = {}
	if flat.has("damage"): result["stats"]["damage"] = flat["damage"]
	if flat.has("duration"): result["stats"]["duration"] = flat["duration"]
	if flat.has("cooldown"): result["stats"]["cooldown"] = flat["cooldown"]
	
	if not result.has("shape"):
		result["shape"] = {}
	if not result.has("motion"):
		result["motion"] = {}
	if not result.has("visual"):
		result["visual"] = {}
	
	if is_nope_bubble:
		# === NOPE BUBBLE ===
		result["stats"]["knockback"] = flat.get("knockback", 600.0)
		result["stats"]["particle_count"] = int(flat.get("particle_count", 48))
		result["stats"]["projectile_count"] = int(flat.get("projectile_count", 2))
		result["stats"]["boss_damage_reduction"] = flat.get("boss_damage_reduction", 0.5)
		result["shape"]["size"] = flat.get("size", 80.0)
		result["shape"]["shockwave_range"] = flat.get("shockwave_range", 200.0)
		result["shape"]["shockwave_angle_deg"] = flat.get("shockwave_angle_deg", 45.0)
		if flat.has("color") and flat["color"] is Color:
			result["visual"]["color"] = _color_to_hex(flat["color"])
	elif is_nikolas_coil:
		# === NIKOLA'S COIL ===
		# Shape
		result["shape"]["arc_width"] = flat.get("arc_width", 8.0)
		result["shape"]["search_radius"] = flat.get("search_radius", 300.0)
		# Motion
		result["motion"]["cascade_delay"] = flat.get("cascade_delay", 0.08)
		result["motion"]["hold_time"] = flat.get("hold_time", 0.30)
		result["motion"]["fade_in"] = flat.get("fade_in", 0.04)
		result["motion"]["fade_out"] = flat.get("fade_out", 0.15)
		# Visual
		result["visual"]["color_core"] = _color_to_hex(flat.get("color_core", Color.WHITE))
		result["visual"]["color_glow"] = _color_to_hex(flat.get("color_glow", Color(0.27, 0.53, 1.0)))
		result["visual"]["color_fringe"] = _color_to_hex(flat.get("color_fringe", Color(0.53, 0.27, 0.8)))
		result["visual"]["glow_strength"] = flat.get("glow_strength", 4.0)
		result["visual"]["bolt_width"] = flat.get("bolt_width", 0.5)
		result["visual"]["jaggedness"] = flat.get("jaggedness", 0.7)
		result["visual"]["branch_intensity"] = flat.get("branch_intensity", 0.3)
		result["visual"]["flicker_speed"] = flat.get("flicker_speed", 30.0)
		# Remove any radiant arc keys that may have leaked in
		for bad_key in ["arc_angle_deg", "thickness", "radius", "taper", "length_scale", "distance"]:
			result["shape"].erase(bad_key)
		for bad_key in ["speed", "sweep_speed", "rotation_offset_deg", "seed_offset"]:
			result["motion"].erase(bad_key)
		for bad_key in ["color_a", "color_b", "color_c", "core_strength", "noise_strength", "uv_scroll_speed", "chromatic_aberration", "pulse_strength", "pulse_speed", "electric_strength", "electric_frequency", "electric_speed", "gradient_offset"]:
			result["visual"].erase(bad_key)
		result.erase("particles")
	elif is_ion_wake:
		# === ION WAKE ===
		result["shape"]["inner_radius"] = flat.get("inner_radius", 20.0)
		result["shape"]["outer_radius"] = flat.get("outer_radius", 200.0)
		result["shape"]["ring_thickness"] = flat.get("ring_thickness", 30.0)
		result["shape"]["expansion_speed"] = flat.get("expansion_speed", 300.0)
		result["motion"]["fade_in"] = flat.get("fade_in", 0.08)
		result["motion"]["fade_out"] = flat.get("fade_out", 0.15)
		result["visual"]["color_inner"] = _color_to_hex(flat.get("color_inner", Color(0.4, 0.8, 1.0)))
		result["visual"]["color_outer"] = _color_to_hex(flat.get("color_outer", Color(0.1, 0.3, 0.5)))
		result["visual"]["color_edge"] = _color_to_hex(flat.get("color_edge", Color(0.8, 0.9, 1.0)))
		result["visual"]["glow_strength"] = flat.get("glow_strength", 2.0)
		result["visual"]["edge_sharpness"] = flat.get("edge_sharpness", 2.0)
		result["visual"]["edge_glow"] = flat.get("edge_glow", 1.5)
	else:
		# === RADIANT ARC ===
		result["shape"]["arc_angle_deg"] = flat.get("arc_angle_deg", 90.0)
		result["shape"]["radius"] = flat.get("radius", 42.0)
		result["shape"]["thickness"] = flat.get("thickness", 18.0)
		result["shape"]["taper"] = flat.get("taper", 0.5)
		result["shape"]["length_scale"] = flat.get("length_scale", 0.75)
		result["shape"]["distance"] = flat.get("distance", 25.0)
		result["motion"]["fade_in"] = flat.get("fade_in", 0.08)
		result["motion"]["fade_out"] = flat.get("fade_out", 0.15)
		result["motion"]["seed_offset"] = flat.get("seed_offset", 0.0)
		result["motion"]["speed"] = flat.get("speed", 0.0)
		result["motion"]["sweep_speed"] = flat.get("sweep_speed", 1.2)
		result["motion"]["rotation_offset_deg"] = flat.get("rotation_offset_deg", 0.0)
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
	# Push live updates to persistent effects like the Nope Bubble
	_push_live_config_update()


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
	_apply_hitbox_visibility()


func _on_boss_target_toggled(enabled: bool) -> void:
	_spawn_boss_target = enabled


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


# --- Hitbox Debug Visualization ---

## Recursively find all CollisionShape2D nodes and add/remove debug overlays.
func _apply_hitbox_visibility() -> void:
	_apply_hitbox_recursive(self)


func _apply_hitbox_recursive(node: Node) -> void:
	if node is CollisionShape2D:
		var cs: CollisionShape2D = node as CollisionShape2D
		if _show_hitboxes:
			_ensure_debug_overlay(cs)
		else:
			_remove_debug_overlay(cs)
	for child in node.get_children():
		_apply_hitbox_recursive(child)


func _ensure_debug_overlay(cs: CollisionShape2D) -> void:
	# Skip if overlay already exists
	for child in cs.get_children():
		if child.has_meta("hitbox_debug_overlay"):
			return
	var overlay := HitboxDebugOverlay.new()
	overlay.set_meta("hitbox_debug_overlay", true)
	cs.add_child(overlay)


func _remove_debug_overlay(cs: CollisionShape2D) -> void:
	for child in cs.get_children():
		if child.has_meta("hitbox_debug_overlay"):
			child.queue_free()


## Push current config to any active persistent effect (e.g. Nope Bubble) in real time.
func _push_live_config_update() -> void:
	# Find any active NopeBubble in the scene tree
	var bubbles = get_tree().get_nodes_in_group("nope_bubble")
	for bubble in bubbles:
		if is_instance_valid(bubble) and bubble.has_method("setup"):
			bubble.setup(_current_config)
			bubble._update_visuals()


## Lightweight node that draws the parent CollisionShape2D's shape outline.
class HitboxDebugOverlay extends Node2D:
	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var parent := get_parent()
		if not parent is CollisionShape2D:
			return
		var cs: CollisionShape2D = parent as CollisionShape2D
		# Only draw when the collision shape is actually active
		if cs.disabled:
			return
		var shape: Shape2D = cs.shape
		if shape == null:
			return

		# Pick color based on what the collision shape belongs to
		var color := Color(0.0, 1.0, 0.0, 0.6)  # Green default
		var grandparent := cs.get_parent()
		if grandparent:
			if grandparent.is_in_group("enemies"):
				color = Color(1.0, 0.2, 0.2, 0.6)  # Red for enemies
			elif grandparent is CharacterBody2D:
				color = Color(0.2, 0.6, 1.0, 0.6)  # Blue for player ship
			elif grandparent.name == "PickupRange":
				color = Color(1.0, 1.0, 0.2, 0.3)  # Yellow for pickup range

		if shape is CircleShape2D:
			var r: float = shape.radius
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, color, 1.5)
			draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, color.a * 0.15))
		elif shape is RectangleShape2D:
			var half: Vector2 = shape.size * 0.5
			var rect := Rect2(-half, shape.size)
			draw_rect(rect, Color(color.r, color.g, color.b, color.a * 0.15), true)
			draw_rect(rect, color, false, 1.5)
		elif shape is CapsuleShape2D:
			var r: float = shape.radius
			var h: float = shape.height * 0.5 - r
			draw_arc(Vector2(0, -h), r, PI, TAU, 24, color, 1.5)
			draw_arc(Vector2(0, h), r, 0, PI, 24, color, 1.5)
			draw_line(Vector2(-r, -h), Vector2(-r, h), color, 1.5)
			draw_line(Vector2(r, -h), Vector2(r, h), color, 1.5)
		else:
			# Fallback: draw a small marker
			draw_circle(Vector2.ZERO, 5.0, color)
