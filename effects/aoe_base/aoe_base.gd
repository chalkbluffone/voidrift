extends Node2D

## Generic persistent AoE aura effect.
## Used by Proximity Tax prototype: follow-source aura with periodic damage ticks.

@export var damage: float = 5.0
@export var size: float = 90.0
@export var tick_interval: float = 0.25
@export var aura_color: Color = Color(1.0, 0.93, 0.35, 0.12)
@export var ring_color: Color = Color(1.0, 0.95, 0.45, 0.75)
@export var glow_strength: float = 0.45
@export var glow_width_px: float = 10.0

var _follow_source: Node2D = null
var _tick_timer: float = 0.0
var _mesh: MeshInstance2D = null
var _shader_material: ShaderMaterial = null
var _hitbox: Area2D = null
var _hitbox_collision: CollisionShape2D = null


func _ready() -> void:
	tick_interval = maxf(tick_interval, 0.01)
	add_to_group("proximity_tax_aura")
	_create_visuals()
	_create_hitbox()
	_update_radius(size)
	_tick_timer = tick_interval


func setup(params: Dictionary) -> void:
	for key in params:
		if key in self:
			set(key, params[key])

	if _shader_material:
		_shader_material.set_shader_parameter("aura_color", aura_color)
		_shader_material.set_shader_parameter("ring_color", ring_color)
		_shader_material.set_shader_parameter("glow_strength", glow_strength)
		_shader_material.set_shader_parameter("glow_width_px", glow_width_px)

	tick_interval = maxf(tick_interval, 0.01)

	_update_radius(size)


func spawn_at(spawn_pos: Vector2) -> void:
	global_position = spawn_pos


func set_follow_source(source: Node2D) -> void:
	_follow_source = source


func _process(delta: float) -> void:
	if _follow_source:
		if is_instance_valid(_follow_source):
			global_position = _follow_source.global_position
		else:
			queue_free()
			return

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_deal_tick_damage()
		_tick_timer = tick_interval


func _create_visuals() -> void:
	_mesh = MeshInstance2D.new()
	var quad: QuadMesh = QuadMesh.new()
	_mesh.mesh = quad

	_mesh.texture = EffectUtils.get_white_pixel_texture()

	var shader: Shader = load("res://effects/aoe_base/proximity_tax_aura.gdshader")
	if shader:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = shader
		_mesh.material = _shader_material
		_shader_material.set_shader_parameter("aura_color", aura_color)
		_shader_material.set_shader_parameter("ring_color", ring_color)
		_shader_material.set_shader_parameter("ring_width_px", 2.0)
		_shader_material.set_shader_parameter("glow_width_px", glow_width_px)
		_shader_material.set_shader_parameter("glow_strength", glow_strength)
	else:
		push_warning("AoEBase: Failed to load proximity_tax_aura.gdshader")

	_mesh.z_index = 0
	add_child(_mesh)


func _create_hitbox() -> void:
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 8
	_hitbox.monitoring = true
	_hitbox.monitorable = true
	add_child(_hitbox)

	_hitbox_collision = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = size
	_hitbox_collision.shape = circle
	_hitbox.add_child(_hitbox_collision)


func _update_radius(radius: float) -> void:
	var clamped_radius: float = maxf(radius, 1.0)
	size = clamped_radius

	if _hitbox_collision and _hitbox_collision.shape is CircleShape2D:
		(_hitbox_collision.shape as CircleShape2D).radius = clamped_radius

	var visual_extent: float = clamped_radius + glow_width_px + 6.0
	if _mesh and _mesh.mesh is QuadMesh:
		var quad_size: Vector2 = Vector2(visual_extent * 2.0, visual_extent * 2.0)
		(_mesh.mesh as QuadMesh).size = quad_size
		if _shader_material:
			_shader_material.set_shader_parameter("quad_size_px", quad_size)

	if _shader_material:
		_shader_material.set_shader_parameter("radius_px", clamped_radius)


func _deal_tick_damage() -> void:
	var damaged: Array = []

	if _hitbox and _hitbox.monitoring:
		var areas: Array = _hitbox.get_overlapping_areas()
		for area in areas:
			if not is_instance_valid(area):
				continue
			if area.has_method("take_damage") and not damaged.has(area):
				area.take_damage(damage, self)
				damaged.append(area)
				continue
			var parent: Node = area.get_parent()
			if parent and parent.is_in_group("enemies") and parent.has_method("take_damage") and not damaged.has(parent):
				parent.take_damage(damage, self)
				damaged.append(parent)

		var bodies: Array = _hitbox.get_overlapping_bodies()
		for body in bodies:
			if not is_instance_valid(body):
				continue
			if body.is_in_group("enemies") and body.has_method("take_damage") and not damaged.has(body):
				body.take_damage(damage, self)
				damaged.append(body)

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if damaged.has(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= size and enemy.has_method("take_damage"):
			enemy.take_damage(damage, self)
