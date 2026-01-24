extends CharacterBody2D

## Player ship controller with StatsComponent, Phase Shift, and i-frames.
## Tank controls: W thrusts forward, A/D turns, S moves down.

signal phase_shift_started
signal phase_shift_ended
signal phase_energy_changed(current: int, maximum: int)

# --- Preloads ---
const StatsComponentScript := preload("res://scripts/core/stats_component.gd")

# --- Components ---
@onready var stats: Node = $StatsComponent
@onready var weapons: Node = $WeaponComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var GameManager: Node = get_node("/root/GameManager")
@onready var FileLogger: Node = get_node("/root/FileLogger")

# --- Phase Shift ---
const PHASE_SHIFT_DURATION := 0.3  # How long the dash lasts
const PHASE_SHIFT_COOLDOWN := 0.5  # Min time between phases
const PHASE_SHIFT_DISTANCE := 250.0  # How far we dash

@export var max_phase_energy: int = 3
var phase_energy: int = 3
var phase_recharge_time: float = 3.0  # Seconds to recharge one charge
var _phase_recharge_timer: float = 0.0
var _is_phasing: bool = false
var _phase_timer: float = 0.0
var _phase_cooldown_timer: float = 0.0
var _phase_direction: Vector2 = Vector2.ZERO

# --- I-Frames ---
var _iframes_timer: float = 0.0
var _is_invincible: bool = false

# --- Movement ---
var _base_speed: float = 100.0  # Will be set from GameConfig in _ready
var _last_move_direction: Vector2 = Vector2.RIGHT
var _knockback_velocity: Vector2 = Vector2.ZERO
var _last_input_device: String = "keyboard" # "keyboard" or "joypad"
const KNOCKBACK_FRICTION := 10.0
const DAMAGE_IFRAMES := 0.5  # Brief i-frames after taking damage


func _ready() -> void:
	FileLogger.log_info("Ship", "Initializing player ship...")
	
	# Set base speed from config
	var config: Node = get_node("/root/GameConfig")
	_base_speed = config.PLAYER_BASE_SPEED
	
	# Set pickup range from config
	var pickup_range: Area2D = get_node_or_null("PickupRange")
	if pickup_range:
		var shape: CollisionShape2D = pickup_range.get_node_or_null("PickupRangeShape")
		if shape and shape.shape is CircleShape2D:
			(shape.shape as CircleShape2D).radius = config.PICKUP_MAGNET_RADIUS
	
	# Register with GameManager
	GameManager.register_player(self)
	
	# Listen for level ups
	if not GameManager.level_up_completed.is_connected(_on_level_up_completed):
		GameManager.level_up_completed.connect(_on_level_up_completed)
	
	# Connect stats signals
	stats.hp_changed.connect(_on_hp_changed)
	stats.died.connect(_on_died)
	
	phase_energy = max_phase_energy
	phase_energy_changed.emit(phase_energy, max_phase_energy)
	
	# Defer weapon setup to ensure all @onready vars are initialized
	call_deferred("_deferred_init")


func _initialize_from_character(character_data: Dictionary) -> void:
	stats.initialize_from_character(character_data)
	
	# Set phase shift variant
	var phase_shift: Dictionary = character_data.get("phase_shift", {})
	max_phase_energy = phase_shift.get("energy_charges", 3)
	phase_energy = max_phase_energy
	
	# Get base speed from character
	var base_stats: Dictionary = character_data.get("base_stats", {})
	_base_speed = base_stats.get("base_speed", 450.0)
	
	# Equip weapons from run data
	weapons.sync_from_run_data()


func _deferred_init() -> void:
	FileLogger.log_info("Ship", "Running deferred init...")
	# Initialize from character data (deferred to ensure @onready vars ready)
	if not GameManager.run_data.character_data.is_empty():
		FileLogger.log_info("Ship", "Initializing from character data")
		_initialize_from_character(GameManager.run_data.character_data)
	else:
		# Default setup for testing without full run
		FileLogger.log_info("Ship", "No character data, setting up default weapons")
		_setup_default_weapons()


func _setup_default_weapons() -> void:
	# Default weapon for testing
	weapons.equip_weapon("plasma_cannon")


func _physics_process(delta: float) -> void:
	_process_phase_shift(delta)
	_process_phase_recharge(delta)
	_process_iframes(delta)
	_process_movement(delta)


func _process_movement(delta: float) -> void:
	# Process knockback decay
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta * 500)

	# Hybrid movement:
	# - Keyboard: 8-way digital (snapped)
	# - Controller: analog (preserve stick magnitude)
	var move_input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var desired_dir := Vector2.ZERO
	if move_input.length() > 0.1:
		if _last_input_device == "keyboard":
			var x := 0.0
			var y := 0.0
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
		var face_dir := desired_dir
		if face_dir.length() > 0.001:
			face_dir = face_dir.normalized()
			var target_angle := face_dir.angle()
			rotation = lerp_angle(rotation, target_angle, min(1.0, GameConfig.PLAYER_TURN_RATE * delta))
	
	if _is_phasing:
		# During phase shift, move in phase direction at high speed
		velocity = _phase_direction * (PHASE_SHIFT_DISTANCE / PHASE_SHIFT_DURATION)
	else:
		# Normal movement + knockback
		var speed_mult: float = stats.get_stat(StatsComponentScript.STAT_MOVEMENT_SPEED)
		velocity = desired_dir * _base_speed * speed_mult + _knockback_velocity
	
	move_and_slide()
	
	# Track last move direction for phase shift
	if desired_dir.length() > 0.1:
		_last_move_direction = desired_dir.normalized()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		_last_input_device = "joypad"
	elif event is InputEventKey or event is InputEventMouseMotion or event is InputEventMouseButton:
		_last_input_device = "keyboard"

	if event.is_action_pressed("phase_shift"):
		_try_phase_shift()


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
	_phase_timer = PHASE_SHIFT_DURATION
	_phase_cooldown_timer = PHASE_SHIFT_COOLDOWN
	_phase_direction = _last_move_direction
	
	# Grant i-frames
	_set_invincible(true)
	
	# Disable collision during phase
	collision_shape.set_deferred("disabled", true)
	
	# Visual feedback
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.3, 0.05)
	
	phase_shift_started.emit()
	GameManager.record_phase()


func _process_phase_shift(delta: float) -> void:
	if not _is_phasing:
		return
	
	_phase_timer -= delta
	
	if _phase_timer <= 0:
		_end_phase_shift()


func _end_phase_shift() -> void:
	_is_phasing = false
	
	# Re-enable collision
	collision_shape.set_deferred("disabled", false)
	
	# Brief i-frames after phase ends
	_iframes_timer = 0.2
	
	# Visual feedback
	if sprite:
		var tween := create_tween()
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
	
	var actual_damage: float = stats.take_damage(amount, source)
	
	if actual_damage > 0:
		GameManager.record_damage_taken(actual_damage)
		_flash_damage()
		
		# Apply knockback away from source
		if source and source is Node2D:
			var source_2d: Node2D = source as Node2D
			var knockback_dir: Vector2 = (global_position - source_2d.global_position).normalized()
			_knockback_velocity = knockback_dir * 400
		
		# Brief i-frames to prevent rapid damage
		_set_invincible(true)
		_iframes_timer = DAMAGE_IFRAMES
	
	return actual_damage


func _flash_damage() -> void:
	if sprite:
		# More dramatic flash - white then red then back
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.02)
		tween.tween_property(sprite, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.08)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
		
		# Also flash during i-frames
		for i in range(3):
			tween.tween_property(sprite, "modulate:a", 0.3, 0.05)
			tween.tween_property(sprite, "modulate:a", 1.0, 0.05)


func heal(amount: float) -> void:
	stats.heal(amount)


# --- Signal Handlers ---

func _on_hp_changed(_current: float, _maximum: float) -> void:
	# Could emit signal for HUD update
	pass


func _on_died() -> void:
	# GameManager handles run end via signal connection
	# Play death animation, disable controls, etc.
	set_physics_process(false)


func _on_level_up_completed(option: Dictionary) -> void:
	var type: String = option.get("type", "unknown")
	var id: String = option.get("id", "")
	
	if type == "upgrade":
		FileLogger.log_info("Ship", "Applying upgrade: " + id)
		if stats.has_method("apply_level_up_upgrade"):
			stats.apply_level_up_upgrade(option)
		else:
			stats.apply_ship_upgrade(id)
	elif type == "weapon":
		FileLogger.log_info("Ship", "Equipping weapon: " + id)
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
