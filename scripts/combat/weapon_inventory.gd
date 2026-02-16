class_name WeaponInventory
extends RefCounted

## Tracks equipped weapons, their levels, and per-weapon stat bonuses.
## Owned by WeaponComponent as an internal helper — not a scene-tree node.

## Equipped weapons keyed by id: {weapon_id: {data: Dictionary, timer: float, level: int}}
var weapons: Dictionary = {}

## Per-weapon bonuses from level-ups: {weapon_id: {"flat": {stat: float}, "mult": {stat: float}}}
var _level_bonuses: Dictionary = {}


## Add or level-up a weapon. Returns true if newly equipped.
func equip_weapon(weapon_id: String, weapon_data: Dictionary) -> bool:
	if weapons.has(weapon_id):
		weapons[weapon_id].level = int(weapons[weapon_id].get("level", 1)) + 1
		if not _level_bonuses.has(weapon_id):
			_level_bonuses[weapon_id] = {"flat": {}, "mult": {}}
		return false

	weapons[weapon_id] = {
		"data": weapon_data,
		"timer": 0.0,
		"level": 1
	}
	_level_bonuses[weapon_id] = {"flat": {}, "mult": {}}
	return true


## Remove a weapon's data and bonuses. Returns false if not equipped.
func remove_weapon(weapon_id: String) -> bool:
	if not weapons.has(weapon_id):
		return false
	weapons.erase(weapon_id)
	_level_bonuses.erase(weapon_id)
	return true


## Remove all weapons.
func clear() -> void:
	weapons.clear()
	_level_bonuses.clear()


## Check whether a weapon is equipped.
func has_weapon(weapon_id: String) -> bool:
	return weapons.has(weapon_id)


## Return the level of an equipped weapon, or 0 if not equipped.
func get_weapon_level(weapon_id: String) -> int:
	if weapons.has(weapon_id):
		return int(weapons[weapon_id].get("level", 1))
	return 0


## Return [{id: String, level: int}] for all equipped weapons.
func get_equipped_weapon_summaries() -> Array:
	var out: Array = []
	for weapon_id in weapons.keys():
		var state: Dictionary = weapons[weapon_id]
		out.append({
			"id": weapon_id,
			"level": int(state.get("level", 1))
		})
	return out


## Apply stat bonuses from a weapon level-up.
## Effects schema: [{"stat": String, "kind": "flat"|"mult", "amount": float}, ...]
func apply_level_up_effects(weapon_id: String, effects_any: Array) -> void:
	if not _level_bonuses.has(weapon_id):
		_level_bonuses[weapon_id] = {"flat": {}, "mult": {}}
	var state: Dictionary = _level_bonuses[weapon_id]
	var flat: Dictionary = state.get("flat", {})
	var mult: Dictionary = state.get("mult", {})

	for e_any in effects_any:
		if not (e_any is Dictionary):
			continue
		var e: Dictionary = e_any
		var stat_name: String = String(e.get("stat", ""))
		if stat_name == "":
			continue
		var kind: String = String(e.get("kind", "mult"))
		var amount: float = float(e.get("amount", 0.0))
		if amount == 0.0:
			continue
		if kind == "flat":
			flat[stat_name] = float(flat.get(stat_name, 0.0)) + amount
		else:
			mult[stat_name] = float(mult.get(stat_name, 0.0)) + amount

	state["flat"] = flat
	state["mult"] = mult
	_level_bonuses[weapon_id] = state


## Return accumulated flat bonus for a weapon stat.
func get_weapon_flat(weapon_id: String, stat_name: String) -> float:
	if not _level_bonuses.has(weapon_id):
		return 0.0
	var state: Dictionary = _level_bonuses[weapon_id]
	var flat: Dictionary = state.get("flat", {})
	return float(flat.get(stat_name, 0.0))


## Return accumulated multiplicative bonus for a weapon stat.
func get_weapon_mult(weapon_id: String, stat_name: String) -> float:
	if not _level_bonuses.has(weapon_id):
		return 0.0
	var state: Dictionary = _level_bonuses[weapon_id]
	var mult: Dictionary = state.get("mult", {})
	return float(mult.get(stat_name, 0.0))


## Apply flat + mult weapon bonuses to a base value: (base + flat) * (1 + mult).
func apply_weapon_stat_mod(weapon_id: String, stat_name: String, base_value: float) -> float:
	var flat: float = get_weapon_flat(weapon_id, stat_name)
	var mult: float = get_weapon_mult(weapon_id, stat_name)
	return (base_value + flat) * (1.0 + mult)
