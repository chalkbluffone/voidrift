extends Node2D
class_name SpaceNukesEffect

@onready var GameManager: Node = get_node_or_null("/root/GameManager")

@export var damage: float = 12.0
@export var projectile_speed: float = 520.0
@export var explosion_radius: float = 96.0
@export var lifetime: float = 2.2
@export var turn_rate_deg: float = 420.0
@export var acceleration: float = 1200.0
@export var weave_angle_deg: float = 8.0
@export var weave_frequency: float = 7.0
@export var thrust_flutter: float = 0.08
@export var size_mult: float = 1.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 0.0
@export var projectile_color: Color = Color(1.0, 0.83, 0.34, 1.0)
@export var explosion_color: Color = Color(1.0, 0.54, 0.12, 0.6)

var _missile_visual: _MissileVisual = null
var _missile_pos: Vector2 = Vector2.ZERO
var _missile_dir: Vector2 = Vector2.RIGHT
var _missile_speed: float = 0.0
var _target_node: Node2D = null
var _target_pos: Vector2 = Vector2.ZERO
var _source: Node2D = null
var _stats_component: Node = null
var _elapsed: float = 0.0
var _cleanup_timer: float = 0.0
var _exploded: bool = false
var _weave_seed: float = 0.0
var _weave_sign: float = 1.0


func setup(params: Dictionary) -> SpaceNukesEffect:
	for key in params:
		if key in self:
			set(key, params[key])
	return self


func launch(spawn_pos: Vector2, direction: Vector2, target: Node2D, target_pos: Vector2, source: Node2D = null) -> void:
	_source = source
	_target_node = target
	_target_pos = target_pos
	_missile_pos = spawn_pos
	global_position = spawn_pos

	if _source and _source.has_node("StatsComponent"):
		_stats_component = _source.get_node("StatsComponent")

	_missile_dir = direction.normalized()
	if _missile_dir.is_zero_approx():
		_missile_dir = Vector2.RIGHT
	_missile_speed = projectile_speed * 0.45
	_weave_seed = randf() * TAU
	_weave_sign = -1.0 if randf() < 0.5 else 1.0

	if _missile_visual == null:
		_missile_visual = _MissileVisual.new()
		add_child(_missile_visual)
	_missile_visual.body_color = projectile_color
	_missile_visual.scale = Vector2.ONE * maxf(0.8, size_mult)


func _process(delta: float) -> void:
	if _exploded:
		_cleanup_timer -= delta
		if _cleanup_timer <= 0.0:
			queue_free()
		return

	_elapsed += delta
	_update_target_position()

	# Turn missile toward target with a limited turn rate for true "missile" arc flight.
	var desired_dir: Vector2 = (_target_pos - _missile_pos).normalized()
	if desired_dir.is_zero_approx():
		desired_dir = _missile_dir

	# Add a small sinusoidal steering weave to feel more like a rocket "hunting" the target.
	var dist_to_target: float = _missile_pos.distance_to(_target_pos)
	var proximity_damp: float = clampf(dist_to_target / 220.0, 0.25, 1.0)
	var weave_angle: float = sin((_elapsed * weave_frequency) + _weave_seed)
	weave_angle *= deg_to_rad(weave_angle_deg) * _weave_sign * proximity_damp
	desired_dir = desired_dir.rotated(weave_angle)

	var desired_angle: float = desired_dir.angle()
	var current_angle: float = _missile_dir.angle()
	var delta_angle: float = wrapf(desired_angle - current_angle, -PI, PI)
	var max_turn: float = deg_to_rad(turn_rate_deg) * delta
	var turn_step: float = clampf(delta_angle, -max_turn, max_turn)
	_missile_dir = _missile_dir.rotated(turn_step).normalized()

	# Accelerate into cruise speed plus subtle thrust flutter for organic rocket motion.
	_missile_speed = minf(projectile_speed, _missile_speed + acceleration * delta)
	var flutter: float = 1.0 + (sin((_elapsed * weave_frequency * 0.75) + (_weave_seed * 1.7)) * thrust_flutter)
	var frame_speed: float = _missile_speed * flutter
	_missile_pos += _missile_dir * _missile_speed * delta
	_missile_pos += _missile_dir * (frame_speed - _missile_speed) * delta
	global_position = _missile_pos
	rotation = _missile_dir.angle()

	if _missile_visual:
		_missile_visual.thrust = clampf(_missile_speed / maxf(1.0, projectile_speed), 0.2, 1.0)
		_missile_visual.queue_redraw()

	var trigger_distance: float = maxf(14.0, explosion_radius * size_mult * 0.12)
	if _missile_pos.distance_to(_target_pos) <= trigger_distance:
		_explode(_missile_pos)
		return

	if _check_enemy_contact():
		_explode(_missile_pos)
		return

	if _elapsed >= lifetime:
		_explode(_missile_pos)


func _update_target_position() -> void:
	if is_instance_valid(_target_node):
		_target_pos = _target_node.global_position
		return

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy_any in enemies:
		if not enemy_any is Node2D or not is_instance_valid(enemy_any):
			continue
		var enemy: Node2D = enemy_any as Node2D
		var dist: float = _missile_pos.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	if nearest:
		_target_node = nearest
		_target_pos = nearest.global_position


func _check_enemy_contact() -> bool:
	var contact_radius: float = maxf(14.0, 12.0 * size_mult)
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_any in enemies:
		if not enemy_any is Node2D or not is_instance_valid(enemy_any):
			continue
		var enemy: Node2D = enemy_any as Node2D
		if _missile_pos.distance_to(enemy.global_position) <= contact_radius:
			return true
	return false


func _explode(origin: Vector2) -> void:
	if _exploded:
		return
	_exploded = true
	_cleanup_timer = 0.16

	if _missile_visual and is_instance_valid(_missile_visual):
		_missile_visual.visible = false

	_spawn_explosion_flash(origin)
	_apply_burst_damage(origin)


func _apply_burst_damage(origin: Vector2) -> void:
	var effective_radius: float = explosion_radius * size_mult
	var enemies: Array = get_tree().get_nodes_in_group("enemies")

	for enemy_any in enemies:
		if not enemy_any is Node2D or not is_instance_valid(enemy_any):
			continue

		var enemy: Node2D = enemy_any as Node2D
		if origin.distance_to(enemy.global_position) > effective_radius:
			continue

		var final_damage: float = damage
		if _stats_component and _stats_component.has_method("calculate_damage"):
			var damage_info: Dictionary = _stats_component.calculate_damage(damage, crit_chance, crit_damage)
			final_damage = float(damage_info.get("damage", damage))
			if _stats_component.has_method("roll_lifesteal"):
				_stats_component.roll_lifesteal()

		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage, self)
			if GameManager and GameManager.has_method("record_damage_dealt"):
				GameManager.record_damage_dealt(final_damage)


func _spawn_explosion_flash(origin: Vector2) -> void:
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return

	var flash: _ExplosionFlash = _ExplosionFlash.new()
	flash.global_position = origin
	flash.max_radius = explosion_radius * size_mult
	flash.flash_color = explosion_color
	scene_root.add_child(flash)


class _MissileVisual extends Node2D:
	var body_color: Color = Color(1.0, 0.83, 0.34, 1.0)
	var thrust: float = 0.8

	func _draw() -> void:
		var flame_len: float = lerpf(6.0, 12.0, thrust)
		draw_polygon(
			PackedVector2Array([
				Vector2(-9.0, 0.0),
				Vector2(-14.0 - flame_len, 3.0),
				Vector2(-14.0 - flame_len, -3.0),
			]),
			PackedColorArray([
				Color(1.0, 0.95, 0.65, 0.85),
				Color(1.0, 0.35, 0.1, 0.0),
				Color(1.0, 0.35, 0.1, 0.0),
			])
		)

		draw_polygon(
			PackedVector2Array([
				Vector2(9.0, 0.0),
				Vector2(-9.0, 5.0),
				Vector2(-9.0, -5.0),
			]),
			PackedColorArray([body_color, body_color.darkened(0.2), body_color.darkened(0.2)])
		)

		draw_circle(Vector2(6.0, 0.0), 2.0, Color(1.0, 0.98, 0.75, 0.95))


class _ExplosionFlash extends Node2D:
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
