extends Node

## UpgradeService - Handles upgrade/weapon selection, rarity rolling, and effect generation.
## Autoload singleton: UpgradeService

@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var PersistenceManager: Node = get_node("/root/PersistenceManager")
@onready var ProgressionManager: Node = get_node("/root/ProgressionManager")
@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var GameSeed: Node = get_node("/root/GameSeed")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func generate_level_up_options() -> Array[Dictionary]:
	## Generate 3-4 upgrade options for level up selection.
	var _rng: RandomNumberGenerator = GameSeed.rng("upgrade_service")
	var available_upgrades: Array = DataLoader.get_all_ship_upgrades()
	var luck: float = _get_player_luck()
	var weapon_rng: RandomNumberGenerator = GameSeed.rng("weapon_upgrade")

	var owned_weapons: Array = RunManager.run_data.weapons
	var owned_modules: Array = []
	for u in RunManager.run_data.ship_upgrades:
		if u is Dictionary:
			var uid: String = String(u.get("id", ""))
			if uid != "":
				owned_modules.append(uid)

	var weapon_slots_full: bool = owned_weapons.size() >= GameConfig.MAX_WEAPON_SLOTS
	var module_slots_full: bool = owned_modules.size() >= GameConfig.MAX_MODULE_SLOTS

	# Weights: after you have a weapon/module, bias towards leveling what you already have.
	var w_existing_weapon: float = GameConfig.OFFER_WEIGHT_EXISTING_WEAPON
	var w_new_weapon: float = GameConfig.OFFER_WEIGHT_NEW_WEAPON
	var w_existing_module: float = GameConfig.OFFER_WEIGHT_EXISTING_MODULE
	var w_new_module: float = GameConfig.OFFER_WEIGHT_NEW_MODULE

	if weapon_slots_full:
		# All weapon slots occupied — only offer upgrades for owned weapons.
		w_existing_weapon = GameConfig.OFFER_WEIGHT_WEAPON_FULL_EXISTING
		w_new_weapon = 0.0
	else:
		# Slots still open — offer BOTH existing-weapon upgrades and new weapons.
		# This avoids forcing only-new options until all weapon slots are filled.
		w_existing_weapon = GameConfig.OFFER_WEIGHT_EXISTING_WEAPON
		w_new_weapon = GameConfig.OFFER_WEIGHT_WEAPON_OPEN_NEW

	if module_slots_full:
		w_existing_module = GameConfig.OFFER_WEIGHT_MODULE_FULL_EXISTING
		w_new_module = 0.0
	elif owned_modules.size() > 0:
		w_existing_module = GameConfig.OFFER_WEIGHT_MODULE_PARTIAL_EXISTING
		w_new_module = GameConfig.OFFER_WEIGHT_MODULE_PARTIAL_NEW
	else:
		w_existing_module = GameConfig.OFFER_WEIGHT_MODULE_EMPTY_EXISTING
		w_new_module = GameConfig.OFFER_WEIGHT_MODULE_EMPTY_NEW

	var candidates: Array[Dictionary] = []
	candidates.append_array(_build_module_candidates(
		available_upgrades, owned_modules, module_slots_full, luck, _rng,
		w_existing_module, w_new_module
	))
	candidates.append_array(_build_weapon_candidates(
		owned_weapons, weapon_slots_full, luck, weapon_rng,
		w_existing_weapon, w_new_weapon
	))

	return _select_from_candidates(candidates, int(GameConfig.LEVEL_UP_OPTION_COUNT), _rng)


func _build_module_candidates(
	available_upgrades: Array, owned_modules: Array, module_slots_full: bool,
	luck: float, rng: RandomNumberGenerator, w_existing: float, w_new: float
) -> Array[Dictionary]:
	## Build candidate entries for ship-upgrade (module) options.
	var candidates: Array[Dictionary] = []
	for upgrade in available_upgrades:
		var upgrade_id: String = upgrade.get("id", "")
		if upgrade_id == "":
			continue
		# Skip modules that haven't been unlocked yet
		if not PersistenceManager.is_module_unlocked(upgrade_id):
			continue
		var current_stacks: int = ProgressionManager.get_upgrade_stacks(upgrade_id)
		var max_level: int = int(upgrade.get("max_level", 99))
		if current_stacks >= max_level:
			continue
		var is_owned: bool = upgrade_id in owned_modules
		if (not is_owned) and module_slots_full:
			continue
		var rarity: String = _roll_rarity(upgrade.get("rarity_weights", {}), luck, rng)
		var effects: Array = _build_upgrade_effects(upgrade, rarity, rng)
		candidates.append({
			"weight": w_existing if is_owned else w_new,
			"type": "upgrade",
			"id": upgrade_id,
			"rarity": rarity,
			"effects": effects,
			"data": upgrade,
			"is_new": not is_owned,
			"current_level": current_stacks,
		})
	return candidates


func _build_weapon_candidates(
	owned_weapons: Array, weapon_slots_full: bool, luck: float,
	weapon_rng: RandomNumberGenerator, w_existing: float, w_new: float
) -> Array[Dictionary]:
	## Build candidate entries for weapon options (upgrades to existing + new unlocks).
	var candidates: Array[Dictionary] = []

	# Existing weapons (level up)
	for weapon_id_any in owned_weapons:
		var weapon_id: String = String(weapon_id_any)
		var weapon_data: Dictionary = DataLoader.get_weapon(weapon_id)
		if weapon_data.is_empty():
			continue
		var max_level_w: int = int(weapon_data.get("max_level", 40))
		var current_level_w: int = _get_weapon_level(weapon_id)
		if current_level_w >= max_level_w:
			continue
		var weapon_rarity: String = _roll_rarity({}, luck, weapon_rng)
		var weapon_effects: Array = _build_weapon_effects(weapon_id, weapon_rarity, weapon_rng)
		candidates.append({
			"weight": w_existing,
			"type": "weapon",
			"id": weapon_id,
			"rarity": weapon_rarity,
			"effects": weapon_effects,
			"data": weapon_data,
			"is_new": false,
			"current_level": current_level_w,
		})

	# New weapons (only if slots available)
	if not weapon_slots_full and w_new > 0.0:
		for wid in DataLoader.weapons.keys():
			if wid in owned_weapons:
				continue
			if not PersistenceManager.is_weapon_unlocked(wid):
				continue
			var w_data: Dictionary = DataLoader.weapons[wid]
			var new_weapon_rarity: String = _roll_rarity({}, luck, weapon_rng)
			var new_weapon_effects: Array = _build_weapon_effects(wid, new_weapon_rarity, weapon_rng)
			candidates.append({
				"weight": w_new,
				"type": "weapon",
				"id": wid,
				"rarity": new_weapon_rarity,
				"effects": new_weapon_effects,
				"data": w_data,
				"is_new": true,
				"current_level": 0,
			})

	return candidates


func _select_from_candidates(candidates: Array[Dictionary], count: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	## Pick up to count options via weighted sampling without replacement.
	var options: Array[Dictionary] = []
	var picks: int = mini(count, candidates.size())
	for _i in range(picks):
		var idx: int = _pick_weighted_index(candidates, rng)
		if idx < 0:
			break
		var chosen: Dictionary = candidates[idx]
		chosen.erase("weight")
		options.append(chosen)
		candidates.remove_at(idx)
	return options


func _pick_weighted_index(items: Array[Dictionary], rng: RandomNumberGenerator = null) -> int:
	var total: float = 0.0
	for it in items:
		total += float(it.get("weight", 1.0))
	if total <= 0.0:
		return -1
	var rng_to_use: RandomNumberGenerator = rng if rng else GameSeed.rng("upgrade_service")
	var roll: float = rng_to_use.randf() * total
	var acc: float = 0.0
	for i in range(items.size()):
		acc += float(items[i].get("weight", 1.0))
		if roll <= acc:
			return i
	return items.size() - 1


func _get_weapon_level(weapon_id: String) -> int:
	var player: Node = RunManager.get_player()
	if player and player.has_node("WeaponComponent"):
		var wc: Node = player.get_node("WeaponComponent")
		if wc and wc.has_method("get_weapon_level"):
			return int(wc.get_weapon_level(weapon_id))
	return 1


func _get_player_luck() -> float:
	var player: Node = RunManager.get_player()
	if player and player.has_method("get_stat"):
		return float(player.get_stat("luck"))
	return 0.0


func _roll_rarity(weights: Dictionary, luck: float, rng: RandomNumberGenerator) -> String:
	var w: Dictionary = {
		"common": float(weights.get("common", GameConfig.RARITY_DEFAULT_WEIGHTS.get("common", 60.0))),
		"uncommon": float(weights.get("uncommon", GameConfig.RARITY_DEFAULT_WEIGHTS.get("uncommon", 25.0))),
		"rare": float(weights.get("rare", GameConfig.RARITY_DEFAULT_WEIGHTS.get("rare", 10.0))),
		"epic": float(weights.get("epic", GameConfig.RARITY_DEFAULT_WEIGHTS.get("epic", 4.0))),
		"legendary": float(weights.get("legendary", GameConfig.RARITY_DEFAULT_WEIGHTS.get("legendary", 1.0))),
	}
	var luck_factor: float = 1.0 + (clampf(luck, 0.0, float(GameConfig.RARITY_LUCK_MAX)) / float(GameConfig.RARITY_LUCK_FACTOR_DIVISOR))
	for rarity_key in GameConfig.RARITY_ORDER:
		if rarity_key == "common":
			continue
		var rarity_exp: int = int(GameConfig.RARITY_LUCK_EXPONENT_BY_RARITY.get(rarity_key, 1))
		w[rarity_key] = float(w.get(rarity_key, 0.0)) * pow(luck_factor, rarity_exp)

	var total: float = 0.0
	for key in GameConfig.RARITY_ORDER:
		total += w.get(key, 0.0)
	if total <= 0.0:
		return "common"

	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for key in GameConfig.RARITY_ORDER:
		acc += w.get(key, 0.0)
		if roll <= acc:
			return key
	return "common"


func _build_upgrade_effects(upgrade_data: Dictionary, rarity: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	if upgrade_data.has("effects") and upgrade_data["effects"] is Array:
		for effect in upgrade_data["effects"]:
			if effect is Dictionary:
				effects.append(_normalize_effect(effect))
	else:
		var stat_name: String = upgrade_data.get("stat", "")
		var per_level_raw: float = float(upgrade_data.get("per_level", 0.0))
		effects.append(_normalize_stat_per_level(stat_name, per_level_raw))

	var tier_mult: float = float(GameConfig.RARITY_TIER_MULT.get(rarity, 1.0))
	for i in range(effects.size()):
		var e: Dictionary = effects[i]
		e["amount"] = float(e.get("amount", 0.0)) * tier_mult
		effects[i] = e

	var desired_count: int = int(GameConfig.MODULE_EFFECT_COUNT_BY_RARITY.get(rarity, 1))
	if effects.size() >= desired_count:
		return effects

	var used_stats: Dictionary = {}
	for e in effects:
		used_stats[e.get("stat", "")] = true

	var pool: Array = []
	for extra in GameConfig.MODULE_EXTRA_EFFECT_POOL:
		if not used_stats.has(extra.get("stat", "")):
			pool.append(extra)
	_seeded_shuffle(pool, rng)

	while effects.size() < desired_count and pool.size() > 0:
		var extra: Dictionary = pool.pop_back()
		var extra_scaled: Dictionary = extra.duplicate(true)
		var extra_stat: String = String(extra_scaled.get("stat", ""))
		var extra_kind: String = String(extra_scaled.get("kind", "mult"))
		var extra_amount: float = float(extra_scaled.get("amount", 0.0))
		if extra_kind == "flat" and GameConfig.PERCENTAGE_POINT_STATS.has(extra_stat):
			extra_amount = GameConfig.json_pct_to_stat(extra_stat, extra_amount)
		extra_scaled["amount"] = extra_amount * tier_mult
		effects.append(extra_scaled)

	return effects


func _build_weapon_effects(weapon_id: String, rarity: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	## Build weapon upgrade effects using tier-based data from weapon_upgrades.json.
	## Reads deterministic per-rarity stat deltas, picks N stats via weighted selection,
	## and applies rarity factors per the Megabonk hybrid model.
	var effects: Array[Dictionary] = []

	# Load tier data from weapon_upgrades.json
	var upgrade_data: Dictionary = DataLoader.get_weapon_upgrade(weapon_id)
	if upgrade_data.is_empty():
		return effects

	var tier_stats: Dictionary = upgrade_data.get("tier_stats", {})
	if tier_stats.is_empty():
		return effects

	# Build weighted pool from eligible stats (only stats present in tier_stats)
	var pool: Array[Dictionary] = []
	for stat_name in tier_stats.keys():
		var stat_str: String = String(stat_name)
		var base_weight: float = float(GameConfig.WEAPON_UPGRADE_STAT_WEIGHTS.get(stat_str, 1.0))
		pool.append({"stat": stat_str, "weight": base_weight})

	if pool.is_empty():
		return effects

	# Determine how many stats to upgrade this level-up
	var pick_range: Array = GameConfig.WEAPON_STAT_PICK_COUNT.get(rarity, [1, 1])
	var min_picks: int = int(pick_range[0])
	var max_picks: int = int(pick_range[1])
	var desired_count: int = min_picks
	if max_picks > min_picks:
		desired_count = min_picks + (rng.randi() % (max_picks - min_picks + 1))
	desired_count = mini(desired_count, pool.size())

	# Get rarity factor
	var rarity_factor: float = 1.0
	if GameConfig.WEAPON_TIER_VALUE_MODE == "baseline_plus_factor":
		rarity_factor = float(GameConfig.WEAPON_RARITY_FACTORS.get(rarity, 1.0))

	# Pick stats via weighted random selection (without replacement)
	var remaining: Array[Dictionary] = pool.duplicate(true)
	for _i in range(desired_count):
		var idx: int = _pick_weighted_index(remaining, rng)
		if idx < 0:
			break
		var chosen: Dictionary = remaining[idx]
		remaining.remove_at(idx)

		var stat_name_c: String = String(chosen.get("stat", ""))
		if stat_name_c == "":
			continue

		# Read deterministic baseline from tier_stats at the rolled rarity
		var stat_tiers: Dictionary = tier_stats.get(stat_name_c, {})
		var base_delta: float = float(stat_tiers.get(rarity, 0.0))

		# Convert percentage-point stats from 0-1 JSON to 0-100 internal
		base_delta = GameConfig.json_pct_to_stat(stat_name_c, base_delta)

		# Apply rarity factor scaling
		var scaled_delta: float = base_delta * rarity_factor

		# Determine stat kind (flat vs mult)
		var kind: String = String(GameConfig.WEAPON_UPGRADE_STAT_KIND.get(stat_name_c, "mult"))

		# Apply rounding and minimum floor
		if kind == "flat" and stat_name_c in ["projectile_count", "projectile_bounces"]:
			# Integer stats: round to nearest, ensure at least 1 if base > 0
			scaled_delta = round(scaled_delta)
			if base_delta > 0.0 and scaled_delta < 1.0:
				scaled_delta = 1.0
		else:
			# Decimal stats: clamp to minimum positive delta
			if base_delta > 0.0 and scaled_delta < GameConfig.WEAPON_MIN_POSITIVE_DELTA:
				scaled_delta = GameConfig.WEAPON_MIN_POSITIVE_DELTA

		effects.append({"stat": stat_name_c, "kind": kind, "amount": scaled_delta})

	return effects





func _normalize_effect(effect: Dictionary) -> Dictionary:
	var stat_name: String = effect.get("stat", "")
	if effect.has("kind"):
		var amount_raw: float = float(effect.get("amount", 0.0))
		var kind: String = String(effect.get("kind", "mult"))
		if kind == "flat" and GameConfig.PERCENTAGE_POINT_STATS.has(stat_name):
			amount_raw = GameConfig.json_pct_to_stat(stat_name, amount_raw)
		return {
			"stat": stat_name,
			"kind": kind,
			"amount": amount_raw,
		}
	var fallback_raw: float = float(effect.get("amount", effect.get("per_level", 0.0)))
	return _normalize_stat_per_level(stat_name, fallback_raw)


func _normalize_stat_per_level(stat_name: String, per_level_raw: float) -> Dictionary:
	if GameConfig.FLAT_ABSOLUTE_STATS.has(stat_name):
		return {"stat": stat_name, "kind": "flat", "amount": per_level_raw}
	if GameConfig.PERCENTAGE_POINT_STATS.has(stat_name):
		return {"stat": stat_name, "kind": "flat", "amount": GameConfig.json_pct_to_stat(stat_name, per_level_raw)}
	# Multiplier stat: value is already a 0-1 fraction in JSON.
	return {"stat": stat_name, "kind": "mult", "amount": per_level_raw}


## Fisher-Yates shuffle using a seeded RNG for deterministic ordering.
func _seeded_shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
