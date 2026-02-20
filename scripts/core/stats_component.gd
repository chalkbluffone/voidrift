class_name StatsComponent
extends Node

## StatsComponent - Tracks all stats for an entity with base values, flat bonuses, and multipliers.
## Attach to player ship or enemies. Supports temporary buffs and stat recalculation.

signal stat_changed(stat_name: String, old_value: float, new_value: float)
signal hp_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal died

# Autoload references
var DataLoader: Node

# --- Stat Names (constants for type safety) ---
const STAT_MAX_HP: String = "max_hp"
const STAT_HP_REGEN: String = "hp_regen"
const STAT_SHIELD: String = "shield"
const STAT_ARMOR: String = "armor"
const STAT_EVASION: String = "evasion"
const STAT_LIFESTEAL: String = "lifesteal"
const STAT_HULL_SHOCK: String = "hull_shock"
const STAT_OVERHEAL: String = "overheal"

const STAT_DAMAGE: String = "damage"
const STAT_CRIT_CHANCE: String = "crit_chance"
const STAT_CRIT_DAMAGE: String = "crit_damage"
const STAT_ATTACK_SPEED: String = "attack_speed"
const STAT_PROJECTILE_COUNT: String = "projectile_count"
const STAT_PROJECTILE_SPEED: String = "projectile_speed"
const STAT_PROJECTILE_BOUNCES: String = "projectile_bounces"
const STAT_SIZE: String = "size"
const STAT_DURATION: String = "duration"
const STAT_KNOCKBACK: String = "knockback"

const STAT_MOVEMENT_SPEED: String = "movement_speed"
const STAT_EXTRA_PHASE_SHIFTS: String = "extra_phase_shifts"
const STAT_PHASE_SHIFT_DISTANCE: String = "phase_shift_distance"
const STAT_PICKUP_RANGE: String = "pickup_range"
const STAT_XP_GAIN: String = "xp_gain"
const STAT_CREDITS_GAIN: String = "credits_gain"
const STAT_STARDUST_GAIN: String = "stardust_gain"
const STAT_LUCK: String = "luck"
const STAT_DIFFICULTY: String = "difficulty"
const STAT_ELITE_SPAWN_RATE: String = "elite_spawn_rate"
const STAT_POWERUP_MULTIPLIER: String = "powerup_multiplier"
const STAT_POWERUP_DROP_CHANCE: String = "powerup_drop_chance"
const STAT_DAMAGE_TO_ELITES: String = "damage_to_elites"

# Default base values for player (fallback if base_player_stats.json fails to load)
const DEFAULT_BASE_STATS: Dictionary = {
	STAT_MAX_HP: 100.0,
	STAT_HP_REGEN: 5.0,  # per minute
	STAT_OVERHEAL: 0.0,  # extra HP above max_hp
	STAT_SHIELD: 0.0,
	STAT_ARMOR: 0.0,  # percentage
	STAT_EVASION: 0.0,  # percentage
	STAT_LIFESTEAL: 0.0,  # percentage
	STAT_HULL_SHOCK: 0.0,  # damage reflected to attackers
	
	STAT_DAMAGE: 1.0,  # multiplier
	STAT_CRIT_CHANCE: 1.0,  # percentage
	STAT_CRIT_DAMAGE: 2.0,  # multiplier
	STAT_ATTACK_SPEED: 1.0,  # multiplier
	STAT_PROJECTILE_COUNT: 0.0,  # bonus (added to weapon base)
	STAT_PROJECTILE_SPEED: 1.0,  # multiplier
	STAT_PROJECTILE_BOUNCES: 0.0,  # flat
	STAT_SIZE: 1.0,  # multiplier
	STAT_DURATION: 1.0,  # multiplier
	STAT_KNOCKBACK: 1.0,  # multiplier
	
	STAT_MOVEMENT_SPEED: 1.0,  # multiplier
	STAT_EXTRA_PHASE_SHIFTS: 0.0,  # bonus charges added to character base
	STAT_PHASE_SHIFT_DISTANCE: 250.0,  # pixels
	STAT_PICKUP_RANGE: 1.0,  # multiplier
	STAT_XP_GAIN: 1.0,  # multiplier (capped at 10x)
	STAT_CREDITS_GAIN: 1.0,  # multiplier
	STAT_STARDUST_GAIN: 1.0,  # multiplier
	STAT_LUCK: 0.0,  # percentage bonus
	STAT_DIFFICULTY: 0.0,  # percentage
	STAT_ELITE_SPAWN_RATE: 1.0,  # multiplier
	STAT_POWERUP_MULTIPLIER: 1.0,  # multiplier
	STAT_POWERUP_DROP_CHANCE: 1.0,  # multiplier
	STAT_DAMAGE_TO_ELITES: 1.0,  # multiplier
}

# Stats that use diminishing returns (armor, evasion)
const DIMINISHING_STATS: Array[String] = [STAT_ARMOR, STAT_EVASION]

# Stats that are capped — loaded from GameConfig
var STAT_CAPS: Dictionary = {}

# Reference to GameConfig autoload
var GameConfig: Node

# --- Instance Data ---

# Base stats (from character + passive)
var base_stats: Dictionary = {}

# Flat bonuses (from items, tomes, shrines)
var flat_bonuses: Dictionary = {}

# Multiplier bonuses (percentage increases)
var multiplier_bonuses: Dictionary = {}

# Cached final values
var _cached_stats: Dictionary = {}
var _cache_dirty: bool = true

# Current HP and Shield (not max)
var current_hp: float = 0.0
var current_shield: float = 0.0
var shield_recharge_timer: float = 0.0

# HP Regen accumulator
var _regen_accumulator: float = 0.0


func _ready() -> void:
	# Get autoload references
	DataLoader = get_node_or_null("/root/DataLoader")
	GameConfig = get_node_or_null("/root/GameConfig")
	
	# Load stat caps from GameConfig
	if GameConfig:
		STAT_CAPS = GameConfig.STAT_CAPS.duplicate()
	
	# Start with hardcoded defaults as fallback
	for stat_name in DEFAULT_BASE_STATS:
		base_stats[stat_name] = DEFAULT_BASE_STATS[stat_name]
		flat_bonuses[stat_name] = 0.0
		multiplier_bonuses[stat_name] = 0.0
	
	# Override with data-driven base stats from JSON (single source of truth)
	if DataLoader:
		var json_stats: Dictionary = DataLoader.get_base_player_stats()
		for stat_name in json_stats:
			if base_stats.has(stat_name):
				base_stats[stat_name] = float(json_stats[stat_name])
	
	_recalculate_all()
	current_hp = get_stat(STAT_MAX_HP)
	current_shield = get_stat(STAT_SHIELD)

## Apply a single stack of a ship upgrade.
func apply_ship_upgrade(upgrade_id: String) -> void:
	if not DataLoader:
		push_error("StatsComponent: DataLoader not available")
		return
	
	var upgrade_data: Dictionary = DataLoader.get_ship_upgrade(upgrade_id)
	if upgrade_data.is_empty():
		return
	
	var stat_name: String = upgrade_data.get("stat", "")
	var per_level: float = upgrade_data.get("per_level", 0.0)
	if stat_name == "" or per_level == 0.0:
		return

	_apply_effect(stat_name, per_level)


## Apply upgrade effects from a level-up option (supports multiple effects).
func apply_level_up_upgrade(option: Dictionary) -> void:
	var effects: Array = option.get("effects", [])
	if effects.is_empty():
		# Back-compat: apply by id if no effects were generated.
		apply_ship_upgrade(String(option.get("id", "")))
		return

	for effect in effects:
		if effect is Dictionary:
			var stat_name: String = effect.get("stat", "")
			var kind: String = effect.get("kind", "mult")
			var amount: float = float(effect.get("amount", 0.0))
			if stat_name == "" or amount == 0.0:
				continue
			if kind == "flat":
				add_flat_bonus(stat_name, amount)
				_apply_post_gain(stat_name, amount)
			else:
				add_multiplier_bonus(stat_name, amount)


func _apply_effect(stat_name: String, per_level_raw: float) -> void:
	# Some data are stored as percent points (e.g. 15 means 15%), while others are flat.
	var flat_stats: Dictionary = {
		STAT_MAX_HP: true,
		STAT_HP_REGEN: true,
		STAT_OVERHEAL: true,
		STAT_SHIELD: true,
		STAT_HULL_SHOCK: true,
		STAT_PROJECTILE_COUNT: true,
		STAT_PROJECTILE_BOUNCES: true,
		STAT_EXTRA_PHASE_SHIFTS: true,
		STAT_PHASE_SHIFT_DISTANCE: true,
	}
	var percent_point_stats: Dictionary = {
		STAT_ARMOR: true,
		STAT_EVASION: true,
		STAT_CRIT_CHANCE: true,
		STAT_LUCK: true,
		STAT_DIFFICULTY: true,
	}

	if flat_stats.has(stat_name) or percent_point_stats.has(stat_name):
		add_flat_bonus(stat_name, per_level_raw)
		_apply_post_gain(stat_name, per_level_raw)
		return

	# Multiplier stat: store as fraction. If the data looks like percent points, convert.
	var amount: float = per_level_raw
	if absf(amount) >= 1.0:
		amount = amount / 100.0
	add_multiplier_bonus(stat_name, amount)


func _apply_post_gain(stat_name: String, flat_amount: float) -> void:
	# Keep the player from feeling "punished" when max HP/Shield increases.
	if stat_name == STAT_MAX_HP and flat_amount > 0.0:
		current_hp = minf(current_hp + flat_amount, get_stat(STAT_MAX_HP))
		hp_changed.emit(current_hp, get_stat(STAT_MAX_HP))
	elif stat_name == STAT_SHIELD and flat_amount > 0.0:
		current_shield = minf(current_shield + flat_amount, get_stat(STAT_SHIELD))
		shield_changed.emit(current_shield, get_stat(STAT_SHIELD))

func _process(delta: float) -> void:
	_process_hp_regen(delta)
	_process_shield_recharge(delta)


# --- Initialization ---

## Initialize stats from ship + captain + synergy data.
func initialize_from_loadout(ship_data: Dictionary, captain_data: Dictionary, synergy_data: Dictionary) -> void:
	# Layer 1: Ship stat overrides (replace base values)
	var ship_base_stats: Dictionary = ship_data.get("base_stats", {})
	for stat_name in ship_base_stats:
		if base_stats.has(stat_name):
			base_stats[stat_name] = float(ship_base_stats[stat_name])
	
	# Layer 2: Captain passive effects (flat bonuses)
	var passive: Dictionary = captain_data.get("passive", {})
	var passive_effects: Dictionary = passive.get("effects", {})
	for stat_name in passive_effects:
		add_flat_bonus(stat_name, float(passive_effects[stat_name]))
	
	# Layer 3: Synergy effects (flat bonuses, small nudges)
	var synergy_effects: Dictionary = synergy_data.get("effects", {})
	for stat_name in synergy_effects:
		add_flat_bonus(stat_name, float(synergy_effects[stat_name]))
	
	_recalculate_all()
	current_hp = get_stat(STAT_MAX_HP)
	current_shield = get_stat(STAT_SHIELD)


# --- Stat Modification ---

func add_flat_bonus(stat_name: String, amount: float) -> void:
	if not flat_bonuses.has(stat_name):
		flat_bonuses[stat_name] = 0.0
	flat_bonuses[stat_name] += amount
	_mark_dirty()


func remove_flat_bonus(stat_name: String, amount: float) -> void:
	add_flat_bonus(stat_name, -amount)


## Add a percentage multiplier (e.g., 0.1 = +10%).
func add_multiplier_bonus(stat_name: String, amount: float) -> void:
	if not multiplier_bonuses.has(stat_name):
		multiplier_bonuses[stat_name] = 0.0
	multiplier_bonuses[stat_name] += amount
	_mark_dirty()


func remove_multiplier_bonus(stat_name: String, amount: float) -> void:
	add_multiplier_bonus(stat_name, -amount)


func set_base_stat(stat_name: String, value: float) -> void:
	base_stats[stat_name] = value
	_mark_dirty()


# --- Stat Retrieval ---

func get_stat(stat_name: String) -> float:
	if _cache_dirty:
		_recalculate_all()
	return _cached_stats.get(stat_name, 0.0)


func get_stat_int(stat_name: String) -> int:
	return int(get_stat(stat_name))


func _recalculate_all() -> void:
	for stat_name in base_stats:
		var old_value: float = _cached_stats.get(stat_name, 0.0)
		var new_value: float = _calculate_stat(stat_name)
		_cached_stats[stat_name] = new_value
		
		if old_value != new_value:
			stat_changed.emit(stat_name, old_value, new_value)
	
	_cache_dirty = false


func _calculate_stat(stat_name: String) -> float:
	var base: float = base_stats.get(stat_name, 0.0)
	var flat: float = flat_bonuses.get(stat_name, 0.0)
	var mult: float = multiplier_bonuses.get(stat_name, 0.0)
	
	var result: float
	
	if stat_name in DIMINISHING_STATS:
		# Diminishing returns formula for armor/evasion
		var raw: float = base + flat
		result = _apply_diminishing_returns(raw)
	else:
		# Standard formula: (base + flat) * (1 + mult)
		result = (base + flat) * (1.0 + mult)
	
	# Apply caps
	if STAT_CAPS.has(stat_name):
		result = minf(result, STAT_CAPS[stat_name])
	
	return result


## Apply diminishing returns curve. Higher values become less effective.\n## Denominator tuned via GameConfig.DIMINISHING_RETURNS_DENOMINATOR.
func _apply_diminishing_returns(raw_value: float) -> float:
	# Formula: effective = raw / (raw + DENOM)
	# At DENOM raw, you get 50% effective
	# At 2*DENOM raw, you get 66% effective
	if raw_value <= 0:
		return 0.0
	var denom: float = GameConfig.DIMINISHING_RETURNS_DENOMINATOR if GameConfig else 100.0
	return (raw_value / (raw_value + denom)) * 100.0


func _mark_dirty() -> void:
	_cache_dirty = true


# --- HP & Damage ---

## Apply damage after armor/evasion. Returns actual damage taken.
func take_damage(amount: float, source: Node = null) -> float:
	# Check evasion
	var evasion: float = get_stat(STAT_EVASION)
	if randf() * 100.0 < evasion:
		# Dodged!
		return 0.0
	
	# Apply armor reduction
	var armor: float = get_stat(STAT_ARMOR)
	var damage_mult: float = 1.0 - (armor / 100.0)
	var actual_damage: float = amount * damage_mult
	
	# Shield absorbs first
	if current_shield > 0:
		if current_shield >= actual_damage:
			current_shield -= actual_damage
			shield_recharge_timer = GameConfig.SHIELD_RECHARGE_DELAY
			shield_changed.emit(current_shield, get_stat(STAT_SHIELD))
			return actual_damage
		else:
			actual_damage -= current_shield
			current_shield = 0
			shield_recharge_timer = GameConfig.SHIELD_RECHARGE_DELAY
			shield_changed.emit(current_shield, get_stat(STAT_SHIELD))
	
	# Apply to HP
	current_hp -= actual_damage
	hp_changed.emit(current_hp, get_stat(STAT_MAX_HP))
	
	# Hull Shock damage
	var hull_shock: float = get_stat(STAT_HULL_SHOCK)
	if hull_shock > 0 and source != null and source.has_method("take_damage"):
		source.take_damage(hull_shock, self)
	
	# Check death
	if current_hp <= 0:
		current_hp = 0
		died.emit()
	
	return actual_damage


## Heal HP. Returns actual amount healed. If allow_overheal is true, can exceed max_hp up to max_hp + overheal.
func heal(amount: float, allow_overheal: bool = false) -> float:
	var max_hp: float = get_stat(STAT_MAX_HP)
	var hp_cap: float = max_hp
	if allow_overheal:
		hp_cap = max_hp + get_stat(STAT_OVERHEAL)
	var old_hp: float = current_hp
	current_hp = minf(current_hp + amount, hp_cap)
	var healed: float = current_hp - old_hp
	
	if healed > 0:
		hp_changed.emit(current_hp, max_hp)
	
	return healed


func _process_hp_regen(delta: float) -> void:
	var regen_per_minute: float = get_stat(STAT_HP_REGEN)
	if regen_per_minute <= 0:
		return
	
	var regen_per_second: float = regen_per_minute / 60.0
	_regen_accumulator += regen_per_second * delta
	
	if _regen_accumulator >= 1.0:
		var to_heal: float = floor(_regen_accumulator)
		_regen_accumulator -= to_heal
		heal(to_heal)


func _process_shield_recharge(delta: float) -> void:
	var max_shield: float = get_stat(STAT_SHIELD)
	if max_shield <= 0 or current_shield >= max_shield:
		return
	
	if shield_recharge_timer > 0:
		shield_recharge_timer -= delta
		return
	
	current_shield = minf(current_shield + GameConfig.SHIELD_RECHARGE_RATE * delta, max_shield)
	shield_changed.emit(current_shield, max_shield)


# --- Combat Calculations ---

## Calculate final damage with crit. Returns {damage: float, is_crit: bool, is_overcrit: bool}.
func calculate_damage(base_damage: float, weapon_crit_chance: float = 0.0, weapon_crit_damage: float = 0.0) -> Dictionary:
	var damage_mult: float = get_stat(STAT_DAMAGE)
	var crit_chance: float = get_stat(STAT_CRIT_CHANCE) + weapon_crit_chance
	var crit_damage: float = get_stat(STAT_CRIT_DAMAGE) + weapon_crit_damage
	
	var final_damage: float = base_damage * damage_mult
	var is_crit: bool = false
	var is_overcrit: bool = false
	
	# Check for crit
	var roll: float = randf() * 100.0
	if roll < crit_chance:
		is_crit = true
		final_damage *= crit_damage
		
		# Check for overcrit (crit chance > 100%)
		if crit_chance > 100.0 and roll < (crit_chance - 100.0):
			is_overcrit = true
			final_damage *= crit_damage
	
	return {
		"damage": final_damage,
		"is_crit": is_crit,
		"is_overcrit": is_overcrit
	}


## Roll for lifesteal proc. Returns true if should heal 1 HP.
func roll_lifesteal() -> bool:
	var lifesteal: float = get_stat(STAT_LIFESTEAL)
	if lifesteal <= 0:
		return false
	
	var roll: float = randf() * 100.0
	if roll < lifesteal:
		heal(1)
		# Check for double heal (lifesteal > 100%)
		if lifesteal > 100.0 and roll < (lifesteal - 100.0):
			heal(1)
		return true
	return false


## Roll for evasion. Returns true if attack should be dodged.
func roll_evasion() -> bool:
	var evasion: float = get_stat(STAT_EVASION)
	return randf() * 100.0 < evasion


# --- Debug ---

func print_stats() -> void:
	print("=== Stats ===")
	for stat_name in _cached_stats:
		print("%s: %.2f" % [stat_name, _cached_stats[stat_name]])
