extends Node2D

## Spin Cycle weapon effect.
## Draws a visible circle around the player with a bright 36° wedge (10% slice)
## that smoothly rotates clockwise, dealing tick damage to enemies inside the slice.

@export var damage: float = 8.0
@export var base_radius: float = 150.0
@export var size: float = 1.0
@export var rotation_speed: float = 3.14159  # radians/sec — TAU/2 ≈ 2s per revolution
@export var attack_speed: float = 1.0  # multiplier on rotation_speed from upgrades
@export var hit_cooldown: float = 0.25
@export var slice_fraction: float = 0.10  # 10% of circle = 36°

@export var ring_color: Color = Color(1.0, 1.0, 1.0, 0.15)
@export var wedge_color: Color = Color(0.4, 0.8, 1.0, 0.5)

var _follow_source: Node2D = null
var _sweep_angle: float = 0.0  # current leading edge of the slice in radians
var _enemy_hit_cooldowns: Dictionary = {}  # enemy_instance_id -> remaining cooldown
var _slice_angle: float = 0.0  # cached: slice_fraction * TAU

const ARC_POINT_COUNT: int = 24  # points used to draw the wedge arc


func _ready() -> void:
	add_to_group("weapon_effect")
	_slice_angle = slice_fraction * TAU


func setup(params: Dictionary) -> void:
	# Consume size_mult as our size multiplier instead of the generic area
	# weapon "size" key (which is a pixel radius for other area weapons).
	if params.has("size_mult"):
		size = maxf(0.1, float(params["size_mult"]))

	for key in params:
		# Skip "size" and "size_mult" — size_mult is handled above and
		# the generic area-weapon "size" is a pixel radius, not our multiplier.
		if key == "size" or key == "size_mult":
			continue
		if key in self:
			var value: Variant = params[key]
			# Handle Color properties that arrive as Color objects from the flattener
			if (key == "ring_color" or key == "wedge_color") and value is Color:
				set(key, value)
			elif (key == "ring_color" or key == "wedge_color") and value is String:
				set(key, Color.from_string(value, get(key)))
			else:
				set(key, value)

	base_radius = maxf(20.0, base_radius)
	size = maxf(0.1, size)
	rotation_speed = maxf(0.1, rotation_speed)
	attack_speed = maxf(0.05, attack_speed)
	hit_cooldown = maxf(0.05, hit_cooldown)
	slice_fraction = clampf(slice_fraction, 0.01, 1.0)
	_slice_angle = slice_fraction * TAU


func spawn_at(spawn_pos: Vector2) -> void:
	global_position = spawn_pos


func set_follow_source(source: Node2D) -> void:
	_follow_source = source


func _process(delta: float) -> void:
	# Follow the player
	if _follow_source:
		if is_instance_valid(_follow_source):
			global_position = _follow_source.global_position
		else:
			queue_free()
			return

	# Advance the sweep angle clockwise (positive = clockwise in Godot's Y-down coords)
	_sweep_angle += rotation_speed * attack_speed * delta
	if _sweep_angle >= TAU:
		_sweep_angle -= TAU

	# Tick per-enemy hit cooldowns
	_tick_cooldowns(delta)

	# Deal damage to enemies inside the slice
	_check_slice_damage()

	# Redraw visuals every frame
	queue_redraw()


func _draw() -> void:
	var radius: float = base_radius * size

	# --- Faint ring outline (full circle) ---
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, ring_color, 1.5, true)

	# --- Bright filled wedge for the active slice ---
	var wedge_start: float = _sweep_angle
	var wedge_end: float = _sweep_angle + _slice_angle
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)  # center of the pie

	for i in range(ARC_POINT_COUNT + 1):
		var t: float = float(i) / float(ARC_POINT_COUNT)
		var angle: float = wedge_start + t * _slice_angle
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	var colors: PackedColorArray = PackedColorArray()
	for i in range(points.size()):
		colors.append(wedge_color)

	draw_polygon(points, colors)

	# --- Bright arc edge on the wedge ---
	var edge_color: Color = Color(wedge_color.r, wedge_color.g, wedge_color.b, minf(wedge_color.a * 2.0, 1.0))
	draw_arc(Vector2.ZERO, radius, wedge_start, wedge_end, ARC_POINT_COUNT, edge_color, 2.0, true)


func _tick_cooldowns(delta: float) -> void:
	var expired: Array = []
	for enemy_id in _enemy_hit_cooldowns:
		_enemy_hit_cooldowns[enemy_id] -= delta
		if _enemy_hit_cooldowns[enemy_id] <= 0.0:
			expired.append(enemy_id)
	for enemy_id in expired:
		_enemy_hit_cooldowns.erase(enemy_id)


func _check_slice_damage() -> void:
	var radius: float = base_radius * size
	var enemies: Array = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not (enemy is Node2D) or not is_instance_valid(enemy):
			continue

		var enemy_2d: Node2D = enemy as Node2D
		var enemy_id: int = enemy_2d.get_instance_id()

		# Skip if on cooldown
		if _enemy_hit_cooldowns.has(enemy_id):
			continue

		# Distance check
		var offset: Vector2 = enemy_2d.global_position - global_position
		var dist: float = offset.length()
		if dist > radius:
			continue

		# Angle check — is the enemy inside the active slice?
		if _is_angle_in_slice(offset):
			_apply_damage(enemy_2d)
			_enemy_hit_cooldowns[enemy_id] = hit_cooldown


func _is_angle_in_slice(offset: Vector2) -> bool:
	## Returns true if the direction vector falls within the active wedge arc.
	var enemy_angle: float = atan2(offset.y, offset.x)
	if enemy_angle < 0.0:
		enemy_angle += TAU

	var sweep_start: float = fmod(_sweep_angle, TAU)
	if sweep_start < 0.0:
		sweep_start += TAU

	# Compute angular distance from sweep_start to enemy_angle (clockwise)
	var delta_angle: float = enemy_angle - sweep_start
	if delta_angle < 0.0:
		delta_angle += TAU

	return delta_angle <= _slice_angle


func _apply_damage(enemy: Node2D) -> void:
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, self)
	elif enemy.get_parent() and enemy.get_parent().has_method("take_damage"):
		enemy.get_parent().take_damage(damage, self)
