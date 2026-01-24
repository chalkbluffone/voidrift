extends CanvasLayer

## HUD - Displays player stats, XP, level, and run timer.
## Scales automatically based on screen resolution.

const REFERENCE_HEIGHT := 1080.0  # Design resolution height

# Top left - HP bar
@onready var hp_bar: ProgressBar = $TopLeft/HPBar
@onready var hp_label: Label = $TopLeft/HPBar/HPLabel

# Top center - Level
@onready var level_label: Label = $TopCenter/LevelLabel

# Top right
@onready var timer_label: Label = $TopRight/VBoxContainer/TimerLabel
@onready var fps_label: Label = $TopRight/VBoxContainer/FPSLabel
@onready var credits_label: Label = $TopRight/VBoxContainer/CreditsLabel

# Bottom - XP bar stretched across screen
@onready var xp_bar: ProgressBar = $BottomXP/XPBar
@onready var xp_label: Label = $BottomXP/XPBar/XPLabel

# Containers for scaling
@onready var top_left: Control = $TopLeft
@onready var top_center: Control = $TopCenter
@onready var top_right: Control = $TopRight

# Left side - weapons list
@onready var left_weapons: Control = $LeftWeapons
@onready var weapons_title: Label = $LeftWeapons/VBox/Title
@onready var weapons_list: VBoxContainer = $LeftWeapons/VBox/WeaponsList
@onready var modules_title: Label = $LeftWeapons/VBox/ModulesTitle
@onready var modules_list: VBoxContainer = $LeftWeapons/VBox/ModulesList

@onready var GameManager: Node = get_node("/root/GameManager")
@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var FileLogger: Node = get_node("/root/FileLogger")

var _player: Node = null
var _level_tween: Tween = null
var _level_base_scale := Vector2.ONE

# Synthwave colors
const COLOR_HP := Color(1.0, 0.08, 0.4, 1.0)  # Hot pink/magenta
const COLOR_XP := Color(0.67, 0.2, 0.95, 1.0)  # Neon purple
const COLOR_TIMER := Color(0.0, 1.0, 0.9, 1.0)  # Cyan
const COLOR_LEVEL := Color(1.0, 0.95, 0.2, 1.0)  # Neon yellow
const COLOR_LEVEL_GLOW := Color(1.0, 0.4, 0.8, 1.0)  # Pink glow for level up
const COLOR_CREDITS := Color(1.0, 0.85, 0.1, 1.0)  # Gold for credits
const COLOR_WEAPONS := Color(0.2, 1.0, 0.9, 1.0)  # Cyan-ish


func _ready() -> void:
	FileLogger.log_info("HUD", "Initializing HUD...")
	
	# Apply synthwave colors
	_apply_synthwave_theme()
	
	# Scale HUD based on resolution
	_update_scale()
	get_tree().root.size_changed.connect(_update_scale)
	
	# Connect to GameManager signals
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.credits_changed.connect(_on_credits_changed)
	GameManager.level_up_completed.connect(_on_level_up_completed)
	GameManager.run_started.connect(_on_run_started)
	
	# Wait a frame then find player
	await get_tree().process_frame
	_find_player()
	
	# Initialize display
	_update_timer(0.0)
	_update_level(1)
	_update_credits(0)


func _update_scale() -> void:
	var viewport_height := get_viewport().get_visible_rect().size.y
	var scale_factor := viewport_height / REFERENCE_HEIGHT
	top_left.scale = Vector2(scale_factor, scale_factor)
	top_center.scale = Vector2(scale_factor, scale_factor)
	top_right.scale = Vector2(scale_factor, scale_factor)
	# Bottom XP bar doesn't need scaling - it stretches with anchors
	FileLogger.log_debug("HUD", "Scaled to %.2f (viewport height: %.0f)" % [scale_factor, viewport_height])


func _apply_synthwave_theme() -> void:
	# HP Bar - Hot pink
	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = COLOR_HP
	hp_style.corner_radius_top_left = 4
	hp_style.corner_radius_top_right = 4
	hp_style.corner_radius_bottom_left = 4
	hp_style.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("fill", hp_style)
	
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.15, 0.05, 0.1, 0.8)
	hp_bg.corner_radius_top_left = 4
	hp_bg.corner_radius_top_right = 4
	hp_bg.corner_radius_bottom_left = 4
	hp_bg.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	
	# XP Bar - Neon purple
	var xp_style := StyleBoxFlat.new()
	xp_style.bg_color = COLOR_XP
	xp_style.corner_radius_top_left = 0
	xp_style.corner_radius_top_right = 0
	xp_style.corner_radius_bottom_left = 0
	xp_style.corner_radius_bottom_right = 0
	xp_bar.add_theme_stylebox_override("fill", xp_style)
	
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.2, 0.08, 0.3, 0.9)  # Lighter purple background
	xp_bg.corner_radius_top_left = 0
	xp_bg.corner_radius_top_right = 0
	xp_bg.corner_radius_bottom_left = 0
	xp_bg.corner_radius_bottom_right = 0
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	
	# Timer - Cyan
	timer_label.add_theme_color_override("font_color", COLOR_TIMER)
	timer_label.add_theme_color_override("font_outline_color", Color(0, 0.3, 0.4, 1.0))
	timer_label.add_theme_constant_override("outline_size", 2)
	
	# FPS - Dimmer cyan
	fps_label.add_theme_color_override("font_color", Color(0.0, 0.7, 0.6, 0.7))
	
	# Level - Neon yellow with glow effect
	level_label.add_theme_color_override("font_color", COLOR_LEVEL)
	level_label.add_theme_color_override("font_outline_color", Color(1.0, 0.5, 0.0, 0.8))
	level_label.add_theme_constant_override("outline_size", 3)
	_level_base_scale = level_label.scale
	
	# Credits - Gold
	credits_label.add_theme_color_override("font_color", COLOR_CREDITS)

	# Weapons panel
	weapons_title.add_theme_color_override("font_color", COLOR_WEAPONS)
	weapons_title.add_theme_color_override("font_outline_color", Color(0, 0.25, 0.3, 1.0))
	weapons_title.add_theme_constant_override("outline_size", 2)
	modules_title.add_theme_color_override("font_color", COLOR_WEAPONS)
	modules_title.add_theme_color_override("font_outline_color", Color(0, 0.25, 0.3, 1.0))
	modules_title.add_theme_constant_override("outline_size", 2)


func _process(_delta: float) -> void:
	# Update FPS
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
	# Update timer (countdown)
	if GameManager.current_state == GameManager.GameState.PLAYING:
		_update_timer(GameManager.run_data.time_remaining)
	
	# Update HP from player stats
	if _player and _player.stats:
		var current_hp: float = _player.stats.current_hp
		var max_hp: float = _player.stats.get_stat("max_hp")
		_update_hp(current_hp, max_hp)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		FileLogger.log_info("HUD", "Found player: %s" % _player.name)
		
		# Hook weapon events
		if _player.has_node("WeaponComponent"):
			var weapon_comp: Node = _player.get_node("WeaponComponent")
			if weapon_comp.has_signal("weapon_equipped") and not weapon_comp.weapon_equipped.is_connected(_on_weapon_changed):
				weapon_comp.weapon_equipped.connect(_on_weapon_changed)
			if weapon_comp.has_signal("weapon_removed") and not weapon_comp.weapon_removed.is_connected(_on_weapon_changed):
				weapon_comp.weapon_removed.connect(_on_weapon_changed)
			_refresh_weapon_list()
		_refresh_modules_list()
		
		# Initial HP update
		if _player.stats:
			var current_hp: float = _player.stats.current_hp
			var max_hp: float = _player.stats.get_stat("max_hp")
			_update_hp(current_hp, max_hp)
			
			# Connect HP changed signal
			_player.stats.hp_changed.connect(_on_hp_changed)


func _update_hp(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d" % [ceili(current), ceili(maximum)]


func _update_xp(current: float, required: float) -> void:
	xp_bar.max_value = required
	xp_bar.value = current
	xp_label.text = "XP: %d / %d" % [int(current), int(required)]


func _update_level(level: int) -> void:
	level_label.text = "LV %d" % level
	
	# Animate level up with pulse and color flash
	if _level_tween:
		_level_tween.kill()
	_level_tween = create_tween()
	
	# Flash to pink, scale up, then back
	level_label.modulate = COLOR_LEVEL_GLOW
	level_label.scale = _level_base_scale * 1.5
	
	_level_tween.set_ease(Tween.EASE_OUT)
	_level_tween.set_trans(Tween.TRANS_ELASTIC)
	_level_tween.tween_property(level_label, "scale", _level_base_scale, 0.6)
	_level_tween.parallel().tween_property(level_label, "modulate", Color.WHITE, 0.4)


func _update_timer(time_remaining: float) -> void:
	var total_seconds := int(max(0, time_remaining))
	var minutes: int = int(total_seconds / 60.0)
	var seconds := total_seconds % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	
	# Flash red when low on time
	if time_remaining <= 60.0:
		timer_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	else:
		timer_label.modulate = Color.WHITE


# --- Signal Handlers ---

func _on_hp_changed(current: float, maximum: float) -> void:
	_update_hp(current, maximum)


func _on_xp_changed(current: float, required: float, level: int) -> void:
	_update_xp(current, required)
	_update_level(level)


func _on_credits_changed(amount: int) -> void:
	_update_credits(amount)
	_animate_credits_gain()


func _update_credits(amount: int) -> void:
	credits_label.text = "$ %d" % amount


func _animate_credits_gain() -> void:
	# Quick pulse animation when gaining credits
	var tween: Tween = create_tween()
	credits_label.scale = Vector2(1.3, 1.3)
	tween.tween_property(credits_label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)


func _on_weapon_changed(_weapon_id: String = "") -> void:
	_refresh_weapon_list()


func _refresh_weapon_list() -> void:
	if not _player or not _player.has_node("WeaponComponent"):
		left_weapons.visible = false
		return
	left_weapons.visible = true

	# Clear existing rows (keep title separate)
	for child in weapons_list.get_children():
		child.queue_free()

	var weapon_comp: Node = _player.get_node("WeaponComponent")
	if not weapon_comp.has_method("get_equipped_weapon_summaries"):
		return

	var summaries: Array = weapon_comp.get_equipped_weapon_summaries()
	# Stable display order
	summaries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)

	for s in summaries:
		var id: String = String(s.get("id", ""))
		var level: int = int(s.get("level", 1))
		var weapon_name := id
		if DataLoader:
			var w: Dictionary = DataLoader.get_weapon(id)
			weapon_name = String(w.get("name", id))
		var label := Label.new()
		label.text = "%s  LV %d" % [weapon_name.to_upper(), level]
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_font_size_override("font_size", 14)
		label.tooltip_text = "%s (LV %d)" % [id, level]
		weapons_list.add_child(label)


func _on_run_started() -> void:
	_refresh_modules_list()
	_refresh_weapon_list()


func _on_level_up_completed(_chosen_upgrade: Dictionary) -> void:
	# Modules change on level up; refresh the list.
	_refresh_modules_list()


func _refresh_modules_list() -> void:
	if not GameManager:
		return
	left_weapons.visible = true

	for child in modules_list.get_children():
		child.queue_free()

	var upgrades: Array = []
	if GameManager.has_method("get_ship_upgrades"):
		upgrades = GameManager.get_ship_upgrades()
	else:
		upgrades = GameManager.run_data.get("ship_upgrades", [])

	# Normalize + sort
	upgrades.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)

	for u in upgrades:
		var id: String = String(u.get("id", ""))
		var level: int = int(u.get("stacks", 1))
		var display_name: String = id
		if DataLoader:
			var data: Dictionary = DataLoader.get_ship_upgrade(id)
			display_name = String(data.get("name", id))
		var label := Label.new()
		label.text = "%s  LV %d" % [display_name.to_upper(), level]
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_font_size_override("font_size", 13)
		label.tooltip_text = "%s (LV %d)" % [id, level]
		modules_list.add_child(label)
