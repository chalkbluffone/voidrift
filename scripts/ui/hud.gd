extends CanvasLayer

## HUD - Displays player stats, XP, level, and run timer.
## Scales automatically via project stretch mode (canvas_items).

# Top left - Shield + HP bars
@onready var shield_bar: ProgressBar = $TopLeft/ShieldBar
@onready var shield_label: Label = $TopLeft/ShieldBar/ShieldLabel
@onready var hp_bar: ProgressBar = $TopLeft/HPBar
@onready var hp_label: Label = $TopLeft/HPBar/HPLabel

# Top center - Level
@onready var level_label: Label = $TopCenter/LevelLabel

# Top right
@onready var timer_label: Label = $TopRight/HBoxContainer/VBoxContainer/TimerLabel
@onready var credits_label: Label = $TopRight/HBoxContainer/VBoxContainer/CreditsLabel
@onready var stardust_label: Label = $TopRight/HBoxContainer/VBoxContainer/StardustLabel
@onready var captain_avatar: Control = $TopRight/HBoxContainer/CaptainAvatar

# Bottom left - debug stats
@onready var debug_container: VBoxContainer = $BottomLeftDebug
var fps_label: Label = null
var nodes_label: Label = null
var draw_calls_label: Label = null
var vram_label: Label = null

# Bottom - XP bar stretched across screen
@onready var xp_bar: ProgressBar = $BottomXP/XPBar
@onready var xp_label: Label = $BottomXP/XPBar/XPLabel

# Left side - weapons list
@onready var left_weapons: Control = $LeftWeapons
@onready var weapons_title: Label = $LeftWeapons/VBox/Title
@onready var weapons_list: VBoxContainer = $LeftWeapons/VBox/WeaponsList
@onready var modules_title: Label = $LeftWeapons/VBox/ModulesTitle
@onready var modules_list: VBoxContainer = $LeftWeapons/VBox/ModulesList

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var ProgressionManager: Node = get_node("/root/ProgressionManager")
@onready var PersistenceManager: Node = get_node("/root/PersistenceManager")
@onready var SettingsManager: Node = get_node("/root/SettingsManager")
@onready var DataLoader: Node = get_node("/root/DataLoader")
@onready var GameConfig: Node = get_node("/root/GameConfig")

var _player: Node = null
var _level_tween: Tween = null
var _level_base_scale: Vector2 = Vector2.ONE

# Synthwave colors
const COLOR_SHIELD: Color = Color(0.2, 0.6, 1.0, 1.0)  # Neon blue
const COLOR_HP: Color = Color(1.0, 0.08, 0.4, 1.0)  # Hot pink/magenta
const COLOR_XP: Color = Color(0.67, 0.2, 0.95, 1.0)  # Neon purple
const COLOR_TIMER: Color = Color(0.0, 1.0, 0.9, 1.0)  # Cyan
const COLOR_LEVEL: Color = Color(1.0, 0.95, 0.2, 1.0)  # Neon yellow
const COLOR_LEVEL_GLOW: Color = Color(1.0, 0.4, 0.8, 1.0)  # Pink glow for level up
const COLOR_CREDITS: Color = Color(1.0, 0.85, 0.1, 1.0)  # Gold for credits
const COLOR_STARDUST: Color = Color(0.6, 0.85, 1.0, 1.0)  # Icy blue for stardust
const COLOR_WEAPONS: Color = Color(0.2, 1.0, 0.9, 1.0)  # Cyan-ish

const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")
const FONT_SWARM: Font = preload("res://assets/fonts/Orbitron-ExtraBold.ttf")
const DEBUG_XP_GRAPH_SCENE: PackedScene = preload("res://scenes/ui/debug_xp_graph.tscn")
const MINIMAP_SCENE: PackedScene = preload("res://scenes/ui/minimap.tscn")
const FullMapOverlayScript: GDScript = preload("res://scripts/ui/full_map_overlay.gd")

var _debug_xp_graph: Control = null
var _swarm_warning_label: Label = null
var _minimap: Control = null
var _full_map_overlay: Control = null


func _ready() -> void:
	# Apply synthwave colors
	_apply_synthwave_theme()
	
	# Build captain avatar portrait
	_build_captain_avatar()
	
	# Build debug XP graph (in left debug panel)
	_build_debug_xp_graph()
	
	# Build minimap (bottom-right corner)
	_build_minimap()
	
	# Build full map overlay (shown on Tab/RT)
	_build_full_map_overlay()
	
	# Build swarm warning label (centered at top)
	_build_swarm_warning_label()
	
	# Connect to service signals
	ProgressionManager.xp_changed.connect(_on_xp_changed)
	ProgressionManager.credits_changed.connect(_on_credits_changed)
	ProgressionManager.stardust_changed.connect(_on_stardust_changed)
	ProgressionManager.level_up_completed.connect(_on_level_up_completed)
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
	shield_label.add_theme_constant_override("outline_size", 4)
	
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
	hp_label.add_theme_constant_override("outline_size", 4)
	
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
	
	# Credits - Gold
	credits_label.add_theme_font_override("font", FONT_HEADER)
	credits_label.add_theme_color_override("font_color", COLOR_CREDITS)

	# Stardust - Icy blue
	stardust_label.add_theme_font_override("font", FONT_HEADER)
	stardust_label.add_theme_color_override("font_color", COLOR_STARDUST)
	stardust_label.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.4, 1.0))
	stardust_label.add_theme_constant_override("outline_size", 2)

	# Weapons panel
	weapons_title.add_theme_font_override("font", FONT_HEADER)
	weapons_title.add_theme_color_override("font_color", COLOR_WEAPONS)
	weapons_title.add_theme_color_override("font_outline_color", Color(0, 0.25, 0.3, 1.0))
	weapons_title.add_theme_constant_override("outline_size", 2)
	modules_title.add_theme_font_override("font", FONT_HEADER)
	modules_title.add_theme_color_override("font_color", COLOR_WEAPONS)
	modules_title.add_theme_color_override("font_outline_color", Color(0, 0.25, 0.3, 1.0))
	modules_title.add_theme_constant_override("outline_size", 2)


## Create debug stat labels programmatically in the bottom-left VBoxContainer.
func _build_debug_labels() -> void:
	fps_label = _make_debug_label("FPS: 0")
	nodes_label = _make_debug_label("NODES: 0")
	draw_calls_label = _make_debug_label("DRAW: 0")
	vram_label = _make_debug_label("VRAM: 0 MB")


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


## Avatar circle diameter in pixels.
## Tuned in GameConfig: HUD_AVATAR_SIZE, HUD_AVATAR_CROP_FRACTION

## Build a circular-masked captain portrait in the CaptainAvatar container.
func _build_captain_avatar() -> void:
	if not captain_avatar:
		return
	var captain_data: Dictionary = RunManager.run_data.get("captain_data", {})
	var sprite_path: String = String(captain_data.get("sprite", ""))
	if sprite_path.is_empty() or not ResourceLoader.exists(sprite_path):
		captain_avatar.visible = false
		return

	var tex: Texture2D = load(sprite_path) as Texture2D
	if tex == null:
		captain_avatar.visible = false
		return

	# Compute texture aspect ratio so the shader can correct for non-square images
	var tex_size: Vector2 = tex.get_size()
	var tex_aspect: float = tex_size.x / tex_size.y if tex_size.y > 0.0 else 1.0

	# Portrait — use a ColorRect with a shader that does everything:
	# 1. Samples the texture with correct aspect ratio
	# 2. Shows only the top portion (head & shoulders)
	# 3. Masks to a perfect circle
	var portrait: ColorRect = ColorRect.new()
	portrait.color = Color(1, 1, 1, 1)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	captain_avatar.add_child(portrait)

	var shader_code: String = """
shader_type canvas_item;

uniform sampler2D portrait_tex : filter_linear;
uniform float crop_fraction : hint_range(0.1, 1.0) = 0.5;
uniform float tex_aspect = 1.0;

void fragment() {
	// Sample a square region from the texture with uniform scaling on both axes.
	// crop_fraction zooms in (smaller = tighter crop on head).
	vec2 sample_uv;
	if (tex_aspect >= 1.0) {
		// Wide or square texture: fit full height, center-crop width
		float x_span = crop_fraction / tex_aspect;
		sample_uv.x = mix(0.5 - x_span * 0.5, 0.5 + x_span * 0.5, UV.x);
		sample_uv.y = UV.y * crop_fraction;
	} else {
		// Tall texture (typical portrait): fit full width, crop from top
		float half_crop = crop_fraction * 0.5;
		sample_uv.x = mix(0.5 - half_crop, 0.5 + half_crop, UV.x);
		sample_uv.y = UV.y * tex_aspect * crop_fraction;
	}

	vec4 col = texture(portrait_tex, sample_uv);

	// Perfect circle mask
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	col.a *= 1.0 - smoothstep(0.47, 0.5, dist);
	COLOR = col;
}
"""
	var shader: Shader = Shader.new()
	shader.code = shader_code
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("portrait_tex", tex)
	mat.set_shader_parameter("crop_fraction", GameConfig.HUD_AVATAR_CROP_FRACTION)
	mat.set_shader_parameter("tex_aspect", tex_aspect)
	portrait.material = mat

	# Circular border ring (synthwave cyan)
	var border_rect: ColorRect = ColorRect.new()
	border_rect.color = Color(1, 1, 1, 1)
	border_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	captain_avatar.add_child(border_rect)

	var border_shader_code: String = """
shader_type canvas_item;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float ring = smoothstep(0.46, 0.48, dist) * (1.0 - smoothstep(0.49, 0.51, dist));
	COLOR = vec4(0.0, 1.0, 0.9, ring);
}
"""
	var border_shader: Shader = Shader.new()
	border_shader.code = border_shader_code
	var border_mat: ShaderMaterial = ShaderMaterial.new()
	border_mat.shader = border_shader
	border_rect.material = border_mat


func _process(_delta: float) -> void:
	# Update debug stats (only when visible)
	if debug_container.visible:
		if fps_label:
			fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
		if nodes_label:
			nodes_label.text = "NODES: %d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if draw_calls_label:
			draw_calls_label.text = "DRAW: %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if vram_label:
			var vram_mb: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
			vram_label.text = "VRAM: %.1f MB" % vram_mb
	
	# Update timer (countdown)
	if RunManager.current_state == RunManager.GameState.PLAYING:
		_update_timer(RunManager.run_data.time_remaining)
	
	# Update HP and shield from player stats
	if _player and _player.stats:
		var current_hp: float = _player.stats.current_hp
		var max_hp: float = _player.stats.get_stat("max_hp")
		_update_hp(current_hp, max_hp)
		var current_shield: float = _player.stats.current_shield
		var max_shield: float = _player.stats.get_stat("shield")
		_update_shield(current_shield, max_shield)


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
		_refresh_modules_list()
		
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


func _update_hp(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = maxf(current, 0.0)
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
		shield_bar.offset_bottom = 38.0
		hp_bar.offset_top = 42.0
		hp_bar.offset_bottom = 72.0
	else:
		# Only HP bar, centered vertically
		hp_bar.offset_top = 10.0
		hp_bar.offset_bottom = 50.0


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
	_minimap.offset_top = -minimap_size - 50.0  # Above XP bar
	_minimap.offset_bottom = -50.0
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


## Handle input for full map toggle.
func _unhandled_input(event: InputEvent) -> void:
	# Tab key or right trigger to show/hide full map
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_TAB:
			if key_event.pressed:
				_full_map_overlay.show_map()
			else:
				_full_map_overlay.hide_map()
	elif event is InputEventJoypadButton:
		var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
		# Right trigger (button 7 on most controllers)
		if joy_event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			if joy_event.pressed:
				_full_map_overlay.show_map()
			else:
				_full_map_overlay.hide_map()


func _on_hp_changed(current: float, maximum: float) -> void:
	_update_hp(current, maximum)


func _on_shield_changed(current: float, maximum: float) -> void:
	_update_shield(current, maximum)


func _on_xp_changed(current: float, required: float, level: int) -> void:
	_update_xp(current, required)
	_update_level(level)


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
		var weapon_name: String = id
		if DataLoader:
			var w: Dictionary = DataLoader.get_weapon(id)
			weapon_name = String(w.get("name", id))
		var label: Label = Label.new()
		label.text = "%s  LV %d" % [weapon_name.to_upper(), level]
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_font_override("font", FONT_HEADER)
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
	if not RunManager:
		return
	left_weapons.visible = true

	for child in modules_list.get_children():
		child.queue_free()

	var upgrades: Array = []
	var raw: Array = RunManager.run_data.get("ship_upgrades", [])
	for item: Variant in raw:
		if item is Dictionary:
			upgrades.append(item)

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
		var label: Label = Label.new()
		label.text = "%s  LV %d" % [display_name.to_upper(), level]
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_font_override("font", FONT_HEADER)
		label.add_theme_font_size_override("font_size", 13)
		label.tooltip_text = "%s (LV %d)" % [id, level]
		modules_list.add_child(label)


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
