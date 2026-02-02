extends Node

## UpgradeService - Handles upgrade/weapon selection, rarity rolling, and effect generation.
## Autoload singleton: UpgradeService

# Stats that are expressed as percentage points (0..100), not multipliers.
const PERCENT_POINT_STATS: Dictionary = {
	"armor": true,
	"evasion": true,
	"crit_chance": true,
	"luck": true,
	"difficulty": true,
}

# Stats that should be treated as flat additions.
const FLAT_STATS: Dictionary = {
	"max_hp": true,
	"hp_regen": true,
	"shield": true,
	"thorns": true,
	"projectile_count": true,
	"projectile_bounces": true,
}

@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var PersistenceManager: Node = get_node("/root/PersistenceManager")
@onready var ProgressionManager: Node = get_node("/root/ProgressionManager")
@onready var GameConfig: Node = get_node("/root/GameConfig")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func generate_level_up_options() -> Array:
	"""Generate 3-4 upgrade options for level up selection."""
	var options: Array = []
	var available_upgrades: Array = DataLoader.get_all_ship_upgrades()
	var available_weapons: Array = DataLoader.get_all_weapons()
	var luck: float = _get_player_luck()

	var owned_weapons: Array = RunManager.run_data.weapons
	var owned_modules: Array = []
	for u in RunManager.run_data.ship_upgrades:
		if u is Dictionary:
			var uid := String(u.get("id", ""))
			if uid != "":
				owned_modules.append(uid)

	var weapon_slots_full: bool = owned_weapons.size() >= ProgressionManager.MAX_WEAPON_SLOTS
	var module_slots_full: bool = owned_modules.size() >= ProgressionManager.MAX_MODULE_SLOTS

	# Weights: after you have a weapon/module, bias towards leveling what you already have.
	var w_existing_weapon: float = 1.0
	var w_new_weapon: float = 1.5
	var w_existing_module: float = 1.0
	var w_new_module: float = 1.2

	if weapon_slots_full:
		w_existing_weapon = 8.0
		w_new_weapon = 0.0
	elif owned_weapons.size() > 0:
		w_existing_weapon = 4.0
		w_new_weapon = 1.5
	else:
		w_existing_weapon = 1.0
		w_new_weapon = 6.0

	if module_slots_full:
		w_existing_module = 8.0
		w_new_module = 0.0
	elif owned_modules.size() > 0:
		w_existing_module = 4.0
		w_new_module = 1.2
	else:
		w_existing_module = 1.0
		w_new_module = 5.0

	var candidates: Array[Dictionary] = []

	# --- Modules (ship upgrades) ---
	for upgrade in available_upgrades:
		var upgrade_id: String = upgrade.get("id", "")
		if upgrade_id == "":
			continue
		var current_stacks: int = ProgressionManager.get_upgrade_stacks(upgrade_id)
		var max_level: int = int(upgrade.get("max_level", 99))
		if current_stacks >= max_level:
			continue
		var is_owned := upgrade_id in owned_modules
		if (not is_owned) and module_slots_full:
			continue
		var rarity: String = _roll_rarity(upgrade.get("rarity_weights", {}), luck)
		var effects: Array = _build_upgrade_effects(upgrade, rarity)
		candidates.append({
			"weight": w_existing_module if is_owned else w_new_module,
			"type": "upgrade",
			"id": upgrade_id,
			"rarity": rarity,
			"effects": effects,
			"data": upgrade,
		})

	# --- Weapons ---
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
		var weapon_rarity: String = _roll_rarity({}, luck)
		var weapon_effects: Array = _build_weapon_effects(weapon_data, weapon_rarity)
		candidates.append({
			"weight": w_existing_weapon,
			"type": "weapon",
			"id": weapon_id,
			"rarity": weapon_rarity,
			"effects": weapon_effects,
			"data": weapon_data,
			"is_new": false,
			"current_level": current_level_w,
		})

	# New weapons (only if slots available)
	if not weapon_slots_full and w_new_weapon > 0.0:
		for weapon in available_weapons:
			var weapon_id: String = weapon.get("id", "")
			if weapon_id == "":
				continue
			if weapon_id in owned_weapons:
				continue
			if not PersistenceManager.is_weapon_unlocked(weapon_id):
				continue
			candidates.append({
				"weight": w_new_weapon,
				"type": "weapon",
				"id": weapon_id,
				"rarity": String(weapon.get("rarity", "common")),
				"data": weapon,
				"is_new": true,
				"current_level": 0,
			})

	# Pick N options via weighted sampling without replacement
	var picks: int = mini(int(GameConfig.LEVEL_UP_OPTION_COUNT), candidates.size())
	for _i in range(picks):
		var idx: int = _pick_weighted_index(candidates)
		if idx < 0:
			break
		var chosen: Dictionary = candidates[idx]
		chosen.erase("weight")
		options.append(chosen)
		candidates.remove_at(idx)

	return options


func _pick_weighted_index(items: Array[Dictionary]) -> int:
	var total := 0.0
	for it in items:
		total += float(it.get("weight", 1.0))
	if total <= 0.0:
		return -1
	var roll := randf() * total
	var acc := 0.0
	for i in range(items.size()):
		acc += float(items[i].get("weight", 1.0))
		if roll <= acc:
			return i
	return items.size() - 1


func _get_weapon_level(weapon_id: String) -> int:
	var player = RunManager.get_player()
	if player and player.has_node("WeaponComponent"):
		var wc: Node = player.get_node("WeaponComponent")
		if wc and wc.has_method("get_weapon_level"):
			return int(wc.get_weapon_level(weapon_id))
	return 1


func _get_player_luck() -> float:
	var player = RunManager.get_player()
	if player and player.has_method("get_stat"):
		return float(player.get_stat("luck"))
	return 0.0


func _roll_rarity(weights: Dictionary, luck: float) -> String:
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

	var total := 0.0
	for key in GameConfig.RARITY_ORDER:
		total += w.get(key, 0.0)
	if total <= 0.0:
		return "common"

	var roll := randf() * total
	var acc := 0.0
	for key in GameConfig.RARITY_ORDER:
		acc += w.get(key, 0.0)
		if roll <= acc:
			return key
	return "common"


func _build_upgrade_effects(upgrade_data: Dictionary, rarity: String) -> Array:
	var effects: Array = []
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
	pool.shuffle()

	while effects.size() < desired_count and pool.size() > 0:
		var extra: Dictionary = pool.pop_back()
		var extra_scaled := extra.duplicate(true)
		extra_scaled["amount"] = float(extra_scaled.get("amount", 0.0)) * tier_mult
		effects.append(extra_scaled)

	return effects


func _build_weapon_effects(weapon_data: Dictionary, rarity: String) -> Array:
	var effects: Array = []
	var upgrade_stats_any: Variant = weapon_data.get("upgrade_stats", [])
	if not (upgrade_stats_any is Array):
		return effects
	var upgrade_stats: Array = upgrade_stats_any
	if upgrade_stats.is_empty():
		return effects

	var desired_count: int = int(GameConfig.WEAPON_EFFECT_COUNT_BY_RARITY.get(rarity, 1))
	var tier_mult: float = float(GameConfig.RARITY_TIER_MULT.get(rarity, 1.0))

	var pool: Array[Dictionary] = []
	for entry_any in upgrade_stats:
		if entry_any is String:
			var stat_name: String = String(entry_any)
			var base_weight: float = float(GameConfig.WEAPON_UPGRADE_STAT_WEIGHTS.get(stat_name, 1.0))
			var rarity_mult: float = 1.0
			var rm_any: Variant = GameConfig.WEAPON_UPGRADE_WEIGHT_MULT_BY_RARITY.get(rarity, {})
			if rm_any is Dictionary:
				rarity_mult = float(rm_any.get(stat_name, 1.0))
			pool.append({"stat": stat_name, "weight": base_weight * rarity_mult})
		elif entry_any is Dictionary:
			var entry: Dictionary = entry_any
			var stat_name_d: String = String(entry.get("stat", ""))
			if stat_name_d == "":
				continue
			var base_weight_d: float = float(entry.get("weight", GameConfig.WEAPON_UPGRADE_STAT_WEIGHTS.get(stat_name_d, 1.0)))
			var rarity_mult_d: float = 1.0
			var rm_any_d: Variant = entry.get("rarity_weight_mult", GameConfig.WEAPON_UPGRADE_WEIGHT_MULT_BY_RARITY.get(rarity, {}))
			if rm_any_d is Dictionary:
				rarity_mult_d = float(rm_any_d.get(stat_name_d, 1.0))
			pool.append({"stat": stat_name_d, "weight": base_weight_d * rarity_mult_d, "amount": entry.get("amount", null), "kind": entry.get("kind", null)})

	var remaining: Array[Dictionary] = pool.duplicate(true)
	var picks: int = mini(desired_count, remaining.size())
	for _i in range(picks):
		var idx: int = _pick_weighted_index(remaining)
		if idx < 0:
			break
		var chosen: Dictionary = remaining[idx]
		remaining.remove_at(idx)
		var stat_name_c: String = String(chosen.get("stat", ""))
		if stat_name_c == "":
			continue

		var kind: String = "mult"
		if chosen.has("kind") and chosen["kind"] != null:
			kind = String(chosen.get("kind", "mult"))
		else:
			kind = String(GameConfig.WEAPON_UPGRADE_STAT_KIND.get(stat_name_c, "mult"))

		var base_amount: float = 0.0
		if chosen.has("amount") and chosen["amount"] != null:
			base_amount = float(chosen.get("amount", 0.0))
		else:
			base_amount = float(GameConfig.WEAPON_UPGRADE_BASE_AMOUNTS.get(stat_name_c, 0.0))

		var amount: float = base_amount * tier_mult
		effects.append({"stat": stat_name_c, "kind": kind, "amount": amount})

	return effects


func _normalize_effect(effect: Dictionary) -> Dictionary:
	var stat_name: String = effect.get("stat", "")
	if effect.has("kind"):
		return {
			"stat": stat_name,
			"kind": String(effect.get("kind", "mult")),
			"amount": float(effect.get("amount", 0.0)),
		}
	var amount_raw: float = float(effect.get("amount", effect.get("per_level", 0.0)))
	return _normalize_stat_per_level(stat_name, amount_raw)


func _normalize_stat_per_level(stat_name: String, per_level_raw: float) -> Dictionary:
	if FLAT_STATS.has(stat_name):
		return {"stat": stat_name, "kind": "flat", "amount": per_level_raw}
	if PERCENT_POINT_STATS.has(stat_name):
		return {"stat": stat_name, "kind": "flat", "amount": per_level_raw}
	var amount: float = per_level_raw
	if absf(amount) >= 1.0:
		amount = amount / 100.0
	return {"stat": stat_name, "kind": "mult", "amount": amount}
