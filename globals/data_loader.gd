extends Node

## DataLoader - Loads game data from JSON files and supports mod merging.
## Autoload this as "DataLoader" in project settings.

# Loaded data dictionaries
var weapons: Dictionary = {}
var weapon_upgrades: Dictionary = {}
var ships: Dictionary = {}
var captains: Dictionary = {}
var synergies: Dictionary = {}
var ship_upgrades: Dictionary = {}
var items: Dictionary = {}
var enemies: Dictionary = {}
var base_player_stats: Dictionary = {}

# Mod info
var loaded_mods: Array[String] = []

const BASE_DATA_PATH := "res://data/"
const MOD_DATA_PATH := "user://mods/"

func _ready() -> void:
	_load_all_data()

func _load_all_data() -> void:
	# Load base game data
	weapons = _load_json_file(BASE_DATA_PATH + "weapons.json")
	weapon_upgrades = _load_json_file(BASE_DATA_PATH + "weapon_upgrades.json")
	ships = _load_json_file(BASE_DATA_PATH + "ships.json")
	captains = _load_json_file(BASE_DATA_PATH + "captains.json")
	synergies = _load_json_file(BASE_DATA_PATH + "synergies.json")
	ship_upgrades = _load_json_file(BASE_DATA_PATH + "ship_upgrades.json")
	items = _load_json_file(BASE_DATA_PATH + "items.json")
	enemies = _load_json_file(BASE_DATA_PATH + "enemies.json")
	base_player_stats = _load_json_file(BASE_DATA_PATH + "base_player_stats.json")
	
	# Load and merge mods
	_load_mods()
	
	print("[DataLoader] Loaded %d weapons, %d weapon_upgrades, %d ships, %d captains, %d synergies, %d ship_upgrades, %d items, %d enemies, %d base_player_stats" % [
		weapons.size(), weapon_upgrades.size(), ships.size(), captains.size(), synergies.size(), ship_upgrades.size(), items.size(), enemies.size(), base_player_stats.size()
	])

func _load_mods() -> void:
	if not DirAccess.dir_exists_absolute(MOD_DATA_PATH):
		DirAccess.make_dir_recursive_absolute(MOD_DATA_PATH)
		return
	
	var dir := DirAccess.open(MOD_DATA_PATH)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var folder_name := dir.get_next()
	
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			_load_mod(MOD_DATA_PATH + folder_name + "/")
		folder_name = dir.get_next()
	
	dir.list_dir_end()

func _load_mod(mod_path: String) -> void:
	var mod_info_path := mod_path + "mod.json"
	if not FileAccess.file_exists(mod_info_path):
		push_warning("[DataLoader] Mod missing mod.json: " + mod_path)
		return
	
	var mod_info := _load_json_file(mod_info_path)
	var mod_name: String = mod_info.get("name", "Unknown Mod")
	
	print("[DataLoader] Loading mod: " + mod_name)
	loaded_mods.append(mod_name)
	
	# Merge mod data into base data
	_merge_data(weapons, _load_json_file(mod_path + "weapons.json"))
	_merge_data(weapon_upgrades, _load_json_file(mod_path + "weapon_upgrades.json"))
	_merge_data(ships, _load_json_file(mod_path + "ships.json"))
	_merge_data(captains, _load_json_file(mod_path + "captains.json"))
	_merge_data(synergies, _load_json_file(mod_path + "synergies.json"))
	_merge_data(ship_upgrades, _load_json_file(mod_path + "ship_upgrades.json"))
	_merge_data(items, _load_json_file(mod_path + "items.json"))
	_merge_data(enemies, _load_json_file(mod_path + "enemies.json"))
	_merge_data(base_player_stats, _load_json_file(mod_path + "base_player_stats.json"))

func _merge_data(base: Dictionary, mod_data: Dictionary) -> void:
	for key in mod_data:
		if key.begins_with("$") or key.begins_with("_"):
			continue  # Skip schema/comment fields
		base[key] = mod_data[key]

func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DataLoader] Failed to open: " + path)
		return {}
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_text)
	
	if error != OK:
		push_error("[DataLoader] JSON parse error in %s at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return {}
	
	var data = json.get_data()
	if data is Dictionary:
		# Remove schema/comment fields
		var cleaned := {}
		for key in data:
			if not key.begins_with("$") and not key.begins_with("_"):
				cleaned[key] = data[key]
		return cleaned
	
	push_error("[DataLoader] Expected Dictionary in: " + path)
	return {}

# --- Public API ---

func get_weapon(id: String) -> Dictionary:
	return weapons.get(id, {})

func get_weapon_upgrade(id: String) -> Dictionary:
	return weapon_upgrades.get(id, {})

func get_all_weapon_upgrades() -> Array:
	return weapon_upgrades.values()

func get_weapon_upgrade_ids() -> Array:
	return weapon_upgrades.keys()

func get_ship(id: String) -> Dictionary:
	return ships.get(id, {})

func get_captain(id: String) -> Dictionary:
	return captains.get(id, {})

func get_ship_upgrade(id: String) -> Dictionary:
	return ship_upgrades.get(id, {})

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})

func get_base_player_stats() -> Dictionary:
	return base_player_stats.duplicate()

func get_all_weapons() -> Array:
	return weapons.values()

func get_all_ships() -> Array:
	return ships.values()

func get_all_captains() -> Array:
	return captains.values()

func get_all_ship_upgrades() -> Array:
	return ship_upgrades.values()

func get_all_items() -> Array:
	return items.values()

func get_all_enemies() -> Array:
	return enemies.values()

func get_weapon_ids() -> Array:
	return weapons.keys()

func get_enabled_weapon_ids() -> Array:
	"""Return only weapon IDs where enabled != false (defaults to true if key missing)."""
	return weapons.keys().filter(func(id): return weapons[id].get("enabled", true))

func get_unlocked_weapons() -> Array:
	# TODO: Filter by player's unlock progress
	return weapons.values().filter(func(w): return w.get("enabled", true) and w.get("unlock_condition") == "default")

func get_unlocked_ships() -> Array:
	# TODO: Filter by player's unlock progress
	return ships.values().filter(func(s): return s.get("unlock_condition") == "default")

func get_unlocked_captains() -> Array:
	# TODO: Filter by player's unlock progress
	return captains.values().filter(func(c): return c.get("unlock_condition") == "default")

func get_synergy_for_combo(ship_id: String, captain_id: String) -> Dictionary:
	"""Return synergy data for a ship+captain combo, or empty dict if none."""
	var key: String = ship_id + "+" + captain_id
	return synergies.get(key, {})

func reload_data() -> void:
	_load_all_data()


# --- Save API (for tools like Weapon Test Lab) ---

func save_weapon(weapon_id: String, weapon_data: Dictionary) -> bool:
	"""Save a weapon's data back to weapons.json. Used by Weapon Test Lab."""
	weapons[weapon_id] = weapon_data
	return _save_json_file(BASE_DATA_PATH + "weapons.json", weapons)


func _save_json_file(path: String, data: Dictionary) -> bool:
	"""Save a dictionary to a JSON file with pretty formatting."""
	var json_string := JSON.stringify(data, "  ")
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[DataLoader] Failed to open for writing: " + path)
		return false
	
	file.store_string(json_string)
	file.close()
	print("[DataLoader] Saved: " + path)
	return true
