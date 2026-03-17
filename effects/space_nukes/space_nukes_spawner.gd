class_name SpaceNukesSpawner

## Spawner for Space Nukes.
## 4-arg spawn signature: (pos, direction, params, follow_source).
## Fires homing missiles via BlastBullets2D that explode in AoE on contact.
## Explosion damage is handled by BulletFactoryRef collision routing.

var _parent_node: Node
var _rng: RandomNumberGenerator = null
var _launch_arc_min_deg: float
var _launch_arc_max_deg: float
var _base_targeting_radius: float
var _missile_speed_factor: float
var _textures: Array = []


func _init(parent: Node) -> void:
	_parent_node = parent
	var config: Node = _parent_node.get_node("/root/GameConfig")
	_launch_arc_min_deg = config.NUKE_LAUNCH_ARC_MIN_DEG
	_launch_arc_max_deg = config.NUKE_LAUNCH_ARC_MAX_DEG
	_base_targeting_radius = config.NUKE_BASE_TARGETING_RADIUS
	_missile_speed_factor = config.NUKE_MISSILE_SPEED_FACTOR
	var game_seed: Node = _parent_node.get_node_or_null("/root/GameSeed")
	if game_seed and game_seed.has_method("rng"):
		_rng = game_seed.rng("space_nukes_spawner")
	else:
		_rng = RandomNumberGenerator.new()

	# Load 5-frame missile animation
	for i: int in range(1, 6):
		var path: String = "res://assets/missiles/missile_purple_sprite_sheet_%02d.png" % i
		var tex: Texture2D = ResourceLoader.load(path) as Texture2D
		if tex:
			_textures.append(tex)
	if _textures.is_empty():
		var fallback: Texture2D = ResourceLoader.load("res://assets/missiles/missile_purple.png") as Texture2D
		if fallback:
			_textures.append(fallback)


func spawn(
	spawn_pos: Vector2,
	direction: Vector2,
	params: Dictionary = {},
	follow_source: Node2D = null
) -> Node2D:
	var factory_ref: Node = _parent_node.get_node_or_null("/root/BulletFactoryRef")
	if not factory_ref or not factory_ref.factory:
		return null

	var targeting_center: Vector2 = spawn_pos
	if is_instance_valid(follow_source):
		targeting_center = follow_source.global_position

	var size_mult: float = maxf(0.2, float(params.get("size_mult", 1.0)))
	var targeting_radius: float = _base_targeting_radius * size_mult

	var targets: Array[Node2D] = EffectUtils.find_enemies_in_range(
		_parent_node.get_tree(), targeting_center, targeting_radius
	)
	if targets.is_empty():
		return null

	# Extract params
	var rockets_per_volley: int = maxi(1, int(params.get("projectile_count", 3)))
	var rockets_to_fire: int = mini(rockets_per_volley, targets.size())
	var projectile_speed: float = float(params.get("projectile_speed", 520.0))
	var lifetime: float = float(params.get("lifetime", 2.2))
	var damage_val: float = float(params.get("damage", 20.0))
	var crit_chance: float = float(params.get("crit_chance", 0.0))
	var crit_damage: float = float(params.get("crit_damage", 0.0))
	var explosion_radius: float = float(params.get("explosion_radius", 128.0))
	var launch_arc_min_deg: float = float(params.get("launch_arc_min_deg", _launch_arc_min_deg))
	var launch_arc_max_deg: float = float(params.get("launch_arc_max_deg", _launch_arc_max_deg))
	if launch_arc_max_deg < launch_arc_min_deg:
		var swap: float = launch_arc_min_deg
		launch_arc_min_deg = launch_arc_max_deg
		launch_arc_max_deg = swap

	var explosion_color_str: String = str(params.get("explosion_color", "#ff8a1f99"))
	var explosion_color: Color = EffectUtils.parse_color(explosion_color_str, Color(1.0, 0.54, 0.12, 0.6))

	var origin: Vector2 = EffectUtils.source_edge_origin(follow_source, direction, spawn_pos)

	# Build per-missile transforms with arc launch angles
	var transforms: Array[Transform2D] = []
	var speed_data_arr: Array = []
	var target_refs: Array[Node2D] = []

	for i: int in range(rockets_to_fire):
		var target: Node2D = targets[i]
		if not is_instance_valid(target):
			continue

		var travel_dir: Vector2 = (target.global_position - origin).normalized()
		if travel_dir.is_zero_approx():
			travel_dir = direction.normalized()
			if travel_dir.is_zero_approx():
				travel_dir = Vector2.RIGHT

		# Randomized exit arc for natural rocket curve
		var arc_sign: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var arc_radians: float = deg_to_rad(_rng.randf_range(launch_arc_min_deg, launch_arc_max_deg)) * arc_sign
		var launch_dir: Vector2 = travel_dir.rotated(arc_radians).normalized()
		var angle: float = launch_dir.angle()

		transforms.append(Transform2D(angle, origin))
		target_refs.append(target)

		var spd: Object = ClassDB.instantiate(&"BulletSpeedData2D")
		spd.speed = projectile_speed * _missile_speed_factor
		spd.max_speed = projectile_speed * 2.0
		spd.acceleration = 600.0
		speed_data_arr.append(spd)

	if transforms.is_empty():
		return null

	# Build BB2D directional data
	var data: Object = ClassDB.instantiate(&"DirectionalBulletsData2D")
	data.textures = _textures
	data.default_change_texture_time = 0.033  # 30fps animation
	# Native texture size: 24×13 px — scaled up 87.5%
	data.texture_size = Vector2(45.0, 24.375) * size_mult
	data.collision_shape_size = Vector2(26.25, 15.0) * size_mult
	data.set_collision_layer_from_array([3])
	data.set_collision_mask_from_array([4])
	data.monitorable = true
	data.max_life_time = lifetime
	data.transforms = transforms
	data.all_bullet_speed_data = speed_data_arr

	# Attach weapon metadata
	var bullet_meta: WeaponBulletData = WeaponBulletData.new()
	bullet_meta.weapon_id = "space_nukes"
	bullet_meta.base_damage = damage_val
	bullet_meta.crit_chance = crit_chance
	bullet_meta.crit_damage = crit_damage
	bullet_meta.size_mult = size_mult
	bullet_meta.spawn_origin = origin
	bullet_meta.extra = {
		"explosion_radius": explosion_radius,
		"explosion_color": explosion_color,
	}
	if is_instance_valid(follow_source) and follow_source.has_node("StatsComponent"):
		bullet_meta.set_stats_component(follow_source.get_node("StatsComponent"))
	data.bullets_custom_data = bullet_meta

	# Spawn as controllable for homing
	var multimesh: Object = factory_ref.factory.spawn_controllable_directional_bullets(data)
	if multimesh:
		# Configure homing
		multimesh.homing_smoothing = 3.5
		multimesh.homing_update_interval = 0.0
		multimesh.homing_take_control_of_texture_rotation = true
		multimesh.homing_distance_before_reached = maxf(14.0, explosion_radius * size_mult * 0.12)
		multimesh.bullet_homing_auto_pop_after_target_reached = false

		# Set per-bullet homing targets
		for i: int in range(target_refs.size()):
			if is_instance_valid(target_refs[i]):
				multimesh.bullet_homing_push_back_node2d_target(i, target_refs[i])

	return null


func cleanup() -> void:
	pass
