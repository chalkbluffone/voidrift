extends Node

## GameManager - Central game state manager, handles scene transitions, run data, and persistence.
## Autoload singleton: GameManager

signal run_started
signal run_ended(victory: bool, stats: Dictionary)
signal level_up_triggered(current_level: int, available_upgrades: Array)
signal level_up_completed(chosen_upgrade: Dictionary)
signal pause_toggled(is_paused: bool)
signal credits_changed(amount: int)
signal stardust_changed(amount: int)
signal xp_changed(current: float, required: float, level: int)

# --- Scenes ---
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAMEPLAY_SCENE := "res://scenes/gameplay/world.tscn"
const GAME_OVER_SCENE := "res://scenes/ui/game_over.tscn"

# --- Game State ---
enum GameState {
	MAIN_MENU,
	PLAYING,
	PAUSED,
	LEVEL_UP,
	GAME_OVER
}

var current_state: GameState = GameState.MAIN_MENU

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


# --- Run Configuration ---
const DEFAULT_RUN_DURATION := 600.0  # 10 minutes in seconds
var run_duration: float = DEFAULT_RUN_DURATION

# --- Run Data (reset each run) ---
var run_data: Dictionary = {
	# Character
	"character_id": "",
	"character_data": {},
	
	# Progression
	"level": 1,
	"xp": 0.0,
	"xp_required": 100.0,
	"time_elapsed": 0.0,
	"time_remaining": DEFAULT_RUN_DURATION,
	
	# Currency (run-local)
	"credits": 0,
	
	# Weapons & Upgrades
	"weapons": [],  # Array of weapon IDs equipped
	"ship_upgrades": [],  # Array of {id, stacks} for each upgrade
	"items": [],  # Array of item IDs collected
	
	# Stats for end screen
	"enemies_killed": 0,
	"elites_killed": 0,
	"bosses_killed": 0,
	"damage_dealt": 0.0,
	"damage_taken": 0.0,
	"credits_collected": 0,
	"xp_collected": 0.0,
	"distance_traveled": 0.0,
	"phases_performed": 0,
}

# --- Persistent Data (survives game close) ---
var persistent_data: Dictionary = {
	"stardust": 0,  # Meta currency
	"total_runs": 0,
	"total_wins": 0,
	"total_time_played": 0.0,
	"unlocked_characters": ["scout"],  # Starting character
	"unlocked_weapons": ["plasma_cannon", "laser_array", "ion_orbit"],  # Default weapons
	"high_score": 0,
	"best_time": 0.0,
	"settings": {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
		"screen_shake": true,
		"show_damage_numbers": true,
	}
}

const SAVE_PATH := "user://voidrift_save.dat"

# --- XP Scaling ---
const XP_BASE := 100.0
const XP_GROWTH := 1.15  # Each level needs 15% more XP

# --- Loadout Limits ---
const MAX_WEAPON_SLOTS := 2
const MAX_MODULE_SLOTS := 2

# --- Node References ---
var _player: Node = null

@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var FileLogger: Node = get_node("/root/FileLogger")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		run_data.time_elapsed += delta
		run_data.time_remaining = max(0.0, run_duration - run_data.time_elapsed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if current_state == GameState.PLAYING:
			pause_game()
		elif current_state == GameState.PAUSED:
			resume_game()


# --- Scene Management ---

func go_to_main_menu() -> void:
	current_state = GameState.MAIN_MENU
	get_tree().paused = false
	_change_scene(MAIN_MENU_SCENE)


func start_run(character_id: String) -> void:
	"""Begin a new run with the specified character."""
	# Reset run data
	_reset_run_data()
	
	# Load character
	var character: Dictionary = DataLoader.get_character(character_id)
	if character.is_empty():
		push_error("GameManager: Invalid character ID: " + character_id)
		return
	
	run_data.character_id = character_id
	run_data.character_data = character
	
	# Add starting weapon
	var starting_weapon: String = character.get("starting_weapon", "plasma_cannon")
	run_data.weapons.append(starting_weapon)
	
	# Increment run counter
	persistent_data.total_runs += 1
	save_game()
	
	current_state = GameState.PLAYING
	_change_scene(GAMEPLAY_SCENE)
	run_started.emit()


func end_run(victory: bool) -> void:
	"""End the current run."""
	current_state = GameState.GAME_OVER
	get_tree().paused = true
	
	# Update persistent stats
	persistent_data.total_time_played += run_data.time_elapsed
	if victory:
		persistent_data.total_wins += 1
	
	# Update high score (based on time survived + kills)
	var score: int = int(run_data.time_elapsed) + (run_data.enemies_killed * 10) + (run_data.bosses_killed * 1000)
	if score > persistent_data.high_score:
		persistent_data.high_score = score
	
	# Update best time (for victories)
	if victory and (persistent_data.best_time == 0 or run_data.time_elapsed < persistent_data.best_time):
		persistent_data.best_time = run_data.time_elapsed
	
	save_game()
	run_ended.emit(victory, run_data.duplicate())


func _reset_run_data() -> void:
	run_data = {
		"character_id": "",
		"character_data": {},
		"level": 1,
		"xp": 0.0,
		"xp_required": XP_BASE,
		"time_elapsed": 0.0,
		"credits": 0,
		"weapons": [],
		"ship_upgrades": [],
		"items": [],
		"enemies_killed": 0,
		"elites_killed": 0,
		"bosses_killed": 0,
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
		"credits_collected": 0,
		"xp_collected": 0.0,
		"distance_traveled": 0.0,
		"phases_performed": 0,
	}


func _change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


# --- Pause ---

func pause_game() -> void:
	if current_state != GameState.PLAYING:
		return
	
	current_state = GameState.PAUSED
	get_tree().paused = true
	pause_toggled.emit(true)


func resume_game() -> void:
	if current_state != GameState.PAUSED and current_state != GameState.LEVEL_UP:
		return
	
	current_state = GameState.PLAYING
	get_tree().paused = false
	pause_toggled.emit(false)


# --- XP & Leveling ---

func add_xp(amount: float) -> void:
	"""Add XP and check for level up."""
	var xp_mult := 1.0
	if _player and _player.has_method("get_stat"):
		xp_mult = _player.get_stat("xp_gain")
	
	var actual_xp := amount * xp_mult
	run_data.xp += actual_xp
	run_data.xp_collected += actual_xp
	
	xp_changed.emit(run_data.xp, run_data.xp_required, run_data.level)
	
	# Check level up
	while run_data.xp >= run_data.xp_required:
		_level_up()


func _level_up() -> void:
	run_data.xp -= run_data.xp_required
	run_data.level += 1
	run_data.xp_required = XP_BASE * pow(XP_GROWTH, run_data.level - 1)
	
	FileLogger.log_info("GameManager", "LEVEL UP! Now level %d" % run_data.level)
	
	# Generate upgrade options
	var upgrades := _generate_level_up_options()
	
	if upgrades.size() > 0:
		# Pause game and show level-up UI
		current_state = GameState.LEVEL_UP
		get_tree().paused = true
		level_up_triggered.emit(run_data.level, upgrades)
	else:
		FileLogger.log_warn("GameManager", "No upgrades available!")
		# Don't pause if no options


func _generate_level_up_options() -> Array:
	"""Generate 3-4 upgrade options for level up selection."""
	var options: Array = []
	var available_upgrades: Array = DataLoader.get_all_ship_upgrades()
	var available_weapons: Array = DataLoader.get_all_weapons()
	var luck: float = _get_player_luck()

	var owned_weapons: Array = run_data.weapons
	var owned_modules: Array = []
	for u in run_data.ship_upgrades:
		if u is Dictionary:
			var uid := String(u.get("id", ""))
			if uid != "":
				owned_modules.append(uid)

	var weapon_slots_full := owned_weapons.size() >= MAX_WEAPON_SLOTS
	var module_slots_full := owned_modules.size() >= MAX_MODULE_SLOTS

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

	# Candidate pool with weights for weighted sampling
	var candidates: Array[Dictionary] = []

	# --- Modules (ship upgrades) ---
	for upgrade in available_upgrades:
		var upgrade_id: String = upgrade.get("id", "")
		if upgrade_id == "":
			continue
		var current_stacks: int = _get_upgrade_stacks(upgrade_id)
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
			if not is_weapon_unlocked(weapon_id):
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


func select_level_up_option(option: Dictionary) -> void:
	"""Apply the selected level up option."""
	var type: String = option.get("type", "")
	var id: String = option.get("id", "")
	
	if type == "upgrade":
		_add_ship_upgrade(id)
	elif type == "weapon":
		# Only track distinct equipped weapons in run_data (levels are handled by WeaponComponent)
		if id not in run_data.weapons and run_data.weapons.size() < MAX_WEAPON_SLOTS:
			run_data.weapons.append(id)
	
	level_up_completed.emit(option)
	resume_game()


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
	if _player and _player.has_node("WeaponComponent"):
		var wc: Node = _player.get_node("WeaponComponent")
		if wc and wc.has_method("get_weapon_level"):
			return int(wc.get_weapon_level(weapon_id))
	return 1


func _get_player_luck() -> float:
	if _player and _player.has_method("get_stat"):
		return float(_player.get_stat("luck"))
	return 0.0


func _roll_rarity(weights: Dictionary, luck: float) -> String:
	# Base weights (fallback if missing)
	var w: Dictionary = {
		"common": float(weights.get("common", GameConfig.RARITY_DEFAULT_WEIGHTS.get("common", 60.0))),
		"uncommon": float(weights.get("uncommon", GameConfig.RARITY_DEFAULT_WEIGHTS.get("uncommon", 25.0))),
		"rare": float(weights.get("rare", GameConfig.RARITY_DEFAULT_WEIGHTS.get("rare", 10.0))),
		"epic": float(weights.get("epic", GameConfig.RARITY_DEFAULT_WEIGHTS.get("epic", 4.0))),
		"legendary": float(weights.get("legendary", GameConfig.RARITY_DEFAULT_WEIGHTS.get("legendary", 1.0))),
	}
	# Luck biases towards higher rarities.
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
	# Supports either a single (stat, per_level) or a list of effects in data.
	var effects: Array = []
	if upgrade_data.has("effects") and upgrade_data["effects"] is Array:
		for effect in upgrade_data["effects"]:
			if effect is Dictionary:
				effects.append(_normalize_effect(effect))
	else:
		var stat_name: String = upgrade_data.get("stat", "")
		var per_level_raw: float = float(upgrade_data.get("per_level", 0.0))
		effects.append(_normalize_stat_per_level(stat_name, per_level_raw))

	# Scale effect strength by rarity tier.
	var tier_mult: float = float(GameConfig.RARITY_TIER_MULT.get(rarity, 1.0))
	for i in range(effects.size()):
		var e: Dictionary = effects[i]
		e["amount"] = float(e.get("amount", 0.0)) * tier_mult
		effects[i] = e

	# Add minor extra effects depending on rarity.
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
	# Weapon level-ups roll weapon-local effects from the weapon's upgrade_stats pool.
	var effects: Array = []
	var upgrade_stats_any: Variant = weapon_data.get("upgrade_stats", [])
	if not (upgrade_stats_any is Array):
		return effects
	var upgrade_stats: Array = upgrade_stats_any
	if upgrade_stats.is_empty():
		return effects

	var desired_count: int = int(GameConfig.WEAPON_EFFECT_COUNT_BY_RARITY.get(rarity, 1))
	var tier_mult: float = float(GameConfig.RARITY_TIER_MULT.get(rarity, 1.0))

	# Build weighted pool. Supports either ["damage", "attack_speed"] or
	# [{"stat":"damage","weight":1.0,"amount":0.08,"kind":"mult"}, ...]
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

	# Weighted sampling without replacement
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
	# If caller explicitly provided kind, trust it.
	if effect.has("kind"):
		return {
			"stat": stat_name,
			"kind": String(effect.get("kind", "mult")),
			"amount": float(effect.get("amount", 0.0)),
		}
	# Otherwise normalize from per_level style
	var amount_raw: float = float(effect.get("amount", effect.get("per_level", 0.0)))
	return _normalize_stat_per_level(stat_name, amount_raw)


func _normalize_stat_per_level(stat_name: String, per_level_raw: float) -> Dictionary:
	# Flat stats (HP, Shield, Regen, etc.)
	if FLAT_STATS.has(stat_name):
		return {"stat": stat_name, "kind": "flat", "amount": per_level_raw}
	# Percent-point stats (armor, evasion, crit chance, luck)
	if PERCENT_POINT_STATS.has(stat_name):
		return {"stat": stat_name, "kind": "flat", "amount": per_level_raw}
	# Multiplier stats (damage, speed, pickup_range, xp_gain, etc.)
	var amount: float = per_level_raw
	# Many existing data values are stored as "percent points" (e.g. 15 means 15%).
	if absf(amount) >= 1.0:
		amount = amount / 100.0
	return {"stat": stat_name, "kind": "mult", "amount": amount}


func _get_upgrade_stacks(upgrade_id: String) -> int:
	for u in run_data.ship_upgrades:
		if u is Dictionary and String(u.get("id", "")) == upgrade_id:
			return int(u.get("stacks", 0))
	return 0


func _add_ship_upgrade(upgrade_id: String) -> void:
	for i in range(run_data.ship_upgrades.size()):
		var u_any: Variant = run_data.ship_upgrades[i]
		if u_any is Dictionary and String(u_any.get("id", "")) == upgrade_id:
			var u: Dictionary = u_any
			u["stacks"] = int(u.get("stacks", 0)) + 1
			run_data.ship_upgrades[i] = u
			return
	
	# Limit distinct modules
	if run_data.ship_upgrades.size() >= MAX_MODULE_SLOTS:
		return
	
	run_data.ship_upgrades.append({"id": upgrade_id, "stacks": 1})


# --- Currency ---

func add_credits(amount: int) -> void:
	var credit_mult := 1.0
	if _player and _player.has_method("get_stat"):
		credit_mult = _player.get_stat("credits_gain")
	
	var actual := int(amount * credit_mult)
	run_data.credits += actual
	run_data.credits_collected += actual
	credits_changed.emit(run_data.credits)


func spend_credits(amount: int) -> bool:
	if run_data.credits >= amount:
		run_data.credits -= amount
		credits_changed.emit(run_data.credits)
		return true
	return false


func add_stardust(amount: int) -> void:
	var stardust_mult := 1.0
	if _player and _player.has_method("get_stat"):
		stardust_mult = _player.get_stat("stardust_gain")
	
	var actual := int(amount * stardust_mult)
	persistent_data.stardust += actual
	stardust_changed.emit(persistent_data.stardust)
	save_game()


func spend_stardust(amount: int) -> bool:
	if persistent_data.stardust >= amount:
		persistent_data.stardust -= amount
		stardust_changed.emit(persistent_data.stardust)
		save_game()
		return true
	return false


# --- Stats Tracking ---

func record_kill(enemy_type: String) -> void:
	run_data.enemies_killed += 1
	if enemy_type == "elite":
		run_data.elites_killed += 1
	elif enemy_type == "boss":
		run_data.bosses_killed += 1


func record_damage_dealt(amount: float) -> void:
	run_data.damage_dealt += amount


func record_damage_taken(amount: float) -> void:
	run_data.damage_taken += amount


func record_phase() -> void:
	run_data.phases_performed += 1


# --- Player Reference ---

func register_player(player_node: Node) -> void:
	_player = player_node
	if _player.has_signal("died"):
		_player.died.connect(_on_player_died)


func _on_player_died() -> void:
	end_run(false)


# --- Persistence ---

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(persistent_data)
		file.close()


func load_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if data is Dictionary:
				# Merge with defaults to handle save format upgrades
				for key in persistent_data:
					if data.has(key):
						persistent_data[key] = data[key]
			file.close()


func reset_save() -> void:
	"""Reset all persistent data (for testing or player request)."""
	persistent_data = {
		"stardust": 0,
		"total_runs": 0,
		"total_wins": 0,
		"total_time_played": 0.0,
		"unlocked_characters": ["scout"],
		"unlocked_weapons": ["plasma_cannon", "laser_array", "ion_orbit"],
		"high_score": 0,
		"best_time": 0.0,
		"settings": {
			"master_volume": 1.0,
			"music_volume": 0.8,
			"sfx_volume": 1.0,
			"screen_shake": true,
			"show_damage_numbers": true,
		}
	}
	save_game()


# --- Unlocks ---

func unlock_character(character_id: String) -> void:
	if character_id not in persistent_data.unlocked_characters:
		persistent_data.unlocked_characters.append(character_id)
		save_game()


func unlock_weapon(weapon_id: String) -> void:
	if weapon_id not in persistent_data.unlocked_weapons:
		persistent_data.unlocked_weapons.append(weapon_id)
		save_game()


func is_character_unlocked(character_id: String) -> bool:
	return character_id in persistent_data.unlocked_characters


func is_weapon_unlocked(weapon_id: String) -> bool:
	return weapon_id in persistent_data.unlocked_weapons


# --- Getters ---

func get_run_time_formatted() -> String:
	var total_seconds: int = int(run_data.time_elapsed)
	@warning_ignore("integer_division")
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func get_current_level() -> int:
	return run_data.level


func get_equipped_weapons() -> Array:
	return run_data.weapons.duplicate()


func get_ship_upgrades() -> Array:
	return run_data.ship_upgrades.duplicate()
