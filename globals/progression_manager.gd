extends Node

## ProgressionManager - Handles XP, leveling, currency, and stat tracking.
## Autoload singleton: ProgressionManager

signal level_up_triggered(current_level: int, available_upgrades: Array)
signal level_up_completed(chosen_upgrade: Dictionary)
signal credits_changed(amount: int)
signal stardust_changed(amount: int)
signal xp_changed(current: float, required: float, level: int)

# --- XP Scaling ---
const XP_BASE := 100.0
const XP_GROWTH := 1.15  # Each level needs 15% more XP

# --- Loadout Limits ---
const MAX_WEAPON_SLOTS := 2
const MAX_MODULE_SLOTS := 2

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var UpgradeService: Node = get_node("/root/UpgradeService")
@onready var PersistenceManager: Node = get_node("/root/PersistenceManager")
@onready var FileLogger: Node = get_node("/root/FileLogger")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- XP & Leveling ---

func add_xp(amount: float) -> void:
	"""Add XP and check for level up."""
	var player = RunManager.get_player()
	var xp_mult := 1.0
	if player and player.has_method("get_stat"):
		xp_mult = player.get_stat("xp_gain")
	
	var actual_xp := amount * xp_mult
	RunManager.run_data.xp += actual_xp
	RunManager.run_data.xp_collected += actual_xp
	
	xp_changed.emit(RunManager.run_data.xp, RunManager.run_data.xp_required, RunManager.run_data.level)
	
	# Check level up
	while RunManager.run_data.xp >= RunManager.run_data.xp_required:
		_level_up()


func _level_up() -> void:
	RunManager.run_data.xp -= RunManager.run_data.xp_required
	RunManager.run_data.level += 1
	RunManager.run_data.xp_required = XP_BASE * pow(XP_GROWTH, RunManager.run_data.level - 1)
	
	FileLogger.log_info("ProgressionManager", "LEVEL UP! Now level %d" % RunManager.run_data.level)
	
	# Generate upgrade options via UpgradeService
	var upgrades: Array = UpgradeService.generate_level_up_options()
	
	if upgrades.size() > 0:
		RunManager.set_level_up_state()
		level_up_triggered.emit(RunManager.run_data.level, upgrades)
	else:
		FileLogger.log_warn("ProgressionManager", "No upgrades available!")


func select_level_up_option(option: Dictionary) -> void:
	"""Apply the selected level up option."""
	var type: String = option.get("type", "")
	var id: String = option.get("id", "")
	
	if type == "upgrade":
		_add_ship_upgrade(id)
	elif type == "weapon":
		if id not in RunManager.run_data.weapons and RunManager.run_data.weapons.size() < MAX_WEAPON_SLOTS:
			RunManager.run_data.weapons.append(id)
	
	level_up_completed.emit(option)
	RunManager.resume_game()


func get_current_level() -> int:
	return RunManager.run_data.level


# --- Ship Upgrades ---

func get_upgrade_stacks(upgrade_id: String) -> int:
	for u in RunManager.run_data.ship_upgrades:
		if u is Dictionary and String(u.get("id", "")) == upgrade_id:
			return int(u.get("stacks", 0))
	return 0


func _add_ship_upgrade(upgrade_id: String) -> void:
	for i in range(RunManager.run_data.ship_upgrades.size()):
		var u_any: Variant = RunManager.run_data.ship_upgrades[i]
		if u_any is Dictionary and String(u_any.get("id", "")) == upgrade_id:
			var u: Dictionary = u_any
			u["stacks"] = int(u.get("stacks", 0)) + 1
			RunManager.run_data.ship_upgrades[i] = u
			return
	
	if RunManager.run_data.ship_upgrades.size() >= MAX_MODULE_SLOTS:
		return
	
	RunManager.run_data.ship_upgrades.append({"id": upgrade_id, "stacks": 1})


# --- Currency ---

func add_credits(amount: int) -> void:
	var player = RunManager.get_player()
	var credit_mult := 1.0
	if player and player.has_method("get_stat"):
		credit_mult = player.get_stat("credits_gain")
	
	var actual := int(amount * credit_mult)
	RunManager.run_data.credits += actual
	RunManager.run_data.credits_collected += actual
	credits_changed.emit(RunManager.run_data.credits)


func spend_credits(amount: int) -> bool:
	if RunManager.run_data.credits >= amount:
		RunManager.run_data.credits -= amount
		credits_changed.emit(RunManager.run_data.credits)
		return true
	return false


func add_stardust(amount: int) -> void:
	var player = RunManager.get_player()
	var stardust_mult := 1.0
	if player and player.has_method("get_stat"):
		stardust_mult = player.get_stat("stardust_gain")
	
	var actual := int(amount * stardust_mult)
	PersistenceManager.persistent_data.stardust += actual
	stardust_changed.emit(PersistenceManager.persistent_data.stardust)
	PersistenceManager.save_game()


func spend_stardust(amount: int) -> bool:
	if PersistenceManager.persistent_data.stardust >= amount:
		PersistenceManager.persistent_data.stardust -= amount
		stardust_changed.emit(PersistenceManager.persistent_data.stardust)
		PersistenceManager.save_game()
		return true
	return false
