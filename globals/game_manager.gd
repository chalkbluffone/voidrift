extends Node

## GameManager - Thin coordinator that delegates to focused services.
## This is a DEPRECATED compatibility layer. New code should use the focused services directly:
## - RunManager: Run lifecycle, timing, scene transitions, pause state
## - ProgressionManager: XP, leveling, currency
## - UpgradeService: Upgrade selection, rarity rolling, effect generation
## - PersistenceManager: Save/load, unlocks, persistent data
## Autoload singleton: GameManager

# Re-export signals for backwards compatibility (delegate to services)
signal run_started
signal run_ended(victory: bool, stats: Dictionary)
signal level_up_triggered(current_level: int, available_upgrades: Array)
signal level_up_completed(chosen_upgrade: Dictionary)
signal pause_toggled(is_paused: bool)
signal credits_changed(amount: int)
signal stardust_changed(amount: int)
signal xp_changed(current: float, required: float, level: int)

# Service references
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var ProgressionManager: Node = get_node("/root/ProgressionManager")
@onready var UpgradeService: Node = get_node("/root/UpgradeService")
@onready var PersistenceManager: Node = get_node("/root/PersistenceManager")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect to service signals and re-emit for backwards compatibility
	call_deferred("_connect_service_signals")


func _connect_service_signals() -> void:
	if RunManager:
		RunManager.run_started.connect(func(): run_started.emit())
		RunManager.run_ended.connect(func(v, s): run_ended.emit(v, s))
		RunManager.pause_toggled.connect(func(p): pause_toggled.emit(p))
	if ProgressionManager:
		ProgressionManager.level_up_triggered.connect(func(l, u): level_up_triggered.emit(l, u))
		ProgressionManager.level_up_completed.connect(func(u): level_up_completed.emit(u))
		ProgressionManager.credits_changed.connect(func(a): credits_changed.emit(a))
		ProgressionManager.stardust_changed.connect(func(a): stardust_changed.emit(a))
		ProgressionManager.xp_changed.connect(func(c, r, l): xp_changed.emit(c, r, l))


# --- DEPRECATED Properties (delegate to services) ---

var current_state: int:
	get: return RunManager.current_state if RunManager else 0
	set(v): if RunManager: RunManager.current_state = v

var run_data: Dictionary:
	get: return RunManager.run_data if RunManager else {}
	set(v): if RunManager: RunManager.run_data = v

var run_duration: float:
	get: return RunManager.run_duration if RunManager else 600.0
	set(v): if RunManager: RunManager.run_duration = v

var persistent_data: Dictionary:
	get: return PersistenceManager.persistent_data if PersistenceManager else {}
	set(v): if PersistenceManager: PersistenceManager.persistent_data = v


# --- DEPRECATED Methods (delegate to services) ---

func go_to_main_menu() -> void:
	if RunManager:
		RunManager.go_to_main_menu()


func start_run(ship_id: String, captain_id: String) -> void:
	if RunManager:
		RunManager.start_run(ship_id, captain_id)


func end_run(victory: bool) -> void:
	if RunManager:
		RunManager.end_run(victory)


func pause_game() -> void:
	if RunManager:
		RunManager.pause_game()


func resume_game() -> void:
	if RunManager:
		RunManager.resume_game()


func add_xp(amount: float) -> void:
	if ProgressionManager:
		ProgressionManager.add_xp(amount)


func select_level_up_option(option: Dictionary) -> void:
	if ProgressionManager:
		ProgressionManager.select_level_up_option(option)


func add_credits(amount: int) -> void:
	if ProgressionManager:
		ProgressionManager.add_credits(amount)


func spend_credits(amount: int) -> bool:
	if ProgressionManager:
		return ProgressionManager.spend_credits(amount)
	return false


func add_stardust(amount: int) -> void:
	if ProgressionManager:
		ProgressionManager.add_stardust(amount)


func spend_stardust(amount: int) -> bool:
	if ProgressionManager:
		return ProgressionManager.spend_stardust(amount)
	return false


func record_kill(enemy_type: String) -> void:
	if RunManager:
		RunManager.record_kill(enemy_type)


func record_damage_dealt(amount: float) -> void:
	if RunManager:
		RunManager.record_damage_dealt(amount)


func record_damage_taken(amount: float) -> void:
	if RunManager:
		RunManager.record_damage_taken(amount)


func record_phase() -> void:
	if RunManager:
		RunManager.record_phase()


func register_player(player_node: Node) -> void:
	if RunManager:
		RunManager.register_player(player_node)


func save_game() -> void:
	if PersistenceManager:
		PersistenceManager.save_game()


func load_game() -> void:
	if PersistenceManager:
		PersistenceManager.load_game()


func reset_save() -> void:
	if PersistenceManager:
		PersistenceManager.reset_save()


func unlock_ship(ship_id: String) -> void:
	if PersistenceManager:
		PersistenceManager.unlock_ship(ship_id)


func unlock_captain(captain_id: String) -> void:
	if PersistenceManager:
		PersistenceManager.unlock_captain(captain_id)


func unlock_weapon(weapon_id: String) -> void:
	if PersistenceManager:
		PersistenceManager.unlock_weapon(weapon_id)


func is_ship_unlocked(ship_id: String) -> bool:
	if PersistenceManager:
		return PersistenceManager.is_ship_unlocked(ship_id)
	return false


func is_captain_unlocked(captain_id: String) -> bool:
	if PersistenceManager:
		return PersistenceManager.is_captain_unlocked(captain_id)
	return false


func is_weapon_unlocked(weapon_id: String) -> bool:
	if PersistenceManager:
		return PersistenceManager.is_weapon_unlocked(weapon_id)
	return false


func get_run_time_formatted() -> String:
	if RunManager:
		return RunManager.get_run_time_formatted()
	return "00:00"


func get_current_level() -> int:
	if ProgressionManager:
		return ProgressionManager.get_current_level()
	return 1


func get_equipped_weapons() -> Array[String]:
	if RunManager:
		return RunManager.run_data.weapons.duplicate()
	return []


func get_ship_upgrades() -> Array[Dictionary]:
	if RunManager:
		return RunManager.run_data.ship_upgrades.duplicate()
	return []


# --- Constants for backwards compatibility ---
const MAX_WEAPON_SLOTS: int = 2
const MAX_MODULE_SLOTS: int = 2
const XP_BASE: float = 100.0
const XP_GROWTH: float = 1.15

enum GameState {
	MAIN_MENU,
	PLAYING,
	PAUSED,
	LEVEL_UP,
	GAME_OVER
}
