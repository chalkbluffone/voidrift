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
const STAT_MAX_HP := "max_hp"
const STAT_HP_REGEN := "hp_regen"
const STAT_SHIELD := "shield"
const STAT_ARMOR := "armor"
const STAT_EVASION := "evasion"
const STAT_LIFESTEAL := "lifesteal"
const STAT_HULL_SHOCK := "hull_shock"
const STAT_OVERHEAL := "overheal"

const STAT_DAMAGE := "damage"
const STAT_CRIT_CHANCE := "crit_chance"
const STAT_CRIT_DAMAGE := "crit_damage"
const STAT_ATTACK_SPEED := "attack_speed"
const STAT_PROJECTILE_COUNT := "projectile_count"
const STAT_PROJECTILE_SPEED := "projectile_speed"
const STAT_PROJECTILE_BOUNCES := "projectile_bounces"
const STAT_SIZE := "size"
const STAT_DURATION := "duration"
const STAT_KNOCKBACK := "knockback"

const STAT_MOVEMENT_SPEED := "movement_speed"
const STAT_EXTRA_PHASE_SHIFTS := "extra_phase_shifts"
const STAT_PHASE_SHIFT_DISTANCE := "phase_shift_distance"
const STAT_PICKUP_RANGE := "pickup_range"
const STAT_XP_GAIN := "xp_gain"
const STAT_CREDITS_GAIN := "credits_gain"
const STAT_STARDUST_GAIN := "stardust_gain"
const STAT_LUCK := "luck"
const STAT_DIFFICULTY := "difficulty"
const STAT_ELITE_SPAWN_RATE := "elite_spawn_rate"
const STAT_POWERUP_MULTIPLIER := "powerup_multiplier"
const STAT_POWERUP_DROP_CHANCE := "powerup_drop_chance"
const STAT_DAMAGE_TO_ELITES := "damage_to_elites"

# Default base values for player (fallback if base_player_stats.json fails to load)
const DEFAULT_BASE_STATS := {
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
const DIMINISHING_STATS := [STAT_ARMOR, STAT_EVASION]

# Stats that are capped
const STAT_CAPS := {
	STAT_XP_GAIN: 10.0,
	STAT_ARMOR: 90.0,
	STAT_EVASION: 90.0,
}

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
const SHIELD_RECHARGE_DELAY := 5.0
const SHIELD_RECHARGE_RATE := 10.0  # per second

# HP Regen accumulator
var _regen_accumulator: float = 0.0


func _ready() -> void:
	# Get autoload references
	DataLoader = get_node_or_null("/root/DataLoader")
	
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

func apply_ship_upgrade(upgrade_id: String) -> void:
	"""Apply a single stack of a ship upgrade."""
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


func apply_level_up_upgrade(option: Dictionary) -> void:
	"""Apply upgrade effects from a level-up option (supports multiple effects)."""
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
	var flat_stats := {
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
	var percent_point_stats := {
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
	var amount := per_level_raw
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

func initialize_from_loadout(ship_data: Dictionary, captain_data: Dictionary, synergy_data: Dictionary) -> void:
	"""Initialize stats from ship + captain + synergy data."""
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


func add_multiplier_bonus(stat_name: String, amount: float) -> void:
	"""Add a percentage multiplier (e.g., 0.1 = +10%)."""
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
		var new_value := _calculate_stat(stat_name)
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
		var raw := base + flat
		result = _apply_diminishing_returns(raw)
	else:
		# Standard formula: (base + flat) * (1 + mult)
		result = (base + flat) * (1.0 + mult)
	
	# Apply caps
	if STAT_CAPS.has(stat_name):
		result = minf(result, STAT_CAPS[stat_name])
	
	return result


func _apply_diminishing_returns(raw_value: float) -> float:
	"""Apply diminishing returns curve. Higher values become less effective."""
	# Formula: effective = raw / (raw + 100)
	# At 100 raw, you get 50% effective
	# At 200 raw, you get 66% effective
	if raw_value <= 0:
		return 0.0
	return (raw_value / (raw_value + 100.0)) * 100.0


func _mark_dirty() -> void:
	_cache_dirty = true


# --- HP & Damage ---

func take_damage(amount: float, source: Node = null) -> float:
	"""Apply damage after armor/evasion. Returns actual damage taken."""
	# Check evasion
	var evasion := get_stat(STAT_EVASION)
	if randf() * 100.0 < evasion:
		# Dodged!
		return 0.0
	
	# Apply armor reduction
	var armor := get_stat(STAT_ARMOR)
	var damage_mult := 1.0 - (armor / 100.0)
	var actual_damage := amount * damage_mult
	
	# Shield absorbs first
	if current_shield > 0:
		if current_shield >= actual_damage:
			current_shield -= actual_damage
			shield_recharge_timer = SHIELD_RECHARGE_DELAY
			shield_changed.emit(current_shield, get_stat(STAT_SHIELD))
			return actual_damage
		else:
			actual_damage -= current_shield
			current_shield = 0
			shield_recharge_timer = SHIELD_RECHARGE_DELAY
			shield_changed.emit(current_shield, get_stat(STAT_SHIELD))
	
	# Apply to HP
	current_hp -= actual_damage
	hp_changed.emit(current_hp, get_stat(STAT_MAX_HP))
	
	# Hull Shock damage
	var hull_shock := get_stat(STAT_HULL_SHOCK)
	if hull_shock > 0 and source != null and source.has_method("take_damage"):
		source.take_damage(hull_shock, self)
	
	# Check death
	if current_hp <= 0:
		current_hp = 0
		died.emit()
	
	return actual_damage


func heal(amount: float, allow_overheal: bool = false) -> float:
	"""Heal HP. Returns actual amount healed. If allow_overheal is true, can exceed max_hp up to max_hp + overheal."""
	var max_hp := get_stat(STAT_MAX_HP)
	var hp_cap := max_hp
	if allow_overheal:
		hp_cap = max_hp + get_stat(STAT_OVERHEAL)
	var old_hp := current_hp
	current_hp = minf(current_hp + amount, hp_cap)
	var healed := current_hp - old_hp
	
	if healed > 0:
		hp_changed.emit(current_hp, max_hp)
	
	return healed


func _process_hp_regen(delta: float) -> void:
	var regen_per_minute := get_stat(STAT_HP_REGEN)
	if regen_per_minute <= 0:
		return
	
	var regen_per_second := regen_per_minute / 60.0
	_regen_accumulator += regen_per_second * delta
	
	if _regen_accumulator >= 1.0:
		var to_heal: float = floor(_regen_accumulator)
		_regen_accumulator -= to_heal
		heal(to_heal)


func _process_shield_recharge(delta: float) -> void:
	var max_shield := get_stat(STAT_SHIELD)
	if max_shield <= 0 or current_shield >= max_shield:
		return
	
	if shield_recharge_timer > 0:
		shield_recharge_timer -= delta
		return
	
	current_shield = minf(current_shield + SHIELD_RECHARGE_RATE * delta, max_shield)
	shield_changed.emit(current_shield, max_shield)


# --- Combat Calculations ---

func calculate_damage(base_damage: float, weapon_crit_chance: float = 0.0, weapon_crit_damage: float = 0.0) -> Dictionary:
	"""Calculate final damage with crit. Returns {damage: float, is_crit: bool, is_overcrit: bool}."""
	var damage_mult := get_stat(STAT_DAMAGE)
	var crit_chance := get_stat(STAT_CRIT_CHANCE) + weapon_crit_chance
	var crit_damage := get_stat(STAT_CRIT_DAMAGE) + weapon_crit_damage
	
	var final_damage := base_damage * damage_mult
	var is_crit := false
	var is_overcrit := false
	
	# Check for crit
	var roll := randf() * 100.0
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


func roll_lifesteal() -> bool:
	"""Roll for lifesteal proc. Returns true if should heal 1 HP."""
	var lifesteal := get_stat(STAT_LIFESTEAL)
	if lifesteal <= 0:
		return false
	
	var roll := randf() * 100.0
	if roll < lifesteal:
		heal(1)
		# Check for double heal (lifesteal > 100%)
		if lifesteal > 100.0 and roll < (lifesteal - 100.0):
			heal(1)
		return true
	return false


func roll_evasion() -> bool:
	"""Roll for evasion. Returns true if attack should be dodged."""
	var evasion := get_stat(STAT_EVASION)
	return randf() * 100.0 < evasion


# --- Debug ---

func print_stats() -> void:
	print("=== Stats ===")
	for stat_name in _cached_stats:
		print("%s: %.2f" % [stat_name, _cached_stats[stat_name]])
