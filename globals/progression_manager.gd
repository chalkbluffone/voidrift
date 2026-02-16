extends Node

## ProgressionManager - Handles XP, leveling, currency, and stat tracking.
## Autoload singleton: ProgressionManager

signal level_up_triggered(current_level: int, available_upgrades: Array)
signal level_up_completed(chosen_upgrade: Dictionary)
signal credits_changed(amount: int)
signal stardust_changed(amount: int)
signal xp_changed(current: float, required: float, level: int)

# --- XP Scaling ---
const XP_BASE: float = 100.0
const XP_GROWTH: float = 1.15  # Each level needs 15% more XP

# --- Loadout Limits ---
const MAX_WEAPON_SLOTS: int = 2
const MAX_MODULE_SLOTS: int = 2

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var UpgradeService: Node = get_node("/root/UpgradeService")
@onready var PersistenceManager: Node = get_node("/root/PersistenceManager")
@onready var FileLogger: Node = get_node("/root/FileLogger")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- XP & Leveling ---

## Add XP and check for level up.
func add_xp(amount: float) -> void:
	var player: Node = RunManager.get_player()
	var xp_mult: float = 1.0
	if player and player.has_method("get_stat"):
		xp_mult = player.get_stat("xp_gain")
	
	var actual_xp: float = amount * xp_mult
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


## Apply the selected level up option.
func select_level_up_option(option: Dictionary) -> void:
	var type: String = option.get("type", "")
	var id: String = option.get("id", "")
	
	if type == "upgrade":
		_add_ship_upgrade(id)
	elif type == "weapon":
		if id not in RunManager.run_data.weapons and RunManager.run_data.weapons.size() < MAX_WEAPON_SLOTS:
			# New weapon — add to loadout
			RunManager.run_data.weapons.append(id)
		elif id in RunManager.run_data.weapons:
			# Existing weapon re-pick — apply level-up stat effects
			var effects: Array = option.get("effects", [])
			if effects.size() > 0:
				var player: Node = RunManager.get_player()
				if player and player.has_method("get_weapon_component"):
					var wc: Node = player.get_weapon_component()
					if wc and wc.has_method("apply_level_up_effects"):
						wc.apply_level_up_effects(id, effects)
	
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
	var actual: int = _apply_currency_mult(amount, "credits_gain")
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
	var actual: int = _apply_currency_mult(amount, "stardust_gain")
	PersistenceManager.persistent_data.stardust += actual
	stardust_changed.emit(PersistenceManager.persistent_data.stardust)
	PersistenceManager.save_game()


func _apply_currency_mult(amount: int, stat_name: String) -> int:
	var player: Node = RunManager.get_player()
	var mult: float = 1.0
	if player and player.has_method("get_stat"):
		mult = float(player.get_stat(stat_name))
	return int(amount * mult)


func spend_stardust(amount: int) -> bool:
	if PersistenceManager.persistent_data.stardust >= amount:
		PersistenceManager.persistent_data.stardust -= amount
		stardust_changed.emit(PersistenceManager.persistent_data.stardust)
		PersistenceManager.save_game()
		return true
	return false
