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
@export var color: Color = Color(0.55, 0.15, 0.85, 0.8)
@export var cooldown: float = 3.0  # Used for display only; spawner handles regen timing

# --- Internal state ---
var _current_layers: int = 2
var _max_layers: int = 2
var _follow_source: Node2D = null
var _shield_mesh: MeshInstance2D = null
var _layer_label: Label = null
var _shader_material: ShaderMaterial = null
var _hit_flash_timer: float = 0.0
var _hit_flash_duration: float = 0.15

# --- Shockwave tracking ---
var _active_shockwaves: Array[Node2D] = []

@onready var FileLogger: Node = get_node_or_null("/root/FileLogger")


func _ready() -> void:
	add_to_group("nope_bubble")


func setup(params: Dictionary) -> void:
	for key in params:
		if key in self:
			set(key, params[key])
	# Ensure max layers matches projectile_count
	var old_max := _max_layers
	_max_layers = projectile_count
	if old_max == 0:
		# First-time init
		_current_layers = _max_layers
	else:
		# Live update: clamp current layers to new max, don't reset
		_current_layers = mini(_current_layers, _max_layers)


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
		if FileLogger:
			FileLogger.log_info("NopeBubble", "Regenerated layer: %d/%d" % [_current_layers, _max_layers])


## Damage interceptor callback — registered on the Ship.
## Returns modified damage amount: 0.0 for full block, reduced for weak block.
func intercept_damage(amount: float, source: Node) -> float:
	if _current_layers <= 0:
		return amount  # Shield is down, damage passes through
	
	# Consume a layer
	_current_layers -= 1
	
	# Determine block type
	var is_boss: bool = false
	if source and "enemy_type" in source:
		is_boss = source.enemy_type == "boss"
	
	# Apply knockback to attacker
	if source and source is Node2D and source.has_method("apply_knockback"):
		var kb_direction: Vector2 = Vector2.ZERO
		if _follow_source:
			kb_direction = (source.global_position - _follow_source.global_position).normalized()
		else:
			kb_direction = (source.global_position - global_position).normalized()
		source.apply_knockback(kb_direction * knockback)
	
	# Spawn shockwave cone toward the attacker
	if source and source is Node2D:
		_spawn_shockwave(source as Node2D)
	
	# Visual feedback — hit flash
	_hit_flash_timer = _hit_flash_duration
	_update_visuals()
	
	if FileLogger:
		var block_type: String = "weak" if is_boss else "full"
		FileLogger.log_info("NopeBubble", "Layer consumed (%s block): %d/%d remaining" % [block_type, _current_layers, _max_layers])
	
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
	
	# Clean up finished shockwaves
	_active_shockwaves = _active_shockwaves.filter(func(sw): return is_instance_valid(sw))


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
		# Boost alpha for visibility: use full-alpha color, control transparency via shader
		var shield_color_bright: Color = Color(color.r, color.g, color.b, max(color.a, 0.7))
		_shader_material.set_shader_parameter("shield_color", shield_color_bright)
		_shader_material.set_shader_parameter("opacity", 1.0)
		_shader_material.set_shader_parameter("pulse", 0.0)
		_shield_mesh.material = _shader_material
	else:
		push_warning("NopeBubble: Could not load shader, using fallback color")
		# Fallback: tint the mesh directly
		_shield_mesh.modulate = Color(color.r, color.g, color.b, 0.3)
	
	_shield_mesh.z_index = 0
	add_child(_shield_mesh)
	
	# --- Layer counter label ---
	_layer_label = Label.new()
	_layer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_layer_label.position = Vector2(size * 0.7, -(size * 0.9))  # Top-right, just outside the ring
	_layer_label.add_theme_font_size_override("font_size", 18)
	_layer_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0, 0.95))
	_layer_label.visible = false
	add_child(_layer_label)


func _update_visuals() -> void:
	if not _shield_mesh:
		return
	
	# Opacity based on layer ratio
	var layer_ratio: float = float(_current_layers) / max(float(_max_layers), 1.0)
	var visual_opacity: float = clampf(0.15 + layer_ratio * 0.85, 0.1, 1.0)
	
	# Color shift: full layers = bright blue, low layers = dim red-ish
	var current_color: Color = color.lerp(Color(1.0, 0.3, 0.2, 1.0), 1.0 - layer_ratio)
	current_color.a = max(current_color.a, 0.7)  # Keep alpha high — shader handles transparency
	
	if _shader_material:
		_shader_material.set_shader_parameter("opacity", visual_opacity)
		_shader_material.set_shader_parameter("shield_color", current_color)
	else:
		# Fallback for no shader — modulate the mesh directly
		_shield_mesh.modulate = Color(current_color.r, current_color.g, current_color.b, visual_opacity * 0.4)
	
	# Show numeric counter when max layers >= 5
	if _layer_label:
		if _max_layers >= 5:
			_layer_label.text = str(_current_layers)
			_layer_label.visible = true
			# Reposition label in case size changed
			_layer_label.position = Vector2(size * 0.7, -(size * 0.9))
		else:
			_layer_label.visible = false
	
	# Update mesh size in case size param changed
	if _shield_mesh and _shield_mesh.mesh:
		(_shield_mesh.mesh as QuadMesh).size = Vector2(size * 2.6, size * 2.6)


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
	
	# Visual: cone mesh with fade
	var visual_mesh: MeshInstance2D = MeshInstance2D.new()
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var shockwave_color: Color = Color(0.5, 0.8, 1.0, 0.6)
	
	# Build triangle fan for cone visual
	for i in range(segments):
		var t0: float = float(i) / float(segments)
		var t1: float = float(i + 1) / float(segments)
		var a0: float = -half_angle + t0 * half_angle * 2.0
		var a1: float = -half_angle + t1 * half_angle * 2.0
		
		vertices.append(Vector2.ZERO)
		vertices.append(direction.rotated(a0) * shockwave_range)
		vertices.append(direction.rotated(a1) * shockwave_range)
		
		colors.append(Color(shockwave_color.r, shockwave_color.g, shockwave_color.b, 0.6))
		colors.append(Color(shockwave_color.r, shockwave_color.g, shockwave_color.b, 0.0))
		colors.append(Color(shockwave_color.r, shockwave_color.g, shockwave_color.b, 0.0))
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	visual_mesh.mesh = arr_mesh
	shockwave.add_child(visual_mesh)
	
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
	
	# Animate: expand and fade out over 0.3s, then destroy
	var tween: Tween = shockwave.create_tween()
	tween.tween_property(visual_mesh, "modulate:a", 0.0, 0.3)
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
