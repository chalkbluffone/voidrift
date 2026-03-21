extends BulletAttachment2D

## Small spark particle trail attached to Space Nukes rockets via BB2D's
## BulletAttachment2D system. Emits orange/yellow sparks behind the rocket.

var _particles: Node2D = null


func _ready() -> void:
	_particles = EffectUtils.create_particles(self, {
		"emitting": false,
		"amount": 10,
		"lifetime": 0.2,
		"one_shot": false,
		"local_coords": false,
		"position": Vector2(-18.0, 0.0),
		"emission_shape": CPUParticles2D.EMISSION_SHAPE_SPHERE,
		"emission_sphere_radius": 2.0,
		"direction": Vector2(-1, 0),
		"spread": 35.0,
		"initial_velocity_min": 15.0,
		"initial_velocity_max": 40.0,
		"damping_min": 10.0,
		"damping_max": 25.0,
		"gravity": Vector2.ZERO,
		"scale_amount_min": 1.0,
		"scale_amount_max": 2.5,
		"scale_amount_curve": EffectUtils.make_curve([
			Vector2(0, 1), Vector2(0.4, 0.5), Vector2(1, 0)
		]),
		"color_ramp": EffectUtils.make_gradient([
			[0.0, Color(1.0, 0.95, 0.6, 1.0)],
			[0.3, Color(1.0, 0.6, 0.15, 0.8)],
			[0.7, Color(0.8, 0.25, 0.0, 0.35)],
			[1.0, Color(0.4, 0.1, 0.0, 0.0)],
		]),
		"texture": EffectUtils.get_white_pixel_texture(4),
	})


func on_bullet_spawn() -> void:
	if _particles:
		EffectUtils.set_particle_prop(_particles, "emitting", true)


func on_bullet_enable() -> void:
	if _particles:
		EffectUtils.set_particle_prop(_particles, "emitting", true)


func on_bullet_disable() -> void:
	if _particles:
		EffectUtils.set_particle_prop(_particles, "emitting", false)


func on_spawn_in_pool() -> void:
	if _particles:
		EffectUtils.set_particle_prop(_particles, "emitting", false)
