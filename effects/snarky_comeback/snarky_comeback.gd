extends ArcEffectBase
class_name SnarkyComeback

## Snarky Comeback — a radiant-arc shaped boomerang projectile.
## Shares mesh / hitbox / particle / shader plumbing with ArcEffectBase.
## Unique features:
##   • Flies outward, brakes near apex, reverses, returns to player
##   • Continuous spin while in flight
##   • After initial sweep animation, entire arc stays visible (full_visible)
##   • Deals damage on both outward and return passes


# ── Boomerang motion exports ─────────────────────────────────────────────

@export var projectile_speed: float = 400.0  ## Travel speed (px/sec)
@export var max_range: float = 500.0         ## Distance before reversing
@export var spin_speed: float = 1.0          ## Full rotations per second
@export var return_radius: float = 30.0      ## Distance to player for self-destruct
@export var size_mult: float = 1.0           ## Multiplier from size stat

# ── Unique internal state ─────────────────────────────────────────────────

var _direction: Vector2 = Vector2.RIGHT
var _returning: bool = false
var _source: Node2D = null
var _distance_traveled: float = 0.0
var _spin_angle: float = 0.0
var _return_time: float = 0.0
var _sweep_completed: bool = false


# ══════════════════════════════════════════════════════════════════════════
#  OVERRIDES
# ══════════════════════════════════════════════════════════════════════════

func _get_shader_path() -> String:
	return "res://effects/snarky_comeback/snarky_comeback.gdshader"


func _on_ready_hook() -> void:
	# Force distance to 0 so the arc centres on the node origin —
	# prevents bobbing when spinning.
	distance = 0.0
	_generate_arc_mesh()


func _compute_sweep_and_alpha() -> Dictionary:
	## Faster sweep than RadiantArc (0.4s base instead of 70% of duration).
	var sweep_duration: float = 0.4 / max(sweep_speed, 0.1)
	var sweep_progress: float = clamp(_elapsed / sweep_duration, 0.0, 1.0)
	if sweep_progress >= 1.0:
		_sweep_completed = true

	if _sweep_completed:
		sweep_progress = 1.0
		_shader_material.set_shader_parameter("full_visible", 1.0)

	var alpha: float = 1.0
	if _elapsed < fade_in:
		alpha = _elapsed / fade_in
	elif _returning and _source and is_instance_valid(_source):
		var dist_to_source: float = global_position.distance_to(_source.global_position)
		if dist_to_source < return_radius * 3.0:
			alpha = clamp(dist_to_source / (return_radius * 3.0), 0.0, 1.0)

	return {"sweep": sweep_progress, "alpha": alpha}


func _on_sweep_completed_hitbox() -> bool:
	if _sweep_completed:
		return true  # Tell base to enable all collision bubbles
	return false


func _on_sweep_completed_particles(_alpha: float) -> bool:
	if _sweep_completed:
		_emit_particles_full_arc(_alpha)
		return true
	return false


func _update_blade_position(sweep_progress: float, sweep_edge: float, arc_rad: float) -> void:
	if not _blade_collision:
		return
	if _sweep_completed:
		_blade_collision.disabled = true
		if _blade_debug:
			_blade_debug.visible = false
		return
	# Delegate to base for normal sweep-phase blade
	super._update_blade_position(sweep_progress, sweep_edge, arc_rad)


func _process(delta: float) -> void:
	if not _is_active:
		return

	_elapsed += delta

	# Safety timeout
	if _elapsed >= 10.0:
		_is_active = false
		queue_free()
		return

	# ── Boomerang movement ────────────────────────────────────────────
	if not _returning:
		var total_range: float = max_range * size_mult
		var progress: float = clampf(_distance_traveled / total_range, 0.0, 1.0)
		var speed_mult: float = 1.6
		if progress > 0.8:
			var brake_t: float = (progress - 0.8) / 0.2
			speed_mult = lerpf(1.6, 0.3, brake_t * brake_t)
		var move_amount: float = projectile_speed * speed_mult * delta
		global_position += _direction * move_amount
		_distance_traveled += move_amount

		if _distance_traveled >= total_range:
			_returning = true
			_return_time = 0.0
			_hit_targets.clear()
	else:
		_return_time += delta
		var t: float = _return_time
		var ramp_duration: float = 0.6
		var return_mult: float
		if t < ramp_duration:
			var nt: float = t / ramp_duration
			var eased: float = nt * nt * (3.0 - 2.0 * nt)
			return_mult = lerpf(0.3, 1.6, eased)
		else:
			return_mult = 1.6 + (t - ramp_duration) * 0.3
		var return_speed: float = projectile_speed * return_mult
		if _source and is_instance_valid(_source):
			_direction = (_source.global_position - global_position).normalized()
		var move_amount: float = return_speed * delta
		global_position += _direction * move_amount

		if _source and is_instance_valid(_source):
			var dist_to_source: float = global_position.distance_to(_source.global_position)
			if dist_to_source <= return_radius:
				_is_active = false
				queue_free()
				return
		else:
			_is_active = false
			queue_free()
			return

	# ── Spin ──────────────────────────────────────────────────────────
	_spin_angle += spin_speed * TAU * delta
	rotation = _spin_angle

	_update_shader_uniforms()


# ══════════════════════════════════════════════════════════════════════════
#  SETUP / PUBLIC API
# ══════════════════════════════════════════════════════════════════════════

func setup(params: Dictionary) -> SnarkyComeback:
	for key in params:
		if key in self:
			set(key, params[key])

	if is_node_ready():
		_generate_arc_mesh()
		_update_shader_uniforms()
		_recreate_particles()

	return self


func set_direction(direction: Vector2) -> void:
	_direction = direction.normalized()


func set_source(source: Node2D) -> void:
	_source = source


func spawn_from(spawn_pos: Vector2, direction: Vector2) -> void:
	global_position = spawn_pos
	_direction = direction.normalized()
	_spin_angle = _direction.angle()
