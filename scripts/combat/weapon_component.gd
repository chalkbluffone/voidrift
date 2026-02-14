class_name WeaponComponent
extends Node2D

## WeaponComponent - Manages auto-firing weapons based on JSON data.
## Attach to player ship. Add weapons via equip_weapon().

signal weapon_fired(weapon_id: String, projectiles: Array)
signal weapon_equipped(weapon_id: String)
signal weapon_removed(weapon_id: String)

# Projectile scene (will need to be created)
const PROJECTILE_SCENE := preload("res://scenes/gameplay/projectile.tscn")

# Reference to player stats
const StatsComponentScript := preload("res://scripts/core/stats_component.gd")
var stats_component: Node = null

# Autoload references
@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var GameManager: Node = get_node("/root/GameManager")
@onready var FileLogger: Node = get_node("/root/FileLogger")

# Dynamic spawner cache: {weapon_id: spawner_instance}
var _spawner_cache: Dictionary = {}
# Loaded spawner scripts cache: {script_path: GDScript}
var _spawner_script_cache: Dictionary = {}

# Equipped weapons: {weapon_id: {data: Dictionary, timer: float, level: int}}
var _equipped_weapons: Dictionary = {}

# When false, weapons won't auto-fire (for test lab manual control)
var auto_fire_enabled: bool = true

# Weapon-local bonuses applied by weapon level-ups.
# {_weapon_id: {"flat": {stat: float}, "mult": {stat: float}}}
var _weapon_level_bonuses: Dictionary = {}

# Targeting
var _targeting_range: float = 500.0


func _ready() -> void:
	FileLogger.log_info("WeaponComponent", "Initializing...")
	# Get stats from parent
	var parent := get_parent()
	if parent.has_node("StatsComponent"):
		stats_component = parent.get_node("StatsComponent")
		FileLogger.log_info("WeaponComponent", "Found StatsComponent")


func _process(delta: float) -> void:
	_update_timers(delta)
	if auto_fire_enabled:
		_process_weapons()


func _update_timers(delta: float) -> void:
	for weapon_id in _equipped_weapons:
		_equipped_weapons[weapon_id].timer -= delta


func _process_weapons() -> void:
	for weapon_id in _equipped_weapons:
		var weapon_state: Dictionary = _equipped_weapons[weapon_id]
		
		if weapon_state.timer <= 0:
			_fire_weapon(weapon_id, weapon_state)
			
			# Reset timer based on cooldown and attack speed
			# Check both top-level and nested stats.cooldown for compatibility
			var stats_dict: Dictionary = weapon_state.data.get("stats", {})
			var cooldown: float = float(weapon_state.data.get("cooldown", stats_dict.get("cooldown", 0.0)))
			if cooldown <= 0.0:
				# Prefer base_stats.attack_speed (shots per second) from weapons.json
				var base_stats: Dictionary = weapon_state.data.get("base_stats", {})
				var atk_speed: float = float(base_stats.get("attack_speed", 1.0))
				atk_speed = _apply_weapon_stat_mod(weapon_id, StatsComponentScript.STAT_ATTACK_SPEED, atk_speed)
				cooldown = 1.0 / max(0.05, atk_speed)
			
			# Apply projectile_count as a fire rate multiplier
			var projectile_count: float = float(stats_dict.get("projectile_count", 1.0))
			if projectile_count > 1.0:
				cooldown /= projectile_count
			
			var attack_speed := 1.0
			if stats_component:
				attack_speed = stats_component.get_stat(StatsComponentScript.STAT_ATTACK_SPEED)
			
			weapon_state.timer = cooldown / attack_speed


func _fire_weapon(weapon_id: String, weapon_state: Dictionary) -> void:
	var data: Dictionary = weapon_state.data
	var weapon_type: String = data.get("type", "projectile")
	match weapon_type:
		"projectile":
			_fire_projectile_weapon(weapon_id, data, weapon_state.level)
		"orbit":
			_fire_orbit_weapon(weapon_id, data, weapon_state.level)
		"area":
			_fire_area_weapon(weapon_id, data, weapon_state.level)
		"beam":
			_fire_beam_weapon(weapon_id, data, weapon_state.level)
		"melee":
			_fire_melee_weapon(weapon_id, data, weapon_state.level)


func _fire_projectile_weapon(weapon_id: String, data: Dictionary, _level: int) -> void:
	# Check if this projectile weapon has a custom spawner (e.g., Nikola's Coil).
	# If so, delegate to the spawner system instead of the generic projectile path.
	var spawner_path: String = data.get("spawner", "")
	if not spawner_path.is_empty() and not spawner_path.begins_with("res://effects/projectile_base/"):
		FileLogger.log_info("WeaponComponent", "Delegating %s to custom spawner: %s" % [weapon_id, spawner_path])
		_fire_projectile_via_spawner(weapon_id, data)
		return

	# Get base stats from nested base_stats dict
	var base_stats: Dictionary = data.get("base_stats", {})
	var base_projectiles: int = base_stats.get("projectile_count", 1)
	var base_damage: float = float(base_stats.get("damage", 10.0))
	var base_speed: float = float(base_stats.get("projectile_speed", 400.0))
	var piercing: int = base_stats.get("piercing", 0)
	var spread: float = base_stats.get("spread", 15.0)
	
	# Apply stat bonuses
	var bonus_projectiles: int = 0
	var speed_mult := 1.0
	var size_mult := 1.0
	var weapon_bonus_projectiles: int = int(round(_get_weapon_flat(weapon_id, StatsComponentScript.STAT_PROJECTILE_COUNT)))
	var weapon_damage_mult: float = _get_weapon_mult(weapon_id, StatsComponentScript.STAT_DAMAGE)
	var weapon_damage_flat: float = _get_weapon_flat(weapon_id, StatsComponentScript.STAT_DAMAGE)
	var weapon_speed_mult: float = _get_weapon_mult(weapon_id, StatsComponentScript.STAT_PROJECTILE_SPEED)
	var weapon_speed_flat: float = _get_weapon_flat(weapon_id, StatsComponentScript.STAT_PROJECTILE_SPEED)
	var weapon_size_mult: float = _get_weapon_mult(weapon_id, StatsComponentScript.STAT_SIZE)
	var weapon_crit_chance: float = _get_weapon_flat(weapon_id, StatsComponentScript.STAT_CRIT_CHANCE)
	var weapon_crit_damage: float = _get_weapon_flat(weapon_id, StatsComponentScript.STAT_CRIT_DAMAGE)
	
	if stats_component:
		bonus_projectiles = stats_component.get_stat_int(StatsComponentScript.STAT_PROJECTILE_COUNT)
		speed_mult = stats_component.get_stat(StatsComponentScript.STAT_PROJECTILE_SPEED)
		size_mult = stats_component.get_stat(StatsComponentScript.STAT_SIZE)
	
	var total_projectiles: int = base_projectiles + bonus_projectiles + weapon_bonus_projectiles
	# IMPORTANT: do NOT apply global STAT_DAMAGE here; Projectile uses StatsComponent.calculate_damage().
	var final_damage: float = (base_damage + weapon_damage_flat) * (1.0 + weapon_damage_mult)
	var final_speed: float = (base_speed + weapon_speed_flat) * (speed_mult * (1.0 + weapon_speed_mult))
	var final_size_mult: float = size_mult * (1.0 + weapon_size_mult)
	
	# Get target direction
	var fire_dir := _get_fire_direction(data)
	
	# Fire projectiles
	var spawned: Array = []
	
	for i in range(total_projectiles):
		var angle_offset := 0.0
		if total_projectiles > 1:
			var spread_range: float = deg_to_rad(spread)
			angle_offset = lerp(-spread_range / 2, spread_range / 2, float(i) / (total_projectiles - 1))
		
		var proj_dir := fire_dir.rotated(angle_offset)
		var projectile := _spawn_projectile(weapon_id, proj_dir, final_damage, final_speed, piercing, final_size_mult, weapon_crit_chance, weapon_crit_damage)
		if projectile:
			spawned.append(projectile)
	
	weapon_fired.emit(weapon_id, spawned)


func _fire_projectile_via_spawner(weapon_id: String, data: Dictionary) -> void:
	"""Fire a projectile-type weapon that has a custom spawner (e.g., Nikola's Coil).
	   Delegates to the spawner system using the same pattern as orbit/area/beam weapons."""
	var parent := get_parent()
	if not parent:
		FileLogger.log_warn("WeaponComponent", "_fire_projectile_via_spawner: no parent for %s" % weapon_id)
		return
	var config: Dictionary = WeaponDataFlattener.flatten(data).flat
	
	# Inject runtime stats that aren't in the JSON (size, projectile_count with bonuses)
	var size_mult: float = 1.0
	var weapon_size_mult: float = _get_weapon_mult(weapon_id, StatsComponentScript.STAT_SIZE)
	if stats_component:
		size_mult = stats_component.get_stat(StatsComponentScript.STAT_SIZE)
	config["size_mult"] = size_mult * (1.0 + weapon_size_mult)
	
	# Merge projectile_count bonuses from stats + weapon upgrades
	var base_proj_count: int = int(config.get("projectile_count", 1))
	var bonus_proj: int = 0
	var weapon_bonus_proj: int = int(round(_get_weapon_flat(weapon_id, StatsComponentScript.STAT_PROJECTILE_COUNT)))
	if stats_component:
		bonus_proj = stats_component.get_stat_int(StatsComponentScript.STAT_PROJECTILE_COUNT)
	config["projectile_count"] = base_proj_count + bonus_proj + weapon_bonus_proj
	
	FileLogger.log_info("WeaponComponent", "Spawner config for %s: %d keys" % [weapon_id, config.size()])
	var spawner = _get_or_create_spawner(weapon_id, data)
	if spawner == null:
		FileLogger.log_warn("WeaponComponent", "No spawner for custom projectile weapon: %s" % weapon_id)
		return

	if not spawner.has_method("spawn"):
		FileLogger.log_warn("WeaponComponent", "Spawner missing spawn() for weapon: %s" % weapon_id)
		return

	# Detect spawn() signature (3-arg vs 4-arg) like _fire_melee_with_config does
	var script: Script = spawner.get_script()
	var methods: Array = script.get_script_method_list() if script else []
	var spawn_arg_count: int = 3  # Default to position-only (chain lightning style)
	for m in methods:
		if m.get("name", "") == "spawn":
			var args: Array = m.get("args", [])
			spawn_arg_count = args.size()
			break

	FileLogger.log_info("WeaponComponent", "Firing %s via spawner (%d-arg) at %s" % [weapon_id, spawn_arg_count, str(parent.global_position)])
	var result = null
	if spawn_arg_count >= 4:
		var direction: Vector2 = _get_fire_direction(data)
		result = spawner.spawn(parent.global_position, direction, config, parent)
	else:
		result = spawner.spawn(parent.global_position, config, parent)

	if result:
		FileLogger.log_info("WeaponComponent", "Spawner produced result for %s" % weapon_id)
		weapon_fired.emit(weapon_id, [result])
	else:
		FileLogger.log_info("WeaponComponent", "Spawner returned null for %s (no targets?)" % weapon_id)


func _fire_orbit_weapon(weapon_id: String, data: Dictionary, _level: int) -> void:
	# Orbit weapons create projectiles that circle the player
	var parent := get_parent()
	if not parent:
		return
	var config: Dictionary = WeaponDataFlattener.flatten(data).flat
	var spawner = _get_or_create_spawner(weapon_id, data)
	if spawner and spawner.has_method("spawn"):
		var result = spawner.spawn(parent.global_position, config, parent)
		if result:
			weapon_fired.emit(weapon_id, [result])
	else:
		FileLogger.log_warn("WeaponComponent", "No spawner for orbit weapon: %s" % weapon_id)


func _fire_area_weapon(weapon_id: String, data: Dictionary, _level: int) -> void:
	# Area weapons create damage zones around the player
	var parent := get_parent()
	if not parent:
		return
	var config: Dictionary = WeaponDataFlattener.flatten(data).flat
	var spawner = _get_or_create_spawner(weapon_id, data)
	if spawner and spawner.has_method("spawn"):
		var result = spawner.spawn(parent.global_position, config, parent)
		if result:
			weapon_fired.emit(weapon_id, [result])
	else:
		FileLogger.log_warn("WeaponComponent", "No spawner for area weapon: %s" % weapon_id)


func _fire_beam_weapon(weapon_id: String, data: Dictionary, _level: int) -> void:
	# Beam weapons fire continuous damage rays
	var parent := get_parent()
	if not parent:
		return
	var config: Dictionary = WeaponDataFlattener.flatten(data).flat
	var direction: Vector2 = _get_fire_direction(data)
	var spawner = _get_or_create_spawner(weapon_id, data)
	if spawner and spawner.has_method("spawn"):
		var result = spawner.spawn(parent.global_position, direction, config, parent)
		if result:
			weapon_fired.emit(weapon_id, [result])
	else:
		FileLogger.log_warn("WeaponComponent", "No spawner for beam weapon: %s" % weapon_id)


func _fire_melee_weapon(weapon_id: String, data: Dictionary, _level: int) -> void:
	# Melee weapons spawn close-range effects around the player
	FileLogger.log_info("WeaponComponent", "Firing melee weapon: %s" % weapon_id)
	var parent := get_parent()
	if not parent:
		FileLogger.log_warn("WeaponComponent", "No parent for melee weapon")
		return
	
	# Build flat config from nested weapon data (same format as weapon test lab)
	var config: Dictionary = WeaponDataFlattener.flatten(data).flat
	
	_fire_melee_with_config(weapon_id, config, parent)


func _fire_melee_with_config(weapon_id: String, config: Dictionary, source: Node2D) -> void:
	"""Fire a melee weapon with explicit flat config. Used by both auto-fire and test lab."""
	var spawn_pos: Vector2 = source.global_position
	var direction: Vector2 = Vector2.RIGHT.rotated(source.rotation)

	# Look up weapon data for spawner path
	var weapon_data: Dictionary = DataLoader.get_weapon(weapon_id)
	var spawner = _get_or_create_spawner(weapon_id, weapon_data)
	if spawner == null:
		push_warning("WeaponComponent: No spawner for melee weapon: " + weapon_id)
		return

	# Spawners may have different spawn() signatures. Try direction-based first,
	# then fall back to position-only (like IonWake).
	var result = null
	if spawner.has_method("spawn"):
		# Check parameter count to decide which call signature to use.
		# RadiantArc-style: spawn(pos, direction, params, follow_source)
		# IonWake-style: spawn(pos, params, follow_source)
		var script: Script = spawner.get_script()
		var methods: Array = script.get_script_method_list() if script else []
		var spawn_arg_count: int = 4  # default to direction-based
		for m in methods:
			if m.get("name", "") == "spawn":
				var args: Array = m.get("args", [])
				spawn_arg_count = args.size()
				break
		if spawn_arg_count >= 4:
			result = spawner.spawn(spawn_pos, direction, config, source)
		else:
			result = spawner.spawn(spawn_pos, config, source)

	if result:
		weapon_fired.emit(weapon_id, [result])


func fire_weapon_with_config(weapon_id: String, config: Dictionary, source: Node2D) -> void:
	"""Public API for firing a weapon with explicit config (for test lab).
	   Config should be in flat format (same as weapon_test_lab uses)."""
	# Determine weapon type from equipped data or config
	var weapon_type: String = "melee"  # Default for radiant_arc
	if _equipped_weapons.has(weapon_id):
		weapon_type = _equipped_weapons[weapon_id].data.get("type", "melee")
	else:
		# Not equipped yet — look up from DataLoader
		var wd: Dictionary = DataLoader.get_weapon(weapon_id)
		weapon_type = wd.get("type", "melee")
	
	match weapon_type:
		"melee":
			_fire_melee_with_config(weapon_id, config, source)
		"projectile":
			_fire_projectile_with_config(weapon_id, config, source)
		"area":
			_fire_area_with_config(weapon_id, config, source)
		"beam":
			_fire_beam_with_config(weapon_id, config, source)
		_:
			push_warning("WeaponComponent: fire_weapon_with_config not implemented for type: " + weapon_type)


func _fire_beam_with_config(weapon_id: String, config: Dictionary, source: Node2D) -> void:
	"""Fire a beam weapon with explicit flat config (for test lab)."""
	var weapon_data: Dictionary = DataLoader.get_weapon(weapon_id)
	var spawner = _get_or_create_spawner(weapon_id, weapon_data)
	if spawner == null:
		push_warning("WeaponComponent: No spawner for beam weapon: " + weapon_id)
		return
	if not spawner.has_method("spawn"):
		return
	var direction: Vector2 = Vector2.RIGHT.rotated(source.rotation)
	var result = spawner.spawn(source.global_position, direction, config, source)
	if result:
		weapon_fired.emit(weapon_id, [result])


func _fire_area_with_config(weapon_id: String, config: Dictionary, source: Node2D) -> void:
	"""Fire an area weapon with explicit flat config (for test lab)."""
	var weapon_data: Dictionary = DataLoader.get_weapon(weapon_id)
	var spawner = _get_or_create_spawner(weapon_id, weapon_data)
	if spawner == null:
		push_warning("WeaponComponent: No spawner for area weapon: " + weapon_id)
		return
	if not spawner.has_method("spawn"):
		return
	var result = spawner.spawn(source.global_position, config, source)
	if result:
		weapon_fired.emit(weapon_id, [result])


func _fire_projectile_with_config(weapon_id: String, config: Dictionary, source: Node2D) -> void:
	"""Fire a projectile weapon with explicit flat config (for test lab)."""
	var weapon_data: Dictionary = DataLoader.get_weapon(weapon_id)
	var spawner_path: String = weapon_data.get("spawner", "")
	
	# Custom spawner weapons (Nikola's Coil, etc.)
	if not spawner_path.is_empty() and not spawner_path.begins_with("res://effects/projectile_base/"):
		var spawner = _get_or_create_spawner(weapon_id, weapon_data)
		if spawner == null:
			push_warning("WeaponComponent: No spawner for weapon: " + weapon_id)
			return
		if not spawner.has_method("spawn"):
			return
		# Detect arg count
		var script: Script = spawner.get_script()
		var methods: Array = script.get_script_method_list() if script else []
		var spawn_arg_count: int = 3
		for m in methods:
			if m.get("name", "") == "spawn":
				spawn_arg_count = m.get("args", []).size()
				break
		var result = null
		if spawn_arg_count >= 4:
			var direction: Vector2 = Vector2.RIGHT.rotated(source.rotation)
			result = spawner.spawn(source.global_position, direction, config, source)
		else:
			result = spawner.spawn(source.global_position, config, source)
		if result:
			weapon_fired.emit(weapon_id, [result])
		return
	
	# Generic projectile weapons — fire the standard projectile path
	var fire_dir: Vector2 = Vector2.RIGHT.rotated(source.rotation)
	var proj_damage: float = float(config.get("damage", 10.0))
	var proj_speed: float = float(config.get("projectile_speed", 400.0))
	var piercing: int = int(config.get("piercing", 0))
	var projectile := _spawn_projectile(weapon_id, fire_dir, proj_damage, proj_speed, piercing, 1.0)
	if projectile:
		weapon_fired.emit(weapon_id, [projectile])


func _get_or_create_spawner(weapon_id: String, weapon_data: Dictionary):
	"""Dynamically load and cache a weapon's spawner from its 'spawner' path in weapons.json."""
	if _spawner_cache.has(weapon_id):
		return _spawner_cache[weapon_id]

	var spawner_path: String = weapon_data.get("spawner", "")
	if spawner_path.is_empty():
		FileLogger.log_warn("WeaponComponent", "No spawner path for weapon: %s" % weapon_id)
		return null

	# Load the spawner script (cached)
	var script: GDScript = null
	if _spawner_script_cache.has(spawner_path):
		script = _spawner_script_cache[spawner_path]
	else:
		if not ResourceLoader.exists(spawner_path):
			FileLogger.log_warn("WeaponComponent", "Spawner script not found: %s" % spawner_path)
			return null
		script = load(spawner_path) as GDScript
		if script == null:
			FileLogger.log_warn("WeaponComponent", "Failed to load spawner script: %s" % spawner_path)
			return null
		_spawner_script_cache[spawner_path] = script

	# Instantiate spawner with scene root as parent (effects shouldn't follow ship rotation)
	var effects_parent: Node = get_tree().current_scene
	var spawner = script.new(effects_parent)
	_spawner_cache[weapon_id] = spawner
	FileLogger.log_info("WeaponComponent", "Created spawner for weapon: %s from %s" % [weapon_id, spawner_path])
	return spawner


func _spawn_projectile(_weapon_id: String, direction: Vector2, damage: float, speed: float, piercing: int, size_mult: float, weapon_crit_chance: float = 0.0, weapon_crit_damage: float = 0.0) -> Node2D:
	if not PROJECTILE_SCENE:
		push_warning("WeaponComponent: No projectile scene loaded")
		return null
	
	var projectile: Node2D = PROJECTILE_SCENE.instantiate()
	projectile.z_index = -1
	var style: Dictionary = _get_projectile_style(_weapon_id)
	
	# Set projectile properties
	if projectile.has_method("initialize"):
		# style is optional; projectile handles it if it supports it
		projectile.initialize(damage, direction, speed, piercing, size_mult, stats_component, style, weapon_crit_chance, weapon_crit_damage)
	else:
		push_warning("WeaponComponent: Projectile missing initialize method")
	
	# Spawn at weapon position
	projectile.global_position = global_position
	
	# Add to scene tree (projectiles manage themselves)
	get_tree().current_scene.add_child(projectile)
	
	FileLogger.log_debug("WeaponComponent", "Spawned projectile at %s dir: %s dmg: %.1f spd: %.1f" % [global_position, direction, damage, speed])
	
	return projectile


func _get_projectile_style(weapon_id: String) -> Dictionary:
	# Provides basic visual variety without needing unique projectile scenes.
	# Uses the Bullets sprite sheet regions + color.
	match weapon_id:
		"plasma_cannon":
			return {"color": Color(0.2, 1.0, 0.9, 1.0), "region": 0}
		"laser_array":
			return {"color": Color(1.0, 0.25, 0.25, 1.0), "region": 1}
		"ion_orbit":
			return {"color": Color(0.4, 0.6, 1.0, 1.0), "region": 2}
		"missile_pod":
			return {"color": Color(1.0, 0.7, 0.2, 1.0), "region": 3}
		"plasma_field":
			return {"color": Color(0.7, 0.3, 1.0, 1.0), "region": 4}
		_:
			# Stable hash -> consistent color per weapon id
			var h := absi(hash(weapon_id))
			var hue := float(h % 360) / 360.0
			return {"color": Color.from_hsv(hue, 0.75, 1.0, 1.0), "region": int(h % 6)}


func _get_fire_direction(weapon_data: Dictionary) -> Vector2:
	var targeting: String = weapon_data.get("targeting", "nearest")
	
	match targeting:
		"nearest":
			var target := _find_nearest_enemy()
			if target:
				return (target.global_position - global_position).normalized()
			return Vector2.from_angle(get_parent().rotation)
		
		"random":
			return Vector2.from_angle(randf() * TAU)
		
		"forward":
			return Vector2.from_angle(get_parent().rotation)
		
		"cursor":
			var cursor := get_global_mouse_position()
			return (cursor - global_position).normalized()
	
	return Vector2.from_angle(get_parent().rotation)


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := _targeting_range
	
	# Get all enemies in the scene
	var enemies := get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not enemy is Node2D:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	return nearest


# --- Public API ---

func equip_weapon(weapon_id: String) -> bool:
	"""Equip a weapon by ID. Returns false if weapon not found."""
	if _equipped_weapons.has(weapon_id):
		# Already equipped - level it up
		_equipped_weapons[weapon_id].level = int(_equipped_weapons[weapon_id].get("level", 1)) + 1
		if not _weapon_level_bonuses.has(weapon_id):
			_weapon_level_bonuses[weapon_id] = {"flat": {}, "mult": {}}
		weapon_equipped.emit(weapon_id)
		return true
	
	var weapon_data: Dictionary = DataLoader.get_weapon(weapon_id)
	if weapon_data.is_empty():
		push_error("WeaponComponent: Unknown weapon ID: " + weapon_id)
		return false
	
	var weapon_type: String = weapon_data.get("type", "projectile")
	FileLogger.log_info("WeaponComponent", "Equipping weapon: %s (type: %s)" % [weapon_id, weapon_type])
	
	_equipped_weapons[weapon_id] = {
		"data": weapon_data,
		"timer": 0.0,  # Fire immediately
		"level": 1
	}
	_weapon_level_bonuses[weapon_id] = {"flat": {}, "mult": {}}
	
	FileLogger.log_info("WeaponComponent", "Equipped weapon: %s" % weapon_id)
	FileLogger.log_data("WeaponComponent", "Weapon data", weapon_data)
	weapon_equipped.emit(weapon_id)
	return true


func remove_weapon(weapon_id: String) -> bool:
	"""Remove a weapon. Returns false if not equipped."""
	if not _equipped_weapons.has(weapon_id):
		return false
	
	# Clean up spawner's active effects (persistent bubbles, projectiles, etc.)
	if _spawner_cache.has(weapon_id):
		var spawner = _spawner_cache[weapon_id]
		if spawner.has_method("cleanup"):
			spawner.cleanup()
		_spawner_cache.erase(weapon_id)
	
	_equipped_weapons.erase(weapon_id)
	_weapon_level_bonuses.erase(weapon_id)
	weapon_removed.emit(weapon_id)
	return true


func clear_all_weapons() -> void:
	"""Remove all equipped weapons. Used by test lab for exclusive weapon testing."""
	var weapon_ids = _equipped_weapons.keys().duplicate()
	for weapon_id in weapon_ids:
		remove_weapon(weapon_id)


func apply_level_up_effects(weapon_id: String, effects_any: Array) -> void:
	# Effects schema: [{"stat": String, "kind": "flat"|"mult", "amount": float}, ...]
	if not _weapon_level_bonuses.has(weapon_id):
		_weapon_level_bonuses[weapon_id] = {"flat": {}, "mult": {}}
	var state: Dictionary = _weapon_level_bonuses[weapon_id]
	var flat: Dictionary = state.get("flat", {})
	var mult: Dictionary = state.get("mult", {})

	for e_any in effects_any:
		if not (e_any is Dictionary):
			continue
		var e: Dictionary = e_any
		var stat_name: String = String(e.get("stat", ""))
		if stat_name == "":
			continue
		var kind: String = String(e.get("kind", "mult"))
		var amount: float = float(e.get("amount", 0.0))
		if amount == 0.0:
			continue
		if kind == "flat":
			flat[stat_name] = float(flat.get(stat_name, 0.0)) + amount
		else:
			mult[stat_name] = float(mult.get(stat_name, 0.0)) + amount

	state["flat"] = flat
	state["mult"] = mult
	_weapon_level_bonuses[weapon_id] = state


func _get_weapon_flat(weapon_id: String, stat_name: String) -> float:
	if not _weapon_level_bonuses.has(weapon_id):
		return 0.0
	var state: Dictionary = _weapon_level_bonuses[weapon_id]
	var flat: Dictionary = state.get("flat", {})
	return float(flat.get(stat_name, 0.0))


func _get_weapon_mult(weapon_id: String, stat_name: String) -> float:
	if not _weapon_level_bonuses.has(weapon_id):
		return 0.0
	var state: Dictionary = _weapon_level_bonuses[weapon_id]
	var mult: Dictionary = state.get("mult", {})
	return float(mult.get(stat_name, 0.0))


func _apply_weapon_stat_mod(weapon_id: String, stat_name: String, base_value: float) -> float:
	var flat: float = _get_weapon_flat(weapon_id, stat_name)
	var mult: float = _get_weapon_mult(weapon_id, stat_name)
	return (base_value + flat) * (1.0 + mult)


func has_weapon(weapon_id: String) -> bool:
	return _equipped_weapons.has(weapon_id)


func get_weapon_level(weapon_id: String) -> int:
	if _equipped_weapons.has(weapon_id):
		return _equipped_weapons[weapon_id].level
	return 0


func get_equipped_weapon_ids() -> Array:
	return _equipped_weapons.keys()


func get_equipped_weapon_summaries() -> Array:
	# Returns: [{"id": String, "level": int}]
	var out: Array = []
	for weapon_id in _equipped_weapons.keys():
		var state: Dictionary = _equipped_weapons[weapon_id]
		out.append({
			"id": weapon_id,
			"level": int(state.get("level", 1))
		})
	return out


func sync_from_run_data() -> void:
	"""Sync equipped weapons from GameManager run data."""
	FileLogger.log_info("WeaponComponent", "sync_from_run_data called, weapons: %s" % str(GameManager.run_data.weapons))
	for weapon_id in GameManager.run_data.weapons:
		if not has_weapon(weapon_id):
			FileLogger.log_info("WeaponComponent", "Equipping weapon from run_data: %s" % weapon_id)
			equip_weapon(weapon_id)
