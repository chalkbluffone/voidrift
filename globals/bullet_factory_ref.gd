extends Node

## Manages the shared BulletFactory2D and handles all BB2D collision routing.
## Autoload — registered by world.gd at run start, cleared between runs.

## The active BulletFactory2D node (lives in the gameplay scene tree).
var factory: Node = null

## Per-frame hit dedup: prevents body_entered + area_entered double-hit.
var _hit_guard: Dictionary = {}

@onready var _run_manager: Node = get_node("/root/RunManager")
@onready var _frame_cache: Node = get_node("/root/FrameCache")


func _process(_delta: float) -> void:
	if not _hit_guard.is_empty():
		_hit_guard.clear()


## Register a BulletFactory2D and connect its collision signals.
func register_factory(factory_node: Node) -> void:
	clear_factory()
	factory = factory_node
	factory.area_entered.connect(_on_area_entered)
	factory.body_entered.connect(_on_body_entered)
	FileLogger.info("BulletFactoryRef: factory registered")


## Disconnect and clear the factory reference.
func clear_factory() -> void:
	if factory and is_instance_valid(factory):
		if factory.area_entered.is_connected(_on_area_entered):
			factory.area_entered.disconnect(_on_area_entered)
		if factory.body_entered.is_connected(_on_body_entered):
			factory.body_entered.disconnect(_on_body_entered)
	factory = null
	_hit_guard.clear()


# -- Signal callbacks --------------------------------------------------

func _on_body_entered(hit_body: Object, multimesh: Object, bullet_index: int, custom_data: Resource, bullet_transform: Transform2D) -> void:
	if not hit_body is Node2D:
		return
	var body: Node2D = hit_body as Node2D
	if body.is_in_group("enemies"):
		_handle_enemy_hit(body, multimesh, bullet_index, custom_data, bullet_transform)
	elif body.is_in_group("obstacles"):
		# Obstacle hit — bullet already handled by BB2D collision count
		pass


func _on_area_entered(hit_area: Object, multimesh: Object, bullet_index: int, custom_data: Resource, bullet_transform: Transform2D) -> void:
	if not hit_area is Node2D:
		return
	var area: Node2D = hit_area as Node2D

	# Direct enemy Area2D (e.g. TestTarget)
	if area.is_in_group("enemies"):
		_handle_enemy_hit(area, multimesh, bullet_index, custom_data, bullet_transform)
		return

	# HitboxArea child of an enemy
	var parent: Node = area.get_parent()
	if parent and parent is Node2D and (parent as Node2D).is_in_group("enemies"):
		_handle_enemy_hit(parent as Node2D, multimesh, bullet_index, custom_data, bullet_transform)


# -- Core damage application -------------------------------------------

func _handle_enemy_hit(enemy: Node2D, multimesh: Object, bullet_index: int, custom_data: Resource, _bullet_transform: Transform2D) -> void:
	if not is_instance_valid(enemy):
		return

	# Per-frame dedup: prevent body_entered + area_entered double-hit for same bullet + enemy
	var dedup_key: int = _make_dedup_key(multimesh.get_instance_id(), bullet_index, enemy.get_instance_id())
	if _hit_guard.has(dedup_key):
		return
	_hit_guard[dedup_key] = true

	var bullet_data: WeaponBulletData = custom_data as WeaponBulletData
	if not bullet_data:
		return

	# Calculate damage with crits
	var stats: Node = bullet_data.get_stats_component()
	var damage_info: Dictionary = {"damage": bullet_data.base_damage, "is_crit": false, "is_overcrit": false}

	if stats and stats.has_method("calculate_damage"):
		damage_info = stats.calculate_damage(bullet_data.base_damage, bullet_data.crit_chance, bullet_data.crit_damage)
		stats.roll_lifesteal()

	# Weapon-specific damage modifiers
	var final_damage: float = damage_info.damage
	if bullet_data.weapon_id == "personal_space_violator":
		var hit_pos: Vector2 = Vector2(_bullet_transform.origin.x, _bullet_transform.origin.y)
		var distance: float = bullet_data.spawn_origin.distance_to(hit_pos)
		final_damage *= _calculate_falloff(distance, bullet_data.extra)
		damage_info.damage = final_damage

	# Space Nukes: AoE explosion replaces single-target damage
	if bullet_data.weapon_id == "space_nukes":
		var explosion_pos: Vector2 = Vector2(_bullet_transform.origin.x, _bullet_transform.origin.y)
		call_deferred("_apply_nuke_explosion", explosion_pos, bullet_data)
		return

	# Apply damage to enemy
	if enemy.has_method("take_damage"):
		enemy.take_damage(final_damage, null, damage_info)
		_run_manager.record_damage_dealt(final_damage)

	# Apply knockback along pellet travel direction
	if bullet_data.knockback > 0.0 and enemy.has_method("apply_knockback"):
		var kb_dir: Vector2 = (enemy.global_position - bullet_data.spawn_origin).normalized()
		enemy.apply_knockback(kb_dir * bullet_data.knockback)

	# Bounce chain: spawn a new bullet toward the nearest other enemy
	if bullet_data.bounces_remaining > 0:
		var hit_pos: Vector2 = Vector2(_bullet_transform.origin.x, _bullet_transform.origin.y)
		call_deferred("_spawn_bounce_bullet", hit_pos, enemy, bullet_data)


## Distance-based damage falloff for weapons like Personal Space Violator.
func _calculate_falloff(distance: float, extra: Dictionary) -> float:
	var start: float = float(extra.get("falloff_start", 80.0))
	var end: float = float(extra.get("falloff_end", 350.0))
	var min_mult: float = float(extra.get("falloff_min_mult", 0.15))
	if distance <= start:
		return 1.0
	elif distance >= end:
		return min_mult
	var t: float = (distance - start) / (end - start)
	return lerpf(1.0, min_mult, t)


# -- AoE explosion (Space Nukes) -----------------------------------------

## Apply burst damage to all enemies within explosion radius and spawn flash.
func _apply_nuke_explosion(origin: Vector2, bullet_data: WeaponBulletData) -> void:
	var extra: Dictionary = bullet_data.extra
	var explosion_radius: float = float(extra.get("explosion_radius", 128.0)) * bullet_data.size_mult
	var explosion_color: Color = extra.get("explosion_color", Color(1.0, 0.54, 0.12, 0.6))

	var stats: Node = bullet_data.get_stats_component()
	var enemies: Array = _frame_cache.enemies
	for enemy_any: Variant in enemies:
		if not is_instance_valid(enemy_any):
			continue
		var enemy: Node2D = enemy_any as Node2D
		if not enemy:
			continue
		if origin.distance_to(enemy.global_position) > explosion_radius:
			continue

		var damage_info: Dictionary = {"damage": bullet_data.base_damage, "is_crit": false, "is_overcrit": false}
		if stats and stats.has_method("calculate_damage"):
			damage_info = stats.calculate_damage(bullet_data.base_damage, bullet_data.crit_chance, bullet_data.crit_damage)
			stats.roll_lifesteal()

		var final_damage: float = damage_info.damage
		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage, null, damage_info)
			_run_manager.record_damage_dealt(final_damage)

	# Spawn explosion flash visual
	_spawn_explosion_flash(origin, explosion_radius, explosion_color)


## Spawn a simple expanding circle explosion visual.
func _spawn_explosion_flash(origin: Vector2, radius: float, color: Color) -> void:
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return
	var flash: _NukeFlash = _NukeFlash.new()
	flash.global_position = origin
	flash.max_radius = radius
	flash.flash_color = color
	scene_root.add_child(flash)


# -- Bounce chain spawning -----------------------------------------------

## Find the nearest other enemy and spawn a bounce bullet toward it.
func _spawn_bounce_bullet(hit_pos: Vector2, hit_enemy: Node2D, source_data: WeaponBulletData) -> void:
	if not factory or not is_instance_valid(factory):
		return

	var nearest: Node2D = null
	var nearest_dist: float = source_data.bounce_range
	var enemies: Array = _frame_cache.enemies
	for enemy_any: Variant in enemies:
		if not is_instance_valid(enemy_any):
			continue
		var e: Node2D = enemy_any as Node2D
		if not e or e == hit_enemy:
			continue
		var dist: float = hit_pos.distance_to(e.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = e

	if nearest == null:
		return

	var enemy_pos: Vector2 = hit_enemy.global_position
	var bounce_dir: Vector2 = (nearest.global_position - enemy_pos).normalized()
	if bounce_dir.is_zero_approx():
		return

	# Spawn at the edge of the hit enemy, offset by the bullet's collision half-size
	var extra: Dictionary = source_data.extra
	var enemy_radius: float = 22.0
	var col_shape: CollisionShape2D = hit_enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape and col_shape.shape is CircleShape2D:
		enemy_radius = (col_shape.shape as CircleShape2D).radius * hit_enemy.scale.x
	var col_size: Vector2 = extra.get("collision_shape_size", Vector2(8, 8))
	var bullet_half: float = col_size.x / 2.0
	var spawn_pos: Vector2 = enemy_pos + bounce_dir * (enemy_radius + bullet_half + 2.0)

	# Build single-bullet BB2D spawn for the bounce
	var texture: Texture2D = extra.get("texture") as Texture2D
	if not texture:
		return

	var data: Object = ClassDB.instantiate(&"DirectionalBulletsData2D")
	data.textures = [texture]
	data.texture_size = extra.get("texture_size", Vector2(16, 16))
	data.collision_shape_size = extra.get("collision_shape_size", Vector2(8, 8))
	data.set_collision_layer_from_array([3])
	data.set_collision_mask_from_array([4])
	data.monitorable = true
	data.max_life_time = float(extra.get("lifetime", 1.5))
	data.transforms = [Transform2D(bounce_dir.angle(), spawn_pos)]

	var spd: Object = ClassDB.instantiate(&"BulletSpeedData2D")
	spd.speed = float(extra.get("projectile_speed", 750.0))
	spd.max_speed = spd.speed
	data.all_bullet_speed_data = [spd]

	# Clone metadata with decremented bounce count
	var bullet_meta: WeaponBulletData = WeaponBulletData.new()
	bullet_meta.weapon_id = source_data.weapon_id
	bullet_meta.base_damage = source_data.base_damage
	bullet_meta.crit_chance = source_data.crit_chance
	bullet_meta.crit_damage = source_data.crit_damage
	bullet_meta.bounces_remaining = source_data.bounces_remaining - 1
	bullet_meta.bounce_range = source_data.bounce_range
	bullet_meta.size_mult = source_data.size_mult
	bullet_meta.spawn_origin = spawn_pos
	bullet_meta.extra = extra.duplicate()
	var stats: Node = source_data.get_stats_component()
	if stats:
		bullet_meta.set_stats_component(stats)
	data.bullets_custom_data = bullet_meta

	factory.spawn_directional_bullets(data)


## Build a dedup key from three ints. Uses Cantor pairing to collapse to a single int.
func _make_dedup_key(mm_id: int, b_idx: int, enemy_id: int) -> int:
	@warning_ignore("integer_division")
	var ab: int = ((mm_id + b_idx) * (mm_id + b_idx + 1)) / 2 + b_idx
	@warning_ignore("integer_division")
	return ((ab + enemy_id) * (ab + enemy_id + 1)) / 2 + enemy_id


# -- Inner classes --------------------------------------------------------

## Simple expanding-circle explosion visual for Space Nukes.
class _NukeFlash extends Node2D:
	var max_radius: float = 90.0
	var flash_color: Color = Color(1.0, 0.55, 0.1, 0.6)
	var life: float = 0.14
	var elapsed: float = 0.0

	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t: float = clampf(elapsed / life, 0.0, 1.0)
		var radius: float = max_radius * lerpf(0.35, 1.0, t)
		var alpha: float = (1.0 - t) * flash_color.a
		draw_circle(Vector2.ZERO, radius, Color(flash_color.r, flash_color.g, flash_color.b, alpha))
		draw_circle(Vector2.ZERO, radius * 0.42, Color(1.0, 0.95, 0.7, alpha * 0.8))
