class_name NopeBubble
extends Node2D

## Nope Bubble — A persistent shield that surrounds the player ship.
## Absorbs incoming damage by consuming layers. Each layer pop triggers knockback
## on the attacker and emits a cone-shaped shockwave that damages nearby enemies.
## Normal enemies are fully blocked; bosses cause a "weak block" (reduced damage).
## Layers regenerate one per cooldown tick (managed by the spawner).
## Visual: translucent sphere with opacity tied to remaining layers.
## At 5+ max layers, a numeric counter is displayed.

# --- Exported / Setup params (set via setup() from flat config) ---
@export var damage: float = 10.0
@export var knockback: float = 600.0
@export var projectile_count: int = 2  # Max layers
@export var size: float = 80.0  # Shield radius
@export var shockwave_range: float = 200.0
@export var shockwave_angle_deg: float = 45.0
@export var boss_damage_reduction: float = 0.5
@export var particle_count: int = 48
@export var ambient_particle_count: int = 24
@export var color: Color = Color(0.65, 0.2, 1.0, 0.75)
@export var cooldown: float = 3.0  # Used for display only; spawner handles regen timing

# --- Internal state ---
var _current_layers: int = 2
var _max_layers: int = 2
var _follow_source: Node2D = null
var _shield_mesh: MeshInstance2D = null
var _shield_area: Area2D = null
var _shield_collision: CollisionShape2D = null
var _layer_label: Label = null
var _shader_material: ShaderMaterial = null
var _hit_flash_timer: float = 0.0
var _hit_flash_duration: float = 0.15

# --- Regen timer (self-managed, independent of weapon component cooldown) ---
var _regen_timer: float = 0.0
var _regen_active: bool = false

# --- Ambient flow particles ---
var _ambient_particles: CPUParticles2D = null
var _ambient_time: float = 0.0

# --- Swirl particles (orbit the shell edge) ---
var _swirl_particles: CPUParticles2D = null

# --- Shockwave tracking ---
var _active_shockwaves: Array[Node2D] = []
var _was_down: bool = false  # Track if shield was already down to avoid repeat break particles

# --- Per-enemy hit cooldown to prevent rapid re-triggers ---
var _enemy_hit_cooldowns: Dictionary = {}  # enemy instance_id -> remaining cooldown
const BUBBLE_HIT_COOLDOWN: float = 0.5  # Seconds before same enemy can trigger again


func _ready() -> void:
	add_to_group("nope_bubble")


func setup(params: Dictionary) -> void:
	for key in params:
		if key in self:
			set(key, params[key])
	# Ensure max layers matches projectile_count
	var old_max: int = _max_layers
	_max_layers = projectile_count
	if old_max == 0:
		# First-time init
		_current_layers = _max_layers
	else:
		# Live update: clamp current layers to new max, don't reset
		_current_layers = mini(_current_layers, _max_layers)
	# Always apply visual changes so live updates take effect immediately
	_update_visuals()


func spawn_at(pos: Vector2) -> void:
	global_position = pos
	_current_layers = _max_layers
	_create_visuals()
	_update_visuals()


func set_follow_source(source: Node2D) -> void:
	_follow_source = source


func add_layer() -> void:
	if _current_layers < _max_layers:
		_current_layers += 1
		_update_visuals()


## Damage interceptor callback — registered on the Ship.
## Now only handles boss damage reduction — layer consumption and knockback
## are handled by _handle_bubble_collision via Area2D/overlap detection.
func intercept_damage(amount: float, source: Node) -> float:
	if _current_layers <= 0:
		return amount  # Shield is down, damage passes through
	
	# The bubble blocked this hit — don't consume a layer here
	# (already consumed by _handle_bubble_collision)
	
	# Determine block type
	var is_boss: bool = false
	if source and "enemy_type" in source:
		is_boss = source.enemy_type == "boss"
	
	# Return damage: 0 for full block, reduced for boss
	if is_boss:
		return amount * boss_damage_reduction
	else:
		return 0.0


func _process(delta: float) -> void:
	# Follow the ship
	if _follow_source and is_instance_valid(_follow_source):
		global_position = _follow_source.global_position
	
	# Hit flash fade
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			_hit_flash_timer = 0.0
	
	# Update shader pulse
	if _shader_material:
		var pulse: float = _hit_flash_timer / _hit_flash_duration if _hit_flash_duration > 0 else 0.0
		_shader_material.set_shader_parameter("pulse", pulse)
	
	# Self-managed layer regen timer
	if _regen_active and _current_layers < _max_layers:
		_regen_timer -= delta
		if _regen_timer <= 0.0:
			add_layer()
			if _current_layers < _max_layers:
				_regen_timer = cooldown  # Reset for next layer
			else:
				_regen_active = false  # Fully recharged
	
	# Animate ambient flow particles — slow orbit rotation
	_ambient_time += delta
	if _ambient_particles and _ambient_particles.visible:
		# Rotate the emission direction to create a swirling flow
		var orbit_speed: float = 0.6  # Radians per second
		var angle: float = _ambient_time * orbit_speed
		_ambient_particles.direction = Vector2(cos(angle), sin(angle))
		# Breathing effect for ambient particles
		var breath: float = 0.5 + 0.5 * sin(_ambient_time * 1.8)
		_ambient_particles.modulate.a = clampf(0.3 + breath * 0.4, 0.1, 0.8)

	# Animate swirl particles — fast orbit around the shell edge
	if _swirl_particles and _swirl_particles.visible:
		var swirl_speed: float = 2.5  # Radians per second (fast orbit)
		var swirl_angle: float = -_ambient_time * swirl_speed  # Negative = clockwise
		# Tangential direction for clockwise orbital motion
		_swirl_particles.direction = Vector2(-sin(swirl_angle), cos(swirl_angle))

	# Clean up finished shockwaves
	_active_shockwaves = _active_shockwaves.filter(func(sw): return is_instance_valid(sw))
	
	# Tick per-enemy hit cooldowns
	var expired_keys: Array = []
	for eid in _enemy_hit_cooldowns:
		_enemy_hit_cooldowns[eid] -= delta
		if _enemy_hit_cooldowns[eid] <= 0.0:
			expired_keys.append(eid)
	for eid in expired_keys:
		_enemy_hit_cooldowns.erase(eid)
	
	# Periodic overlap check: catch enemies that are inside the bubble
	# (body_entered only fires once per entry, so we need this for persistent enemies)
	# Also do direct distance check against all enemies as a reliable fallback
	if _current_layers > 0:
		var bubble_radius: float = size * 1.3
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy is Node2D and is_instance_valid(enemy):
				var dist: float = global_position.distance_to(enemy.global_position)
				if dist < bubble_radius + 22.0:  # 22 = enemy collision radius
					_handle_bubble_collision(enemy)
					# Continuously push enemies away (not just on first contact)
					if enemy.has_method("apply_knockback"):
						var push_dir: Vector2 = (enemy.global_position - global_position).normalized()
						if push_dir == Vector2.ZERO:
							push_dir = Vector2.RIGHT
						enemy.apply_knockback(push_dir * knockback * delta * 10.0)


func _create_visuals() -> void:
	# --- Shield mesh (circle) ---
	_shield_mesh = MeshInstance2D.new()
	var circle_mesh: QuadMesh = QuadMesh.new()
	circle_mesh.size = Vector2(size * 2.6, size * 2.6)  # Ring at UV 0.82 fills most of the quad
	_shield_mesh.mesh = circle_mesh
	
	# Load and apply shader
	var shader: Shader = load("res://effects/nope_bubble/nope_bubble.gdshader")
	if shader:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = shader
		# Pass color directly — user controls transparency via color alpha
		_shader_material.set_shader_parameter("shield_color", color)
		_shader_material.set_shader_parameter("opacity", 1.0)
		_shader_material.set_shader_parameter("pulse", 0.0)
		_shield_mesh.material = _shader_material
	else:
		push_warning("NopeBubble: Could not load shader, using fallback color")
		# Fallback: tint the mesh directly
		_shield_mesh.modulate = Color(color.r, color.g, color.b, 0.3)
	
	_shield_mesh.z_index = 0
	add_child(_shield_mesh)
	
	# --- Layer counter label (roman numerals, near ship) ---
	_layer_label = Label.new()
	_layer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_layer_label.position = Vector2(20, -35)  # 2 o'clock position relative to ship
	_layer_label.add_theme_font_size_override("font_size", 16)
	_layer_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0, 0.95))
	_layer_label.visible = true
	add_child(_layer_label)

	# --- Shield collision area (for detecting enemies entering bubble) ---
	_shield_area = Area2D.new()
	_shield_area.collision_layer = 0
	_shield_area.collision_mask = 8
	_shield_area.monitoring = true
	_shield_area.monitorable = true
	_shield_area.name = "ShieldCollision"
	_shield_collision = CollisionShape2D.new()
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = size * 1.3
	_shield_collision.shape = circle_shape
	_shield_area.add_child(_shield_collision)
	add_child(_shield_area)

	# When an enemy enters the bubble, trigger collision handling
	_shield_area.area_entered.connect(_on_enemy_entered_bubble)
	_shield_area.body_entered.connect(_on_enemy_body_entered_bubble)

	# --- Ambient flow particles (persistent swirling motes inside the bubble) ---
	var swirl_radius: float = size * 1.05
	_ambient_particles = EffectUtils.create_cpu_particles(self, {
		"emitting": true,
		"one_shot": false,
		"amount": ambient_particle_count,
		"lifetime": 2.5,
		"explosiveness": 0.0,
		"randomness": 0.4,
		"emission_shape": CPUParticles2D.EMISSION_SHAPE_RING,
		"emission_ring_radius": size * 0.85,
		"emission_ring_inner_radius": size * 0.2,
		"direction": Vector2(1, 0),
		"spread": 90.0,
		"initial_velocity_min": 8.0,
		"initial_velocity_max": 25.0,
		"gravity": Vector2.ZERO,
		"damping_min": 5.0,
		"damping_max": 15.0,
		"scale_amount_min": 0.8,
		"scale_amount_max": 1.8,
		"color_ramp": EffectUtils.make_gradient([
			[0.0, Color(0.0, 0.8, 0.9, 0.0)],
			[0.3, Color(0.6, 0.1, 0.95, 0.7)],
			[0.7, Color(0.85, 0.1, 0.5, 0.5)],
			[1.0, Color(0.3, 0.7, 1.0, 0.0)],
		]),
		"color_initial_ramp": EffectUtils.make_gradient([
			[0.0, Color(0.0, 0.9, 0.9, 1.0)],
			[0.33, Color(0.74, 0.07, 0.99, 1.0)],
			[0.66, Color(1.0, 0.08, 0.58, 1.0)],
			[1.0, Color(0.49, 0.98, 1.0, 1.0)],
		]),
		"z_index": 1,
	})

	# --- Swirl particles (tiny 1px motes orbiting tightly around the shell edge) ---
	_swirl_particles = EffectUtils.create_cpu_particles(self, {
		"emitting": true,
		"one_shot": false,
		"amount": 40,
		"lifetime": 3.0,
		"explosiveness": 0.0,
		"randomness": 0.2,
		"emission_shape": CPUParticles2D.EMISSION_SHAPE_RING,
		"emission_ring_radius": swirl_radius,
		"emission_ring_inner_radius": swirl_radius * 0.98,
		"direction": Vector2(1, 0),
		"spread": 15.0,
		"initial_velocity_min": 30.0,
		"initial_velocity_max": 55.0,
		"gravity": Vector2.ZERO,
		"damping_min": 2.0,
		"damping_max": 8.0,
		"scale_amount_min": 0.4,
		"scale_amount_max": 0.8,
		"color_ramp": EffectUtils.make_gradient([
			[0.0, Color(0.8, 0.5, 1.0, 0.0)],
			[0.2, Color(0.9, 0.7, 1.0, 0.9)],
			[0.8, Color(0.6, 0.2, 0.95, 0.6)],
			[1.0, Color(0.4, 0.1, 0.8, 0.0)],
		]),
		"z_index": 2,
	})


func _update_visuals() -> void:
	if not _shield_mesh:
		return
	
	var is_down: bool = _current_layers <= 0
	
	# Hide everything when shield is depleted
	_shield_mesh.visible = not is_down
	if _shield_area:
		_shield_collision.set_deferred("disabled", is_down)
	if _layer_label:
		_layer_label.visible = not is_down
	if _ambient_particles:
		_ambient_particles.visible = not is_down
		_ambient_particles.emitting = not is_down
	if _swirl_particles:
		_swirl_particles.visible = not is_down
		_swirl_particles.emitting = not is_down
	
	if is_down:
		if not _was_down:
			_was_down = true
			_spawn_break_particles()
		return
	
	_was_down = false
	
	if _shader_material:
		_shader_material.set_shader_parameter("opacity", 1.0)
		_shader_material.set_shader_parameter("shield_color", color)
	else:
		# Fallback for no shader — modulate the mesh directly
		_shield_mesh.modulate = Color(color.r, color.g, color.b, color.a * 0.4)
	
	# Update layer counter text (roman numerals)
	if _layer_label:
		_layer_label.text = _to_roman(_current_layers)
	
	# Update mesh size in case size param changed
	if _shield_mesh and _shield_mesh.mesh:
		(_shield_mesh.mesh as QuadMesh).size = Vector2(size * 2.6, size * 2.6)
	
	# Update collision radius to match bubble size
	if _shield_collision and _shield_collision.shape:
		(_shield_collision.shape as CircleShape2D).radius = size * 1.3

	# Update ambient particle emission to match bubble size and count
	if _ambient_particles:
		if _ambient_particles.amount != ambient_particle_count:
			_ambient_particles.emitting = false
			_ambient_particles.amount = ambient_particle_count
			_ambient_particles.emitting = true
		_ambient_particles.emission_ring_radius = size * 0.85
		_ambient_particles.emission_ring_inner_radius = size * 0.2

	# Update swirl particle ring to match bubble size
	if _swirl_particles:
		var swirl_r: float = size * 1.05
		_swirl_particles.emission_ring_radius = swirl_r
		_swirl_particles.emission_ring_inner_radius = swirl_r * 0.98


## Enemy Area2D entered the shield bubble
func _on_enemy_entered_bubble(area: Area2D) -> void:
	# area is the child Area2D (HitboxArea), NOT the BaseEnemy parent
	var enemy: Node = area.get_parent() if area.get_parent() else area
	_handle_bubble_collision(enemy)


## Enemy PhysicsBody entered the shield bubble
func _on_enemy_body_entered_bubble(body: Node2D) -> void:
	_handle_bubble_collision(body)


## Core collision handler — directly applies knockback and consumes a layer
## instead of routing through ship.take_damage (which has i-frames / timing issues).
func _handle_bubble_collision(enemy: Node) -> void:
	if _current_layers <= 0:
		return
	if not (enemy.is_in_group("enemies") or "enemy_type" in enemy):
		return
	
	# Per-enemy cooldown to prevent rapid re-triggers from overlap checks
	var eid: int = enemy.get_instance_id()
	if _enemy_hit_cooldowns.has(eid):
		return
	_enemy_hit_cooldowns[eid] = BUBBLE_HIT_COOLDOWN
	
	# Consume a layer
	_current_layers -= 1
	
	# Apply knockback directly to the enemy (no routing through ship.take_damage)
	if enemy is Node2D and enemy.has_method("apply_knockback"):
		var kb_direction: Vector2 = Vector2.ZERO
		if _follow_source:
			kb_direction = (enemy.global_position - _follow_source.global_position).normalized()
		else:
			kb_direction = (enemy.global_position - global_position).normalized()
		enemy.apply_knockback(kb_direction * knockback)
	
	# Spawn shockwave cone toward the attacker (deferred to avoid physics flush conflict)
	if enemy is Node2D:
		call_deferred("_spawn_shockwave", enemy)
	
	# Visual feedback
	_hit_flash_timer = _hit_flash_duration
	if enemy is Node2D:
		_spawn_hit_particles(enemy as Node2D)
	_update_visuals()
	
	# Start regen timer if not already running
	if not _regen_active:
		_regen_active = true
		_regen_timer = cooldown


## Convert integer to Roman numeral string
func _to_roman(num: int) -> String:
	if num <= 0:
		return "0"
	var result: String = ""
	var values: Array[int] = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var symbols: Array[String] = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	for i in range(values.size()):
		while num >= values[i]:
			result += symbols[i]
			num -= values[i]
	return result


## Synthwave color palette for particles
const SYNTHWAVE_COLORS: Array[Color] = [
	Color(0.0, 1.0, 1.0, 1.0),     # Cyan
	Color(1.0, 0.08, 0.58, 1.0),    # Hot pink
	Color(0.49, 0.98, 1.0, 1.0),    # Electric blue
	Color(0.74, 0.07, 0.99, 1.0),   # Neon purple
	Color(1.0, 0.0, 0.4, 1.0),      # Magenta-red
	Color(0.3, 0.0, 0.8, 1.0),      # Deep violet
]


## Spawn a directional burst of particles when a layer is hit (not broken)
func _spawn_hit_particles(source: Node2D) -> void:
	var hit_dir: Vector2 = Vector2.ZERO
	if source:
		hit_dir = (source.global_position - global_position).normalized()
	if hit_dir == Vector2.ZERO:
		hit_dir = Vector2.RIGHT

	var c1: Color = SYNTHWAVE_COLORS[randi() % SYNTHWAVE_COLORS.size()]
	var c2: Color = SYNTHWAVE_COLORS[randi() % SYNTHWAVE_COLORS.size()]

	var particles: CPUParticles2D = EffectUtils.create_cpu_particles(self, {
		"emitting": true,
		"one_shot": true,
		"explosiveness": 0.9,
		"amount": maxi(particle_count / 3, 4),
		"lifetime": 0.4,
		"emission_shape": CPUParticles2D.EMISSION_SHAPE_RING,
		"emission_ring_radius": size * 1.0,
		"emission_ring_inner_radius": size * 0.7,
		"direction": hit_dir,
		"spread": 45.0,
		"initial_velocity_min": 80.0,
		"initial_velocity_max": 200.0,
		"gravity": Vector2.ZERO,
		"damping_min": 100.0,
		"damping_max": 160.0,
		"scale_amount_min": 1.0,
		"scale_amount_max": 2.5,
		"color_ramp": EffectUtils.make_gradient([
			[0.0, c1],
			[1.0, Color(c2.r, c2.g, c2.b, 0.0)],
		]),
		"color_initial_ramp": EffectUtils.make_gradient([
			[0.0, SYNTHWAVE_COLORS[randi() % SYNTHWAVE_COLORS.size()]],
			[1.0, SYNTHWAVE_COLORS[randi() % SYNTHWAVE_COLORS.size()]],
		]),
		"z_index": 1,
	})

	var timer: SceneTreeTimer = get_tree().create_timer(particles.lifetime + 0.1)
	timer.timeout.connect(particles.queue_free)


## Spawn a burst of particles when the shield fully breaks
func _spawn_break_particles() -> void:
	var particles: CPUParticles2D = EffectUtils.create_cpu_particles(self, {
		"emitting": true,
		"one_shot": true,
		"explosiveness": 1.0,
		"amount": particle_count,
		"lifetime": 0.6,
		"emission_shape": CPUParticles2D.EMISSION_SHAPE_RING,
		"emission_ring_radius": size * 1.2,
		"emission_ring_inner_radius": size * 0.8,
		"direction": Vector2(0, -1),
		"spread": 180.0,
		"initial_velocity_min": 60.0,
		"initial_velocity_max": 180.0,
		"gravity": Vector2.ZERO,
		"damping_min": 80.0,
		"damping_max": 120.0,
		"scale_amount_min": 1.0,
		"scale_amount_max": 2.0,
		"color_ramp": EffectUtils.make_gradient([
			[0.0, Color(0.0, 1.0, 1.0, 1.0)],
			[0.25, Color(1.0, 0.08, 0.58, 1.0)],
			[0.5, Color(0.74, 0.07, 0.99, 1.0)],
			[0.75, Color(0.49, 0.98, 1.0, 0.6)],
			[1.0, Color(1.0, 0.0, 0.4, 0.0)],
		]),
		"color_initial_ramp": EffectUtils.make_gradient([
			[0.0, Color(0.0, 1.0, 1.0, 1.0)],
			[0.33, Color(1.0, 0.08, 0.58, 1.0)],
			[0.66, Color(0.74, 0.07, 0.99, 1.0)],
			[1.0, Color(0.49, 0.98, 1.0, 1.0)],
		]),
		"z_index": 1,
	})

	# Auto-cleanup after particles finish
	var timer: SceneTreeTimer = get_tree().create_timer(particles.lifetime + 0.1)
	timer.timeout.connect(particles.queue_free)


func _spawn_shockwave(source: Node2D) -> void:
	# Direction from ship center toward the enemy (shockwave fires outward)
	var origin: Vector2 = global_position
	var direction: Vector2 = (source.global_position - origin).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	
	# Create shockwave container
	var shockwave: Node2D = Node2D.new()
	shockwave.global_position = origin
	shockwave.name = "Shockwave"
	
	# Create hitbox Area2D
	var hitbox: Area2D = Area2D.new()
	hitbox.collision_layer = 4  # Player weapons
	hitbox.collision_mask = 8   # Enemies
	hitbox.name = "ShockwaveHitbox"
	shockwave.add_child(hitbox)
	
	# Build cone collision polygon
	var cone_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
	var half_angle: float = deg_to_rad(shockwave_angle_deg / 2.0)
	var cone_points: PackedVector2Array = PackedVector2Array()
	
	# Cone starts at origin (0,0 in local space), fans out to shockwave_range
	cone_points.append(Vector2.ZERO)
	var segments: int = 8
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = -half_angle + t * half_angle * 2.0
		var point: Vector2 = direction.rotated(angle) * shockwave_range
		cone_points.append(point)
	
	cone_polygon.polygon = cone_points
	hitbox.add_child(cone_polygon)
	
	# Add to parent (world root)
	get_parent().add_child(shockwave)
	_active_shockwaves.append(shockwave)
	
	# Track which enemies have been hit by this shockwave
	var hit_targets: Dictionary = {}
	
	# Connect damage signal
	hitbox.area_entered.connect(func(area: Area2D) -> void:
		_on_shockwave_hit(area, hit_targets)
	)
	hitbox.body_entered.connect(func(body: Node2D) -> void:
		_on_shockwave_body_hit(body, hit_targets)
	)
	
	# Destroy shockwave after brief delay (collision window)
	var tween: Tween = shockwave.create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(shockwave.queue_free)


func _on_shockwave_hit(area: Area2D, hit_targets: Dictionary) -> void:
	var target: Node = area
	# Try area itself, then parent
	if not target.has_method("take_damage") and target.get_parent():
		target = target.get_parent()
	
	if target.has_method("take_damage"):
		var target_id: int = target.get_instance_id()
		if not hit_targets.has(target_id):
			hit_targets[target_id] = true
			target.take_damage(damage)
			# Also apply knockback to shockwave victims
			if target.has_method("apply_knockback") and _follow_source:
				var kb_dir: Vector2 = (target.global_position - _follow_source.global_position).normalized()
				target.apply_knockback(kb_dir * knockback * 0.5)


func _on_shockwave_body_hit(body: Node2D, hit_targets: Dictionary) -> void:
	if body.has_method("take_damage"):
		var target_id: int = body.get_instance_id()
		if not hit_targets.has(target_id):
			hit_targets[target_id] = true
			body.take_damage(damage)
			if body.has_method("apply_knockback") and _follow_source:
				var kb_dir: Vector2 = (body.global_position - _follow_source.global_position).normalized()
				body.apply_knockback(kb_dir * knockback * 0.5)


func get_damage() -> float:
	return damage


func _exit_tree() -> void:
	# Unregister damage interceptor when bubble is destroyed
	if _follow_source and is_instance_valid(_follow_source):
		if _follow_source.has_method("unregister_damage_interceptor"):
			_follow_source.unregister_damage_interceptor(intercept_damage)
	
	# Clean up any active shockwaves
	for sw in _active_shockwaves:
		if is_instance_valid(sw):
			sw.queue_free()
	_active_shockwaves.clear()
