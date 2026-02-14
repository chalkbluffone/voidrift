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
var _current_key_map: Dictionary = {}  # Maps flat keys back to JSON sections
var _auto_fire_enabled: bool = true
var _fire_timer: float = 0.0
var _fire_rate: float = 1.0
var _base_fire_rate: float = 1.0  # Fire rate from slider
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
	
	# Build weapon list from DataLoader (only enabled weapons)
	var weapon_list: Array[Dictionary] = []
	for weapon_id in DataLoader.get_enabled_weapon_ids():
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
	# Apply projectile_count as a fire rate multiplier
	var projectile_count: float = float(_current_config.get("projectile_count", 1.0))
	var effective_fire_rate: float = _base_fire_rate * max(1.0, projectile_count)
	var interval = 1.0 / max(0.1, effective_fire_rate)
	
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
	var result := WeaponDataFlattener.flatten(DataLoader.get_weapon(weapon_id))
	_current_config = result.flat
	_current_key_map = result.key_map
	
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


# --- Signal handlers ---

func _on_weapon_selected(weapon_id: String) -> void:
	select_weapon(weapon_id)


func _on_config_changed(key: String, value: Variant) -> void:
	_current_config[key] = value
	# Push live updates to persistent effects like the Nope Bubble
	_push_live_config_update()
	# If projectile_count changed, update display (fire rate multiplier)
	if key == "projectile_count":
		_update_fire_rate_display()


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
	_base_fire_rate = max(0.1, rate)
	_update_fire_rate_display()


func _update_fire_rate_display() -> void:
	# Calculate effective fire rate with projectile_count multiplier
	var projectile_count: float = float(_current_config.get("projectile_count", 1.0))
	_fire_rate = _base_fire_rate * max(1.0, projectile_count)


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
	var updated_data = WeaponDataFlattener.unflatten(_current_config, _current_key_map, original_data)
	
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


## Push current config to any active persistent effect in real time.
## Searches for nodes in groups matching the current weapon ID or "weapon_effect".
## Any effect that exposes setup() or update_config() will receive live updates.
func _push_live_config_update() -> void:
	# Search by weapon ID group (e.g., "nope_bubble", "ion_wake", "radiant_arc")
	var groups_to_check: Array = [_current_weapon_id, "weapon_effect"]
	for group_name in groups_to_check:
		var nodes = get_tree().get_nodes_in_group(group_name)
		for node in nodes:
			if not is_instance_valid(node):
				continue
			if node.has_method("update_config"):
				node.update_config(_current_config)
			elif node.has_method("setup"):
				node.setup(_current_config)


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
