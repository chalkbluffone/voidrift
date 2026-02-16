class_name WeaponComponent
extends Node2D

## Manages auto-firing weapons based on JSON data.
## Attach to player ship.  Add weapons via equip_weapon().
##
## Internal helpers:
##   WeaponInventory     – weapon state, levels, per-weapon stat bonuses
##   WeaponSpawnerCache  – dynamic spawner loading & caching

signal weapon_fired(weapon_id: String, projectiles: Array)
signal weapon_equipped(weapon_id: String)
signal weapon_removed(weapon_id: String)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/gameplay/projectile.tscn")
const StatsComponentScript: GDScript = preload("res://scripts/core/stats_component.gd")

var stats_component: Node = null

## When false, weapons won't auto-fire (for test lab manual control).
var auto_fire_enabled: bool = true
var _targeting_range: float = 500.0

## Internal helpers (composition, not child nodes).
var _inventory: WeaponInventory = WeaponInventory.new()
var _spawners: WeaponSpawnerCache = WeaponSpawnerCache.new()

@onready var DataLoader: Node = get_node_or_null("/root/DataLoader")
@onready var RunManager: Node = get_node_or_null("/root/RunManager")
@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	FileLogger.log_info("WeaponComponent", "Initializing...")
	var parent: Node = get_parent()
	if parent.has_node("StatsComponent"):
		stats_component = parent.get_node("StatsComponent")
		FileLogger.log_info("WeaponComponent", "Found StatsComponent")


func _process(delta: float) -> void:
	_update_timers(delta)
	if auto_fire_enabled:
		_process_weapons()


func _update_timers(delta: float) -> void:
	for weapon_id in _inventory.weapons:
		_inventory.weapons[weapon_id].timer -= delta


func _process_weapons() -> void:
	for weapon_id in _inventory.weapons:
		var weapon_state: Dictionary = _inventory.weapons[weapon_id]

		if weapon_state.timer <= 0:
			_fire_weapon(weapon_id, weapon_state)

			var stats_dict: Dictionary = weapon_state.data.get("stats", {})
			var cooldown: float = float(weapon_state.data.get("cooldown", stats_dict.get("cooldown", 0.0)))
			if cooldown <= 0.0:
				var base_stats: Dictionary = weapon_state.data.get("base_stats", {})
				var atk_speed: float = float(base_stats.get("attack_speed", 1.0))
				atk_speed = _inventory.apply_weapon_stat_mod(weapon_id, StatsComponentScript.STAT_ATTACK_SPEED, atk_speed)
				cooldown = 1.0 / max(0.05, atk_speed)

			var projectile_count: float = float(stats_dict.get("projectile_count", 1.0))
			if weapon_id == "tothian_mines":
				var weapon_bonus_projectiles: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_PROJECTILE_COUNT)
				projectile_count += weapon_bonus_projectiles
				if stats_component:
					projectile_count += float(stats_component.get_stat_int(StatsComponentScript.STAT_PROJECTILE_COUNT))
				projectile_count = maxf(1.0, projectile_count)
			if projectile_count > 1.0:
				cooldown /= projectile_count

			var attack_speed: float = 1.0
			if stats_component:
				attack_speed = stats_component.get_stat(StatsComponentScript.STAT_ATTACK_SPEED)

			weapon_state.timer = cooldown / attack_speed


# ---------------------------------------------------------------------------
# Fire dispatcher
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Auto-fire paths (one per weapon type)
# ---------------------------------------------------------------------------

func _fire_projectile_weapon(weapon_id: String, data: Dictionary, _level: int) -> void:
	## Generic projectile path with spread.  Custom spawner weapons (Nikola's
	## Coil, etc.) are routed through the spawner system instead.
	var spawner_path: String = data.get("spawner", "")
	if not spawner_path.is_empty() and not spawner_path.begins_with("res://effects/projectile_base/"):
		FileLogger.log_info("WeaponComponent", "Delegating %s to custom spawner: %s" % [weapon_id, spawner_path])
		_fire_projectile_via_spawner(weapon_id, data)
		return

	var base_stats: Dictionary = data.get("base_stats", {})
	var base_projectiles: int = base_stats.get("projectile_count", 1)
	var base_damage: float = float(base_stats.get("damage", 10.0))
	var base_speed: float = float(base_stats.get("projectile_speed", 400.0))
	var piercing: int = base_stats.get("piercing", 0)
	var spread: float = base_stats.get("spread", 15.0)

	var bonus_projectiles: int = 0
	var speed_mult: float = 1.0
	var size_mult: float = 1.0
	var weapon_bonus_projectiles: int = int(round(_inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_PROJECTILE_COUNT)))
	var weapon_damage_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_DAMAGE)
	var weapon_damage_flat: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_DAMAGE)
	var weapon_speed_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_PROJECTILE_SPEED)
	var weapon_speed_flat: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_PROJECTILE_SPEED)
	var weapon_size_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_SIZE)
	var weapon_crit_chance: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_CRIT_CHANCE)
	var weapon_crit_damage: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_CRIT_DAMAGE)

	if stats_component:
		bonus_projectiles = stats_component.get_stat_int(StatsComponentScript.STAT_PROJECTILE_COUNT)
		speed_mult = stats_component.get_stat(StatsComponentScript.STAT_PROJECTILE_SPEED)
		size_mult = stats_component.get_stat(StatsComponentScript.STAT_SIZE)

	var total_projectiles: int = base_projectiles + bonus_projectiles + weapon_bonus_projectiles
	# IMPORTANT: do NOT apply global STAT_DAMAGE here; Projectile uses StatsComponent.calculate_damage().
	var final_damage: float = (base_damage + weapon_damage_flat) * (1.0 + weapon_damage_mult)
	var final_speed: float = (base_speed + weapon_speed_flat) * (speed_mult * (1.0 + weapon_speed_mult))
	var final_size_mult: float = size_mult * (1.0 + weapon_size_mult)

	var fire_dir: Vector2 = _get_fire_direction(data)
	var spawned: Array = []

	for i in range(total_projectiles):
		var angle_offset: float = 0.0
		if total_projectiles > 1:
			var spread_range: float = deg_to_rad(spread)
			angle_offset = lerp(-spread_range / 2, spread_range / 2, float(i) / (total_projectiles - 1))

		var proj_dir: Vector2 = fire_dir.rotated(angle_offset)
		var projectile: Node2D = _spawn_projectile(weapon_id, proj_dir, final_damage, final_speed, piercing, final_size_mult, weapon_crit_chance, weapon_crit_damage)
		if projectile:
			spawned.append(projectile)

	weapon_fired.emit(weapon_id, spawned)


func _fire_projectile_via_spawner(weapon_id: String, data: Dictionary) -> void:
	## Fire a projectile-type weapon that has a custom spawner (e.g., Nikola's
	## Coil).  Injects runtime scaling so weapon level-ups and global stats
	## apply consistently.
	var parent: Node = get_parent()
	if not parent:
		FileLogger.log_warn("WeaponComponent", "_fire_projectile_via_spawner: no parent for %s" % weapon_id)
		return
	var config: Dictionary = WeaponDataFlattener.flatten(data).flat

	var global_size_mult: float = 1.0
	var global_speed_mult: float = 1.0
	var global_duration_mult: float = 1.0
	if stats_component:
		global_size_mult = stats_component.get_stat(StatsComponentScript.STAT_SIZE)
		global_speed_mult = stats_component.get_stat(StatsComponentScript.STAT_PROJECTILE_SPEED)
		global_duration_mult = stats_component.get_stat(StatsComponentScript.STAT_DURATION)

	var weapon_size_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_SIZE)
	config["size_mult"] = global_size_mult * (1.0 + weapon_size_mult)

	var base_proj_count: int = int(config.get("projectile_count", 1))
	var bonus_proj: int = 0
	var weapon_bonus_proj: int = int(round(_inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_PROJECTILE_COUNT)))
	if stats_component:
		bonus_proj = stats_component.get_stat_int(StatsComponentScript.STAT_PROJECTILE_COUNT)
	config["projectile_count"] = maxi(1, base_proj_count + bonus_proj + weapon_bonus_proj)

	var base_damage: float = float(config.get("damage", 10.0))
	var weapon_damage_flat: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_DAMAGE)
	var weapon_damage_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_DAMAGE)
	config["damage"] = (base_damage + weapon_damage_flat) * (1.0 + weapon_damage_mult)

	var base_speed: float = float(config.get("projectile_speed", 400.0))
	var weapon_speed_flat: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_PROJECTILE_SPEED)
	var weapon_speed_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_PROJECTILE_SPEED)
	config["projectile_speed"] = (base_speed + weapon_speed_flat) * (global_speed_mult * (1.0 + weapon_speed_mult))

	var base_duration: float = float(config.get("duration", config.get("lifetime", 0.0)))
	if base_duration > 0.0:
		var weapon_duration_flat: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_DURATION)
		var weapon_duration_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_DURATION)
		config["duration"] = (base_duration + weapon_duration_flat) * (global_duration_mult * (1.0 + weapon_duration_mult))
		config["lifetime"] = config["duration"]

	config["crit_chance"] = float(config.get("crit_chance", 0.0)) + _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_CRIT_CHANCE)
	config["crit_damage"] = float(config.get("crit_damage", 0.0)) + _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_CRIT_DAMAGE)

	FileLogger.log_info("WeaponComponent", "Spawner config for %s: %d keys" % [weapon_id, config.size()])
	var spawner: Object = _spawners.get_or_create_spawner(weapon_id, data, get_tree().current_scene)
	if spawner == null:
		FileLogger.log_warn("WeaponComponent", "No spawner for custom projectile weapon: %s" % weapon_id)
		return

	if not spawner.has_method("spawn"):
		FileLogger.log_warn("WeaponComponent", "Spawner missing spawn() for weapon: %s" % weapon_id)
		return

	var spawn_arg_count: int = WeaponSpawnerCache.get_spawner_arg_count(spawner, 3)
	var result: Variant = null
	if spawn_arg_count >= 4:
		var direction: Vector2 = _get_fire_direction(data)
		result = spawner.spawn(parent.global_position, direction, config, parent)
	else:
		result = spawner.spawn(parent.global_position, config, parent)

	if result:
		weapon_fired.emit(weapon_id, [result])


func _fire_orbit_weapon(weapon_id: String, data: Dictionary, _level: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var config: Dictionary = WeaponDataFlattener.flatten(data).flat

	var size_mult: float = 1.0
	var projectile_speed_mult: float = 1.0
	var knockback_mult: float = 1.0
	if stats_component:
		size_mult = stats_component.get_stat(StatsComponentScript.STAT_SIZE)
		projectile_speed_mult = stats_component.get_stat(StatsComponentScript.STAT_PROJECTILE_SPEED)
		knockback_mult = stats_component.get_stat(StatsComponentScript.STAT_KNOCKBACK)

	var weapon_size_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_SIZE)
	var weapon_projectile_speed_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_PROJECTILE_SPEED)
	var weapon_projectile_speed_flat: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_PROJECTILE_SPEED)
	var weapon_knockback_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_KNOCKBACK)
	var weapon_knockback_flat: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_KNOCKBACK)

	config["size"] = size_mult * (1.0 + weapon_size_mult)

	var base_speed: float = float(config.get("projectile_speed", 2.2))
	config["projectile_speed"] = (base_speed + weapon_projectile_speed_flat) * (projectile_speed_mult * (1.0 + weapon_projectile_speed_mult))

	var base_knockback: float = float(config.get("knockback", 280.0))
	config["knockback"] = (base_knockback + weapon_knockback_flat) * (knockback_mult * (1.0 + weapon_knockback_mult))

	var base_proj_count: int = int(config.get("projectile_count", 1))
	var bonus_proj: int = 0
	var weapon_bonus_proj: int = int(round(_inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_PROJECTILE_COUNT)))
	if stats_component:
		bonus_proj = stats_component.get_stat_int(StatsComponentScript.STAT_PROJECTILE_COUNT)
	config["projectile_count"] = maxi(1, base_proj_count + bonus_proj + weapon_bonus_proj)

	var spawner: Object = _spawners.get_or_create_spawner(weapon_id, data, get_tree().current_scene)
	if spawner and spawner.has_method("spawn"):
		var result: Variant = spawner.spawn(parent.global_position, config, parent)
		if result:
			weapon_fired.emit(weapon_id, [result])
	else:
		FileLogger.log_warn("WeaponComponent", "No spawner for orbit weapon: %s" % weapon_id)


func _fire_area_weapon(weapon_id: String, data: Dictionary, _level: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var config: Dictionary = WeaponDataFlattener.flatten(data).flat

	# --- Stat scaling (applies to ALL area weapons) ---
	var global_size_mult: float = 1.0
	var global_duration_mult: float = 1.0
	if stats_component:
		global_size_mult = stats_component.get_stat(StatsComponentScript.STAT_SIZE)
		global_duration_mult = stats_component.get_stat(StatsComponentScript.STAT_DURATION)

	var weapon_damage_flat: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_DAMAGE)
	var weapon_damage_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_DAMAGE)
	var base_damage: float = float(config.get("damage", 10.0))
	config["damage"] = (base_damage + weapon_damage_flat) * (1.0 + weapon_damage_mult)

	var weapon_size_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_SIZE)
	var base_size: float = float(config.get("size", 90.0))
	config["size"] = maxf(8.0, base_size * global_size_mult * (1.0 + weapon_size_mult))

	var weapon_duration_flat: float = _inventory.get_weapon_flat(weapon_id, StatsComponentScript.STAT_DURATION)
	var weapon_duration_mult: float = _inventory.get_weapon_mult(weapon_id, StatsComponentScript.STAT_DURATION)
	var base_duration: float = float(config.get("duration", 3.0))
	if base_duration > 0.0:
		config["duration"] = maxf(0.15, (base_duration + weapon_duration_flat) * (global_duration_mult * (1.0 + weapon_duration_mult)))

	# Tothian Mines: also scale trigger_radius
	if weapon_id == "tothian_mines":
		var base_trigger_radius: float = float(config.get("trigger_radius", 52.0))
		config["trigger_radius"] = maxf(8.0, base_trigger_radius * global_size_mult * (1.0 + weapon_size_mult))

	var spawner: Object = _spawners.get_or_create_spawner(weapon_id, data, get_tree().current_scene)
	if spawner and spawner.has_method("spawn"):
		var result: Variant = spawner.spawn(parent.global_position, config, parent)
		if result:
			weapon_fired.emit(weapon_id, [result])
	else:
		FileLogger.log_warn("WeaponComponent", "No spawner for area weapon: %s" % weapon_id)


func _fire_beam_weapon(weapon_id: String, data: Dictionary, _level: int) -> void:
	var parent: Node = get_parent()
	if not parent:
		return
	var config: Dictionary = WeaponDataFlattener.flatten(data).flat
	var direction: Vector2 = _get_fire_direction(data)
	var spawner: Object = _spawners.get_or_create_spawner(weapon_id, data, get_tree().current_scene)
	if spawner and spawner.has_method("spawn"):
		var result: Variant = spawner.spawn(parent.global_position, direction, config, parent)
		if result:
			weapon_fired.emit(weapon_id, [result])
	else:
		FileLogger.log_warn("WeaponComponent", "No spawner for beam weapon: %s" % weapon_id)


func _fire_melee_weapon(weapon_id: String, data: Dictionary, _level: int) -> void:
	FileLogger.log_info("WeaponComponent", "Firing melee weapon: %s" % weapon_id)
	var parent: Node2D = get_parent()
	if not parent:
		FileLogger.log_warn("WeaponComponent", "No parent for melee weapon")
		return
	var config: Dictionary = WeaponDataFlattener.flatten(data).flat
	_fire_via_spawner(weapon_id, config, parent)


# ---------------------------------------------------------------------------
# Consolidated spawner fire (replaces 4 separate _fire_*_with_config methods)
# ---------------------------------------------------------------------------

func _fire_via_spawner(weapon_id: String, config: Dictionary, source: Node2D) -> void:
	## Fires any weapon through its spawner. Automatically detects spawn()
	## signature (3-arg vs 4-arg) and passes direction when supported.
	var weapon_data: Dictionary = DataLoader.get_weapon(weapon_id)
	var spawner: Object = _spawners.get_or_create_spawner(weapon_id, weapon_data, get_tree().current_scene)
	if spawner == null:
		push_warning("WeaponComponent: No spawner for weapon: " + weapon_id)
		return
	if not spawner.has_method("spawn"):
		push_warning("WeaponComponent: Spawner missing spawn() for weapon: " + weapon_id)
		return

	var spawn_arg_count: int = WeaponSpawnerCache.get_spawner_arg_count(spawner, 4)
	var result: Variant = null
	if spawn_arg_count >= 4:
		var direction: Vector2 = Vector2.RIGHT.rotated(source.rotation)
		result = spawner.spawn(source.global_position, direction, config, source)
	else:
		result = spawner.spawn(source.global_position, config, source)

	if result:
		weapon_fired.emit(weapon_id, [result])


# ---------------------------------------------------------------------------
# Test-lab manual fire (public API)
# ---------------------------------------------------------------------------

func fire_weapon_with_config(weapon_id: String, config: Dictionary, source: Node2D) -> void:
	## Public API for firing a weapon with explicit flat config (for test lab).
	var weapon_type: String = "melee"
	if _inventory.has_weapon(weapon_id):
		weapon_type = _inventory.weapons[weapon_id].data.get("type", "melee")
	else:
		var wd: Dictionary = DataLoader.get_weapon(weapon_id)
		weapon_type = wd.get("type", "melee")

	if weapon_type == "projectile":
		_fire_projectile_with_config(weapon_id, config, source)
	else:
		_fire_via_spawner(weapon_id, config, source)


func _fire_projectile_with_config(weapon_id: String, config: Dictionary, source: Node2D) -> void:
	## Fire a projectile weapon with explicit flat config (for test lab).
	## Custom spawner weapons are routed through _fire_via_spawner; generic
	## projectile weapons use the standard _spawn_projectile path.
	var weapon_data: Dictionary = DataLoader.get_weapon(weapon_id)
	var spawner_path: String = weapon_data.get("spawner", "")

	if not spawner_path.is_empty() and not spawner_path.begins_with("res://effects/projectile_base/"):
		_fire_via_spawner(weapon_id, config, source)
		return

	var fire_dir: Vector2 = Vector2.RIGHT.rotated(source.rotation)
	var proj_damage: float = float(config.get("damage", 10.0))
	var proj_speed: float = float(config.get("projectile_speed", 400.0))
	var piercing: int = int(config.get("piercing", 0))
	var projectile: Node2D = _spawn_projectile(weapon_id, fire_dir, proj_damage, proj_speed, piercing, 1.0)
	if projectile:
		weapon_fired.emit(weapon_id, [projectile])


# ---------------------------------------------------------------------------
# Projectile helpers
# ---------------------------------------------------------------------------

func _spawn_projectile(_weapon_id: String, direction: Vector2, damage: float, speed: float, piercing: int, size_mult: float, weapon_crit_chance: float = 0.0, weapon_crit_damage: float = 0.0) -> Node2D:
	if not PROJECTILE_SCENE:
		push_warning("WeaponComponent: No projectile scene loaded")
		return null

	var projectile: Node2D = PROJECTILE_SCENE.instantiate()
	projectile.z_index = -1
	var style: Dictionary = _get_projectile_style(_weapon_id)

	if projectile.has_method("initialize"):
		projectile.initialize(damage, direction, speed, piercing, size_mult, stats_component, style, weapon_crit_chance, weapon_crit_damage)
	else:
		push_warning("WeaponComponent: Projectile missing initialize method")

	projectile.global_position = global_position
	get_tree().current_scene.add_child(projectile)
	return projectile


func _get_projectile_style(weapon_id: String) -> Dictionary:
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
			var h: int = absi(hash(weapon_id))
			var hue: float = float(h % 360) / 360.0
			return {"color": Color.from_hsv(hue, 0.75, 1.0, 1.0), "region": int(h % 6)}


# ---------------------------------------------------------------------------
# Targeting
# ---------------------------------------------------------------------------

func _get_fire_direction(weapon_data: Dictionary) -> Vector2:
	var targeting: String = weapon_data.get("targeting", "nearest")

	match targeting:
		"nearest":
			var target: Node2D = _find_nearest_enemy()
			if target:
				return (target.global_position - global_position).normalized()
			return Vector2.from_angle(get_parent().rotation)

		"random":
			return Vector2.from_angle(randf() * TAU)

		"forward":
			return Vector2.from_angle(get_parent().rotation)

		"cursor":
			var cursor: Vector2 = get_global_mouse_position()
			return (cursor - global_position).normalized()

	return Vector2.from_angle(get_parent().rotation)


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = _targeting_range

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not enemy is Node2D:
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest


# ---------------------------------------------------------------------------
# Public API  (thin facades over WeaponInventory + WeaponSpawnerCache)
# ---------------------------------------------------------------------------

func equip_weapon(weapon_id: String) -> bool:
	## Equip a weapon by ID. Returns false if weapon not found.
	var weapon_data: Dictionary = DataLoader.get_weapon(weapon_id)
	if weapon_data.is_empty():
		push_error("WeaponComponent: Unknown weapon ID: " + weapon_id)
		return false

	var weapon_type: String = weapon_data.get("type", "projectile")
	var is_new: bool = _inventory.equip_weapon(weapon_id, weapon_data)

	if is_new:
		FileLogger.log_info("WeaponComponent", "Equipping weapon: %s (type: %s)" % [weapon_id, weapon_type])
		FileLogger.log_info("WeaponComponent", "Equipped weapon: %s" % weapon_id)
		FileLogger.log_data("WeaponComponent", "Weapon data", weapon_data)

	weapon_equipped.emit(weapon_id)
	return true


func remove_weapon(weapon_id: String) -> bool:
	## Remove a weapon. Returns false if not equipped.
	if not _inventory.has_weapon(weapon_id):
		return false
	_spawners.cleanup_spawner(weapon_id)
	_inventory.remove_weapon(weapon_id)
	weapon_removed.emit(weapon_id)
	return true


func clear_all_weapons() -> void:
	## Remove all equipped weapons. Used by test lab for exclusive weapon testing.
	var weapon_ids: Array = _inventory.weapons.keys().duplicate()
	for weapon_id in weapon_ids:
		remove_weapon(weapon_id)


func apply_level_up_effects(weapon_id: String, effects_any: Array) -> void:
	_inventory.apply_level_up_effects(weapon_id, effects_any)


func has_weapon(weapon_id: String) -> bool:
	return _inventory.has_weapon(weapon_id)


func get_weapon_level(weapon_id: String) -> int:
	return _inventory.get_weapon_level(weapon_id)


func get_equipped_weapon_summaries() -> Array[Dictionary]:
	return _inventory.get_equipped_weapon_summaries()


func sync_from_run_data() -> void:
	## Sync equipped weapons from run data.
	FileLogger.log_info("WeaponComponent", "sync_from_run_data called, weapons: %s" % str(RunManager.run_data.weapons))
	for weapon_id in RunManager.run_data.weapons:
		if not has_weapon(weapon_id):
			FileLogger.log_info("WeaponComponent", "Equipping weapon from run_data: %s" % weapon_id)
			equip_weapon(weapon_id)
