class_name LootFreighter
extends BaseEnemy

## LootFreighter - Special loot mob enemy with a chase-then-flee state machine.
## Chases the player until hit once, then flees at player base speed.
## Drops a burst of XP or credits plus stardust on death.

enum FreighterState {
	CHASE,
	FLEE,
}

## What this freighter drops: "xp" or "credits"
@export var drop_type: String = "xp"

## How fast the freighter moves when fleeing (set from data)
@export var flee_speed: float = 90.0

## Number of pickup orbs to scatter on death (for jackpot feel)
@export var drop_burst_count: int = 5

var _state: FreighterState = FreighterState.CHASE
var _flee_direction: Vector2 = Vector2.ZERO
var _has_been_hit: bool = false

## Time spent fleeing — used to add slight direction drift
var _flee_timer: float = 0.0

## Small random drift interval to prevent perfectly straight flee paths
## Tuned in GameConfig: FREIGHTER_FLEE_DRIFT_INTERVAL, FREIGHTER_FLEE_DRIFT_ANGLE


func _ready() -> void:
	super._ready()
	enemy_type = "loot"
	_state = FreighterState.CHASE


func take_damage(amount: float, _source: Node = null) -> void:
	if _is_dying:
		return

	current_hp -= amount
	_flash_damage()

	# Transition to FLEE on first hit
	if not _has_been_hit:
		_has_been_hit = true
		_enter_flee_state()

	if current_hp <= 0:
		_die()


func _enter_flee_state() -> void:
	_state = FreighterState.FLEE
	_flee_timer = 0.0
	# Initial flee direction: directly away from player
	if _target:
		_flee_direction = (global_position - _target.global_position).normalized()
	else:
		_flee_direction = Vector2.RIGHT.rotated(randf() * TAU)


func _process_movement(delta: float) -> void:
	if not _target:
		_find_player()
		return

	match _state:
		FreighterState.CHASE:
			_chase_movement(delta)
		FreighterState.FLEE:
			_flee_movement(delta)


func _chase_movement(_delta: float) -> void:
	## Move toward the player at normal chase speed.
	var direction: Vector2 = (_target.global_position - global_position).normalized()
	var chase_velocity: Vector2 = direction * move_speed

	velocity = chase_velocity + _knockback_velocity

	if velocity.length() > 10:
		rotation = velocity.angle()


func _flee_movement(delta: float) -> void:
	## Move away from the player at flee_speed.
	## Periodically adds a small random drift so the path isn't perfectly linear.
	_flee_timer += delta

	# Update flee direction to always move away from current player position
	if _target:
		var away_dir: Vector2 = (global_position - _target.global_position).normalized()
		# Blend toward the live away direction for responsive fleeing
		_flee_direction = _flee_direction.lerp(away_dir, 2.0 * delta).normalized()

	# Add slight drift every interval to make movement less predictable
	if _flee_timer >= GameConfig.FREIGHTER_FLEE_DRIFT_INTERVAL:
		_flee_timer = 0.0
		var drift_angle: float = randf_range(-GameConfig.FREIGHTER_FLEE_DRIFT_ANGLE, GameConfig.FREIGHTER_FLEE_DRIFT_ANGLE)
		_flee_direction = _flee_direction.rotated(drift_angle).normalized()

	var flee_velocity: Vector2 = _flee_direction * flee_speed
	velocity = flee_velocity + _knockback_velocity

	if velocity.length() > 10:
		rotation = velocity.angle()
