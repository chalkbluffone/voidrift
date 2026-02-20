extends Control

## DebugXPGraph - Displays the XP curve for levels 1-100 with current level highlighted.
## Synthwave-styled debug visualization. Only visible when debug overlay is enabled.

const GRAPH_WIDTH: float = 350.0
const GRAPH_HEIGHT: float = 200.0
const PADDING: float = 10.0
const MAX_LEVEL: int = 50

# Synthwave colors
const COLOR_BG: Color = Color(0.05, 0.02, 0.1, 0.8)
const COLOR_BORDER: Color = Color(0.0, 1.0, 0.9, 0.6)
const COLOR_AXIS: Color = Color(1.0, 1.0, 1.0, 0.3)
const COLOR_CURVE: Color = Color(0.0, 1.0, 1.0, 1.0)  # Cyan
const COLOR_HIGHLIGHT: Color = Color(1.0, 0.08, 0.4, 1.0)  # Magenta
const COLOR_DOT: Color = Color(1.0, 0.4, 0.8, 1.0)  # Pink

@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var ProgressionManager: Node = get_node("/root/ProgressionManager")

var _cached_costs: Array[float] = []
var _last_level: int = -1
var _max_cost: float = 1.0
var _min_cost: float = 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(GRAPH_WIDTH, GRAPH_HEIGHT)
	_cache_xp_costs()
	ProgressionManager.xp_changed.connect(_on_xp_changed)


## Cache XP costs for all levels to avoid recomputing every frame.
func _cache_xp_costs() -> void:
	_cached_costs.clear()
	_cached_costs.resize(MAX_LEVEL + 1)
	
	for level: int in range(1, MAX_LEVEL + 2):
		var cost: float = _xp_cost_for_level(level)
		if level <= MAX_LEVEL:
			_cached_costs[level] = cost
	
	# Find min/max for log scaling (skip level 0)
	_min_cost = _cached_costs[1] if _cached_costs.size() > 1 else 1.0
	_max_cost = _cached_costs[MAX_LEVEL] if _cached_costs.size() > MAX_LEVEL else 1.0
	
	# Ensure valid range
	if _min_cost <= 0.0:
		_min_cost = 1.0
	if _max_cost <= _min_cost:
		_max_cost = _min_cost + 1.0


## Compute XP cost to go from level to level+1.
func _xp_cost_for_level(level: int) -> float:
	var curr: float = _xp_threshold(level)
	var next: float = _xp_threshold(level + 1)
	return maxf(next - curr, 1.0)


## Mirror of ProgressionManager._xp_threshold using GameConfig values.
func _xp_threshold(level: int) -> float:
	if level <= 1:
		return 0.0
	var total: float = 0.0
	for n: int in range(1, level):
		total += GameConfig.XP_BASE * pow(float(n), GameConfig.XP_EXPONENT)
	return total


## Format XP value with K/M suffix for compact display.
func _format_xp(value: float) -> String:
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	elif value >= 1000.0:
		return "%.1fK" % (value / 1000.0)
	else:
		return "%d" % int(value)


func _on_xp_changed(_current: float, _required: float, level: int) -> void:
	if level != _last_level:
		_last_level = level
		queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, Vector2(GRAPH_WIDTH, GRAPH_HEIGHT))
	
	# Background
	draw_rect(rect, COLOR_BG)
	
	# Border
	draw_rect(rect, COLOR_BORDER, false, 2.0)
	
	# Plot area
	var plot_left: float = PADDING
	var plot_right: float = GRAPH_WIDTH - PADDING
	var plot_top: float = PADDING
	var plot_bottom: float = GRAPH_HEIGHT - PADDING
	var plot_width: float = plot_right - plot_left
	var plot_height: float = plot_bottom - plot_top
	
	# Axis lines
	draw_line(Vector2(plot_left, plot_bottom), Vector2(plot_right, plot_bottom), COLOR_AXIS, 1.0)
	draw_line(Vector2(plot_left, plot_top), Vector2(plot_left, plot_bottom), COLOR_AXIS, 1.0)
	
	# Vertical grid lines every 10 levels
	var grid_color: Color = Color(0.3, 0.3, 0.4, 0.6)
	var grid_levels: Array[int] = [10, 20, 30, 40]
	var grid_positions: Dictionary = {}  # Store positions for later dot drawing
	for grid_level: int in grid_levels:
		var grid_x_ratio: float = float(grid_level - 1) / float(MAX_LEVEL - 1)
		var grid_x: float = plot_left + grid_x_ratio * plot_width
		draw_line(Vector2(grid_x, plot_top), Vector2(grid_x, plot_bottom), grid_color, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(grid_x - 6.0, plot_top + 10.0), str(grid_level), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, grid_color)
		grid_positions[grid_level] = grid_x
	
	# Linear Y-axis — show full range to see entire curve shape
	var y_max: float = _max_cost
	var y_min: float = 0.0
	var y_range: float = y_max - y_min
	if y_range <= 0.0:
		y_range = 1.0
	
	var prev_point: Vector2 = Vector2.ZERO
	var current_level: int = 1
	if RunManager and RunManager.run_data:
		current_level = int(RunManager.run_data.get("level", 1))
	
	var highlight_x: float = 0.0
	var highlight_y: float = 0.0
	
	for level: int in range(1, MAX_LEVEL + 1):
		var x_ratio: float = float(level - 1) / float(MAX_LEVEL - 1)
		var x: float = plot_left + x_ratio * plot_width
		
		var cost: float = _cached_costs[level]
		# Clamp to visible range, values above y_max hit the ceiling
		var y_ratio: float = clampf(cost / y_range, 0.0, 1.0)
		var y: float = plot_bottom - y_ratio * plot_height
		
		var point: Vector2 = Vector2(x, y)
		
		if level > 1:
			draw_line(prev_point, point, COLOR_CURVE, 2.0)
		
		# Track current level position
		if level == current_level:
			highlight_x = x
			highlight_y = y
		
		prev_point = point
	
	# Draw dots and XP labels at grid marker positions
	var marker_color: Color = Color(1.0, 0.8, 0.2, 1.0)  # Gold/yellow
	for grid_level: int in grid_levels:
		if grid_level <= MAX_LEVEL and grid_positions.has(grid_level):
			var marker_x: float = grid_positions[grid_level]
			var marker_cost: float = _cached_costs[grid_level]
			var marker_y_ratio: float = clampf(marker_cost / y_range, 0.0, 1.0)
			var marker_y: float = plot_bottom - marker_y_ratio * plot_height
			
			# Draw dot
			draw_circle(Vector2(marker_x, marker_y), 4.0, marker_color)
			
			# Draw XP label (format large numbers with K/M suffix)
			var xp_text: String = _format_xp(marker_cost)
			draw_string(ThemeDB.fallback_font, Vector2(marker_x + 6.0, marker_y - 4.0), xp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, marker_color)
	
	# Draw current level highlight (vertical line + dot)
	if current_level >= 1 and current_level <= MAX_LEVEL:
		# Vertical line
		draw_line(
			Vector2(highlight_x, plot_top),
			Vector2(highlight_x, plot_bottom),
			COLOR_HIGHLIGHT,
			1.5
		)
		
		# Dot on curve
		draw_circle(Vector2(highlight_x, highlight_y), 6.0, COLOR_DOT)
		draw_circle(Vector2(highlight_x, highlight_y), 4.0, COLOR_HIGHLIGHT)
	
	# Level labels at corners
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 12
	
	# "Lv 1" bottom left
	draw_string(font, Vector2(plot_left + 2, plot_bottom - 2), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_AXIS)
	
	# Max level bottom right
	draw_string(font, Vector2(plot_right - 20, plot_bottom - 2), str(MAX_LEVEL), HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size, COLOR_AXIS)
	
	# Current level indicator text
	if current_level >= 1 and current_level <= MAX_LEVEL:
		var level_text: String = "Lv %d" % current_level
		draw_string(font, Vector2(highlight_x + 8, plot_top + 14), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_HIGHLIGHT)
