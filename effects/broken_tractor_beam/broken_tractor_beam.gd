extends Node2D
class_name BrokenTractorBeam

## Broken Tractor Beam — locks onto the nearest enemy with a malfunctioning
## tractor beam that irradiates it over time.  Deals a burst on attach, then
## ticks DPS until the target dies or duration expires.  When the target dies
## the beam instantly retargets the next nearest enemy (with another burst).
## Visually rendered as a solid, stiff UFO-style tractor beam that pulls
## enemies toward the ship.

# --- Exported Parameters (Stats) ---
@export var damage: float = 10.0
@export var duration: float = 2.0
@export var cooldown: float = 2.5
@export var dot_interval: float = 0.5
@export var burst_multiplier: float = 2.0

# --- Shape ---
@export var search_radius: float = 300.0  ## Max lock-on / tether range (driven by "size")

# --- Visual ---
@export var color_core: Color = Color(0.53, 0.81, 1.0, 1.0)   # Light cyan
@export var color_glow: Color = Color(0.27, 0.53, 1.0, 1.0)   # Blue
@export var glow_strength: float = 1.5
@export var particle_count: int = 30
@export var particle_speed: float = 200.0
@export var particle_lifetime: float = 0.4
@export var beam_width: float = 12.0

# --- Pull ---
@export var pull_speed: float = 80.0  ## How fast the beam drags enemies toward the ship (px/s)

# --- Internal State ---
var _follow_source: Node2D = null
var _target: Node2D = null
var _elapsed: float = 0.0
var _dot_timer: float = 0.0
var _is_active: bool = false

# Visuals
var _beam_particles: CPUParticles2D = null
var _impact_particles: CPUParticles2D = null
var _beam_line: Line2D = null
var _white_tex: ImageTexture = null


# =============================================================================
# SETUP
# =============================================================================

func setup(params: Dictionary) -> BrokenTractorBeam:
	## Apply flat config dictionary (from WeaponDataFlattener).
	for key: String in params:
		if key in self:
			var value: Variant = params[key]
			# Handle Color values passed as strings
			if get(key) is Color and value is String:
				set(key, EffectUtils.parse_color(String(value), get(key) as Color))
			else:
				set(key, value)
	return self


func load_from_data(data: Dictionary) -> void:
	## Load from nested weapon data dictionary (JSON structure).
	var stats: Dictionary = data.get("stats", {})
	damage = float(stats.get("damage", damage))
	duration = float(stats.get("duration", duration))
	cooldown = float(stats.get("cooldown", cooldown))
	dot_interval = float(stats.get("dot_interval", dot_interval))

	var shape: Dictionary = data.get("shape", {})
	search_radius = float(shape.get("size", search_radius))

	var motion: Dictionary = data.get("motion", {})
	burst_multiplier = float(motion.get("burst_multiplier", burst_multiplier))

	var visual: Dictionary = data.get("visual", {})
	color_core = EffectUtils.parse_color(visual.get("color_core", ""), color_core)
	color_glow = EffectUtils.parse_color(visual.get("color_glow", ""), color_glow)
	glow_strength = float(visual.get("glow_strength", glow_strength))
	particle_count = int(visual.get("particle_count", particle_count))
	particle_speed = float(visual.get("particle_speed", particle_speed))
	particle_lifetime = float(visual.get("particle_lifetime", particle_lifetime))
	beam_width = float(visual.get("beam_width", beam_width))

	pull_speed = float(motion.get("pull_speed", pull_speed))


func set_follow_source(source: Node2D) -> BrokenTractorBeam:
	_follow_source = source
	return self


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	global_position = Vector2.ZERO  # World-space node
	z_index = -1

	# Create a tiny white texture for particles
	_white_tex = EffectUtils.get_white_pixel_texture()


func activate() -> void:
	## Called by the spawner after setup + follow_source are set.
	## Acquires first target and starts the beam.
	_target = _find_nearest_enemy()
	if _target == null:
		FileLogger.log_warn("BrokenTractorBeam", "No target found at activation — fizzling")
		queue_free()
		return

	_is_active = true
	_elapsed = 0.0
	_dot_timer = 0.0

	# Burst damage on initial lock-on
	_apply_burst_damage(_target)

	# Build visuals
	_create_beam_line()
	_create_beam_particles()
	_create_impact_particles()

	FileLogger.log_info("BrokenTractorBeam", "Locked onto target — beam active for %.1fs" % duration)


func _process(delta: float) -> void:
	if not _is_active:
		return

	# Source died — clean up
	if not is_instance_valid(_follow_source):
		_shutdown()
		return

	# Duration expired
	_elapsed += delta
	if _elapsed >= duration:
		_shutdown()
		return

	# Target died — retarget
	if not is_instance_valid(_target):
		_retarget()
		if not _is_active:
			return

	# Target moved out of range — retarget
	var dist: float = _follow_source.global_position.distance_to(_target.global_position)
	if dist > search_radius * 1.3:  # Small grace margin before snapping
		_retarget()
		if not _is_active:
			return

	# Pull enemy toward ship
	_pull_target(delta)

	# Tick damage
	_dot_timer += delta
	if _dot_timer >= dot_interval:
		_dot_timer -= dot_interval
		_deal_tick_damage(_target)

	# Update visuals
	_update_beam_line()
	_update_beam_particles()
	_update_impact_particles()


# =============================================================================
# TARGETING
# =============================================================================

func _find_nearest_enemy() -> Node2D:
	## Scan the "enemies" group for the closest enemy within search_radius.
	var origin: Vector2 = _follow_source.global_position if is_instance_valid(_follow_source) else global_position
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var best: Node2D = null
	var best_dist: float = search_radius
	for enemy: Node in enemies:
		if not enemy is Node2D or not is_instance_valid(enemy):
			continue
		var d: float = origin.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy as Node2D
	return best


func _retarget() -> void:
	## Instantly snap to the next nearest enemy.  If none found, beam fizzles.
	_target = _find_nearest_enemy()
	if _target == null:
		FileLogger.log_info("BrokenTractorBeam", "No retarget available — beam fizzling")
		_shutdown()
		return

	# Burst damage on new lock-on
	_apply_burst_damage(_target)
	FileLogger.log_info("BrokenTractorBeam", "Retargeted to new enemy")


# =============================================================================
# DAMAGE
# =============================================================================

func _apply_burst_damage(target: Node2D) -> void:
	## Initial burst damage when locking onto a target (2x tick damage).
	if is_instance_valid(target) and target.has_method("take_damage"):
		var burst: float = damage * burst_multiplier
		target.take_damage(burst)


func _deal_tick_damage(target: Node2D) -> void:
	## Periodic tick damage while tethered.
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)


func _pull_target(delta: float) -> void:
	## Drag the locked enemy toward the ship.
	if not is_instance_valid(_target) or not is_instance_valid(_follow_source):
		return
	var dir_to_ship: Vector2 = _follow_source.global_position - _target.global_position
	var dist: float = dir_to_ship.length()
	# Don't pull closer than 40px to avoid overlap
	if dist < 40.0:
		return
	var pull_delta: Vector2 = dir_to_ship.normalized() * pull_speed * delta
	# Clamp so we don't overshoot past the ship
	if pull_delta.length() > dist - 40.0:
		pull_delta = dir_to_ship.normalized() * (dist - 40.0)
	_target.global_position += pull_delta


# =============================================================================
# SHUTDOWN
# =============================================================================

func _shutdown() -> void:
	_is_active = false

	# Stop emitting but let existing particles finish
	if _beam_particles:
		_beam_particles.emitting = false
	if _impact_particles:
		_impact_particles.emitting = false

	# Fade out the beam line
	if _beam_line:
		var tween: Tween = create_tween()
		tween.tween_property(_beam_line, "modulate:a", 0.0, 0.15)
		tween.tween_callback(queue_free)
	else:
		queue_free()


# =============================================================================
# VISUALS — Beam Line (Line2D backbone)
# =============================================================================

func _create_beam_line() -> void:
	## Solid, stiff UFO-style tractor beam — cone shape, narrow at ship, wide at target.
	_beam_line = Line2D.new()
	_beam_line.width = beam_width
	_beam_line.default_color = color_core
	_beam_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_beam_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_line.antialiased = true
	_beam_line.z_index = -1

	# Width curve: narrow at ship (0.0), widens toward target (1.0) — classic UFO cone
	var width_curve: Curve = Curve.new()
	width_curve.add_point(Vector2(0.0, 0.15))
	width_curve.add_point(Vector2(0.3, 0.5))
	width_curve.add_point(Vector2(0.7, 0.85))
	width_curve.add_point(Vector2(1.0, 1.0))
	_beam_line.width_curve = width_curve

	# Gradient: bright core at ship → semi-transparent glow at target
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(color_core.r, color_core.g, color_core.b, 0.9))
	grad.add_point(0.4, Color(color_core.r, color_core.g, color_core.b, 0.7))
	grad.add_point(0.7, Color(color_glow.r, color_glow.g, color_glow.b, 0.5))
	grad.set_color(1, Color(color_glow.r, color_glow.g, color_glow.b, 0.35))
	_beam_line.gradient = grad

	add_child(_beam_line)


func _update_beam_line() -> void:
	if not _beam_line or not is_instance_valid(_target) or not is_instance_valid(_follow_source):
		return

	var from_pos: Vector2 = _follow_source.global_position
	var to_pos: Vector2 = _target.global_position
	var length: float = (to_pos - from_pos).length()

	if length < 1.0:
		_beam_line.clear_points()
		return

	# Solid stiff beam — straight line, no wobble
	_beam_line.clear_points()
	_beam_line.add_point(from_pos)
	_beam_line.add_point(to_pos)


# =============================================================================
# VISUALS — Beam Particles (streaming from ship to target)
# =============================================================================

func _create_beam_particles() -> void:
	## Particles that stream along the beam from ship toward target.
	_beam_particles = CPUParticles2D.new()
	_beam_particles.amount = particle_count
	_beam_particles.lifetime = particle_lifetime
	_beam_particles.one_shot = false
	_beam_particles.explosiveness = 0.0
	_beam_particles.randomness = 0.3
	_beam_particles.emitting = true
	_beam_particles.z_index = -1

	# Shape: directed points along the beam
	_beam_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS

	# Initial positions/normals — will be updated each frame
	_beam_particles.emission_points = PackedVector2Array([Vector2.ZERO])
	_beam_particles.emission_normals = PackedVector2Array([Vector2.RIGHT])

	# Velocity along normalized direction
	_beam_particles.initial_velocity_min = particle_speed * 0.5
	_beam_particles.initial_velocity_max = particle_speed
	_beam_particles.spread = 15.0

	# Slight lateral movement for sparkle
	_beam_particles.damping_min = 50.0
	_beam_particles.damping_max = 150.0

	# Size
	_beam_particles.scale_amount_min = 1.5
	_beam_particles.scale_amount_max = 3.0

	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(0.7, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))
	_beam_particles.scale_amount_curve = scale_curve

	# Color ramp: bright core → glow → fade
	var color_ramp: Gradient = Gradient.new()
	color_ramp.set_color(0, Color(color_core.r, color_core.g, color_core.b, 0.9))
	color_ramp.add_point(0.3, Color(color_glow.r, color_glow.g, color_glow.b, 0.8))
	color_ramp.add_point(0.7, Color(color_glow.r, color_glow.g, color_glow.b, 0.4))
	color_ramp.set_color(1, Color(color_glow.r, color_glow.g, color_glow.b, 0.0))
	_beam_particles.color_ramp = color_ramp

	# Texture: tiny white pixel
	_beam_particles.texture = _white_tex

	add_child(_beam_particles)


func _update_beam_particles() -> void:
	if not _beam_particles or not is_instance_valid(_target) or not is_instance_valid(_follow_source):
		return

	var from_pos: Vector2 = _follow_source.global_position
	var to_pos: Vector2 = _target.global_position
	var direction: Vector2 = (to_pos - from_pos)
	var length: float = direction.length()

	if length < 1.0:
		_beam_particles.emitting = false
		return

	_beam_particles.emitting = true
	var dir_norm: Vector2 = direction.normalized()

	# Distribute emission points along the beam line
	var point_count: int = maxi(5, int(length / 30.0))
	var points: PackedVector2Array = PackedVector2Array()
	var normals: PackedVector2Array = PackedVector2Array()

	for i: int in range(point_count):
		var t: float = float(i) / float(maxi(point_count - 1, 1))
		# Bias emission toward the source end (more particles leave the ship)
		var biased_t: float = t * t  # Quadratic bias toward 0
		points.append(from_pos + direction * biased_t)
		normals.append(dir_norm)

	_beam_particles.emission_points = points
	_beam_particles.emission_normals = normals


# =============================================================================
# VISUALS — Impact Particles (sparkle at the target)
# =============================================================================

func _create_impact_particles() -> void:
	## Sparkling particle burst at the target lock-on point.
	_impact_particles = CPUParticles2D.new()
	_impact_particles.amount = int(particle_count * 0.5)
	_impact_particles.lifetime = particle_lifetime * 0.8
	_impact_particles.one_shot = false
	_impact_particles.explosiveness = 0.0
	_impact_particles.randomness = 0.6
	_impact_particles.emitting = true
	_impact_particles.z_index = 0

	_impact_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_impact_particles.emission_sphere_radius = 8.0

	_impact_particles.initial_velocity_min = 20.0
	_impact_particles.initial_velocity_max = 60.0
	_impact_particles.spread = 180.0

	_impact_particles.scale_amount_min = 1.0
	_impact_particles.scale_amount_max = 2.5

	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.6))
	scale_curve.add_point(Vector2(1.0, 0.0))
	_impact_particles.scale_amount_curve = scale_curve

	# Bright white core → glow color → fade
	var impact_ramp: Gradient = Gradient.new()
	impact_ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	impact_ramp.add_point(0.2, Color(color_core.r, color_core.g, color_core.b, 0.9))
	impact_ramp.add_point(0.6, Color(color_glow.r, color_glow.g, color_glow.b, 0.5))
	impact_ramp.set_color(1, Color(color_glow.r, color_glow.g, color_glow.b, 0.0))
	_impact_particles.color_ramp = impact_ramp

	_impact_particles.texture = _white_tex

	add_child(_impact_particles)


func _update_impact_particles() -> void:
	if not _impact_particles or not is_instance_valid(_target):
		return
	_impact_particles.global_position = _target.global_position


# =============================================================================
# UTILITY
# =============================================================================


