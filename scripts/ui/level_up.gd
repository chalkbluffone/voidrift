extends CanvasLayer

## LevelUp UI - Shows upgrade choices when player levels up.
## Displays 3 cards with upgrade options. Player can select, reroll, or skip.

# Synthwave colors
const COLOR_COMMON: Color = Color(0.7, 0.7, 0.7, 1.0)       # Gray
const COLOR_UNCOMMON: Color = Color(0.2, 0.8, 0.2, 1.0)    # Green
const COLOR_RARE: Color = Color(0.2, 0.5, 1.0, 1.0)        # Blue
const COLOR_EPIC: Color = Color(0.67, 0.2, 0.95, 1.0)      # Purple
const COLOR_LEGENDARY: Color = Color(1.0, 0.8, 0.0, 1.0)   # Gold

const COLOR_WEAPON: Color = Color(1.0, 0.3, 0.3, 1.0)      # Red-ish for weapons
const COLOR_UPGRADE: Color = Color(0.0, 0.9, 0.8, 1.0)     # Cyan for upgrades

const COLOR_PANEL_BG: Color = Color(0.08, 0.05, 0.15, 0.95)
const COLOR_PANEL_BORDER: Color = Color(1.0, 0.08, 0.4, 1.0)  # Hot pink
const COLOR_BUTTON: Color = Color(0.67, 0.2, 0.95, 1.0)       # Neon purple
const COLOR_BUTTON_HOVER: Color = Color(1.0, 0.08, 0.4, 1.0)  # Hot pink

const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")

@onready var GameConfig: Node = get_node("/root/GameConfig")
@onready var RunManager: Node = get_node("/root/RunManager")
@onready var ProgressionManager: Node = get_node("/root/ProgressionManager")
@onready var level_up_label: Label = $VBoxContainer/LevelUpLabel
@onready var choose_label: Label = $VBoxContainer/ChooseLabel
@onready var choices_container: HBoxContainer = $VBoxContainer/ChoicesContainer
@onready var actions_container: HBoxContainer = $VBoxContainer/ActionsContainer
@onready var refresh_button: Button = $VBoxContainer/ActionsContainer/RefreshButton
@onready var skip_button: Button = $VBoxContainer/ActionsContainer/SkipButton
@onready var background: ColorRect = $ColorRect
@onready var root_container: Control = $VBoxContainer

@onready var UpgradeService: Node = get_node("/root/UpgradeService")
@onready var FileLogger: Node = get_node("/root/FileLogger")

# Card references (3 cards)
var _cards: Array[PanelContainer] = []
var _card_buttons: Array[Button] = []
var _current_options: Array = []
var _is_showing: bool = false


func _ready() -> void:
	# Get card references
	_cards = [
		$VBoxContainer/ChoicesContainer/Choice1,
		$VBoxContainer/ChoicesContainer/Choice2,
		$VBoxContainer/ChoicesContainer/Choice3,
	]
	
	_card_buttons = [
		$VBoxContainer/ChoicesContainer/Choice1/VBox1/Select1,
		$VBoxContainer/ChoicesContainer/Choice2/VBox2/Select2,
		$VBoxContainer/ChoicesContainer/Choice3/VBox3/Select3,
	]
	
	# Connect button signals
	for i in range(_card_buttons.size()):
		var button: Button = _card_buttons[i]
		button.pressed.connect(_on_card_selected.bind(i))
	
	refresh_button.pressed.connect(_on_refresh_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	
	# Connect to ProgressionManager signals
	ProgressionManager.level_up_triggered.connect(_on_level_up_triggered)
	
	# Apply synthwave styling
	_apply_synthwave_theme()
	
	# Hide initially
	hide()
	set_process_input(false)


func _apply_synthwave_theme() -> void:
	# Background overlay
	background.color = Color(0, 0, 0, 0.85)
	
	# Level up label - big neon yellow
	level_up_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2, 1.0))
	level_up_label.add_theme_font_override("font", FONT_HEADER)
	level_up_label.add_theme_font_size_override("font_size", 72)
	
	# Choose label - cyan
	choose_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.9, 1.0))
	choose_label.add_theme_font_override("font", FONT_HEADER)
	choose_label.add_theme_font_size_override("font_size", 32)
	
	# Style the cards
	for card in _cards:
		_style_card(card)
	
	# Style action buttons
	_style_button(refresh_button, COLOR_BUTTON)
	_style_button(skip_button, Color(0.5, 0.5, 0.5, 1.0))
	refresh_button.add_theme_font_override("font", FONT_HEADER)
	refresh_button.add_theme_font_size_override("font_size", 22)
	skip_button.add_theme_font_override("font", FONT_HEADER)
	skip_button.add_theme_font_size_override("font_size", 22)


func _style_card(card: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = COLOR_PANEL_BORDER
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)


func _style_button(button: Button, base_color: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", normal)
	
	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = base_color.lightened(0.2)
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("hover", hover)
	
	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = base_color.darkened(0.2)
	pressed.corner_radius_top_left = 4
	pressed.corner_radius_top_right = 4
	pressed.corner_radius_bottom_left = 4
	pressed.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("pressed", pressed)
	
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _on_level_up_triggered(current_level: int, available_upgrades: Array) -> void:
	FileLogger.log_info("LevelUpUI", "Level up triggered! Level: %d, Options: %d" % [current_level, available_upgrades.size()])
	
	_current_options = available_upgrades
	level_up_label.text = "LEVEL %d!" % current_level
	
	_populate_cards()
	_update_refresh_button()
	
	# Show with animation
	show()
	_is_showing = true
	set_process_input(true)
	
	# Animate cards appearing
	_animate_cards_in()


func _populate_cards() -> void:
	for i in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		
		if i < _current_options.size():
			card.visible = true
			_update_card(i, _current_options[i])
		else:
			card.visible = false


func _update_card(index: int, option: Dictionary) -> void:
	var card: PanelContainer = _cards[index]
	var vbox: VBoxContainer = card.get_child(0)
	
	var _icon: TextureRect = vbox.get_node("Icon%d" % (index + 1))
	var name_label: Label = vbox.get_node("Name%d" % (index + 1))
	var desc_label: Label = vbox.get_node("Desc%d" % (index + 1))
	var button: Button = vbox.get_node("Select%d" % (index + 1))
	
	var data: Dictionary = option.get("data", {})
	var option_type: String = option.get("type", "upgrade")
	var option_id: String = option.get("id", "")
	var rarity: String = option.get("rarity", "common")
	var rarity_color: Color = _get_rarity_color(rarity)
	
	# Set name
	var display_name: String = data.get("name", option_id)
	name_label.text = display_name
	
	# Set description based on type
	var description: String = data.get("description", "No description")
	
	if option_type == "upgrade":
		# Ship upgrade - show current stacks and one or more effects
		var current_stacks: int = _get_current_stacks(option_id)
		var effects: Array = option.get("effects", [])
		
		var lines: Array[String] = []
		for effect in effects:
			if effect is Dictionary:
				var stat: String = effect.get("stat", "")
				var kind: String = effect.get("kind", "mult")
				var amount: float = float(effect.get("amount", 0.0))
				if stat == "" or amount == 0.0:
					continue
				if kind == "mult":
					lines.append("+%.0f%% %s" % [amount * 100.0, _format_stat_name(stat)])
				else:
					# flat values: most are points (HP, armor%, crit%, regen per minute)
					if stat in ["armor", "evasion", "crit_chance", "luck", "difficulty"]:
						lines.append("+%.1f%% %s" % [amount, _format_stat_name(stat)])
					else:
						lines.append("+%.0f %s" % [amount, _format_stat_name(stat)])
		
		var effect_block: String = "\n".join(lines)
		if current_stacks > 0:
			description = "%s\nLevel: %d → %d\n%s" % [description, current_stacks, current_stacks + 1, effect_block]
		else:
			description = "%s\n%s" % [description, effect_block]
		
		# Show rarity on the title for clarity and color-code by rarity
		name_label.text = "%s [%s]" % [name_label.text, rarity.capitalize()]
		name_label.add_theme_color_override("font_color", rarity_color)
		_update_card_border(card, rarity_color)
	else:
		# Weapon (new or level-up)
		var is_new: bool = bool(option.get("is_new", false))
		var current_level: int = int(option.get("current_level", 0))
		var effects_w: Array = option.get("effects", [])
		if is_new:
			description = "%s\n[NEW WEAPON]" % description
		else:
			description = "%s\nLevel: %d \u2192 %d" % [description, current_level, current_level + 1]

		var bonus_line: String = _format_weapon_effects_line(effects_w)
		if bonus_line != "":
			description = "%s\n%s" % [description, bonus_line]
		name_label.text = "%s [%s]" % [name_label.text, rarity.capitalize()]
		name_label.add_theme_color_override("font_color", rarity_color)
		_update_card_border(card, rarity_color)
	
	desc_label.text = description
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	desc_label.add_theme_font_size_override("font_size", 20)
	
	# Style name label font size
	name_label.add_theme_font_override("font", FONT_HEADER)
	name_label.add_theme_font_size_override("font_size", 28)
	
	# Style select button
	_style_button(button, COLOR_BUTTON)
	button.add_theme_font_override("font", FONT_HEADER)
	button.add_theme_font_size_override("font_size", 22)


func _update_card_border(card: PanelContainer, color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)


func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return COLOR_LEGENDARY
		"epic":
			return COLOR_EPIC
		"rare":
			return COLOR_RARE
		"uncommon":
			return COLOR_UNCOMMON
		_:
			return COLOR_COMMON


func _get_current_stacks(upgrade_id: String) -> int:
	for upgrade in RunManager.run_data.ship_upgrades:
		if upgrade.id == upgrade_id:
			return upgrade.stacks
	return 0


func _format_stat_name(stat: String) -> String:
	# Convert snake_case to Title Case
	return stat.replace("_", " ").capitalize()


func _format_weapon_effects_line(effects: Array) -> String:
	# Returns a single readable line like: "Bonus: +8% Damage / +1 Projectile"
	if effects.is_empty():
		return ""

	var parts: Array[String] = []
	for effect_any in effects:
		if not (effect_any is Dictionary):
			continue
		var effect: Dictionary = effect_any
		var stat: String = String(effect.get("stat", ""))
		if stat == "":
			continue
		var kind: String = String(effect.get("kind", "mult"))
		var amount: float = float(effect.get("amount", 0.0))
		if amount == 0.0:
			continue

		if kind == "mult":
			parts.append("+%.0f%% %s" % [amount * 100.0, _format_stat_name(stat)])
		else:
			if stat in ["armor", "evasion", "crit_chance", "luck", "difficulty"]:
				parts.append("+%.1f%% %s" % [amount, _format_stat_name(stat)])
			elif stat == "crit_damage":
				parts.append("+%.2f %s" % [amount, _format_stat_name(stat)])
			else:
				parts.append("+%.0f %s" % [amount, _format_stat_name(stat)])

	if parts.is_empty():
		return ""
	return "Bonus: %s" % " / ".join(parts)


func _update_refresh_button() -> void:
	var current_credits: int = RunManager.run_data.credits
	refresh_button.text = "Refresh (%d)" % GameConfig.LEVEL_UP_REFRESH_COST
	refresh_button.disabled = current_credits < GameConfig.LEVEL_UP_REFRESH_COST
	
	if refresh_button.disabled:
		refresh_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		refresh_button.modulate = Color.WHITE


func _animate_cards_in() -> void:
	for i in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		if card.visible:
			card.modulate.a = 0.0
			card.scale = Vector2(0.8, 0.8)
			card.pivot_offset = card.size / 2
			
			var tween: Tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(i * 0.1)
			tween.tween_property(card, "scale", Vector2.ONE, 0.3).set_delay(i * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_card_selected(index: int) -> void:
	if index >= _current_options.size():
		return
	
	var selected_option: Dictionary = _current_options[index]
	FileLogger.log_info("LevelUpUI", "Selected option %d: %s" % [index, selected_option.get("id", "unknown")])
	
	_hide_ui()
	ProgressionManager.select_level_up_option(selected_option)


func _on_refresh_pressed() -> void:
	if ProgressionManager.spend_credits(GameConfig.LEVEL_UP_REFRESH_COST):
		FileLogger.log_info("LevelUpUI", "Refreshing options (spent %d credits)" % GameConfig.LEVEL_UP_REFRESH_COST)
		
		# Generate new options
		_current_options = UpgradeService.generate_level_up_options()
		_populate_cards()
		_update_refresh_button()
		_animate_cards_in()
	else:
		FileLogger.log_debug("LevelUpUI", "Cannot afford refresh")


func _on_skip_pressed() -> void:
	FileLogger.log_info("LevelUpUI", "Skipping level up")
	_hide_ui()
	RunManager.resume_game()


func _hide_ui() -> void:
	_is_showing = false
	set_process_input(false)
	
	# Animate out
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	# CanvasLayer has no modulate; fade CanvasItem children instead.
	tween.tween_property(root_container, "modulate:a", 0.0, 0.2)
	tween.tween_property(background, "modulate:a", 0.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(hide)
	tween.tween_callback(func() -> void:
		root_container.modulate.a = 1.0
		background.modulate.a = 1.0
	)


func _input(event: InputEvent) -> void:
	if not _is_showing:
		return
	
	# Keyboard shortcuts for card selection
	if event.is_action_pressed("ui_accept") or event is InputEventKey:
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_1:
					if _current_options.size() > 0:
						_on_card_selected(0)
				KEY_2:
					if _current_options.size() > 1:
						_on_card_selected(1)
				KEY_3:
					if _current_options.size() > 2:
						_on_card_selected(2)
				KEY_R:
					_on_refresh_pressed()
				# Intentionally no keyboard/controller shortcut for skipping.
				# Use the on-screen Skip button to avoid accidental dismissals.
