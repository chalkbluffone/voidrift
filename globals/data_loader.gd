extends Node

## DataLoader - Loads game data from JSON files and supports mod merging.
## Autoload this as "DataLoader" in project settings.

# Loaded data dictionaries
var weapons: Dictionary = {}
var characters: Dictionary = {}
var ship_upgrades: Dictionary = {}
var items: Dictionary = {}
var enemies: Dictionary = {}

# Mod info
var loaded_mods: Array[String] = []

const BASE_DATA_PATH := "res://data/"
const MOD_DATA_PATH := "user://mods/"

func _ready() -> void:
	_load_all_data()

func _load_all_data() -> void:
	# Load base game data
	weapons = _load_json_file(BASE_DATA_PATH + "weapons.json")
	characters = _load_json_file(BASE_DATA_PATH + "characters.json")
	ship_upgrades = _load_json_file(BASE_DATA_PATH + "ship_upgrades.json")
	items = _load_json_file(BASE_DATA_PATH + "items.json")
	enemies = _load_json_file(BASE_DATA_PATH + "enemies.json")
	
	# Load and merge mods
	_load_mods()
	
	print("[DataLoader] Loaded %d weapons, %d characters, %d ship_upgrades, %d items, %d enemies" % [
		weapons.size(), characters.size(), ship_upgrades.size(), items.size(), enemies.size()
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
	_merge_data(characters, _load_json_file(mod_path + "characters.json"))
	_merge_data(ship_upgrades, _load_json_file(mod_path + "ship_upgrades.json"))
	_merge_data(items, _load_json_file(mod_path + "items.json"))
	_merge_data(enemies, _load_json_file(mod_path + "enemies.json"))

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

func get_character(id: String) -> Dictionary:
	return characters.get(id, {})

func get_ship_upgrade(id: String) -> Dictionary:
	return ship_upgrades.get(id, {})

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})

func get_all_weapons() -> Array:
	return weapons.values()

func get_all_characters() -> Array:
	return characters.values()

func get_all_ship_upgrades() -> Array:
	return ship_upgrades.values()

func get_all_items() -> Array:
	return items.values()

func get_all_enemies() -> Array:
	return enemies.values()

func get_weapon_ids() -> Array:
	return weapons.keys()

func get_unlocked_weapons() -> Array:
	# TODO: Filter by player's unlock progress
	return weapons.values().filter(func(w): return w.get("unlock_condition") == "default")

func get_unlocked_characters() -> Array:
	# TODO: Filter by player's unlock progress
	return characters.values().filter(func(c): return c.get("unlock_condition") == "default")

func reload_data() -> void:
	_load_all_data()
