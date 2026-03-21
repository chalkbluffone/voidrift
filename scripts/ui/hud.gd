extends CanvasLayer

## HUD - Displays player stats, XP, level, and run timer.
## Scales automatically via project stretch mode (canvas_items).

# Top left - Shield + HP bars
@onready var shield_bar: ProgressBar = $TopLeft/ShieldBar
@onready var shield_label: Label = $TopLeft/ShieldBar/ShieldLabel
@onready var hp_bar: ProgressBar = $TopLeft/HPBar
@onready var hp_label: Label = $TopLeft/HPBar/HPLabel

# Top center - Level + Timer
@onready var level_label: Label = $TopCenter/LevelLabel
@onready var timer_label: Label = $TopCenter/TimerLabel
@onready var overtime_label: Label = $TopCenter/OvertimeLabel

# Top left - Info
@onready var credits_label: Label = $TopLeft/InfoLabels/CreditsLabel
@onready var stardust_label: Label = $TopLeft/InfoLabels/StardustLabel

# Bottom left - debug stats
@onready var debug_container: VBoxContainer = $BottomLeftDebug
var damage_numbers_label: Label = null
var enemies_label: Label = null
var xp_shards_label: Label = null
var projectiles_label: Label = null
var nodes_label: Label = null
var draw_calls_label: Label = null

# Bottom - XP bar stretched across screen
@onready var xp_bar: ProgressBar = $BottomXP/XPBar
var xp_label: Label = null

# Bottom center - ability ring indicator
@onready var ability_ring: Control = $BottomCenter/AbilityRingIndicator

# Bottom icon grids flanking the ability ring
@onready var weapons_grid: HBoxContainer = $BottomLeftWeapons
@onready var modules_grid: HBoxContainer = $BottomRightModules

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var ProgressionManager: Node = get_node("/root/ProgressionManager")
@onready var PersistenceManager: Node = get_node("/root/PersistenceManager")
@onready var SettingsManager: Node = get_node("/root/SettingsManager")
@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var FrameCache: Node = get_node("/root/FrameCache")
@onready var BulletFactoryRef: Node = get_node("/root/BulletFactoryRef")

var _player: Node = null
var _level_tween: Tween = null
var _level_base_scale: Vector2 = Vector2.ONE

# Icon grid slot arrays (populated in _ready)
var _weapon_slots: Array[Dictionary] = []  # [{panel, texture, badge}]
var _module_slots: Array[Dictionary] = []  # [{panel, texture, badge}]
var _icon_tooltip: PanelContainer = null
const ICON_SLOT_SIZE: float = 64.0
const ICON_BORDER_WIDTH: int = 2
const ICON_CORNER_RADIUS: int = 4
const COLOR_SLOT_BG: Color = Color(0.1, 0.1, 0.15, 0.6)
const COLOR_SLOT_BORDER_EMPTY: Color = Color(0.3, 0.3, 0.3, 0.5)

# Synthwave colors
const COLOR_SHIELD: Color = Color(0.2, 0.6, 1.0, 1.0)  # Neon blue
const COLOR_HP: Color = Color(1.0, 0.08, 0.4, 1.0)  # Hot pink/magenta
const COLOR_XP: Color = Color(0.67, 0.2, 0.95, 1.0)  # Neon purple
const COLOR_TIMER: Color = Color(0.0, 1.0, 0.9, 1.0)  # Cyan
const COLOR_LEVEL: Color = Color(1.0, 0.95, 0.2, 1.0)  # Neon yellow
const COLOR_LEVEL_GLOW: Color = Color(1.0, 0.4, 0.8, 1.0)  # Pink glow for level up
const COLOR_CREDITS: Color = Color(1.0, 0.85, 0.1, 1.0)  # Gold for credits
const COLOR_STARDUST: Color = Color(0.6, 0.85, 1.0, 1.0)  # Icy blue for stardust
const COLOR_OVERHEAL: Color = Color(1.0, 0.95, 0.2, 1.0)  # Synthwave yellow for overheal
const COLOR_LIFESTEAL: Color = Color(0.2, 1.0, 0.4, 1.0)  # Green for lifesteal heal

const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")
const FONT_SWARM: Font = preload("res://assets/fonts/Orbitron-ExtraBold.ttf")
const DEBUG_XP_GRAPH_SCENE: PackedScene = preload("res://scenes/ui/debug_xp_graph.tscn")
const MINIMAP_SCENE: PackedScene = preload("res://scenes/ui/minimap.tscn")
const FullMapOverlayScript: GDScript = preload("res://scripts/ui/full_map_overlay.gd")
const STATS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/stats_panel.tscn")
const HEAL_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")
const XP_POPUP_SCENE: PackedScene = preload("res://scenes/ui/xp_popup.tscn")

var _debug_xp_graph: Control = null
var _swarm_warning_label: Label = null
var _minimap: Control = null
var _full_map_overlay: Control = null
var _map_stats_panel: PanelContainer = null
var _xp_popup: XpPopup = null


func _ready() -> void:
	# Apply synthwave colors
	_apply_synthwave_theme()
	
	# Build debug XP graph (in left debug panel)
	_build_debug_xp_graph()
	
	# Build minimap (bottom-right corner)
	_build_minimap()
	
	# Build full map overlay (shown on Tab/RT)
	_build_full_map_overlay()
	
	# Build stats panel for full map view (right side)
	_build_map_stats_panel()
	
	# Build icon grids (weapons left, modules right of ability ring)
	_build_icon_grids()
	
	# Build swarm warning label (centered at top)
	_build_swarm_warning_label()
	
	# Connect to service signals
	ProgressionManager.xp_changed.connect(_on_xp_changed)
	ProgressionManager.xp_gained.connect(_on_xp_gained)
	ProgressionManager.credits_changed.connect(_on_credits_changed)
	ProgressionManager.stardust_changed.connect(_on_stardust_changed)
	ProgressionManager.level_up_completed.connect(_on_level_up_completed)
	ProgressionManager.level_up_triggered.connect(_on_level_up_triggered)
	StationService.station_buff_triggered.connect(_on_station_buff_triggered)
	RunManager.run_started.connect(_on_run_started)
	SettingsManager.settings_changed.connect(_on_settings_changed)
	
	# Connect to enemy spawner signals (if it exists in scene)
	_connect_enemy_spawner_signals()
	
	# Wait a frame then find player
	await get_tree().process_frame
	_find_player()
	
	# Initialize display
	_update_timer(0.0)
	_update_level(1)
	_update_credits(0)
	_update_stardust(PersistenceManager.persistent_data.get("stardust", 0))
	_apply_debug_visibility()


func _apply_synthwave_theme() -> void:
	# Shield Bar - Neon blue (hidden by default)
	var shield_style: StyleBoxFlat = StyleBoxFlat.new()
	shield_style.bg_color = COLOR_SHIELD
	shield_style.corner_radius_top_left = 4
	shield_style.corner_radius_top_right = 4
	shield_style.corner_radius_bottom_left = 4
	shield_style.corner_radius_bottom_right = 4
	shield_bar.add_theme_stylebox_override("fill", shield_style)
	
	var shield_bg: StyleBoxFlat = StyleBoxFlat.new()
	shield_bg.bg_color = Color(0.05, 0.1, 0.2, 0.8)
	shield_bg.corner_radius_top_left = 4
	shield_bg.corner_radius_top_right = 4
	shield_bg.corner_radius_bottom_left = 4
	shield_bg.corner_radius_bottom_right = 4
	shield_bar.add_theme_stylebox_override("background", shield_bg)
	
	# Shield Label - Same style as HP label
	shield_label.add_theme_font_override("font", FONT_HEADER)
	shield_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	shield_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	shield_label.add_theme_constant_override("outline_size", 2)
	
	# HP Bar - Hot pink
	var hp_style: StyleBoxFlat = StyleBoxFlat.new()
	hp_style.bg_color = COLOR_HP
	hp_style.corner_radius_top_left = 4
	hp_style.corner_radius_top_right = 4
	hp_style.corner_radius_bottom_left = 4
	hp_style.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("fill", hp_style)
	
	var hp_bg: StyleBoxFlat = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.15, 0.05, 0.1, 0.8)
	hp_bg.corner_radius_top_left = 4
	hp_bg.corner_radius_top_right = 4
	hp_bg.corner_radius_bottom_left = 4
	hp_bg.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	
	# HP Label - Theme font + strong contrast
	hp_label.add_theme_font_override("font", FONT_HEADER)
	hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hp_label.add_theme_constant_override("outline_size", 2)
	
	# XP Bar - Neon purple
	var xp_style: StyleBoxFlat = StyleBoxFlat.new()
	xp_style.bg_color = COLOR_XP
	xp_style.corner_radius_top_left = 0
	xp_style.corner_radius_top_right = 0
	xp_style.corner_radius_bottom_left = 0
	xp_style.corner_radius_bottom_right = 0
	xp_bar.add_theme_stylebox_override("fill", xp_style)
	
	var xp_bg: StyleBoxFlat = StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.2, 0.08, 0.3, 0.9)  # Lighter purple background
	xp_bg.corner_radius_top_left = 0
	xp_bg.corner_radius_top_right = 0
	xp_bg.corner_radius_bottom_left = 0
	xp_bg.corner_radius_bottom_right = 0
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	
	# Timer - Cyan
	timer_label.add_theme_font_override("font", FONT_HEADER)
	timer_label.add_theme_color_override("font_color", COLOR_TIMER)
	timer_label.add_theme_color_override("font_outline_color", Color(0, 0.3, 0.4, 1.0))
	timer_label.add_theme_constant_override("outline_size", 2)
	
	# Debug stats - bottom left
	_build_debug_labels()
	
	# Level - Neon yellow with glow effect
	level_label.add_theme_font_override("font", FONT_HEADER)
	level_label.add_theme_color_override("font_color", COLOR_LEVEL)
	level_label.add_theme_color_override("font_outline_color", Color(1.0, 0.5, 0.0, 0.8))
	level_label.add_theme_constant_override("outline_size", 3)
	_level_base_scale = level_label.scale

	# Overtime multiplier label - styled dynamically via _update_overtime_label()
	overtime_label.add_theme_font_override("font", FONT_HEADER)
	overtime_label.add_theme_constant_override("outline_size", 3)
	
	# Credits - Gold
	credits_label.add_theme_font_override("font", FONT_HEADER)
	credits_label.add_theme_color_override("font_color", COLOR_CREDITS)

	# Stardust - Icy blue
	stardust_label.add_theme_font_override("font", FONT_HEADER)
	stardust_label.add_theme_color_override("font_color", COLOR_STARDUST)
	stardust_label.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.4, 1.0))
	stardust_label.add_theme_constant_override("outline_size", 2)


## Create debug stat labels programmatically in the bottom-left VBoxContainer.
func _build_debug_labels() -> void:
	damage_numbers_label = _make_debug_label("DMG NUMBERS: 0")
	enemies_label = _make_debug_label("ENEMIES: 0")
	xp_shards_label = _make_debug_label("XP SHARDS: 0")
	projectiles_label = _make_debug_label("PROJECTILES: 0")
	xp_label = _make_debug_label("XP: 0 / 7")
	nodes_label = _make_debug_label("NODES: 0")
	draw_calls_label = _make_debug_label("DRAW: 0")


## Factory for a single debug label with consistent style.
func _make_debug_label(initial_text: String) -> Label:
	var label: Label = Label.new()
	label.text = initial_text
	label.add_theme_font_override("font", FONT_HEADER)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	debug_container.add_child(label)
	return label




func _process(_delta: float) -> void:
	# Update debug stats (only when visible)
	if debug_container.visible:
		if damage_numbers_label:
			damage_numbers_label.text = "DMG NUMBERS: %d" % FrameCache.damage_numbers.size()
		if enemies_label:
			enemies_label.text = "ENEMIES: %d" % FrameCache.enemies.size()
		if xp_shards_label:
			xp_shards_label.text = "XP SHARDS: %d" % get_tree().get_nodes_in_group("xp_pickups").size()
		if projectiles_label:
			var area2d_count: int = get_tree().get_nodes_in_group("projectiles").size()
			var bb2d_count: int = BulletFactoryRef.get_active_bullet_count()
			projectiles_label.text = "PROJECTILES: %d" % (area2d_count + bb2d_count)
		if nodes_label:
			nodes_label.text = "NODES: %d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if draw_calls_label:
			draw_calls_label.text = "DRAW: %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	
	# Update timer (countdown)
	if RunManager.current_state == RunManager.GameState.PLAYING:
		_update_timer(RunManager.run_data.time_remaining)
		_update_overtime_label()
	
	# Update HP and shield from player stats
	if _player and _player.stats:
		var current_hp: float = _player.stats.current_hp
		var max_hp: float = _player.stats.get_stat("max_hp")
		_update_hp(current_hp, max_hp)
		var current_shield: float = _player.stats.current_shield
		var max_shield: float = _player.stats.get_stat("shield")
		_update_shield(current_shield, max_shield)

	# Keep XP popup pinned near screen center
	if _xp_popup and is_instance_valid(_xp_popup) and _xp_popup.visible:
		_xp_popup.update_screen_position()


func _find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		
		# Hook weapon events
		if _player.has_node("WeaponComponent"):
			var weapon_comp: Node = _player.get_node("WeaponComponent")
			if weapon_comp.has_signal("weapon_equipped") and not weapon_comp.weapon_equipped.is_connected(_on_weapon_changed):
				weapon_comp.weapon_equipped.connect(_on_weapon_changed)
			if weapon_comp.has_signal("weapon_removed") and not weapon_comp.weapon_removed.is_connected(_on_weapon_changed):
				weapon_comp.weapon_removed.connect(_on_weapon_changed)
			_refresh_weapon_list()
		_refresh_module_icons()
		
		# Initial HP + shield update
		if _player.stats:
			var current_hp: float = _player.stats.current_hp
			var max_hp: float = _player.stats.get_stat("max_hp")
			_update_hp(current_hp, max_hp)
			var current_shield: float = _player.stats.current_shield
			var max_shield: float = _player.stats.get_stat("shield")
			_update_shield(current_shield, max_shield)
			
			# Connect HP and shield changed signals
			_player.stats.hp_changed.connect(_on_hp_changed)
			_player.stats.shield_changed.connect(_on_shield_changed)
			if _player.stats.has_signal("lifesteal_healed"):
				_player.stats.lifesteal_healed.connect(_on_lifesteal_healed)

		# Wire ability ring indicator
		if ability_ring and ability_ring.has_method("setup"):
			ability_ring.setup(_player)


func _update_hp(current: float, maximum: float) -> void:
	var overheal_cap: float = 0.0
	if _player and _player.stats:
		overheal_cap = _player.stats.get_stat("overheal")
	var is_overhealed: bool = current > maximum and overheal_cap > 0.0

	# Expand bar to show overheal headroom when player has overheal stat
	if overheal_cap > 0.0:
		hp_bar.max_value = maximum + overheal_cap
	else:
		hp_bar.max_value = maximum
	hp_bar.value = maxf(current, 0.0)

	# Swap fill color: magenta when overhealed, hot pink normally
	var hp_fill: StyleBoxFlat = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if hp_fill:
		if is_overhealed:
			hp_fill.bg_color = COLOR_OVERHEAL
		else:
			hp_fill.bg_color = COLOR_HP

	# Label shows actual HP / max_hp (overheal visible as exceeding max)
	if is_overhealed:
		hp_label.text = "%d / %d" % [maxi(ceili(current), 0), ceili(maximum)]
	else:
		hp_label.text = "%d / %d" % [maxi(ceili(current), 0), ceili(maximum)]


## Update shield bar display. Shows/hides based on max_shield > 0.
func _update_shield(current: float, maximum: float) -> void:
	var should_show: bool = maximum > 0.0
	if shield_bar.visible != should_show:
		shield_bar.visible = should_show
		_reposition_bars()
	shield_bar.max_value = maximum
	shield_bar.value = maxf(current, 0.0)
	shield_label.text = "%d / %d" % [maxi(ceili(current), 0), ceili(maximum)]


## Repositions HP and shield bars based on shield visibility.
func _reposition_bars() -> void:
	if shield_bar.visible:
		# Shield bar on top, HP bar below
		shield_bar.offset_top = 8.0
		shield_bar.offset_bottom = 28.0
		hp_bar.offset_top = 32.0
		hp_bar.offset_bottom = 52.0
	else:
		# Only HP bar, centered vertically
		hp_bar.offset_top = 10.0
		hp_bar.offset_bottom = 30.0


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
	if time_remaining > 0.0:
		# Normal countdown
		var total_seconds: int = int(time_remaining)
		var minutes: int = int(total_seconds / 60.0)
		var seconds: int = total_seconds % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

		# Flash red when low on time (last 60s)
		if time_remaining <= 60.0:
			timer_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		else:
			timer_label.modulate = Color.WHITE
	else:
		# Overtime: count up from 0
		var overtime: float = absf(time_remaining)
		var total_seconds: int = int(overtime)
		var minutes: int = int(total_seconds / 60.0)
		var seconds: int = total_seconds % 60
		timer_label.text = "+%02d:%02d" % [minutes, seconds]

		if overtime >= 120.0:
			# 2+ minutes overtime → red
			timer_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		elif overtime >= 60.0:
			# 1+ minute overtime → orange
			timer_label.modulate = Color(1.0, 0.6, 0.1, 1.0)
		else:
			timer_label.modulate = Color.WHITE


## Update the overtime difficulty multiplier label (shown only during overtime).
func _update_overtime_label() -> void:
	if RunManager.run_data.time_remaining > 0.0:
		overtime_label.visible = false
		return

	var mult: float = RunManager.get_overtime_multiplier()
	overtime_label.visible = true
	overtime_label.text = "%.1fx" % mult

	# Color shifts: white/cyan → orange → red based on multiplier severity
	if mult >= 5.5:
		overtime_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
		overtime_label.add_theme_color_override("font_outline_color", Color(0.4, 0.0, 0.0, 0.8))
	elif mult >= 2.5:
		overtime_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1, 1.0))
		overtime_label.add_theme_color_override("font_outline_color", Color(0.4, 0.15, 0.0, 0.8))
	else:
		overtime_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.9, 1.0))
		overtime_label.add_theme_color_override("font_outline_color", Color(0.0, 0.3, 0.4, 0.8))


# --- Signal Handlers ---

func _on_settings_changed() -> void:
	_apply_debug_visibility()


## Show or hide the debug overlay based on the current setting.
func _apply_debug_visibility() -> void:
	debug_container.visible = SettingsManager.show_debug_overlay
	if _debug_xp_graph:
		_debug_xp_graph.visible = SettingsManager.show_debug_overlay


## Build the debug XP curve graph in the bottom-left debug panel.
func _build_debug_xp_graph() -> void:
	_debug_xp_graph = DEBUG_XP_GRAPH_SCENE.instantiate()
	# Size it to fit in the debug panel area
	_debug_xp_graph.custom_minimum_size = Vector2(300, 180)
	_debug_xp_graph.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_debug_xp_graph.visible = false
	# Add to debug container (left side) below other debug labels
	debug_container.add_child(_debug_xp_graph)


## Build the minimap in the bottom-right corner.
func _build_minimap() -> void:
	_minimap = MINIMAP_SCENE.instantiate()
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Position above the XP bar with margin
	var minimap_size: float = GameConfig.MINIMAP_SIZE
	_minimap.offset_left = -minimap_size - 10.0
	_minimap.offset_right = -10.0
	_minimap.offset_top = -minimap_size - 30.0  # Above XP bar
	_minimap.offset_bottom = -30.0
	add_child(_minimap)


## Build the full map overlay (shown when holding Tab/RT).
func _build_full_map_overlay() -> void:
	_full_map_overlay = Control.new()
	_full_map_overlay.set_script(FullMapOverlayScript)
	_full_map_overlay.name = "FullMapOverlay"
	add_child(_full_map_overlay)
	
	# Share fog of war reference from minimap
	if _minimap and _minimap.has_method("get_fog_of_war"):
		var fog: RefCounted = _minimap.get_fog_of_war()
		if fog and _full_map_overlay.has_method("set_fog_of_war"):
			_full_map_overlay.set_fog_of_war(fog)


## Build the stats panel shown alongside the full map overlay.
func _build_map_stats_panel() -> void:
	_map_stats_panel = STATS_PANEL_SCENE.instantiate() as PanelContainer
	_map_stats_panel.name = "MapStatsPanel"
	var anchor: Control = Control.new()
	anchor.name = "MapStatsPanelAnchor"
	anchor.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	anchor.anchor_left = 1.0
	anchor.anchor_right = 1.0
	anchor.anchor_top = 0.5
	anchor.anchor_bottom = 0.5
	anchor.offset_left = -300.0
	anchor.offset_right = -20.0
	anchor.offset_top = -400.0
	anchor.offset_bottom = 400.0
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.z_index = 100
	add_child(anchor)
	anchor.add_child(_map_stats_panel)
	_map_stats_panel.visible = false


## Build the weapon and module icon grids flanking the ability ring.
func _build_icon_grids() -> void:
	_weapon_slots = _build_slot_row(weapons_grid, GameConfig.MAX_WEAPON_SLOTS)
	_module_slots = _build_slot_row(modules_grid, GameConfig.MAX_MODULE_SLOTS)
	_build_icon_tooltip()


## Build the shared tooltip label shown above hovered icon slots.
func _build_icon_tooltip() -> void:
	_icon_tooltip = PanelContainer.new()
	var tip_style: StyleBoxFlat = StyleBoxFlat.new()
	tip_style.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	tip_style.border_color = Color(0.4, 0.4, 0.5, 0.8)
	tip_style.set_border_width_all(1)
	tip_style.set_corner_radius_all(4)
	tip_style.content_margin_left = 8.0
	tip_style.content_margin_right = 8.0
	tip_style.content_margin_top = 4.0
	tip_style.content_margin_bottom = 4.0
	_icon_tooltip.add_theme_stylebox_override("panel", tip_style)
	_icon_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_tooltip.z_index = 200
	_icon_tooltip.visible = false

	var tip_label: Label = Label.new()
	tip_label.name = "TipLabel"
	tip_label.add_theme_font_override("font", FONT_HEADER)
	tip_label.add_theme_font_size_override("font_size", 14)
	tip_label.add_theme_color_override("font_color", Color.WHITE)
	tip_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	tip_label.add_theme_constant_override("outline_size", 2)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_tooltip.add_child(tip_label)

	add_child(_icon_tooltip)


## Create N icon slots inside a container and return array of slot dictionaries.
func _build_slot_row(container: HBoxContainer, count: int) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in range(count):
		var slot: Dictionary = _create_icon_slot()
		container.add_child(slot.panel as Panel)
		slots.append(slot)
	return slots


## Create a single icon slot: Panel with TextureRect + level badge.
func _create_icon_slot() -> Dictionary:
	var panel: Panel = Panel.new()
	panel.custom_minimum_size = Vector2(ICON_SLOT_SIZE, ICON_SLOT_SIZE)
	panel.size = Vector2(ICON_SLOT_SIZE, ICON_SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT_BG
	style.border_color = COLOR_SLOT_BORDER_EMPTY
	style.border_width_left = ICON_BORDER_WIDTH
	style.border_width_right = ICON_BORDER_WIDTH
	style.border_width_top = ICON_BORDER_WIDTH
	style.border_width_bottom = ICON_BORDER_WIDTH
	style.corner_radius_top_left = ICON_CORNER_RADIUS
	style.corner_radius_top_right = ICON_CORNER_RADIUS
	style.corner_radius_bottom_left = ICON_CORNER_RADIUS
	style.corner_radius_bottom_right = ICON_CORNER_RADIUS
	panel.add_theme_stylebox_override("panel", style)

	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.visible = false
	panel.add_child(tex_rect)

	# Badge background — small dark pill behind the level number
	var badge_bg: PanelContainer = PanelContainer.new()
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	badge_style.corner_radius_top_left = 3
	badge_style.corner_radius_top_right = 3
	badge_style.corner_radius_bottom_left = 3
	badge_style.corner_radius_bottom_right = 3
	badge_style.content_margin_left = 3.0
	badge_style.content_margin_right = 3.0
	badge_style.content_margin_top = 1.0
	badge_style.content_margin_bottom = 1.0
	badge_bg.add_theme_stylebox_override("panel", badge_style)
	badge_bg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge_bg.offset_right = -2.0
	badge_bg.offset_bottom = -2.0
	badge_bg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge_bg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_bg.visible = false
	panel.add_child(badge_bg)

	var badge: Label = Label.new()
	badge.add_theme_font_override("font", FONT_HEADER)
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	badge.add_theme_constant_override("outline_size", 4)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_bg.add_child(badge)

	panel.mouse_entered.connect(_on_icon_slot_mouse_entered.bind(panel))
	panel.mouse_exited.connect(_on_icon_slot_mouse_exited)

	return {"panel": panel, "texture": tex_rect, "badge": badge, "badge_bg": badge_bg}



## Handle input for full map toggle.
func _unhandled_input(event: InputEvent) -> void:
	# Tab key or left trigger to show/hide full map
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_TAB:
			if key_event.pressed:
				_full_map_overlay.show_map()
				_show_map_stats_panel()
			else:
				_full_map_overlay.hide_map()
				_hide_map_stats_panel()
	elif event is InputEventJoypadMotion:
		var joy_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		# Left trigger (axis 4 = JOY_AXIS_TRIGGER_LEFT)
		if joy_event.axis == JOY_AXIS_TRIGGER_LEFT:
			if joy_event.axis_value >= 0.8:
				if not _full_map_overlay.visible:
					_full_map_overlay.show_map()
					_show_map_stats_panel()
			else:
				if _full_map_overlay.visible:
					_full_map_overlay.hide_map()
					_hide_map_stats_panel()


func _show_map_stats_panel() -> void:
	if _map_stats_panel:
		_map_stats_panel.snapshot()
		_map_stats_panel.refresh()
		_map_stats_panel.visible = true


func _hide_map_stats_panel() -> void:
	if _map_stats_panel:
		_map_stats_panel.visible = false


func _on_hp_changed(current: float, maximum: float) -> void:
	_update_hp(current, maximum)


func _on_shield_changed(current: float, maximum: float) -> void:
	_update_shield(current, maximum)


func _on_lifesteal_healed(amount: float, world_pos: Vector2) -> void:
	## Spawn a green "+N" floating number at the player position.
	if not SettingsManager.show_damage_numbers:
		return

	# Enforce soft cap — remove oldest if exceeded
	var existing: Array[Node] = FrameCache.damage_numbers
	if existing.size() >= GameConfig.DAMAGE_NUMBER_MAX_COUNT:
		if is_instance_valid(existing[0]):
			existing[0].queue_free()

	var label: DamageNumber = HEAL_NUMBER_SCENE.instantiate() as DamageNumber
	get_tree().current_scene.add_child(label)
	# Pass heal-specific damage_info so setup knows this is a heal number
	label.setup(amount, {"is_heal": true}, world_pos)


func _on_xp_changed(current: float, required: float, level: int) -> void:
	_update_xp(current, required)
	_update_level(level)


func _on_xp_gained(actual_amount: float, _player_position: Vector2) -> void:
	## Accumulate XP into a single persistent popup near the player ship.
	if not SettingsManager.show_damage_numbers:
		return

	# Lazy-init the single XP popup instance
	if _xp_popup == null or not is_instance_valid(_xp_popup):
		_xp_popup = XP_POPUP_SCENE.instantiate() as XpPopup
		self.add_child(_xp_popup)

	_xp_popup.add_xp(actual_amount)


func _on_credits_changed(amount: int) -> void:
	_update_credits(amount)
	_animate_credits_gain()


func _update_credits(amount: int) -> void:
	credits_label.text = "⟐ %d" % amount


func _animate_credits_gain() -> void:
	# Quick pulse animation when gaining credits
	var tween: Tween = create_tween()
	credits_label.scale = Vector2(1.3, 1.3)
	tween.tween_property(credits_label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)


func _on_stardust_changed(amount: int) -> void:
	_update_stardust(amount)
	_animate_stardust_gain()


func _update_stardust(amount: int) -> void:
	stardust_label.text = "✦ %d" % amount


func _animate_stardust_gain() -> void:
	## Quick pulse animation when gaining stardust.
	var tween: Tween = create_tween()
	stardust_label.scale = Vector2(1.3, 1.3)
	tween.tween_property(stardust_label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)


func _on_weapon_changed(_weapon_id: String = "") -> void:
	_refresh_weapon_list()


func _format_id_fallback(raw_id: String) -> String:
	if raw_id == "":
		return "Unknown"
	return raw_id.replace("_", " ").capitalize()


func _resolve_weapon_display_name(weapon_id: String) -> String:
	var fallback: String = _format_id_fallback(weapon_id)
	if not DataLoader:
		return fallback
	var weapon_data: Dictionary = DataLoader.get_weapon(weapon_id)
	if weapon_data.is_empty():
		return fallback
	return String(weapon_data.get("display_name", fallback))


func _resolve_module_display_name(module_id: String) -> String:
	var fallback: String = _format_id_fallback(module_id)
	if not DataLoader:
		return fallback
	var module_data: Dictionary = DataLoader.get_ship_upgrade(module_id)
	if module_data.is_empty():
		return fallback
	return String(module_data.get("name", module_data.get("display_name", fallback)))


func _refresh_weapon_list() -> void:
	if not _player or not _player.has_node("WeaponComponent"):
		return

	var weapon_comp: Node = _player.get_node("WeaponComponent")
	if not weapon_comp.has_method("get_equipped_weapon_summaries"):
		return

	var summaries: Array = weapon_comp.get_equipped_weapon_summaries()
	summaries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)

	for i in range(_weapon_slots.size()):
		var slot: Dictionary = _weapon_slots[i]
		var panel: Panel = slot.panel as Panel
		var tex_rect: TextureRect = slot.texture as TextureRect
		var badge: Label = slot.badge as Label
		var badge_bg: PanelContainer = slot.badge_bg as PanelContainer
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat

		if i < summaries.size():
			var s: Dictionary = summaries[i]
			var id: String = String(s.get("id", ""))
			var level: int = int(s.get("level", 1))
			var rarity: String = String(s.get("rarity", "common"))
			var weapon_data: Dictionary = DataLoader.get_weapon(id)
			var max_level_w: int = int(weapon_data.get("max_level", GameConfig.MAX_WEAPON_LEVEL))
			var is_maxed: bool = level >= max_level_w

			# Load weapon image
			var image_path: String = String(weapon_data.get("image", ""))
			if image_path != "" and ResourceLoader.exists("res://" + image_path):
				tex_rect.texture = load("res://" + image_path)
			else:
				tex_rect.texture = preload("res://icon.svg")
			tex_rect.visible = true

			# Rarity border
			var rarity_color: Color = UiColors.get_rarity_color(rarity)
			style.border_color = rarity_color

			# Level badge
			if is_maxed:
				badge.text = "MAX"
				badge.add_theme_color_override("font_color", UiColors.NEON_YELLOW)
			else:
				badge.text = str(level)
				badge.add_theme_color_override("font_color", Color.WHITE)
			badge_bg.visible = true

			# Tooltip name stored on panel metadata
			panel.set_meta("item_name", String(weapon_data.get("display_name", id)))
		else:
			# Empty slot
			tex_rect.texture = null
			tex_rect.visible = false
			style.border_color = COLOR_SLOT_BORDER_EMPTY
			badge_bg.visible = false
			panel.set_meta("item_name", "")


func _on_run_started() -> void:
	_refresh_module_icons()
	_refresh_weapon_list()


func _on_level_up_completed(_chosen_upgrade: Dictionary) -> void:
	_refresh_module_icons()
	_refresh_weapon_list()


func _on_level_up_triggered(_current_level: int, _available_upgrades: Array) -> void:
	_dismiss_map()


func _on_station_buff_triggered(_options: Array) -> void:
	_dismiss_map()


## Force-close the full map overlay (e.g. when an upgrade prompt pauses the game
## and the TAB release event would be missed).
func _dismiss_map() -> void:
	if _full_map_overlay and _full_map_overlay.visible:
		_full_map_overlay.hide_map()
		_hide_map_stats_panel()


func _refresh_module_icons() -> void:
	if not RunManager:
		return

	var upgrades: Array[Dictionary] = []
	var raw: Array = RunManager.run_data.get("ship_upgrades", [])
	for item: Variant in raw:
		if item is Dictionary:
			upgrades.append(item as Dictionary)

	upgrades.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)

	for i in range(_module_slots.size()):
		var slot: Dictionary = _module_slots[i]
		var panel: Panel = slot.panel as Panel
		var tex_rect: TextureRect = slot.texture as TextureRect
		var badge: Label = slot.badge as Label
		var badge_bg: PanelContainer = slot.badge_bg as PanelContainer
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat

		if i < upgrades.size():
			var u: Dictionary = upgrades[i]
			var id: String = String(u.get("id", ""))
			var stacks: int = int(u.get("stacks", 1))
			var rarity: String = String(u.get("rarity", "common"))
			var module_data: Dictionary = DataLoader.get_ship_upgrade(id)
			var max_level_m: int = int(module_data.get("max_level", 99))
			var is_maxed: bool = stacks >= max_level_m

			# Load module image
			var image_path: String = String(module_data.get("image", ""))
			if image_path != "" and ResourceLoader.exists("res://" + image_path):
				tex_rect.texture = load("res://" + image_path)
			else:
				tex_rect.texture = preload("res://icon.svg")
			tex_rect.visible = true

			# Rarity border
			var rarity_color: Color = UiColors.get_rarity_color(rarity)
			style.border_color = rarity_color

			# Level badge
			if is_maxed:
				badge.text = "MAX"
				badge.add_theme_color_override("font_color", UiColors.NEON_YELLOW)
			else:
				badge.text = str(stacks)
				badge.add_theme_color_override("font_color", Color.WHITE)
			badge_bg.visible = true

			# Tooltip name stored on panel metadata
			panel.set_meta("item_name", String(module_data.get("name", id)))
		else:
			# Empty slot
			tex_rect.texture = null
			tex_rect.visible = false
			style.border_color = COLOR_SLOT_BORDER_EMPTY
			badge_bg.visible = false
			panel.set_meta("item_name", "")


## Show tooltip above hovered icon slot.
func _on_icon_slot_mouse_entered(panel: Panel) -> void:
	var item_name: String = panel.get_meta("item_name", "") as String
	if item_name == "" or not _icon_tooltip:
		return
	var tip_label: Label = _icon_tooltip.get_node("TipLabel") as Label
	tip_label.text = item_name
	# Position above the slot, centered horizontally
	var panel_rect: Rect2 = panel.get_global_rect()
	_icon_tooltip.reset_size()
	await get_tree().process_frame
	var tip_size: Vector2 = _icon_tooltip.size
	_icon_tooltip.global_position = Vector2(
		panel_rect.position.x + (panel_rect.size.x - tip_size.x) * 0.5,
		panel_rect.position.y - tip_size.y - 4.0
	)
	_icon_tooltip.visible = true


## Hide tooltip when mouse leaves an icon slot.
func _on_icon_slot_mouse_exited() -> void:
	if _icon_tooltip:
		_icon_tooltip.visible = false


# =============================================================================
# SWARM WARNING UI
# =============================================================================

## Build the swarm warning label (initially hidden).
func _build_swarm_warning_label() -> void:
	_swarm_warning_label = Label.new()
	_swarm_warning_label.text = "A MASSIVE FLEET IS INBOUND"
	_swarm_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swarm_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_swarm_warning_label.add_theme_font_override("font", FONT_SWARM)
	_swarm_warning_label.add_theme_font_size_override("font_size", 48)
	_swarm_warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 1.0))  # Red-orange
	_swarm_warning_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_swarm_warning_label.add_theme_constant_override("outline_size", 4)
	
	# Position at top center, 50px from top
	_swarm_warning_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_swarm_warning_label.offset_top = 50.0
	_swarm_warning_label.offset_bottom = 110.0
	
	_swarm_warning_label.visible = false
	add_child(_swarm_warning_label)


## Connect to enemy spawner signals if available.
func _connect_enemy_spawner_signals() -> void:
	# Wait a frame to ensure scene is loaded
	await get_tree().process_frame
	
	var spawners: Array[Node] = get_tree().get_nodes_in_group("enemy_spawner")
	if spawners.size() > 0:
		var spawner: Node = spawners[0]
		if spawner.has_signal("swarm_warning_started"):
			spawner.swarm_warning_started.connect(_on_swarm_warning_started)
		if spawner.has_signal("swarm_started"):
			spawner.swarm_started.connect(_on_swarm_started)
	else:
		# Try finding by class/script name
		var spawner: Node = _find_enemy_spawner()
		if spawner:
			if spawner.has_signal("swarm_warning_started"):
				spawner.swarm_warning_started.connect(_on_swarm_warning_started)
			if spawner.has_signal("swarm_started"):
				spawner.swarm_started.connect(_on_swarm_started)


## Find enemy spawner in the scene tree.
func _find_enemy_spawner() -> Node:
	var current_scene: Node = get_tree().current_scene
	if not current_scene:
		return null
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		return spawner
	# Search deeper
	for child in current_scene.get_children():
		if child.name == "EnemySpawner":
			return child
	return null


## Called when swarm warning triggers — show the warning label.
func _on_swarm_warning_started() -> void:
	if _swarm_warning_label:
		_swarm_warning_label.visible = true


## Called when swarm actually starts — hide the warning.
func _on_swarm_started() -> void:
	if _swarm_warning_label:
		_swarm_warning_label.visible = false
