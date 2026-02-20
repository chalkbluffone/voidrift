class_name BaseAbility
extends Node

## BaseAbility - Base class for captain active abilities.
## Handles cooldown timing, activation, and expiration.
## Subclasses override _activate() and _on_expire() for specific behavior.

signal ability_activated
signal ability_expired
signal cooldown_updated(remaining: float, total: float)
signal ability_ready

# --- Configuration (set from captain JSON) ---
var ability_id: String = ""
var ability_name: String = ""
var description: String = ""
var cooldown: float = GameConfig.ABILITY_DEFAULT_COOLDOWN
var duration: float = GameConfig.ABILITY_DEFAULT_DURATION
var effects: Dictionary = {}
var vfx_id: String = ""

# --- State ---
var _cooldown_remaining: float = 0.0
var _duration_remaining: float = 0.0
var _is_active: bool = false
var _owner_ship: Node = null
var _owner_stats: Node = null


## Configure from captain JSON ability data.
func configure(ability_data: Dictionary, ship: Node, stats: Node) -> void:
	ability_id = ability_data.get("id", "")
	ability_name = ability_data.get("name", "")
	description = ability_data.get("description", "")
	cooldown = float(ability_data.get("cooldown", GameConfig.ABILITY_DEFAULT_COOLDOWN))
	duration = float(ability_data.get("duration", GameConfig.ABILITY_DEFAULT_DURATION))
	effects = ability_data.get("effects", {})
	vfx_id = ability_data.get("vfx", "")
	_owner_ship = ship
	_owner_stats = stats


## Attempt to activate the ability. Returns true if successful.
func try_activate() -> bool:
	if _is_active:
		return false
	if _cooldown_remaining > 0.0:
		return false

	_is_active = true
	_duration_remaining = duration
	_cooldown_remaining = cooldown
	_activate()
	ability_activated.emit()
	return true


func is_ready() -> bool:
	return not _is_active and _cooldown_remaining <= 0.0


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func get_cooldown_percent() -> float:
	if cooldown <= 0.0:
		return 0.0
	return _cooldown_remaining / cooldown


func _process(delta: float) -> void:
	if _is_active:
		_duration_remaining -= delta
		if _duration_remaining <= 0.0:
			_is_active = false
			_on_expire()
			ability_expired.emit()

	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		cooldown_updated.emit(_cooldown_remaining, cooldown)
		if _cooldown_remaining <= 0.0:
			_cooldown_remaining = 0.0
			ability_ready.emit()


# --- Override in subclasses ---

## Called when the ability activates. Override in subclasses.
func _activate() -> void:
	pass


## Called when the ability duration ends. Override in subclasses.
func _on_expire() -> void:
	pass
