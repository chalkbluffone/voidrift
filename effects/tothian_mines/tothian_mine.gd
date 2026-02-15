extends Node2D
class_name TothianMine

@onready var GameManager: Node = get_node_or_null("/root/GameManager")

@export var damage: float = 15.0
@export var duration: float = 3.0
@export var size: float = 92.0
@export var trigger_radius: float = 52.0
@export var mine_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var explosion_color: Color = Color(1.0, 0.5, 0.2, 0.6)
@export var pulse_speed: float = 5.0
@export var pulse_depth: float = 0.22
@export var detonation_sfx: AudioStream

var _life_remaining: float = 0.0
var _exploded: bool = false
var _area: Area2D = null
var _collision: CollisionShape2D = null
var _base_size: float = 0.0
var _pulse_t: float = 0.0


func _ready() -> void:
	_life_remaining = maxf(0.15, duration)
	_base_size = maxf(8.0, size)
	_create_trigger_area()
	_update_trigger_shape()
	queue_redraw()


func setup(params: Dictionary) -> void:
	for key in params:
		if key in self:
			set(key, params[key])

	duration = maxf(0.15, duration)
	size = maxf(8.0, size)
	trigger_radius = maxf(8.0, trigger_radius)
	_base_size = size
	_life_remaining = duration
	_update_trigger_shape()


func spawn_at(spawn_pos: Vector2) -> void:
	global_position = spawn_pos


func _process(delta: float) -> void:
	if _exploded:
		return

	_life_remaining -= delta
	if _life_remaining <= 0.0:
		queue_free()
		return

	_pulse_t += delta * pulse_speed
	queue_redraw()
	_check_overlap_proximity()


func _draw() -> void:
	if _exploded:
		return

	var pulse: float = 1.0 + (sin(_pulse_t) * pulse_depth)
	var body_radius: float = _base_size * 0.12 * pulse
	var ring_radius: float = trigger_radius

	draw_circle(Vector2.ZERO, ring_radius, Color(mine_color.r, mine_color.g, mine_color.b, 0.18))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, Color(mine_color.r, mine_color.g, mine_color.b, 0.9), 2.5)
	draw_circle(Vector2.ZERO, body_radius, mine_color)
	draw_circle(Vector2.ZERO, body_radius * 0.45, Color(1.0, 0.92, 0.85, 0.9))


func _create_trigger_area() -> void:
	if _area:
		return

	_area = Area2D.new()
	_area.collision_layer = 4
	_area.collision_mask = 8
	_area.monitoring = true
	_area.monitorable = true
	add_child(_area)

	_collision = CollisionShape2D.new()
	_collision.shape = CircleShape2D.new()
	_area.add_child(_collision)

	_area.area_entered.connect(_on_area_entered)
	_area.body_entered.connect(_on_body_entered)


func _update_trigger_shape() -> void:
	if _collision and _collision.shape is CircleShape2D:
		(_collision.shape as CircleShape2D).radius = trigger_radius


func _check_overlap_proximity() -> void:
	if _area == null or not _area.monitoring:
		return

	for area in _area.get_overlapping_areas():
		var enemy: Node = _extract_enemy_node(area)
		if enemy:
			_explode()
			return

	for body in _area.get_overlapping_bodies():
		var enemy: Node = _extract_enemy_node(body)
		if enemy:
			_explode()
			return


func _on_area_entered(area: Area2D) -> void:
	if _extract_enemy_node(area):
		_explode()


func _on_body_entered(body: Node) -> void:
	if _extract_enemy_node(body):
		_explode()


func _extract_enemy_node(candidate: Node) -> Node:
	if candidate == null or not is_instance_valid(candidate):
		return null
	if candidate.is_in_group("enemies"):
		return candidate
	var parent: Node = candidate.get_parent()
	if parent and parent.is_in_group("enemies"):
		return parent
	return null


func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	_spawn_explosion_flash()
	_apply_aoe_damage()
	_play_detonation_sfx()
	queue_free()


func _apply_aoe_damage() -> void:
	var hit_radius: float = maxf(8.0, size)
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_any in enemies:
		if not enemy_any is Node2D or not is_instance_valid(enemy_any):
			continue

		var enemy: Node2D = enemy_any as Node2D
		if global_position.distance_to(enemy.global_position) > hit_radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, self)
			if GameManager and GameManager.has_method("record_damage_dealt"):
				GameManager.record_damage_dealt(damage)


func _spawn_explosion_flash() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var flash := _MineExplosionFlash.new()
	flash.global_position = global_position
	flash.max_radius = maxf(10.0, size)
	flash.flash_color = explosion_color
	scene_root.add_child(flash)


func _play_detonation_sfx() -> void:
	if detonation_sfx == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var player := AudioStreamPlayer2D.new()
	player.stream = detonation_sfx
	player.global_position = global_position
	scene_root.add_child(player)
	player.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)
	player.play()


class _MineExplosionFlash extends Node2D:
	var max_radius: float = 90.0
	var flash_color: Color = Color(1.0, 0.55, 0.1, 0.6)
	var life: float = 0.16
	var elapsed: float = 0.0

	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t: float = clampf(elapsed / life, 0.0, 1.0)
		var radius: float = max_radius * lerpf(0.30, 1.0, t)
		var alpha: float = (1.0 - t) * flash_color.a
		draw_circle(Vector2.ZERO, radius, Color(flash_color.r, flash_color.g, flash_color.b, alpha))
		draw_circle(Vector2.ZERO, radius * 0.42, Color(1.0, 0.93, 0.76, alpha * 0.8))
