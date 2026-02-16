extends ArcEffectBase
class_name RadiantArc

## Melee arc weapon — sweeping energy crescent that follows the player's facing
## direction.  Unique features on top of ArcEffectBase:
##   • Follows a source node's rotation (melee stance)
##   • Fallback linear forward motion when no source
##   • load_from_data() for nested-JSON weapon definitions


# ── Unique exports ────────────────────────────────────────────────────────

@export var speed: float = 0.0  ## Travel speed forward (px/sec)

# ── Unique internal state ─────────────────────────────────────────────────

var _follow_source: Node2D = null
var _start_pos: Vector2
var _start_rotation: float
var _aim_direction: Vector2 = Vector2.RIGHT


# ══════════════════════════════════════════════════════════════════════════
#  OVERRIDES
# ══════════════════════════════════════════════════════════════════════════

func _get_shader_path() -> String:
	return "res://effects/radiant_arc/radiant_arc.gdshader"


func _on_ready_hook() -> void:
	_start_pos = global_position
	_start_rotation = rotation


func _process(delta: float) -> void:
	if not _is_active:
		return

	_elapsed += delta

	if _elapsed >= duration:
		_is_active = false
		queue_free()
		return

	# Follow source's facing direction (rotation)
	if _follow_source and is_instance_valid(_follow_source):
		rotation = _follow_source.rotation + deg_to_rad(rotation_offset_deg)
		global_position = _follow_source.global_position
	elif speed > 0.0:
		var direction: Vector2 = Vector2.RIGHT.rotated(rotation)
		global_position = _start_pos + direction * speed * _elapsed

	_update_shader_uniforms()


# ══════════════════════════════════════════════════════════════════════════
#  NESTED-JSON LOADER  (weapons.json structure)
# ══════════════════════════════════════════════════════════════════════════

func load_from_data(data: Dictionary) -> void:
	var stats: Dictionary = data.get("stats", {})
	damage = float(stats.get("damage", damage))
	duration = float(stats.get("duration", duration))

	var shape: Dictionary = data.get("shape", {})
	arc_angle_deg = float(shape.get("arc_angle_deg", arc_angle_deg))
	radius = float(shape.get("radius", radius))
	thickness = float(shape.get("thickness", thickness))
	taper = float(shape.get("taper", taper))
	length_scale = float(shape.get("length_scale", length_scale))
	distance = float(shape.get("distance", distance))

	var motion: Dictionary = data.get("motion", {})
	speed = float(motion.get("speed", speed))
	sweep_speed = float(motion.get("sweep_speed", sweep_speed))
	fade_in = float(motion.get("fade_in", fade_in))
	fade_out = float(motion.get("fade_out", fade_out))
	rotation_offset_deg = float(motion.get("rotation_offset_deg", rotation_offset_deg))
	seed_offset = float(motion.get("seed_offset", seed_offset))

	var visual: Dictionary = data.get("visual", {})
	color_a = EffectUtils.parse_color(visual.get("color_a", ""), color_a)
	color_b = EffectUtils.parse_color(visual.get("color_b", ""), color_b)
	color_c = EffectUtils.parse_color(visual.get("color_c", ""), color_c)
	glow_strength = float(visual.get("glow_strength", glow_strength))
	core_strength = float(visual.get("core_strength", core_strength))
	noise_strength = float(visual.get("noise_strength", noise_strength))
	uv_scroll_speed = float(visual.get("uv_scroll_speed", uv_scroll_speed))
	chromatic_aberration = float(visual.get("chromatic_aberration", chromatic_aberration))
	pulse_strength = float(visual.get("pulse_strength", pulse_strength))
	pulse_speed = float(visual.get("pulse_speed", pulse_speed))
	electric_strength = float(visual.get("electric_strength", electric_strength))
	electric_frequency = float(visual.get("electric_frequency", electric_frequency))
	electric_speed = float(visual.get("electric_speed", electric_speed))
	gradient_offset = float(visual.get("gradient_offset", gradient_offset))

	var particles: Dictionary = data.get("particles", {})
	particles_enabled = bool(particles.get("enabled", particles_enabled))
	particles_amount = int(particles.get("amount", particles_amount))
	particles_size = float(particles.get("size", particles_size))
	particles_speed = float(particles.get("speed", particles_speed))
	particles_lifetime = float(particles.get("lifetime", particles_lifetime))
	particles_spread = float(particles.get("spread", particles_spread))
	particles_drag = float(particles.get("drag", particles_drag))
	particles_outward = float(particles.get("outward", particles_outward))
	particles_radius = float(particles.get("radius", particles_radius))
	particles_color = EffectUtils.parse_color(particles.get("color", ""), particles_color)


# ══════════════════════════════════════════════════════════════════════════
#  PUBLIC API
# ══════════════════════════════════════════════════════════════════════════

func set_direction(direction: Vector2) -> RadiantArc:
	_aim_direction = direction.normalized()
	rotation = _aim_direction.angle() + deg_to_rad(rotation_offset_deg)
	return self


func spawn_from(spawn_pos: Vector2, direction: Vector2) -> RadiantArc:
	global_position = spawn_pos
	set_direction(direction)
	_start_pos = global_position
	_start_rotation = rotation
	return self


func set_follow_source(source: Node2D) -> RadiantArc:
	_follow_source = source
	return self
