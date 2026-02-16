extends Node2D
class_name IonWake

## Simple orange AoE circle that grows and explodes into particles

# === SHAPE ===
@export var size: float = 32.0             # Circle radius and particle spread radius
@export_range(0.0, 2.0, 0.05) var growth_percent: float = 0.2  # 0.2 = 20% larger

# === VISUAL ===
@export var circle_color: Color = Color(1.0, 0.35, 0.08, 0.8):  # Base color for particles
	set(value):
		circle_color = value
		if _sprite:
			_sprite.modulate = circle_color

# === TIMING ===
@export var hold_time: float = 1.0        # How long to grow before exploding

# === PARTICLES ===
@export var particles_count: int = 160     # Number of particles on explosion
@export var particles_speed_min: float = 100.0
@export var particles_speed_max: float = 250.0
@export var particles_lifetime: float = 0.5  # How long particles live
@export var particles_gravity: float = 0.0  # Downward pull on particles
@export var particles_excitement: float = 30.0  # How much particles wander like fireflies

# === STATS ===
@export var damage: float = 15.0

# --- Internal ---
var _hit_targets: Array = []
var _hitbox: Area2D = null
var _hitbox_collision: CollisionShape2D = null
var _sprite: Sprite2D
var _tween: Tween
var _current_radius: float = 0.0


func load_from_data(data: Dictionary) -> void:
	var stats: Dictionary = data.get("stats", {})
	damage = float(stats.get("damage", damage))

	var shape: Dictionary = data.get("shape", {})
	size = float(shape.get("size", size))
	growth_percent = float(shape.get("growth_percent", growth_percent))

	var motion: Dictionary = data.get("motion", {})
	hold_time = float(motion.get("hold_time", hold_time))
	
	var particles_data: Dictionary = data.get("particles", {})
	particles_count = int(particles_data.get("count", particles_count))
	particles_speed_min = float(particles_data.get("speed_min", particles_speed_min))
	particles_speed_max = float(particles_data.get("speed_max", particles_speed_max))
	particles_lifetime = float(particles_data.get("lifetime", particles_lifetime))
	particles_gravity = float(particles_data.get("gravity", particles_gravity))
	particles_excitement = float(particles_data.get("excitement", particles_excitement))

	var visual: Dictionary = data.get("visual", {})
	if visual.has("circle_color"):
		var color_string: Variant = visual.get("circle_color")
		if color_string is String:
			circle_color = Color(color_string)
		elif color_string is Color:
			circle_color = color_string


func _ready() -> void:
	# Register for live config updates from test lab
	add_to_group("ion_wake")
	add_to_group("weapon_effect")
	
	# Sprite: white circle texture
	var img: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Transparent background
	# Draw a filled circle
	var center: Vector2 = Vector2(64, 64)
	var radius: float = 64.0
	for x in range(128):
		for y in range(128):
			var dist: float = Vector2(x, y).distance_to(center)
			if dist <= radius:
				img.set_pixel(x, y, Color.WHITE)
	_sprite = Sprite2D.new()
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.centered = true
	add_child(_sprite)

	# Initial scale: sprite diameter = size * 2
	var start_diameter: float = size * 2.0
	_sprite.scale = Vector2(start_diameter / 128.0, start_diameter / 128.0)
	_current_radius = size

	# Apply color from parameter
	_sprite.modulate = circle_color

	call_deferred("_create_hitbox")
	call_deferred("_start_expansion")


func _start_expansion() -> void:
	# Calculate max_radius from growth_percent
	var calculated_max_radius: float = size * (1.0 + growth_percent)
	var expand_time: float = hold_time  # Grow over the hold time
	var start_diameter: float = size * 2.0
	var end_diameter: float = calculated_max_radius * 2.0
	var start_scale: float = start_diameter / 128.0
	var end_scale: float = end_diameter / 128.0

	_tween = create_tween()

	# Scale the circle from start_radius to calculated max (growth over hold_time)
	_tween.tween_method(_on_scale_update, start_scale, end_scale, expand_time)

	# Explode into particles after hold_time
	_tween.tween_callback(_explode_into_particles)
	
	# Cleanup shortly after explosion
	_tween.tween_callback(queue_free).set_delay(0.1)


func _on_scale_update(scale_val: float) -> void:
	_sprite.scale = Vector2(scale_val, scale_val)
	# Current radius = (sprite_scale * 128) / 2
	_current_radius = (scale_val * 128.0) / 2.0
	_update_hitbox()


func _explode_into_particles() -> void:
	# Hide the main sprite
	_sprite.visible = false
	
	# Disable hitbox
	if _hitbox:
		_hitbox.monitoring = false
	
	# Use CPUParticles2D for reliable particle lifecycle (same approach as Radiant Arc)
	var particles: CPUParticles2D = CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.z_index = -2  # Render below enemies and ship
	particles.z_as_relative = false
	
	# One-shot explosion burst
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0  # All emit at once
	particles.amount = particles_count
	particles.lifetime = particles_lifetime
	
	# Movement: firefly-like wandering controlled by excitement
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = particles_excitement * 0.3
	particles.initial_velocity_max = particles_excitement
	particles.gravity = Vector2(0, particles_gravity)
	# Angular velocity for swirling firefly motion
	particles.angular_velocity_min = -particles_excitement * 3.0
	particles.angular_velocity_max = particles_excitement * 3.0
	# Randomness makes each particle wander differently
	particles.randomness = 1.0
	# Damping so particles don't fly away
	particles.damping_min = particles_excitement * 0.5
	particles.damping_max = particles_excitement * 1.5
	
	# Scale: 1px sparks
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 1.0
	
	# Emit from entire circle area
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = _current_radius
	
	# Color: base circle_color with slight variation
	particles.color = circle_color
	
	# Color ramp: fade out
	var color_ramp: Gradient = Gradient.new()
	color_ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))  # Full opacity at start
	color_ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))  # Fully transparent at end
	particles.color_ramp = color_ramp
	
	# Slight hue variation
	particles.color_initial_ramp = null
	particles.hue_variation_min = -0.04
	particles.hue_variation_max = 0.04
	
	# Clean up after particles finish
	get_tree().create_timer(particles_lifetime + 0.5).timeout.connect(particles.queue_free)


func _create_hitbox() -> void:
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 8
	_hitbox.monitoring = true
	_hitbox.monitorable = true
	add_child(_hitbox)

	_hitbox_collision = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = _current_radius
	_hitbox_collision.shape = circle
	_hitbox.add_child(_hitbox_collision)
	_hitbox.area_entered.connect(_on_hitbox_area_entered)


func _update_hitbox() -> void:
	if _hitbox_collision and _hitbox_collision.shape is CircleShape2D:
		_hitbox_collision.shape.radius = _current_radius


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area in _hit_targets:
		return
	_hit_targets.append(area)
	if area.has_method("take_damage"):
		area.take_damage(damage, self)
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage, self)


func get_damage() -> float:
	return damage


# === PUBLIC API ===

func setup(params: Dictionary) -> IonWake:
	for key in params:
		if key in self:
			set(key, params[key])
	return self


func spawn_at(spawn_pos: Vector2) -> IonWake:
	global_position = spawn_pos
	return self
