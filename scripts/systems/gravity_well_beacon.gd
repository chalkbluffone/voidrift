extends Node2D

## GravityWellBeacon - One-time-use world interactable that vacuums all pickups
## on the map to the player when they press the interact button within range.
## Space-themed adaptation of Megabonk's magnet shrine concept.

var _is_depleted: bool = false
var _player_in_range: bool = false
var _player_ref: Node2D = null
var _buff_zone: Area2D = null
var _prompt_label: Label = null
var _circle_visual: Node2D = null
var _title_label: Label = null
var _pulse_time: float = 0.0
var _using_controller: bool = false

@onready var GameConfig: Node = get_node("/root/GameConfig")

const CIRCLE_RADIUS: float = 50.0
const CIRCLE_COLOR: Color = Color(0.5, 0.15, 0.9, 0.7)
const CIRCLE_COLOR_DEPLETED: Color = Color(0.2, 0.2, 0.2, 0.3)
const TITLE_COLOR: Color = Color(0.85, 0.75, 1.0, 1.0)
const PROMPT_COLOR: Color = Color(1.0, 1.0, 0.5, 1.0)


func _ready() -> void:
	add_to_group("gravity_well_beacons")
	add_to_group("minimap_objects")
	_using_controller = _has_connected_controller()
	set_process_unhandled_input(true)
	_create_activation_zone()
	_create_visual()
	_create_prompt()


func _create_activation_zone() -> void:
	_buff_zone = Area2D.new()
	_buff_zone.collision_layer = 64
	_buff_zone.collision_mask = 1
	_buff_zone.monitoring = true
	_buff_zone.monitorable = false
	add_child(_buff_zone)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = GameConfig.GRAVITY_WELL_BEACON_ACTIVATION_RADIUS
	shape.shape = circle
	_buff_zone.add_child(shape)

	_buff_zone.body_entered.connect(_on_body_entered)
	_buff_zone.body_exited.connect(_on_body_exited)


func _create_visual() -> void:
	# Custom draw node for the circle
	_circle_visual = Node2D.new()
	_circle_visual.name = "CircleVisual"
	add_child(_circle_visual)
	_circle_visual.draw.connect(_on_draw_circle)

	# Title text inside the circle
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "GRAVITY\nWELL"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.size = Vector2(CIRCLE_RADIUS * 2.0, CIRCLE_RADIUS * 2.0)
	_title_label.position = Vector2(-CIRCLE_RADIUS, -CIRCLE_RADIUS)
	add_child(_title_label)


func _create_prompt() -> void:
	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", PROMPT_COLOR)
	_prompt_label.size = Vector2(200.0, 30.0)
	_prompt_label.position = Vector2(-100.0, CIRCLE_RADIUS + 8.0)
	_prompt_label.visible = false
	add_child(_prompt_label)
	_update_prompt_text()


func _update_prompt_text() -> void:
	if _using_controller:
		_prompt_label.text = "[X] Activate"
	else:
		_prompt_label.text = "[E] Activate"


func _has_connected_controller() -> bool:
	var joypads: Array[int] = Input.get_connected_joypads()
	return joypads.size() > 0


func _set_using_controller(using_controller: bool) -> void:
	if _using_controller == using_controller:
		return
	_using_controller = using_controller
	if _prompt_label:
		_update_prompt_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_set_using_controller(true)
		return
	if event is InputEventJoypadMotion:
		var joy_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		if absf(joy_event.axis_value) > 0.2:
			_set_using_controller(true)
		return
	if event is InputEventKey:
		_set_using_controller(false)
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_set_using_controller(false)


func _process(delta: float) -> void:
	if _is_depleted:
		return
	if _using_controller and not _has_connected_controller():
		_set_using_controller(false)

	# Pulse animation
	_pulse_time += delta
	_circle_visual.queue_redraw()

	if _player_in_range:
		_update_prompt_text()
		if Input.is_action_just_pressed("interact"):
			_activate()


func _on_draw_circle() -> void:
	var color: Color = CIRCLE_COLOR_DEPLETED if _is_depleted else CIRCLE_COLOR
	# Subtle pulse when active
	if not _is_depleted:
		var pulse: float = 0.15 * sin(_pulse_time * 2.0)
		color.a = clampf(color.a + pulse, 0.3, 0.9)

	# Filled circle
	_circle_visual.draw_circle(Vector2.ZERO, CIRCLE_RADIUS, color)
	# Border ring
	var border_color: Color = Color(0.7, 0.4, 1.0, 0.9) if not _is_depleted else Color(0.3, 0.3, 0.3, 0.3)
	_circle_visual.draw_arc(Vector2.ZERO, CIRCLE_RADIUS, 0.0, TAU, 48, border_color, 2.0)


func _on_body_entered(body: Node2D) -> void:
	if _is_depleted:
		return
	if not body.is_in_group("player"):
		return

	_player_ref = body
	_player_in_range = true
	_prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	_player_in_range = false
	_prompt_label.visible = false


func _activate() -> void:
	_is_depleted = true
	_player_in_range = false
	_prompt_label.visible = false

	# Vacuum ALL drops on the map to the player (skip power-ups — they require physical touch)
	if _player_ref and is_instance_valid(_player_ref):
		var all_pickups: Array[Node] = get_tree().get_nodes_in_group("pickups")
		for pickup: Node in all_pickups:
			if not is_instance_valid(pickup):
				continue
			if pickup.is_in_group("powerups"):
				continue
			if pickup is BasePickup:
				var bp: BasePickup = pickup as BasePickup
				bp.attract_to(_player_ref)
				bp._current_speed = GameConfig.GRAVITY_WELL_VACUUM_SPEED

	# Disable zone and dim visual
	_buff_zone.monitoring = false
	_circle_visual.queue_redraw()
	_title_label.modulate = Color(0.4, 0.4, 0.4, 0.4)


func is_depleted() -> bool:
	return _is_depleted
