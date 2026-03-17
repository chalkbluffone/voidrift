class_name TimmyGunSpawner

## Spawner for the Timmy Gun burst-fire machine gun.
## 4-arg spawn signature: (pos, direction, params, follow_source).
## Fires a burst of neon rounds using BlastBullets2D with retargeting.
## Bounce chains are handled by BulletFactoryRef collision routing.

var _parent_node: Node
var _texture: Texture2D = null


func _init(parent: Node) -> void:
	_parent_node = parent
	_texture = ResourceLoader.load("res://assets/lasers/laser_circle_magenta.png") as Texture2D


## Spawn a Timmy Gun burst via BB2D.
## Returns null — BB2D manages all bullet lifecycle.
func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	var factory_ref: Node = _parent_node.get_node_or_null("/root/BulletFactoryRef")
	if not factory_ref or not factory_ref.factory:
		return null

	var nearest: Node2D = EffectUtils.find_nearest_enemy(_parent_node.get_tree(), spawn_pos)
	if nearest == null:
		return null
	direction = (nearest.global_position - spawn_pos).normalized()

	# Extract params
	var burst_count: int = maxi(1, int(params.get("projectile_count", 5)))
	var burst_interval: float = float(params.get("burst_interval", 0.06))
	var projectile_speed: float = float(params.get("projectile_speed", 420.0))
	var lifetime: float = float(params.get("lifetime", 1.5))
	var damage_val: float = float(params.get("damage", 4.0))
	var size_mult: float = float(params.get("size_mult", 1.0))
	var crit_chance: float = float(params.get("crit_chance", 0.0))
	var crit_damage: float = float(params.get("crit_damage", 0.0))
	var bounce_count: int = maxi(0, int(params.get("projectile_bounces", 1)))
	var bounce_range: float = float(params.get("bounce_range", 400.0))
	var spread_angle_deg: float = float(params.get("spread_angle_deg", 4.0))

	var game_seed: Node = _parent_node.get_node("/root/GameSeed")
	var rng: RandomNumberGenerator = game_seed.rng("timmy_gun")

	# Build bolt config dict for reuse across burst ticks and bounce spawns
	# Native texture size: 180×184 px
	var bolt_config: Dictionary = {
		"damage": damage_val,
		"projectile_speed": projectile_speed,
		"lifetime": lifetime,
		"size_mult": size_mult,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
		"bounce_count": bounce_count,
		"bounce_range": bounce_range,
		"spread_angle_deg": spread_angle_deg,
		"texture_size": Vector2(33.75, 34.5) * size_mult,
		"collision_shape_size": Vector2(6.0, 6.0) * size_mult,
	}

	# Fire first bolt immediately
	_fire_bolt(follow_source, direction, bolt_config, factory_ref, rng)

	# Schedule remaining burst bolts with SceneTreeTimers (retargeting each tick)
	for i: int in range(1, burst_count):
		var delay: float = burst_interval * float(i)
		var timer: SceneTreeTimer = _parent_node.get_tree().create_timer(delay, false)
		timer.timeout.connect(
			_fire_bolt_retarget.bind(follow_source, bolt_config, factory_ref, rng),
			CONNECT_ONE_SHOT
		)

	return null


## Fire a burst bolt, re-targeting the nearest enemy from the ship's current position.
func _fire_bolt_retarget(
	follow_source: Node2D,
	bolt_config: Dictionary,
	factory_ref: Node,
	rng: RandomNumberGenerator
) -> void:
	if not is_instance_valid(follow_source):
		return
	if not factory_ref or not factory_ref.factory:
		return

	var pos: Vector2 = follow_source.global_position
	var nearest: Node2D = EffectUtils.find_nearest_enemy(_parent_node.get_tree(), pos)
	if nearest == null:
		return
	var dir: Vector2 = (nearest.global_position - pos).normalized()
	_fire_bolt(follow_source, dir, bolt_config, factory_ref, rng)


## Spawn a single bullet round via BB2D factory.
func _fire_bolt(
	follow_source: Node2D,
	direction: Vector2,
	bolt_config: Dictionary,
	factory_ref: Node,
	rng: RandomNumberGenerator
) -> void:
	var spawn_pos: Vector2 = follow_source.global_position if is_instance_valid(follow_source) else Vector2.ZERO
	if spawn_pos == Vector2.ZERO:
		return
	var origin: Vector2 = EffectUtils.source_edge_origin(follow_source, direction, spawn_pos)

	# Apply spread jitter for machine-gun feel
	var spread_deg: float = float(bolt_config.get("spread_angle_deg", 4.0))
	var spread_rad: float = rng.randf_range(deg_to_rad(-spread_deg), deg_to_rad(spread_deg))
	var bolt_dir: Vector2 = direction.rotated(spread_rad)
	var angle: float = bolt_dir.angle()

	var speed: float = float(bolt_config.get("projectile_speed", 420.0))
	var lifetime: float = float(bolt_config.get("lifetime", 1.5))
	var tex_size: Vector2 = bolt_config.get("texture_size", Vector2(10, 10))
	var col_size: Vector2 = bolt_config.get("collision_shape_size", Vector2(6, 6))

	# Build BB2D directional data
	var data: Object = ClassDB.instantiate(&"DirectionalBulletsData2D")
	data.textures = [_texture]
	data.texture_size = tex_size
	data.collision_shape_size = col_size
	data.set_collision_layer_from_array([3])
	data.set_collision_mask_from_array([4])
	data.monitorable = true
	data.max_life_time = lifetime
	data.transforms = [Transform2D(angle, origin)]

	var spd_data: Object = ClassDB.instantiate(&"BulletSpeedData2D")
	spd_data.speed = speed
	spd_data.max_speed = speed
	data.all_bullet_speed_data = [spd_data]

	# Attach weapon metadata for collision handler
	var bullet_meta: WeaponBulletData = WeaponBulletData.new()
	bullet_meta.weapon_id = "timmy_gun"
	bullet_meta.base_damage = float(bolt_config.get("damage", 4.0))
	bullet_meta.crit_chance = float(bolt_config.get("crit_chance", 0.0))
	bullet_meta.crit_damage = float(bolt_config.get("crit_damage", 0.0))
	bullet_meta.bounces_remaining = int(bolt_config.get("bounce_count", 1))
	bullet_meta.bounce_range = float(bolt_config.get("bounce_range", 400.0))
	bullet_meta.size_mult = float(bolt_config.get("size_mult", 1.0))
	bullet_meta.spawn_origin = origin
	bullet_meta.extra = {
		"texture": _texture,
		"texture_size": tex_size,
		"collision_shape_size": col_size,
		"projectile_speed": speed,
		"lifetime": lifetime,
	}
	if is_instance_valid(follow_source) and follow_source.has_node("StatsComponent"):
		bullet_meta.set_stats_component(follow_source.get_node("StatsComponent"))
	data.bullets_custom_data = bullet_meta

	factory_ref.factory.spawn_directional_bullets(data)


## Called when weapon is unequipped.
func cleanup() -> void:
	pass
