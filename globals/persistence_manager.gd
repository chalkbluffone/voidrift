extends Node

## PersistenceManager - Handles save/load, unlocks, and persistent data storage.
## Autoload singleton: PersistenceManager

const SAVE_PATH: String = "user://savegame.dat"

signal game_saved
signal game_loaded
signal data_reset

var persistent_data: Dictionary = _get_default_persistent_data()


static func _get_default_persistent_data() -> Dictionary:
	return {
		"stardust": 0,
		"total_runs": 0,
		"total_wins": 0,
		"total_time_played": 0.0,
		"unlocked_ships": ["starchaser"],
		"unlocked_captains": ["captain_nightmare", "captain_finswick"],
		"discovered_synergies": [],
		"unlocked_weapons": ["plasma_cannon", "laser_array", "ion_orbit", "proximity_tax", "psp_9000", "space_nukes", "tothian_mines", "timmy_gun"],
		"unlocked_modules": [],
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()
	_ensure_default_unlocks()


func _ensure_default_unlocks() -> void:
	if "proximity_tax" not in persistent_data.unlocked_weapons:
		persistent_data.unlocked_weapons.append("proximity_tax")
	if "psp_9000" not in persistent_data.unlocked_weapons:
		persistent_data.unlocked_weapons.append("psp_9000")
	if "space_nukes" not in persistent_data.unlocked_weapons:
		persistent_data.unlocked_weapons.append("space_nukes")
	if "tothian_mines" not in persistent_data.unlocked_weapons:
		persistent_data.unlocked_weapons.append("tothian_mines")
	if "timmy_gun" not in persistent_data.unlocked_weapons:
		persistent_data.unlocked_weapons.append("timmy_gun")


# --- Persistence ---

func save_game() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(persistent_data)
		file.close()
		game_saved.emit()


func load_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data: Variant = file.get_var()
			if data is Dictionary:
				# Merge with defaults to handle save format upgrades
				for key in persistent_data:
					if data.has(key):
						persistent_data[key] = data[key]
				_ensure_default_unlocks()
			file.close()
			game_loaded.emit()


## Reset all persistent data (for testing or player request).
func reset_save() -> void:
	persistent_data = _get_default_persistent_data()
	_ensure_default_unlocks()
	save_game()
	data_reset.emit()


# --- Unlocks ---

func unlock_ship(ship_id: String) -> void:
	if ship_id not in persistent_data.unlocked_ships:
		persistent_data.unlocked_ships.append(ship_id)
		save_game()


func unlock_captain(captain_id: String) -> void:
	if captain_id not in persistent_data.unlocked_captains:
		persistent_data.unlocked_captains.append(captain_id)
		save_game()


func discover_synergy(synergy_key: String) -> void:
	if synergy_key not in persistent_data.discovered_synergies:
		persistent_data.discovered_synergies.append(synergy_key)
		save_game()


func is_synergy_discovered(synergy_key: String) -> bool:
	return synergy_key in persistent_data.discovered_synergies


func unlock_weapon(weapon_id: String) -> void:
	if weapon_id not in persistent_data.unlocked_weapons:
		persistent_data.unlocked_weapons.append(weapon_id)
		save_game()


func is_ship_unlocked(ship_id: String) -> bool:
	return ship_id in persistent_data.unlocked_ships


func is_captain_unlocked(captain_id: String) -> bool:
	return captain_id in persistent_data.unlocked_captains


func is_weapon_unlocked(weapon_id: String) -> bool:
	return weapon_id in persistent_data.unlocked_weapons


## Check if a ship upgrade module is unlocked.
## Modules with unlock_condition "default" are always available.
## Other modules must be explicitly unlocked via unlock_module().
func is_module_unlocked(module_id: String) -> bool:
	var DataLoader: Node = get_node_or_null("/root/DataLoader")
	if DataLoader == null:
		return true
	var module_data: Dictionary = DataLoader.get_ship_upgrade(module_id)
	if module_data.is_empty():
		return false
	var condition: Variant = module_data.get("unlock_condition", "default")
	if condition is String and condition == "default":
		return true
	return module_id in persistent_data.get("unlocked_modules", [])


func unlock_module(module_id: String) -> void:
	if not persistent_data.has("unlocked_modules"):
		persistent_data["unlocked_modules"] = []
	if module_id not in persistent_data.unlocked_modules:
		persistent_data.unlocked_modules.append(module_id)
		save_game()


# --- Getters/Setters for persistent data ---

func get_stardust() -> int:
	return int(persistent_data.get("stardust", 0))


func add_stardust(amount: int) -> void:
	persistent_data["stardust"] = get_stardust() + amount
	save_game()


func spend_stardust(amount: int) -> bool:
	if get_stardust() >= amount:
		persistent_data["stardust"] = get_stardust() - amount
		save_game()
		return true
	return false


func get_total_runs() -> int:
	return int(persistent_data.get("total_runs", 0))


func increment_total_runs() -> void:
	persistent_data["total_runs"] = get_total_runs() + 1
	save_game()


func get_total_wins() -> int:
	return int(persistent_data.get("total_wins", 0))


func increment_total_wins() -> void:
	persistent_data["total_wins"] = get_total_wins() + 1
	save_game()


func get_high_score() -> int:
	return int(persistent_data.get("high_score", 0))


func update_high_score(score: int) -> bool:
	if score > get_high_score():
		persistent_data["high_score"] = score
		save_game()
		return true
	return false


func get_best_time() -> float:
	return float(persistent_data.get("best_time", 0.0))


func update_best_time(time: float) -> bool:
	var current_best: float = get_best_time()
	if current_best == 0.0 or time < current_best:
		persistent_data["best_time"] = time
		save_game()
		return true
	return false


func add_time_played(seconds: float) -> void:
	persistent_data["total_time_played"] = float(persistent_data.get("total_time_played", 0.0)) + seconds
	# Don't save immediately, batch with other saves
