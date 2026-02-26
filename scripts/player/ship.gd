extends CharacterBody2D

## Player ship controller with StatsComponent, Phase Shift, captain ability, and i-frames.
## Tank controls: W thrusts forward, A/D turns, S moves down.
## Can be used in test mode (weapon test lab) by setting test_mode = true before _ready.

signal phase_shift_started
signal phase_shift_ended
signal phase_energy_changed(current: int, maximum: int)
signal captain_ability_activated
signal captain_ability_expired
signal captain_ability_ready
signal died

# --- Preloads ---
const StatsComponentScript: GDScript = preload("res://scripts/core/stats_component.gd")

# --- Components ---
@onready var stats: Node = $StatsComponent
@onready var weapons: Node = $WeaponComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var RunManager: Node = get_node_or_null("/root/RunManager")
@onready var ProgressionManager: Node = get_node_or_null("/root/ProgressionManager")

# --- Test Mode ---
## When true, skips run registration and auto-weapon equip
@export var test_mode: bool = false

# --- Phase Shift ---
@export var max_phase_energy: int = 3
var phase_energy: int = 3
var phase_recharge_time: float = GameConfig.PHASE_RECHARGE_TIME
var _phase_recharge_timer: float = 0.0
var _is_phasing: bool = false
var _phase_timer: float = 0.0
var _phase_cooldown_timer: float = 0.0
var _phase_direction: Vector2 = Vector2.ZERO
var _normal_collision_layer: int = 0
var _normal_collision_mask: int = 0

# --- I-Frames ---
var _iframes_timer: float = 0.0
var _is_invincible: bool = false

# --- Movement ---
var _base_speed: float = 100.0  # Will be set from GameConfig in _ready
var _last_move_direction: Vector2 = Vector2.RIGHT
var _knockback_velocity: Vector2 = Vector2.ZERO
var _last_input_device: String = "keyboard" # "keyboard" or "joypad"

# --- Damage Interceptors ---
# Callables that receive (amount: float, source: Node) and return modified damage float.
# Used by Nope Bubble and similar defensive weapons to block/reduce incoming damage.
var _damage_interceptors: Array[Callable] = []

# --- Camera Dynamic Zoom ---
var _camera: Camera2D = null

# --- Captain Ability ---
var _captain_ability: Node = null


func _ready() -> void:
	# Set base speed from config
	var config: Node = get_node_or_null("/root/GameConfig")
	if config:
		_base_speed = config.PLAYER_BASE_SPEED
	
	# Set pickup range from config * pickup_range stat (skip in test mode)
	if not test_mode:
		_update_pickup_range()
		if stats:
			stats.stat_changed.connect(_on_stat_changed)
	
	# Register with RunManager (skip in test mode)
	if not test_mode and RunManager:
		RunManager.register_player(self)
		
		# Listen for level ups
		if not ProgressionManager.level_up_completed.is_connected(_on_level_up_completed):
			ProgressionManager.level_up_completed.connect(_on_level_up_completed)
	
	# Connect stats signals
	if stats:
		stats.hp_changed.connect(_on_hp_changed)
		stats.died.connect(_on_died)
	
	phase_energy = max_phase_energy
	phase_energy_changed.emit(phase_energy, max_phase_energy)
	
	# Cache camera reference
	_camera = get_node_or_null("Camera2D") as Camera2D
	
	# In test mode, disable auto-fire so test lab controls firing manually
	if test_mode and weapons:
		weapons.auto_fire_enabled = false
	
	# Defer weapon setup to ensure all @onready vars are initialized (skip in test mode)
	if not test_mode:
		call_deferred("_deferred_init")


func _initialize_from_loadout(ship_data: Dictionary, captain_data: Dictionary, synergy_data: Dictionary) -> void:
	stats.initialize_from_loadout(ship_data, captain_data, synergy_data)
	
	# Apply ship sprite from data
	_apply_ship_sprite(ship_data)
	
	# Apply collision shape from data
	_apply_collision_shape(ship_data)
	
	# Set phase shift from ship data
	var phase_shift: Dictionary = ship_data.get("phase_shift", {})
	var base_charges: int = phase_shift.get("charges", 3)
	var extra_shifts: int = stats.get_stat_int(StatsComponentScript.STAT_EXTRA_PHASE_SHIFTS)
	max_phase_energy = base_charges + extra_shifts
	phase_energy = max_phase_energy
	
	# Get base speed from ship
	_base_speed = float(ship_data.get("base_speed", 100.0))
	
	# Instantiate captain ability
	_setup_captain_ability(captain_data)
	
	# Equip weapons from run data
	weapons.sync_from_run_data()




## Load the ship's sprite texture from data and scale to per-ship visual dimensions.
func _apply_ship_sprite(ship_data: Dictionary) -> void:
	var sprite_path: String = ship_data.get("sprite", "")
	if sprite_path.is_empty() or not sprite:
		return
	var tex: Texture2D = load(sprite_path) as Texture2D
	if tex == null:
		push_warning("Ship: Failed to load ship sprite: %s" % sprite_path)
		return
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_frame(&"default", tex)
	sprite.sprite_frames = frames
	sprite.animation = &"default"
	sprite.play()
	# Scale to per-ship visual dimensions from JSON
	var visual: Dictionary = ship_data.get("visual", {})
	var target_w: float = float(visual.get("width", GameConfig.DEFAULT_VISUAL_WIDTH))
	var target_h: float = float(visual.get("height", GameConfig.DEFAULT_VISUAL_HEIGHT))
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		sprite.scale = Vector2(target_w / tex_size.x, target_h / tex_size.y)


## Apply per-ship collision shape from JSON data (circle or capsule).
func _apply_collision_shape(ship_data: Dictionary) -> void:
	if not collision_shape:
		return
	var col: Dictionary = ship_data.get("collision", {})
	var col_type: String = String(col.get("type", "circle"))
	var col_w: float = float(col.get("width", GameConfig.DEFAULT_COLLISION_RADIUS * 2.0))
	var col_h: float = float(col.get("height", GameConfig.DEFAULT_COLLISION_RADIUS * 2.0))
	match col_type:
		"capsule":
			var capsule: CapsuleShape2D = CapsuleShape2D.new()
			capsule.radius = col_w * 0.5
			capsule.height = col_h
			collision_shape.shape = capsule
		_:
			var circle: CircleShape2D = CircleShape2D.new()
			circle.radius = col_w * 0.5
			collision_shape.shape = circle


## Create and configure the captain's active ability from JSON data.
func _setup_captain_ability(captain_data: Dictionary) -> void:
	var ability_data: Dictionary = captain_data.get("active_ability", {})
	if ability_data.is_empty():
		return
	
	var template: String = ability_data.get("template", "")
	var ability: Node = null
	
	var ability_script: GDScript = null
	match template:
		"buff_self":
			ability_script = load("res://scripts/core/abilities/buff_self_ability.gd") as GDScript
		"area_effect":
			ability_script = load("res://scripts/core/abilities/area_effect_ability.gd") as GDScript
		_:
			push_warning("Ship: Unknown ability template: " + template)
			return
	
	if ability_script == null:
		push_warning("Ship: Failed to load ability script for template: " + template)
		return
	
	ability = ability_script.new()
	
	ability.name = "CaptainAbility"
	add_child(ability)
	ability.configure(ability_data, self, stats)
	
	# Forward signals
	ability.ability_activated.connect(func(): captain_ability_activated.emit())
	ability.ability_expired.connect(func(): captain_ability_expired.emit())
	ability.ability_ready.connect(func(): captain_ability_ready.emit())
	
	_captain_ability = ability


func _deferred_init() -> void:
	# Initialize from loadout data (deferred to ensure @onready vars ready)
	if not RunManager.run_data.ship_data.is_empty():
		_initialize_from_loadout(
			RunManager.run_data.ship_data,
			RunManager.run_data.captain_data,
			RunManager.run_data.synergy_data
		)
	else:
		# Default setup for testing without full run
		_setup_default_weapons()


func _setup_default_weapons() -> void:
	# Default weapon for testing (when running world scene directly)
	weapons.equip_weapon("radiant_arc")


## Recalculate the PickupRange collision shape radius from config base * stat multiplier.
func _update_pickup_range() -> void:
	var config: Node = get_node_or_null("/root/GameConfig")
	var pickup_area: Area2D = get_node_or_null("PickupRange")
	if not pickup_area or not config:
		return
	var shape: CollisionShape2D = pickup_area.get_node_or_null("PickupRangeShape")
	if not shape or not shape.shape is CircleShape2D:
		return
	var multiplier: float = 1.0
	if stats:
		multiplier = stats.get_stat(StatsComponentScript.STAT_PICKUP_RANGE)
	var new_radius: float = config.PICKUP_MAGNET_RADIUS * multiplier
	(shape.shape as CircleShape2D).radius = new_radius


func _on_stat_changed(stat_name: String, _old_value: float, _new_value: float) -> void:
	if stat_name == StatsComponentScript.STAT_PICKUP_RANGE:
		_update_pickup_range()


func _physics_process(delta: float) -> void:
	_process_phase_shift(delta)
	_process_phase_recharge(delta)
	_process_iframes(delta)
	_process_movement(delta)
	_process_camera_zoom(delta)


func _process_movement(delta: float) -> void:
	# Process knockback decay
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, GameConfig.PLAYER_KNOCKBACK_FRICTION * delta * 500)

	# Hybrid movement:
	# - Keyboard: 8-way digital (snapped)
	# - Controller: analog (preserve stick magnitude)
	var move_input: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var desired_dir: Vector2 = Vector2.ZERO
	if move_input.length() > 0.1:
		if _last_input_device == "keyboard":
			var x: float = 0.0
			var y: float = 0.0
			if absf(move_input.x) > 0.1:
				x = signf(move_input.x)
			if absf(move_input.y) > 0.1:
				y = signf(move_input.y)
			desired_dir = Vector2(x, y)
			if desired_dir.length() > 1.0:
				desired_dir = desired_dir.normalized()
		else:
			# Joypad analog: keep magnitude (for variable speed)
			desired_dir = move_input

		# Smoothly face the direction we're moving
		var face_dir: Vector2 = desired_dir
		if face_dir.length() > 0.001:
			face_dir = face_dir.normalized()
			var target_angle: float = face_dir.angle()
			rotation = lerp_angle(rotation, target_angle, min(1.0, GameConfig.PLAYER_TURN_RATE * delta))
	
	if _is_phasing:
		# During phase shift, move in phase direction at high speed
		var phase_distance: float = stats.get_stat(StatsComponentScript.STAT_PHASE_SHIFT_DISTANCE)
		velocity = _phase_direction * (phase_distance / GameConfig.PHASE_SHIFT_DURATION)
	else:
		# Normal movement + knockback
		var speed_mult: float = stats.get_stat(StatsComponentScript.STAT_MOVEMENT_SPEED)
		velocity = desired_dir * _base_speed * speed_mult + _knockback_velocity
	
	move_and_slide()
	
	# Track last move direction for phase shift
	if desired_dir.length() > 0.1:
		_last_move_direction = desired_dir.normalized()


func _process_camera_zoom(delta: float) -> void:
	if _camera == null:
		return
	var speed_mult: float = stats.get_stat(StatsComponentScript.STAT_MOVEMENT_SPEED)
	# Extra speed above baseline (1.0) pulls the camera back
	var speed_excess: float = maxf(speed_mult - 1.0, 0.0)
	var target_zoom: float = maxf(GameConfig.CAMERA_BASE_ZOOM - speed_excess * GameConfig.CAMERA_SPEED_ZOOM_FACTOR, GameConfig.CAMERA_MIN_ZOOM)
	var current_zoom: float = _camera.zoom.x
	var new_zoom: float = lerpf(current_zoom, target_zoom, minf(1.0, GameConfig.CAMERA_ZOOM_LERP * delta))
	_camera.zoom = Vector2(new_zoom, new_zoom)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		_last_input_device = "joypad"
	elif event is InputEventKey or event is InputEventMouseMotion or event is InputEventMouseButton:
		_last_input_device = "keyboard"

	if event.is_action_pressed("phase_shift"):
		_try_phase_shift()
	
	if event.is_action_pressed("captain_ability"):
		_try_captain_ability()


func _try_captain_ability() -> void:
	if _captain_ability and _captain_ability.try_activate():
		pass


func _try_phase_shift() -> void:
	if _is_phasing:
		return
	if _phase_cooldown_timer > 0:
		return
	if phase_energy <= 0:
		return
	
	# Start phase shift
	phase_energy -= 1
	phase_energy_changed.emit(phase_energy, max_phase_energy)
	
	_is_phasing = true
	_phase_timer = GameConfig.PHASE_SHIFT_DURATION
	_phase_cooldown_timer = GameConfig.PHASE_SHIFT_COOLDOWN
	_phase_direction = _last_move_direction
	
	# Grant i-frames
	_set_invincible(true)
	
	# Switch collision to obstacles-only during phase (keep asteroid/station body collisions)
	_normal_collision_layer = collision_layer
	_normal_collision_mask = collision_mask
	set_deferred("collision_layer", 0)    # Nothing can detect us
	set_deferred("collision_mask", 2)      # We only collide with layer 2 (obstacles)
	
	# Visual feedback
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.3, 0.05)
	
	phase_shift_started.emit()
	RunManager.record_phase()


func _process_phase_shift(delta: float) -> void:
	if not _is_phasing:
		return
	
	_phase_timer -= delta
	
	if _phase_timer <= 0:
		_end_phase_shift()


func _end_phase_shift() -> void:
	_is_phasing = false
	
	# Restore normal collision layers
	set_deferred("collision_layer", _normal_collision_layer)
	set_deferred("collision_mask", _normal_collision_mask)
	
	# Brief i-frames after phase ends
	_iframes_timer = GameConfig.POST_PHASE_IFRAMES
	
	# Visual feedback
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	
	phase_shift_ended.emit()


func _process_phase_recharge(delta: float) -> void:
	# Cooldown between phases
	if _phase_cooldown_timer > 0:
		_phase_cooldown_timer -= delta
	
	# Recharge energy
	if phase_energy < max_phase_energy:
		_phase_recharge_timer += delta
		if _phase_recharge_timer >= phase_recharge_time:
			_phase_recharge_timer = 0.0
			phase_energy += 1
			phase_energy_changed.emit(phase_energy, max_phase_energy)


# --- I-Frames ---

func _set_invincible(value: bool) -> void:
	_is_invincible = value


func _process_iframes(delta: float) -> void:
	if _iframes_timer > 0:
		_iframes_timer -= delta
		if _iframes_timer <= 0:
			_set_invincible(false)


# --- Damage ---

func take_damage(amount: float, source: Node = null) -> float:
	if _is_invincible or _is_phasing:
		return 0.0
	
	# Run damage interceptors (e.g. Nope Bubble shield)
	var intercepted_amount: float = amount
	for interceptor in _damage_interceptors:
		if interceptor.is_valid():
			intercepted_amount = interceptor.call(intercepted_amount, source)
			if intercepted_amount <= 0.0:
				return 0.0
	amount = intercepted_amount
	
	var actual_damage: float = stats.take_damage(amount, source)
	
	if actual_damage > 0:
		RunManager.record_damage_taken(actual_damage)
		_flash_damage()
		
		# Apply knockback away from source
		if source and source is Node2D:
			var source_2d: Node2D = source as Node2D
			var knockback_dir: Vector2 = (global_position - source_2d.global_position).normalized()
			_knockback_velocity = knockback_dir * GameConfig.PLAYER_KNOCKBACK_FORCE
		
		# Brief i-frames to prevent rapid damage
		_set_invincible(true)
		_iframes_timer = GameConfig.DAMAGE_IFRAMES
	
	return actual_damage


func register_damage_interceptor(callback: Callable) -> void:
	if not _damage_interceptors.has(callback):
		_damage_interceptors.append(callback)


func unregister_damage_interceptor(callback: Callable) -> void:
	_damage_interceptors.erase(callback)


func _flash_damage() -> void:
	if sprite:
		# More dramatic flash - white then red then back
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.02)
		tween.tween_property(sprite, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.08)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
		
		# Also flash during i-frames
		for i in range(3):
			tween.tween_property(sprite, "modulate:a", 0.3, 0.05)
			tween.tween_property(sprite, "modulate:a", 1.0, 0.05)


func heal(amount: float) -> void:
	stats.heal(amount)


## Apply an external force to the player (e.g., radiation belt push, wind).
## Force is added to knockback velocity and decays naturally.
func apply_external_force(force: Vector2) -> void:
	_knockback_velocity += force


# --- Signal Handlers ---

func _on_hp_changed(_current: float, _maximum: float) -> void:
	# Could emit signal for HUD update
	pass


func _on_died() -> void:
	# Disable controls and physics
	set_physics_process(false)
	set_process_input(false)
	
	# Disable collision so enemies pass through
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Death flash animation
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.4)
	
	# Propagate to RunManager so it can trigger game over
	died.emit()


func _on_level_up_completed(option: Dictionary) -> void:
	var type: String = option.get("type", "unknown")
	var id: String = option.get("id", "")
	
	if type == "upgrade":
		if stats.has_method("apply_level_up_upgrade"):
			stats.apply_level_up_upgrade(option)
		else:
			stats.apply_ship_upgrade(id)
	elif type == "weapon":
		if weapons and weapons.has_method("equip_weapon"):
			weapons.equip_weapon(id)
			var effects_any: Variant = option.get("effects", [])
			if effects_any is Array and weapons.has_method("apply_level_up_effects"):
				weapons.apply_level_up_effects(id, effects_any)
		else:
			weapons.sync_from_run_data()
	# Do not disable/free the ship here; selection should resume gameplay.


# --- Getters for external use ---

func get_stat(stat_name: String) -> float:
	return stats.get_stat(stat_name)


func is_invincible() -> bool:
	return _is_invincible or _is_phasing


# --- Test Mode API ---

## Get the WeaponComponent for external control (e.g., test lab).
func get_weapon_component() -> Node:
	return weapons


## Get the StatsComponent for external access (e.g., station buffs).
func get_stats() -> Node:
	return stats


## Fire a weapon with explicit config (for test lab).
func fire_weapon_manual(weapon_id: String, config: Dictionary) -> void:
	if weapons and weapons.has_method("fire_weapon_with_config"):
		weapons.fire_weapon_with_config(weapon_id, config, self)


## Equip a weapon in test mode (exclusive - clears other weapons first).
func equip_weapon_for_test(weapon_id: String) -> void:
	if weapons:
		if weapons.has_method("clear_all_weapons"):
			weapons.clear_all_weapons()
		if weapons.has_method("equip_weapon"):
			weapons.equip_weapon(weapon_id)
