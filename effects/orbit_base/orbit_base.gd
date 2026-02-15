class_name OrbitBase
extends Node2D

## Prototype orbit weapon effect used by PSP-9000.
## Spawns triangle drones that orbit the ship and body-check enemies.

@export var damage: float = 15.0
@export var knockback: float = 280.0
@export var projectile_count: int = 1
@export var projectile_speed: float = 2.2  # radians/second
@export var size: float = 1.0  # weapon size scalar, typically via size_mult
@export var orbit_radius: float = 72.0
@export var drone_size: float = 9.0
@export var hit_cooldown: float = 0.35

var _follow_source: Node2D = null
var _orbit_phase: float = 0.0
var _drones: Array[Node2D] = []
var _enemy_hit_cooldowns: Dictionary = {}  # enemy_id -> remaining cooldown


func _ready() -> void:
	add_to_group("weapon_effect")
	_rebuild_drones()


func _process(delta: float) -> void:
	if _follow_source and is_instance_valid(_follow_source):
		global_position = _follow_source.global_position

	_orbit_phase += projectile_speed * delta
	_update_drone_positions()
	_tick_cooldowns(delta)
	_check_contacts()


func setup(params: Dictionary) -> OrbitBase:
	for key in params:
		if key in self:
			set(key, params[key])

	projectile_count = maxi(1, int(projectile_count))
	size = maxf(0.2, float(size))
	orbit_radius = maxf(24.0, float(orbit_radius))
	drone_size = maxf(4.0, float(drone_size))
	hit_cooldown = maxf(0.05, float(hit_cooldown))

	_rebuild_drones()
	return self


func spawn_at(spawn_pos: Vector2) -> OrbitBase:
	global_position = spawn_pos
	return self


func set_follow_source(source: Node2D) -> void:
	_follow_source = source


func _rebuild_drones() -> void:
	for drone in _drones:
		if is_instance_valid(drone):
			drone.queue_free()
	_drones.clear()

	for i in range(projectile_count):
		var drone := Node2D.new()
		drone.name = "Drone_%d" % i

		var triangle := Polygon2D.new()
		triangle.color = Color(0.65, 0.9, 1.0, 0.95)
		triangle.polygon = PackedVector2Array([
			Vector2(drone_size * 1.2 * size, 0.0),
			Vector2(-drone_size * 0.9 * size, drone_size * 0.7 * size),
			Vector2(-drone_size * 0.9 * size, -drone_size * 0.7 * size),
		])
		drone.add_child(triangle)

		add_child(drone)
		_drones.append(drone)

	_update_drone_positions()


func _update_drone_positions() -> void:
	if _drones.is_empty():
		return

	var count: int = _drones.size()
	var radius: float = orbit_radius * size
	for i in range(count):
		var drone := _drones[i]
		if not is_instance_valid(drone):
			continue
		var angle: float = _orbit_phase + (TAU * float(i) / float(count))
		drone.position = Vector2(cos(angle), sin(angle)) * radius
		drone.rotation = angle


func _tick_cooldowns(delta: float) -> void:
	var expired: Array = []
	for enemy_id in _enemy_hit_cooldowns:
		_enemy_hit_cooldowns[enemy_id] -= delta
		if _enemy_hit_cooldowns[enemy_id] <= 0.0:
			expired.append(enemy_id)
	for enemy_id in expired:
		_enemy_hit_cooldowns.erase(enemy_id)


func _check_contacts() -> void:
	if _drones.is_empty():
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	var contact_radius: float = maxf(8.0, drone_size * size * 1.2)

	for enemy in enemies:
		if not (enemy is Node2D) or not is_instance_valid(enemy):
			continue

		var enemy_2d := enemy as Node2D
		var enemy_id := enemy_2d.get_instance_id()
		if _enemy_hit_cooldowns.has(enemy_id):
			continue

		var hit: bool = false
		for drone in _drones:
			if not is_instance_valid(drone):
				continue
			var drone_world_pos: Vector2 = global_position + drone.position
			if drone_world_pos.distance_to(enemy_2d.global_position) <= contact_radius + 20.0:
				hit = true
				var push_dir: Vector2 = (enemy_2d.global_position - global_position).normalized()
				if push_dir == Vector2.ZERO:
					push_dir = Vector2.RIGHT
				_apply_hit(enemy_2d, push_dir)
				break

		if hit:
			_enemy_hit_cooldowns[enemy_id] = hit_cooldown


func _apply_hit(enemy: Node2D, push_dir: Vector2) -> void:
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, self)
	elif enemy.get_parent() and enemy.get_parent().has_method("take_damage"):
		enemy.get_parent().take_damage(damage, self)

	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(push_dir * knockback)
