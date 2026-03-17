class_name PersonalSpaceViolatorSpawner

## Spawner for the Personal Space Violator shotgun weapon.
## 4-arg spawn signature: (pos, direction, params, follow_source).
## Fires a cone burst of neon pellets using BlastBullets2D.

var _parent_node: Node
var _texture: Texture2D = null


func _init(parent: Node) -> void:
	_parent_node = parent
	_texture = ResourceLoader.load("res://assets/lasers/laser_bullet_green.png") as Texture2D


## Spawn a PersonalSpaceViolator shotgun blast via BB2D.
## Returns null (no persistent scene node needed — BB2D handles lifecycle).
func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	var factory_ref: Node = _parent_node.get_node_or_null("/root/BulletFactoryRef")
	if not factory_ref or not factory_ref.factory:
		return null

	# Only fire when there's an actual enemy target
	var nearest: Node2D = EffectUtils.find_nearest_enemy(_parent_node.get_tree(), spawn_pos)
	if nearest == null:
		return null
	direction = (nearest.global_position - spawn_pos).normalized()

	# Extract params from flattened weapon config
	var pellet_count: int = int(params.get("projectile_count", 3))
	var pellet_speed: float = float(params.get("projectile_speed", 600.0))
	var spread_deg: float = float(params.get("spread_degrees", 45.0))
	var lifetime: float = float(params.get("lifetime", 0.8))
	var damage_val: float = float(params.get("damage", 15.0))
	var size_mult: float = float(params.get("size_mult", 1.0))
	var crit_chance: float = float(params.get("crit_chance", 0.0))
	var crit_damage: float = float(params.get("crit_damage", 0.0))
	var falloff_start: float = float(params.get("falloff_start", 80.0))
	var falloff_end: float = float(params.get("falloff_end", 350.0))

	var origin: Vector2 = EffectUtils.source_edge_origin(follow_source, direction, spawn_pos)

	# Seeded RNG for deterministic spread jitter + speed variation
	var game_seed: Node = _parent_node.get_node("/root/GameSeed")
	var rng: RandomNumberGenerator = game_seed.rng("personal_space_violator")

	# Build per-pellet transforms (position + rotation) and speed data
	var base_angle: float = direction.angle()
	var half_spread: float = deg_to_rad(spread_deg) / 2.0
	var transforms: Array[Transform2D] = []
	var speed_data_arr: Array = []

	for i: int in range(pellet_count):
		var t: float = 0.0
		if pellet_count > 1:
			t = float(i) / float(pellet_count - 1)
		var angle: float = base_angle - half_spread + (half_spread * 2.0 * t)
		# Random jitter for organic shotgun feel
		angle += rng.randf_range(-deg_to_rad(3.0), deg_to_rad(3.0))
		var spd: float = pellet_speed * rng.randf_range(0.9, 1.1)

		transforms.append(Transform2D(angle, origin))

		var spd_data: Object = ClassDB.instantiate(&"BulletSpeedData2D")
		spd_data.speed = spd
		spd_data.max_speed = spd
		speed_data_arr.append(spd_data)

	# Build BB2D bullet data
	var data: Object = ClassDB.instantiate(&"DirectionalBulletsData2D")
	data.textures = [_texture]
	# Native texture size: 170×133 px — scaled down for gameplay
	data.texture_size = Vector2(68.85, 53.865) * size_mult
	data.collision_shape_size = Vector2(9.0, 9.0) * size_mult
	data.set_collision_layer_from_array([3])  # Layer 3 = Projectiles (bitmask 4)
	data.set_collision_mask_from_array([4])   # Layer 4 = Enemies (bitmask 8)
	data.monitorable = true
	data.max_life_time = lifetime
	data.transforms = transforms
	data.all_bullet_speed_data = speed_data_arr

	# Attach weapon metadata for collision handler
	var bullet_meta: WeaponBulletData = WeaponBulletData.new()
	bullet_meta.weapon_id = "personal_space_violator"
	bullet_meta.base_damage = damage_val
	bullet_meta.crit_chance = crit_chance
	bullet_meta.crit_damage = crit_damage
	bullet_meta.size_mult = size_mult
	bullet_meta.spawn_origin = origin
	bullet_meta.extra = {
		"falloff_start": falloff_start,
		"falloff_end": falloff_end,
	}
	if follow_source and follow_source.has_node("StatsComponent"):
		bullet_meta.set_stats_component(follow_source.get_node("StatsComponent"))
	data.bullets_custom_data = bullet_meta

	factory_ref.factory.spawn_directional_bullets(data)
	return null


## Called when weapon is unequipped.
func cleanup() -> void:
	pass
