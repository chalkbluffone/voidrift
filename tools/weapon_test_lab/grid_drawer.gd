extends Node2D

## Draws a grid pattern for the weapon test lab background.

@export var grid_size: float = 50.0
@export var grid_color: Color = Color(0.15, 0.15, 0.25, 0.5)
@export var axis_color: Color = Color(0.3, 0.3, 0.4, 0.7)
@export var grid_extent: float = 2000.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# Draw grid lines
	var start = -grid_extent
	var end = grid_extent
	
	# Vertical lines
	var x = start
	while x <= end:
		var color = axis_color if x == 0 else grid_color
		var width = 2.0 if x == 0 else 1.0
		draw_line(Vector2(x, start), Vector2(x, end), color, width)
		x += grid_size
	
	# Horizontal lines
	var y = start
	while y <= end:
		var color = axis_color if y == 0 else grid_color
		var width = 2.0 if y == 0 else 1.0
		draw_line(Vector2(start, y), Vector2(end, y), color, width)
		y += grid_size
	
	# Draw range circles
	draw_arc(Vector2.ZERO, 100, 0, TAU, 64, Color(0.3, 0.5, 0.3, 0.3), 1.0)
	draw_arc(Vector2.ZERO, 200, 0, TAU, 64, Color(0.3, 0.5, 0.3, 0.3), 1.0)
	draw_arc(Vector2.ZERO, 300, 0, TAU, 64, Color(0.3, 0.5, 0.3, 0.3), 1.0)
	draw_arc(Vector2.ZERO, 400, 0, TAU, 64, Color(0.5, 0.3, 0.3, 0.3), 1.0)
