extends Node2D
class_name WeaponTestLab

## Weapon Test Lab - Development tool for testing and tuning weapons.
## This scene provides a sandbox environment to test weapon behaviors,
## adjust parameters in real-time, and save configurations.

signal weapon_changed(weapon_id: String)
signal config_saved(weapon_id: String, config: Dictionary)

# --- Preloads ---
const RadiantArcSpawnerScript := preload("res://effects/radiant_arc/radiant_arc_spawner.gd")
const WeaponComponentScript := preload("res://scripts/combat/weapon_component.gd")
const TestTargetScene := preload("res://tools/weapon_test_lab/test_target.tscn")

# --- Node references ---
@onready var camera: Camera2D = $Camera2D
@onready var test_ship: Node2D = $TestShip
@onready var target_container: Node2D = $TargetContainer
@onready var ui_panel: CanvasLayer = $WeaponTestUI

# --- State ---
var _current_weapon_id: String = ""
var _current_config: Dictionary = {}
var _arc_spawner: RadiantArcSpawner
var _auto_fire_enabled: bool = true
var _fire_timer: float = 0.0
var _fire_rate: float = 1.0  # Fires per second
var _target_spawn_timer: float = 0.0
var _auto_spawn_targets: bool = false

# Target settings
var _target_speed: float = 50.0
var _target_spawn_rate: float = 2.0  # Seconds between spawns
var _target_hp: float = 100.0

# Debug settings
var _show_hitboxes: bool = false

# Ship movement
var _ship_speed: float = 300.0
var _last_move_direction: Vector2 = Vector2.RIGHT

# Available weapon types to test
var _available_weapons: Array[Dictionary] = [
	{
		"id": "radiant_arc",
		"name": "Radiant Arc",
		"type": "melee",
		"config_resource": "res://effects/radiant_arc/radiant_arc_config.gd"
	},
	{
		"id": "plasma_cannon",
		"name": "Plasma Cannon",
		"type": "projectile",
		"data_source": "weapons.json"
	},
	{
		"id": "laser_array",
		"name": "Laser Array",
		"type": "projectile",
		"data_source": "weapons.json"
	},
	{
		"id": "ion_orbit",
		"name": "Ion Orbit",
		"type": "orbit",
		"data_source": "weapons.json"
	},
	{
		"id": "missile_pod",
		"name": "Missile Pod",
		"type": "projectile",
		"data_source": "weapons.json"
	},
]


func _ready() -> void:
	_arc_spawner = RadiantArcSpawnerScript.new(self)
	
	# Initialize with radiant arc by default
	select_weapon("radiant_arc")
	
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
		ui_panel.export_resource_pressed.connect(_on_export_resource_pressed)
		ui_panel.target_settings_changed.connect(_on_target_settings_changed)
		ui_panel.auto_spawn_toggled.connect(_on_auto_spawn_toggled)
		ui_panel.show_hitboxes_toggled.connect(_on_show_hitboxes_toggled)
		ui_panel.initialize(_available_weapons)


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
	_current_config = _get_default_config(weapon_id)
	weapon_changed.emit(weapon_id)
	
	if ui_panel:
		ui_panel.update_config_ui(_current_weapon_id, _current_config)


func fire_weapon() -> void:
	if not test_ship:
		return
	
	var direction = Vector2.RIGHT.rotated(test_ship.rotation)
	var spawn_pos = test_ship.global_position
	
	match _current_weapon_id:
		"radiant_arc":
			_fire_radiant_arc(spawn_pos, direction)
		_:
			_fire_projectile_weapon(spawn_pos, direction)


func _fire_radiant_arc(spawn_pos: Vector2, direction: Vector2) -> void:
	var arc = _arc_spawner.spawn(spawn_pos, direction, _current_config, test_ship)
	if _show_hitboxes and arc:
		arc.set_debug_draw(true)


func _fire_projectile_weapon(spawn_pos: Vector2, direction: Vector2) -> void:
	# Use the projectile scene directly for testing
	var projectile_scene = load("res://scenes/gameplay/projectile.tscn")
	if not projectile_scene:
		push_warning("WeaponTestLab: Could not load projectile scene")
		return
	
	var base_damage: float = _current_config.get("damage", 10.0)
	var base_speed: float = _current_config.get("projectile_speed", 400.0)
	var projectile_count: int = _current_config.get("projectile_count", 1)
	var spread: float = _current_config.get("spread", 15.0)
	var piercing: int = _current_config.get("piercing", 0)
	var size_mult: float = _current_config.get("size", 1.0)
	
	for i in range(projectile_count):
		var angle_offset := 0.0
		if projectile_count > 1:
			var spread_range: float = deg_to_rad(spread)
			angle_offset = lerp(-spread_range / 2, spread_range / 2, float(i) / (projectile_count - 1))
		
		var proj_dir = direction.rotated(angle_offset)
		var projectile = projectile_scene.instantiate()
		
		if projectile.has_method("initialize"):
			projectile.initialize(base_damage, proj_dir, base_speed, piercing, size_mult, null, {}, 0.0, 0.0)
		
		projectile.global_position = spawn_pos
		add_child(projectile)


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


func _get_default_config(weapon_id: String) -> Dictionary:
	match weapon_id:
		"radiant_arc":
			return {
				"arc_angle_deg": 90.0,
				"radius": 42.0,
				"thickness": 18.0,
				"taper": 0.5,
				"length_scale": 0.75,
				"distance": 25.0,
				"speed": 0.0,
				"duration": 0.8,
				"fade_in": 0.08,
				"fade_out": 0.15,
				"color_a": Color(0.0, 1.0, 1.0, 1.0),
				"color_b": Color(1.0, 0.0, 1.0, 1.0),
				"color_c": Color(0.0, 0.5, 1.0, 1.0),
				"glow_strength": 3.0,
				"core_strength": 1.2,
				"noise_strength": 0.3,
				"uv_scroll_speed": 3.0,
				"chromatic_aberration": 0.5,
				"pulse_strength": 0.4,
				"pulse_speed": 8.0,
				"electric_strength": 0.5,
				"electric_frequency": 20.0,
				"electric_speed": 15.0,
				"gradient_offset": 0.0,
				"rotation_offset_deg": 0.0,
				"seed_offset": 0.0,
				"damage": 25.0,
				"particles_enabled": true,
				"particles_amount": 30,
				"particles_size": 5.0,
				"particles_speed": 100.0,
				"particles_lifetime": 0.4,
				"particles_spread": 0.5,
				"particles_drag": 1.2,
				"particles_outward": 0.6,
				"particles_radius": 0.8,
				"particles_color": Color(1.0, 1.0, 1.0, 0.8),
			}
		"plasma_cannon", "laser_array", "missile_pod":
			return {
				"damage": 10.0,
				"projectile_speed": 500.0,
				"projectile_count": 1,
				"spread": 15.0,
				"piercing": 0,
				"size": 1.0,
				"attack_speed": 1.0,
			}
		"ion_orbit":
			return {
				"damage": 8.0,
				"projectile_count": 2,
				"size": 1.2,
				"duration": 5.0,
				"orbit_speed": 200.0,
			}
		_:
			return {}


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
	save_current_config()


func _on_load_config_pressed() -> void:
	load_saved_config(_current_weapon_id)


func _on_export_resource_pressed(filename: String) -> void:
	if _current_weapon_id == "radiant_arc":
		save_radiant_arc_resource(filename)
	else:
		push_warning("Resource export only supported for radiant_arc currently")


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


# --- Save/Load ---

const SAVE_PATH_PREFIX = "user://weapon_configs/"

func save_current_config() -> void:
	if _current_weapon_id.is_empty():
		return
	
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(SAVE_PATH_PREFIX):
		DirAccess.make_dir_recursive_absolute(SAVE_PATH_PREFIX)
	
	var save_path = SAVE_PATH_PREFIX + _current_weapon_id + ".cfg"
	var config = ConfigFile.new()
	
	for key in _current_config:
		var value = _current_config[key]
		# Handle Color specially
		if value is Color:
			config.set_value("config", key + "_r", value.r)
			config.set_value("config", key + "_g", value.g)
			config.set_value("config", key + "_b", value.b)
			config.set_value("config", key + "_a", value.a)
		else:
			config.set_value("config", key, value)
	
	var err = config.save(save_path)
	if err == OK:
		print("[WeaponTestLab] Saved config to: ", save_path)
		config_saved.emit(_current_weapon_id, _current_config)
	else:
		push_error("[WeaponTestLab] Failed to save config: ", err)


func load_saved_config(weapon_id: String) -> bool:
	var save_path = SAVE_PATH_PREFIX + weapon_id + ".cfg"
	
	if not FileAccess.file_exists(save_path):
		print("[WeaponTestLab] No saved config found for: ", weapon_id)
		return false
	
	var config = ConfigFile.new()
	var err = config.load(save_path)
	
	if err != OK:
		push_error("[WeaponTestLab] Failed to load config: ", err)
		return false
	
	# Load all keys
	var loaded_config: Dictionary = {}
	var color_keys: Dictionary = {}  # Track color components
	
	for key in config.get_section_keys("config"):
		var value = config.get_value("config", key)
		
		# Check if this is a color component
		if key.ends_with("_r") or key.ends_with("_g") or key.ends_with("_b") or key.ends_with("_a"):
			var base_key = key.substr(0, key.length() - 2)
			if not color_keys.has(base_key):
				color_keys[base_key] = {}
			color_keys[base_key][key.substr(key.length() - 1)] = value
		else:
			loaded_config[key] = value
	
	# Reconstruct colors
	for base_key in color_keys:
		var c = color_keys[base_key]
		loaded_config[base_key] = Color(
			c.get("r", 1.0),
			c.get("g", 1.0),
			c.get("b", 1.0),
			c.get("a", 1.0)
		)
	
	# Merge with defaults - this ensures new parameters added to the game 
	# get their default values even when loading old saves
	var default_config = _get_default_config(weapon_id)
	for key in default_config:
		if not loaded_config.has(key):
			loaded_config[key] = default_config[key]
	
	_current_config = loaded_config
	
	if ui_panel:
		ui_panel.update_config_ui(weapon_id, _current_config)
	
	print("[WeaponTestLab] Loaded config from: ", save_path)
	return true


func get_available_weapons() -> Array[Dictionary]:
	return _available_weapons


func get_current_config() -> Dictionary:
	return _current_config.duplicate()


func get_current_weapon_id() -> String:
	return _current_weapon_id


func export_radiant_arc_config_resource() -> RadiantArcConfig:
	"""Export current radiant arc settings as a RadiantArcConfig resource."""
	if _current_weapon_id != "radiant_arc":
		push_warning("Current weapon is not radiant_arc")
		return null
	
	var config = RadiantArcConfig.new()
	
	# Copy all settings
	config.arc_angle_deg = _current_config.get("arc_angle_deg", 90.0)
	config.radius = _current_config.get("radius", 42.0)
	config.thickness = _current_config.get("thickness", 18.0)
	config.taper = _current_config.get("taper", 0.5)
	config.length_scale = _current_config.get("length_scale", 0.75)
	config.distance = _current_config.get("distance", 25.0)
	config.speed = _current_config.get("speed", 0.0)
	config.duration = _current_config.get("duration", 0.8)
	config.fade_in = _current_config.get("fade_in", 0.08)
	config.fade_out = _current_config.get("fade_out", 0.15)
	config.color_a = _current_config.get("color_a", Color.CYAN)
	config.color_b = _current_config.get("color_b", Color.MAGENTA)
	config.color_c = _current_config.get("color_c", Color(0.0, 0.5, 1.0))
	config.glow_strength = _current_config.get("glow_strength", 3.0)
	config.core_strength = _current_config.get("core_strength", 1.2)
	config.noise_strength = _current_config.get("noise_strength", 0.3)
	config.uv_scroll_speed = _current_config.get("uv_scroll_speed", 3.0)
	config.rotation_offset_deg = _current_config.get("rotation_offset_deg", 0.0)
	config.seed_offset = _current_config.get("seed_offset", 0.0)
	config.damage = _current_config.get("damage", 25.0)
	
	return config


func save_radiant_arc_resource(filename: String) -> bool:
	"""Save current radiant arc config as a .tres resource file."""
	var config = export_radiant_arc_config_resource()
	if config == null:
		return false
	
	var save_path = "res://effects/radiant_arc/" + filename + ".tres"
	var err = ResourceSaver.save(config, save_path)
	
	if err == OK:
		print("[WeaponTestLab] Saved RadiantArcConfig to: ", save_path)
		return true
	else:
		push_error("[WeaponTestLab] Failed to save resource: ", err)
		return false
