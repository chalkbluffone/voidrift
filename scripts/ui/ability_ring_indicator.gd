extends Control

## AbilityRingIndicator — Combined HUD element showing captain ability cooldown
## (center circle) surrounded by a 360° ring of phase shift charge segments.
## Two keybind badges: below center (ability) and bottom-left (phase shift).
## All rendering via _draw() — no external textures.

# =============================================================================
# CONSTANTS
# =============================================================================
const INDICATOR_SIZE: float = 160.0
const INNER_RADIUS: float = 50.0          # Ability icon circle radius
const RING_INNER: float = 60.0            # Ring inner edge
const RING_OUTER: float = 72.0            # Ring outer edge
const RING_WIDTH: float = 12.0            # Stroke width for draw_arc
const RING_GAP_DEGREES: float = 6.0       # Gap between segments in degrees
const ARC_POINT_COUNT: int = 16           # Points per arc segment

const BADGE_SIZE: Vector2 = Vector2(36.0, 24.0)
const BADGE_FONT_SIZE: int = 14
const BADGE_CORNER_RADIUS: float = 4.0

const COLOR_CHARGE_FULL: Color = Color(0.0, 1.0, 1.0, 1.0)        # Neon cyan
const COLOR_CHARGE_EMPTY: Color = Color(0.3, 0.3, 0.3, 0.5)       # Dim gray
const COLOR_ABILITY_BG: Color = Color(0.1, 0.1, 0.15, 0.9)        # Dark bg
const COLOR_ABILITY_READY: Color = Color(0.8, 0.85, 0.9, 1.0)     # Bright when ready
const COLOR_COOLDOWN_OVERLAY: Color = Color(0.0, 0.0, 0.0, 0.6)   # Dark pie overlay
const COLOR_ACTIVE_GLOW: Color = Color(1.0, 0.2, 0.8, 1.0)        # Neon magenta
const COLOR_BADGE_BG: Color = Color(0.05, 0.05, 0.1, 0.85)        # Dark badge bg
const COLOR_BADGE_TEXT: Color = Color(1.0, 1.0, 1.0, 0.95)         # White text
const COLOR_COOLDOWN_TEXT: Color = Color(1.0, 1.0, 1.0, 0.9)       # Cooldown seconds

const FONT_PATH: String = "res://assets/fonts/Orbitron-Bold.ttf"

# =============================================================================
# STATE
# =============================================================================
var _phase_current: int = 0
var _phase_max: int = 3
var _phase_recharge_progress: float = 0.0    # 0.0–1.0 for recharging segment

var _ability_cooldown_progress: float = 0.0  # 0.0 = ready, 1.0 = full cooldown remain
var _ability_active: bool = false
var _ability_duration_remaining: float = 0.0
var _ability_cooldown_remaining: float = 0.0
var _ability_name: String = ""
var _has_ability: bool = false

var _input_device: String = "keyboard"
var _ability_keybind: String = "Q"
var _phase_keybind: String = "Space"

var _ship: Node = null
var _font: Font = null
var _glow_pulse: float = 0.0  # 0–1 oscillation for active glow


func _ready() -> void:
	custom_minimum_size = Vector2(INDICATOR_SIZE, INDICATOR_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font
	else:
		_font = ThemeDB.fallback_font


## Wire this indicator to a player ship. Connects all signals and reads initial state.
func setup(ship: Node) -> void:
	_ship = ship
	if not _ship:
		return

	# Phase shift signals
	if _ship.has_signal("phase_energy_changed"):
		_ship.phase_energy_changed.connect(_on_phase_energy_changed)

	# Captain ability signals
	if _ship.has_signal("captain_ability_activated"):
		_ship.captain_ability_activated.connect(_on_ability_activated)
	if _ship.has_signal("captain_ability_expired"):
		_ship.captain_ability_expired.connect(_on_ability_expired)
	if _ship.has_signal("captain_ability_ready"):
		_ship.captain_ability_ready.connect(_on_ability_ready)

	# Input device signal
	if _ship.has_signal("input_device_changed"):
		_ship.input_device_changed.connect(_on_input_device_changed)

	# Read initial state
	_phase_current = _ship.phase_energy
	_phase_max = _ship.max_phase_energy
	_input_device = _ship.get_input_device()

	# Captain ability initial state
	var ability: Node = _ship.get_captain_ability()
	if ability:
		_has_ability = true
		_ability_name = ability.ability_name
		_ability_active = ability._is_active
		_ability_cooldown_progress = ability.get_cooldown_percent()
	else:
		_has_ability = false
		_ability_name = ""

	# Resolve keybinds
	_ability_keybind = _resolve_keybind_label("captain_ability", _input_device)
	_phase_keybind = _resolve_keybind_label("phase_shift", _input_device)

	queue_redraw()


func _process(delta: float) -> void:
	if not _ship or not is_instance_valid(_ship):
		return

	var needs_redraw: bool = false

	# Poll phase recharge progress for smooth animation
	var new_recharge: float = _ship.get_phase_recharge_progress()
	if not is_equal_approx(_phase_recharge_progress, new_recharge):
		_phase_recharge_progress = new_recharge
		needs_redraw = true

	# Poll ability cooldown for smooth sweep
	var ability: Node = _ship.get_captain_ability()
	if ability:
		var new_cooldown: float = ability.get_cooldown_percent()
		if not is_equal_approx(_ability_cooldown_progress, new_cooldown):
			_ability_cooldown_progress = new_cooldown
			needs_redraw = true

		# Poll active state + duration
		var was_active: bool = _ability_active
		_ability_active = ability._is_active
		if _ability_active:
			_ability_duration_remaining = ability._duration_remaining
			needs_redraw = true
		elif was_active:
			needs_redraw = true

		_ability_cooldown_remaining = ability._cooldown_remaining

	# Glow pulse animation when active
	if _ability_active:
		_glow_pulse += delta * 4.0
		if _glow_pulse > TAU:
			_glow_pulse -= TAU
		needs_redraw = true

	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	# Ring center at XP bar top edge (40px from bottom) so 50% overlaps the bar
	var center: Vector2 = Vector2(size.x * 0.5, size.y - 40.0)

	_draw_ring_segments(center)
	_draw_ability_circle(center)
	if _ability_active:
		_draw_active_glow(center)
	_draw_badge(center, true)   # Ability badge (below center)
	_draw_badge(center, false)  # Phase shift badge (left of ring)


# =============================================================================
# RING SEGMENTS (Phase Shift Charges)
# =============================================================================
func _draw_ring_segments(center: Vector2) -> void:
	if _phase_max <= 0:
		return

	var ring_radius: float = (RING_INNER + RING_OUTER) * 0.5
	var gap_rad: float = deg_to_rad(RING_GAP_DEGREES)
	var total_gap: float = gap_rad * float(_phase_max)
	var segment_arc: float = (TAU - total_gap) / float(_phase_max)

	# Start from top (12 o'clock = -PI/2), go clockwise
	var start_angle: float = -PI / 2.0

	for i: int in range(_phase_max):
		var seg_start: float = start_angle + float(i) * (segment_arc + gap_rad)
		var seg_end: float = seg_start + segment_arc

		if i < _phase_current:
			# Full charge — bright cyan
			draw_arc(center, ring_radius, seg_start, seg_end, ARC_POINT_COUNT, COLOR_CHARGE_FULL, RING_WIDTH, true)
		elif i == _phase_current and _phase_recharge_progress > 0.0:
			# Recharging — draw empty background, then partial fill
			draw_arc(center, ring_radius, seg_start, seg_end, ARC_POINT_COUNT, COLOR_CHARGE_EMPTY, RING_WIDTH, true)
			var fill_end: float = seg_start + segment_arc * _phase_recharge_progress
			var fill_color: Color = COLOR_CHARGE_EMPTY.lerp(COLOR_CHARGE_FULL, _phase_recharge_progress)
			draw_arc(center, ring_radius, seg_start, fill_end, ARC_POINT_COUNT, fill_color, RING_WIDTH + 0.5, true)
		else:
			# Empty charge — dim
			draw_arc(center, ring_radius, seg_start, seg_end, ARC_POINT_COUNT, COLOR_CHARGE_EMPTY, RING_WIDTH, true)


# =============================================================================
# ABILITY CIRCLE (Center)
# =============================================================================
func _draw_ability_circle(center: Vector2) -> void:
	# Background circle
	draw_circle(center, INNER_RADIUS, COLOR_ABILITY_BG)

	# Cooldown pie overlay (sweeps clockwise from top)
	if _ability_cooldown_progress > 0.001 and not _ability_active:
		_draw_cooldown_pie(center, INNER_RADIUS, _ability_cooldown_progress)

	# Ability text (name or cooldown seconds)
	if _font:
		var display_text: String = ""
		var text_color: Color = COLOR_ABILITY_READY

		if _ability_active:
			display_text = "%d" % ceili(_ability_duration_remaining)
			text_color = COLOR_ACTIVE_GLOW
		elif _ability_cooldown_progress > 0.001:
			display_text = "%d" % ceili(_ability_cooldown_remaining)
			text_color = COLOR_COOLDOWN_TEXT
		elif _has_ability:
			# Show full ability name, scaled to fit
			display_text = _ability_name.to_upper() if _ability_name.length() > 0 else "?"
			text_color = COLOR_ABILITY_READY
		else:
			display_text = "-"
			text_color = COLOR_CHARGE_EMPTY

		# Scale font size to fit inside the circle
		var max_text_width: float = INNER_RADIUS * 1.6
		var font_size: int = 20
		var measured: float = _font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		while measured > max_text_width and font_size > 8:
			font_size -= 1
			measured = _font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x

		var text_size: Vector2 = _font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = center + Vector2(-text_size.x * 0.5, text_size.y * 0.3)
		draw_string(_font, text_pos, display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)

	# Thin border ring when ready
	if _ability_cooldown_progress <= 0.001 and not _ability_active and _has_ability:
		draw_arc(center, INNER_RADIUS, 0.0, TAU, 32, COLOR_ABILITY_READY, 2.5, true)


## Draw a clockwise pie overlay from 12 o'clock representing cooldown progress.
func _draw_cooldown_pie(center: Vector2, radius: float, progress: float) -> void:
	# progress: 1.0 = fully on cooldown (full pie), 0.0 = ready (no pie)
	var arc_angle: float = TAU * progress
	var num_points: int = maxi(int(arc_angle / 0.1), 4)
	var points: PackedVector2Array = PackedVector2Array()
	points.append(center)

	var start_angle: float = -PI / 2.0
	for i: int in range(num_points + 1):
		var angle: float = start_angle + arc_angle * (float(i) / float(num_points))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	if points.size() >= 3:
		var colors: PackedColorArray = PackedColorArray()
		for _j: int in range(points.size()):
			colors.append(COLOR_COOLDOWN_OVERLAY)
		draw_polygon(points, colors)


# =============================================================================
# ACTIVE GLOW
# =============================================================================
func _draw_active_glow(center: Vector2) -> void:
	var pulse_alpha: float = 0.5 + 0.5 * sin(_glow_pulse)
	var glow_color: Color = Color(COLOR_ACTIVE_GLOW.r, COLOR_ACTIVE_GLOW.g, COLOR_ACTIVE_GLOW.b, pulse_alpha * 0.8)

	# Inner glow ring
	draw_arc(center, INNER_RADIUS + 4.0, 0.0, TAU, 32, glow_color, 4.0, true)

	# Outer subtle glow
	var outer_glow: Color = Color(glow_color.r, glow_color.g, glow_color.b, pulse_alpha * 0.3)
	draw_arc(center, INNER_RADIUS + 10.0, 0.0, TAU, 32, outer_glow, 3.0, true)


# =============================================================================
# KEYBIND BADGES
# =============================================================================
func _draw_badge(center: Vector2, is_ability: bool) -> void:
	var label_text: String = _ability_keybind if is_ability else _phase_keybind
	if label_text.is_empty():
		return

	# Measure text to size badge dynamically
	var text_width: float = 0.0
	if _font:
		text_width = _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, BADGE_FONT_SIZE).x

	var badge_w: float = maxf(text_width + 8.0, BADGE_SIZE.x)
	var badge_h: float = BADGE_SIZE.y

	# Position: below center for ability, left of ring for phase shift
	var badge_center: Vector2
	if is_ability:
		badge_center = center + Vector2(0.0, INNER_RADIUS + 1.0)
	else:
		# 10px gap from ring edge, vertically 10px above XP bar top
		var ring_left: float = center.x - RING_OUTER
		badge_center = Vector2(ring_left - 10.0 - badge_w * 0.5, size.y - 10.0 - badge_h * 0.5)

	var badge_rect: Rect2 = Rect2(badge_center - Vector2(badge_w * 0.5, badge_h * 0.5), Vector2(badge_w, badge_h))

	# Background
	draw_rect(badge_rect, COLOR_BADGE_BG)

	# Border
	var border_color: Color = COLOR_CHARGE_FULL if not is_ability else COLOR_ACTIVE_GLOW.lerp(COLOR_CHARGE_FULL, 0.5)
	draw_rect(badge_rect, Color(border_color.r, border_color.g, border_color.b, 0.4), false, 1.0)

	# Text
	if _font:
		var text_size: Vector2 = _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, BADGE_FONT_SIZE)
		var text_pos: Vector2 = badge_center + Vector2(-text_size.x * 0.5, text_size.y * 0.3)
		draw_string(_font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, BADGE_FONT_SIZE, COLOR_BADGE_TEXT)


# =============================================================================
# KEYBIND RESOLUTION
# =============================================================================

## Reads InputMap events to determine the display label for an action.
func _resolve_keybind_label(action: String, device: String) -> String:
	if not InputMap.has_action(action):
		return "?"

	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for event: InputEvent in events:
		if device == "keyboard":
			if event is InputEventKey:
				var key_event: InputEventKey = event as InputEventKey
				var keycode: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
				return _key_name(keycode)
		else:
			if event is InputEventJoypadButton:
				var btn: InputEventJoypadButton = event as InputEventJoypadButton
				return _joypad_button_name(btn.button_index)
			elif event is InputEventJoypadMotion:
				var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
				return _joypad_axis_name(motion.axis, motion.axis_value)

	return "?"


## Convert a keyboard keycode to a short display name.
func _key_name(keycode: int) -> String:
	match keycode:
		KEY_SPACE:
			return "Space"
		KEY_TAB:
			return "Tab"
		KEY_ESCAPE:
			return "Esc"
		KEY_SHIFT:
			return "Shift"
		KEY_CTRL:
			return "Ctrl"
		KEY_ALT:
			return "Alt"
		KEY_ENTER:
			return "Enter"
		_:
			var key_name: String = OS.get_keycode_string(keycode)
			if key_name.length() > 5:
				return key_name.left(5)
			return key_name


## Convert a joypad button index to a display name.
func _joypad_button_name(index: int) -> String:
	match index:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_BACK:
			return "Back"
		_:
			return "B%d" % index


## Convert a joypad axis + direction to a display name.
func _joypad_axis_name(axis: int, value: float) -> String:
	match axis:
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
		JOY_AXIS_LEFT_X:
			return "LS←" if value < 0 else "LS→"
		JOY_AXIS_LEFT_Y:
			return "LS↑" if value < 0 else "LS↓"
		JOY_AXIS_RIGHT_X:
			return "RS←" if value < 0 else "RS→"
		JOY_AXIS_RIGHT_Y:
			return "RS↑" if value < 0 else "RS↓"
		_:
			return "A%d" % axis


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================
func _on_phase_energy_changed(current: int, maximum: int) -> void:
	_phase_current = current
	_phase_max = maximum
	queue_redraw()


func _on_ability_activated() -> void:
	_ability_active = true
	_glow_pulse = 0.0
	queue_redraw()


func _on_ability_expired() -> void:
	_ability_active = false
	queue_redraw()


func _on_ability_ready() -> void:
	_ability_cooldown_progress = 0.0
	queue_redraw()


func _on_input_device_changed(device: String) -> void:
	_input_device = device
	_ability_keybind = _resolve_keybind_label("captain_ability", _input_device)
	_phase_keybind = _resolve_keybind_label("phase_shift", _input_device)
	queue_redraw()
