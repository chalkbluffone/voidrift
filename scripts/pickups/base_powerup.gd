class_name BasePowerUp
extends BasePickup

## BasePowerUp - Base class for all power-up pickups (Health, Speed, Stopwatch, Gravity Well).
## Power-ups are 48×48, use a shared glow shader, and are NOT attracted by magnet/PickupRange.
## Player must physically overlap the power-up to collect it.
## Subclasses override _apply_powerup_effect() to define behavior.

## The unicode symbol displayed on top of the glow circle.
var _symbol: String = "?"
## The font size for the symbol.
var _symbol_font_size: int = 28

@onready var _symbol_label: Label = null


func _on_pickup_ready() -> void:
	add_to_group("powerups")
	_create_symbol_label()


## Override attract_to() to no-op — power-ups cannot be magneted or vacuumed.
func attract_to(_target_node: Node2D) -> void:
	pass


## Override fixed magnet radius — power-ups have none.
func _get_fixed_magnet_radius() -> float:
	return 0.0


func _create_symbol_label() -> void:
	_symbol_label = Label.new()
	_symbol_label.name = "SymbolLabel"
	_symbol_label.text = _symbol
	_symbol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_symbol_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var half: float = GameConfig.POWERUP_VISUAL_SIZE * 0.5
	_symbol_label.size = Vector2(GameConfig.POWERUP_VISUAL_SIZE, GameConfig.POWERUP_VISUAL_SIZE)
	_symbol_label.position = Vector2(-half, -half)
	_symbol_label.add_theme_font_size_override("font_size", _symbol_font_size)
	_symbol_label.add_theme_color_override("font_color", Color.WHITE)
	_symbol_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_symbol_label)


func _apply_effect() -> void:
	var player: Node2D = _get_player()
	if not player:
		return
	var multiplier: float = 1.0
	if player.has_method("get_stat"):
		multiplier = player.get_stat("powerup_multiplier")
	_apply_powerup_effect(player, multiplier)


## Override in subclasses to define the power-up's effect.
func _apply_powerup_effect(_player: Node2D, _multiplier: float) -> void:
	push_warning("BasePowerUp._apply_powerup_effect() not overridden!")


func _get_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null
