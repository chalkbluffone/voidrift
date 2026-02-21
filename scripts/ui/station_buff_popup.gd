extends CanvasLayer

## StationBuffPopup - Shows buff choices when a space station is fully charged.
## Displays 3 cards with stat buff options. Player can select one or ignore.

const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")
const CARD_HOVER_SHADER: Shader = preload("res://shaders/ui_upgrade_card_hover.gdshader")
const CARD_HOVER_FX_SCRIPT: Script = preload("res://scripts/ui/card_hover_fx.gd")

@onready var RunManager: Node = get_node("/root/RunManager")
@onready var StationService: Node = get_node("/root/StationService")
@onready var FileLogger: Node = get_node("/root/FileLogger")

@onready var background: ColorRect = $ColorRect
@onready var root_container: VBoxContainer = $VBoxContainer
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var choices_container: VBoxContainer = $VBoxContainer/ChoicesContainer
@onready var ignore_button: Button = $VBoxContainer/IgnoreButton

var _cards: Array[PanelContainer] = []
var _current_options: Array[Dictionary] = []
var _card_hover_tweens: Dictionary = {}
var _button_hover_tweens: Dictionary = {}


func _ready() -> void:
	# Get card references
	_cards = [
		$VBoxContainer/ChoicesContainer/Choice1,
		$VBoxContainer/ChoicesContainer/Choice2,
		$VBoxContainer/ChoicesContainer/Choice3,
	]
	
	# Make cards clickable
	for i: int in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		card.gui_input.connect(_on_card_input.bind(i))
		card.mouse_entered.connect(_on_card_mouse_entered.bind(i))
		card.mouse_exited.connect(_on_card_mouse_exited.bind(i))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		CARD_HOVER_FX_SCRIPT.setup_card_focus(card, _card_hover_tweens, i)
		
		# Let clicks pass through children to the card
		for child: Control in card.get_children():
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for grandchild: Node in child.get_children():
				if grandchild is Control:
					(grandchild as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	ignore_button.pressed.connect(_on_ignore_pressed)
	
	# Connect to StationService
	StationService.station_buff_triggered.connect(_on_buff_triggered)
	
	# Apply styling
	_apply_synthwave_theme()
	
	# Hide initially
	hide()
	set_process_input(false)


func _apply_synthwave_theme() -> void:
	# Background overlay
	background.color = UiColors.BG_OVERLAY
	
	# Title - big neon cyan
	title_label.add_theme_color_override("font_color", UiColors.CYAN)
	title_label.add_theme_font_override("font", FONT_HEADER)
	title_label.add_theme_font_size_override("font_size", 56)
	
	# Subtitle
	subtitle_label.add_theme_color_override("font_color", UiColors.TEXT_DESC)
	subtitle_label.add_theme_font_override("font", FONT_HEADER)
	subtitle_label.add_theme_font_size_override("font_size", 24)
	
	# Style cards
	for card in _cards:
		_style_card(card)
	
	# Style ignore button
	CARD_HOVER_FX_SCRIPT.style_synthwave_button(ignore_button, UiColors.BUTTON_NEUTRAL, _button_hover_tweens, 4, 16, 8)
	ignore_button.add_theme_font_override("font", FONT_HEADER)
	ignore_button.add_theme_font_size_override("font_size", 20)
	ignore_button.custom_minimum_size.x = 180
	
	# Focus navigation
	if _cards.size() > 0:
		_cards[_cards.size() - 1].focus_neighbor_bottom = ignore_button.get_path()
		ignore_button.focus_neighbor_top = _cards[0].get_path()


func _style_card(card: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = UiColors.PANEL_BG
	style.border_color = UiColors.PANEL_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	card.focus_mode = Control.FOCUS_ALL
	card.custom_minimum_size = Vector2(500, 80)


func _on_buff_triggered(options: Array) -> void:
	_current_options.clear()
	for opt in options:
		_current_options.append(opt as Dictionary)
	
	_populate_cards()
	_show_popup()


func _populate_cards() -> void:
	for i: int in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		
		if i < _current_options.size():
			var option: Dictionary = _current_options[i]
			_setup_buff_card(card, option)
			card.visible = true
		else:
			card.visible = false


func _setup_buff_card(card: PanelContainer, option: Dictionary) -> void:
	var stat_name: String = String(option.get("display_name", "Unknown"))
	var amount: float = float(option.get("amount", 0.0))
	var rarity: String = String(option.get("rarity", "uncommon"))
	var is_flat: bool = bool(option.get("is_flat", false))
	var color: Color = option.get("color", UiColors.RARITY_UNCOMMON) as Color
	
	# Format the bonus text
	var bonus_text: String
	if is_flat:
		bonus_text = "+%.0f" % [amount * 100.0]  # Display flat as whole number scaled
	else:
		bonus_text = "+%.0f%%" % [amount * 100.0]
	
	# Get or create labels
	var name_label: Label = card.find_child("NameLabel") as Label
	var bonus_label: Label = card.find_child("BonusLabel") as Label
	var rarity_label: Label = card.find_child("RarityLabel") as Label
	
	if name_label:
		name_label.text = stat_name
		name_label.add_theme_color_override("font_color", UiColors.TEXT_PRIMARY)
		name_label.add_theme_font_override("font", FONT_HEADER)
		name_label.add_theme_font_size_override("font_size", 28)
	
	if bonus_label:
		bonus_label.text = bonus_text
		bonus_label.add_theme_color_override("font_color", color)
		bonus_label.add_theme_font_override("font", FONT_HEADER)
		bonus_label.add_theme_font_size_override("font_size", 32)
	
	if rarity_label:
		rarity_label.text = rarity.capitalize()
		rarity_label.add_theme_color_override("font_color", color)
		rarity_label.add_theme_font_size_override("font_size", 16)
	
	# Update card border color based on rarity
	var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = color
	card.add_theme_stylebox_override("panel", style)


func _show_popup() -> void:
	show()
	set_process_input(true)
	
	# Focus first card
	if _cards.size() > 0 and _cards[0].visible:
		_cards[0].grab_focus()
	
	FileLogger.log_info("StationBuffPopup", "Showing %d buff options" % [_current_options.size()])


func _hide_popup() -> void:
	hide()
	set_process_input(false)
	_current_options.clear()


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_select_option(index)


func _on_card_mouse_entered(index: int) -> void:
	var card: PanelContainer = _cards[index]
	card.grab_focus()


func _on_card_mouse_exited(_index: int) -> void:
	pass  # Keep focus until another card is hovered


func _select_option(index: int) -> void:
	if index < 0 or index >= _current_options.size():
		return
	
	var option: Dictionary = _current_options[index]
	FileLogger.log_info("StationBuffPopup", "Selected %s +%.0f%%" % [
		String(option.get("stat", "")),
		float(option.get("amount", 0.0)) * 100.0
	])
	
	# Apply buff via StationService (which will emit station_buff_completed)
	var player: Node = RunManager.get_player()
	if player and player.has_method("get_stats"):
		var stats: Node = player.get_stats()
		if stats:
			StationService.apply_buff(option, stats)
	
	_hide_popup()
	RunManager.resume_game()


func _on_ignore_pressed() -> void:
	FileLogger.log_info("StationBuffPopup", "Player ignored buff")
	StationService.station_buff_completed.emit({})
	_hide_popup()
	RunManager.resume_game()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Handle confirm on focused card
	if event.is_action_pressed("ui_accept"):
		for i: int in range(_cards.size()):
			if _cards[i].has_focus():
				_select_option(i)
				get_viewport().set_input_as_handled()
				return
	
	# Handle cancel to ignore
	if event.is_action_pressed("ui_cancel"):
		_on_ignore_pressed()
		get_viewport().set_input_as_handled()
