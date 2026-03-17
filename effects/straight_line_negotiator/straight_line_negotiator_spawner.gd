class_name StraightLineNegotiatorSpawner

## Spawner for the Straight-Line Negotiator piercing sniper weapon.
## 4-arg spawn signature: (pos, direction, params, follow_source).
## Fires staggered shots that pierce through enemies using BlastBullets2D.
## Piercing is handled natively by BB2D's bullet_max_collision_count on the data class.

var _parent_node: Node
var _texture: Texture2D = null


func _init(parent: Node) -> void:
	_parent_node = parent
	_texture = ResourceLoader.load("res://assets/lasers/laser_bullet_white.png") as Texture2D


func spawn(
	spawn_pos: Vector2,
	_direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	var factory_ref: Node = _parent_node.get_node_or_null("/root/BulletFactoryRef")
	if not factory_ref or not factory_ref.factory:
		return null

	if not is_instance_valid(_parent_node) or not _parent_node.is_inside_tree():
		return null

	var origin: Vector2 = spawn_pos
	if is_instance_valid(follow_source):
		origin = follow_source.global_position

	# Compute effective range
	var base_range: float = float(params.get("size", 300.0))
	var range_mult: float = float(params.get("size_mult", 1.0))
	var max_range: float = base_range * range_mult
	if max_range <= 0.0:
		return null

	# Build target list: unique enemies sorted nearest-first
	var targets: Array[Node2D] = EffectUtils.find_enemies_in_range(
		_parent_node.get_tree(), origin, max_range
	)
	if targets.is_empty():
		return null

	# Extract params
	var projectile_count: int = maxi(1, int(params.get("projectile_count", 1)))
	var cooldown: float = float(params.get("cooldown", 1.0))
	var projectile_speed: float = float(params.get("projectile_speed", 500.0))
	var damage_val: float = float(params.get("damage", 15.0))
	var size_mult: float = float(params.get("size_mult", 1.0))
	var crit_chance: float = float(params.get("crit_chance", 0.0))
	var crit_damage: float = float(params.get("crit_damage", 0.0))
	var piercing: int = maxi(1, int(params.get("piercing", 3)))

	# Use the lifetime from JSON / weapon_component (includes duration stat scaling)
	var lifetime: float = float(params.get("lifetime", 1.4))

	# Build bolt config
	# Sniper needle: narrow and elongated. Base texture is 237×136 laser glow.
	var bolt_config: Dictionary = {
		"damage": damage_val,
		"projectile_speed": projectile_speed,
		"lifetime": lifetime,
		"size_mult": size_mult,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
		"piercing": piercing,
		"texture_size": Vector2(40.0, 8.0) * size_mult,
		"collision_shape_size": Vector2(16.0, 5.0) * size_mult,
	}

	# Fire first shot immediately at nearest target
	_fire_bolt(origin, targets[0], bolt_config, factory_ref, follow_source)

	# Schedule remaining shots evenly across the cooldown, cycling through targets
	if projectile_count > 1 and is_instance_valid(_parent_node) and _parent_node.is_inside_tree():
		var interval: float = cooldown / float(projectile_count)
		for i: int in range(1, projectile_count):
			var target_index: int = i % targets.size()
			var delay: float = interval * float(i)
			var timer: SceneTreeTimer = _parent_node.get_tree().create_timer(delay, false)
			timer.timeout.connect(
				_fire_delayed.bind(target_index, targets, bolt_config, factory_ref, follow_source),
				CONNECT_ONE_SHOT
			)

	return null


func _fire_delayed(
	target_index: int,
	targets: Array[Node2D],
	bolt_config: Dictionary,
	factory_ref: Node,
	follow_source: Node2D
) -> void:
	if not factory_ref or not factory_ref.factory:
		return

	var origin: Vector2 = Vector2.ZERO
	if is_instance_valid(follow_source):
		origin = follow_source.global_position

	# Try the assigned target first; fall back to nearest if it died
	var target: Node2D = null
	if target_index < targets.size() and is_instance_valid(targets[target_index]):
		target = targets[target_index]
	else:
		target = EffectUtils.find_nearest_enemy(_parent_node.get_tree(), origin)
	if target == null:
		return

	_fire_bolt(origin, target, bolt_config, factory_ref, follow_source)


## Spawn a single piercing needle via BB2D factory.
func _fire_bolt(
	origin: Vector2,
	target: Node2D,
	bolt_config: Dictionary,
	factory_ref: Node,
	follow_source: Node2D
) -> void:
	if not is_instance_valid(target):
		return

	var direction: Vector2 = (target.global_position - origin).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	var fire_origin: Vector2 = EffectUtils.source_edge_origin(follow_source, direction, origin)
	var angle: float = direction.angle()

	var speed: float = float(bolt_config.get("projectile_speed", 500.0))
	var lifetime: float = float(bolt_config.get("lifetime", 1.0))
	var piercing: int = int(bolt_config.get("piercing", 3))
	var tex_size: Vector2 = bolt_config.get("texture_size", Vector2(28, 6))
	var col_size: Vector2 = bolt_config.get("collision_shape_size", Vector2(16, 5))

	var data: Object = ClassDB.instantiate(&"DirectionalBulletsData2D")
	data.textures = [_texture]
	data.texture_size = tex_size
	data.collision_shape_size = col_size
	data.set_collision_layer_from_array([3])
	data.set_collision_mask_from_array([4])
	data.monitorable = true
	data.max_life_time = lifetime
	data.transforms = [Transform2D(angle, fire_origin)]

	var spd_data: Object = ClassDB.instantiate(&"BulletSpeedData2D")
	spd_data.speed = speed
	spd_data.max_speed = speed
	data.all_bullet_speed_data = [spd_data]

	# Set piercing on data class (bullet survives N collisions)
	data.bullet_max_collision_count = piercing

	var bullet_meta: WeaponBulletData = WeaponBulletData.new()
	bullet_meta.weapon_id = "straight_line_negotiator"
	bullet_meta.base_damage = float(bolt_config.get("damage", 15.0))
	bullet_meta.crit_chance = float(bolt_config.get("crit_chance", 0.0))
	bullet_meta.crit_damage = float(bolt_config.get("crit_damage", 0.0))
	bullet_meta.size_mult = float(bolt_config.get("size_mult", 1.0))
	bullet_meta.spawn_origin = fire_origin
	if is_instance_valid(follow_source) and follow_source.has_node("StatsComponent"):
		bullet_meta.set_stats_component(follow_source.get_node("StatsComponent"))
	data.bullets_custom_data = bullet_meta

	factory_ref.factory.spawn_directional_bullets(data)


func cleanup() -> void:
	pass
