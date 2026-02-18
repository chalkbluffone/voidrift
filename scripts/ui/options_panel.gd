extends PanelContainer
class_name OptionsPanel

## Shared tab-based options panel used by both OptionsMenu (main menu)
## and PauseMenu (in-game). Builds all UI programmatically.
## Emits `back_pressed` for the parent to handle navigation.

signal back_pressed

const CARD_HOVER_FX_SCRIPT: Script = preload("res://scripts/ui/card_hover_fx.gd")
const FONT_HEADER: Font = preload("res://assets/fonts/Orbitron-Bold.ttf")

## Tab names — order matches the _tab_containers array.
const TAB_NAMES: Array[String] = ["Audio", "Display", "Graphics", "Debug"]

@onready var _settings: Node = get_node("/root/SettingsManager")

var _tab_buttons: Array[Button] = []
var _tab_containers: Array[VBoxContainer] = []
var _active_tab: int = 0
var _button_hover_tweens: Dictionary = {}

# ── Control references (populated in _build_*) ────────────────────────
var _master_slider: HSlider
var _sfx_slider: HSlider
var _music_slider: HSlider

var _window_mode_option: OptionButton
var _resolution_option: OptionButton
var _max_fps_option: OptionButton
var _vsync_check: CheckButton

var _bg_quality_option: OptionButton
var _particle_density_option: OptionButton
var _shake_slider: HSlider

var _debug_overlay_check: CheckButton

var _back_button: Button


func _ready() -> void:
	_build_ui()
	sync_from_settings()
	_connect_signals()
	_switch_tab(0)

	# Focus first interactive control
	if _master_slider:
		_master_slider.grab_focus()


# ═══════════════════════════════════════════════════════════════════════
# BUILD
# ═══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Panel background style
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = UiColors.PANEL_BG
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_color = UiColors.PANEL_BORDER
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	add_theme_stylebox_override("panel", panel_style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# Title
	var title: Label = Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_HEADER)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UiColors.CYAN)
	root_vbox.add_child(title)

	# Tab bar
	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(tab_bar)

	for i: int in TAB_NAMES.size():
		var btn: Button = Button.new()
		btn.text = TAB_NAMES[i]
		btn.add_theme_font_override("font", FONT_HEADER)
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(110, 34)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	# Separator line
	var sep: HSeparator = HSeparator.new()
	root_vbox.add_child(sep)

	# Content container — stacked VBoxContainers
	var content_holder: Control = Control.new()
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_holder.custom_minimum_size = Vector2(0, 260)
	root_vbox.add_child(content_holder)

	for i: int in TAB_NAMES.size():
		var tab_vbox: VBoxContainer = VBoxContainer.new()
		tab_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tab_vbox.add_theme_constant_override("separation", 10)
		tab_vbox.visible = false
		content_holder.add_child(tab_vbox)
		_tab_containers.append(tab_vbox)

	_build_audio_tab(_tab_containers[0])
	_build_display_tab(_tab_containers[1])
	_build_graphics_tab(_tab_containers[2])
	_build_debug_tab(_tab_containers[3])

	# Back button
	_back_button = Button.new()
	_back_button.text = "← Back"
	_back_button.custom_minimum_size = Vector2(0, 40)
	_back_button.add_theme_font_override("font", FONT_HEADER)
	_back_button.add_theme_font_size_override("font_size", 20)
	CARD_HOVER_FX_SCRIPT.style_synthwave_button(_back_button, UiColors.BUTTON_BACK, _button_hover_tweens, 4)
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	root_vbox.add_child(_back_button)


# ── Audio tab ──────────────────────────────────────────────────────────

func _build_audio_tab(parent: VBoxContainer) -> void:
	_master_slider = _make_slider_row(parent, "Master Volume", 0.0, 1.0, 0.05)
	_sfx_slider = _make_slider_row(parent, "SFX Volume", 0.0, 1.0, 0.05)
	_music_slider = _make_slider_row(parent, "Music Volume", 0.0, 1.0, 0.05)


# ── Display tab ────────────────────────────────────────────────────────

func _build_display_tab(parent: VBoxContainer) -> void:
	_window_mode_option = _make_option_row(parent, "Window Mode",
		["Windowed", "Borderless Fullscreen", "Exclusive Fullscreen"])

	var res_labels: Array[String] = []
	for preset: Vector2i in _settings.RESOLUTION_PRESETS:
		res_labels.append("%d × %d" % [preset.x, preset.y])
	_resolution_option = _make_option_row(parent, "Resolution", res_labels)

	var fps_labels: Array[String] = []
	for fps: int in _settings.FPS_PRESETS:
		fps_labels.append("Unlimited" if fps == 0 else str(fps))
	_max_fps_option = _make_option_row(parent, "Max FPS", fps_labels)

	_vsync_check = _make_check_row(parent, "V-Sync")


# ── Graphics tab ───────────────────────────────────────────────────────

func _build_graphics_tab(parent: VBoxContainer) -> void:
	_bg_quality_option = _make_option_row(parent, "Background Quality", ["Low", "High"])
	_particle_density_option = _make_option_row(parent, "Particle Density",
		["Off", "Low", "Medium", "High"])
	_shake_slider = _make_slider_row(parent, "Screen Shake", 0.0, 1.0, 0.05)


# ── Debug tab ──────────────────────────────────────────────────────────

func _build_debug_tab(parent: VBoxContainer) -> void:
	_debug_overlay_check = _make_check_row(parent, "Debug Overlay")


# ═══════════════════════════════════════════════════════════════════════
# ROW FACTORIES
# ═══════════════════════════════════════════════════════════════════════

func _make_slider_row(parent: VBoxContainer, label_text: String,
		min_val: float, max_val: float, step_val: float) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)

	var lbl: Label = _make_row_label(label_text)
	row.add_child(lbl)

	var slider: HSlider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.custom_minimum_size = Vector2(200, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	return slider


func _make_option_row(parent: VBoxContainer, label_text: String,
		items: Array[String]) -> OptionButton:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)

	var lbl: Label = _make_row_label(label_text)
	row.add_child(lbl)

	var option: OptionButton = OptionButton.new()
	for item_text: String in items:
		option.add_item(item_text)
	option.custom_minimum_size = Vector2(200, 0)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(option)

	return option


func _make_check_row(parent: VBoxContainer, label_text: String) -> CheckButton:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)

	var lbl: Label = _make_row_label(label_text)
	row.add_child(lbl)

	var check: CheckButton = CheckButton.new()
	row.add_child(check)

	return check


func _make_row_label(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_font_override("font", FONT_HEADER)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", UiColors.TEXT_DESC)
	return lbl


# ═══════════════════════════════════════════════════════════════════════
# TABS
# ═══════════════════════════════════════════════════════════════════════

func _on_tab_pressed(index: int) -> void:
	_switch_tab(index)


func _switch_tab(index: int) -> void:
	_active_tab = index
	for i: int in _tab_containers.size():
		_tab_containers[i].visible = (i == index)
	_update_tab_button_styles()


func _update_tab_button_styles() -> void:
	for i: int in _tab_buttons.size():
		var btn: Button = _tab_buttons[i]
		if i == _active_tab:
			CARD_HOVER_FX_SCRIPT.style_synthwave_button(btn, UiColors.CYAN.darkened(0.5), _button_hover_tweens, 4)
			btn.add_theme_color_override("font_color", UiColors.CYAN)
			btn.add_theme_color_override("font_hover_color", UiColors.CYAN)
			btn.add_theme_color_override("font_focus_color", UiColors.CYAN)
		else:
			CARD_HOVER_FX_SCRIPT.style_synthwave_button(btn, UiColors.BUTTON_NEUTRAL.darkened(0.3), _button_hover_tweens, 4)
			btn.add_theme_color_override("font_color", UiColors.TEXT_DESC)
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.add_theme_color_override("font_focus_color", Color.WHITE)


# ═══════════════════════════════════════════════════════════════════════
# SYNC / CONNECT
# ═══════════════════════════════════════════════════════════════════════

## Read current SettingsManager values into the UI controls.
func sync_from_settings() -> void:
	# Audio
	_master_slider.value = _settings.master_volume
	_sfx_slider.value = _settings.sfx_volume
	_music_slider.value = _settings.music_volume

	# Display
	_window_mode_option.selected = _settings.window_mode
	_sync_resolution_option()
	_sync_fps_option()
	_vsync_check.button_pressed = _settings.vsync

	# Graphics
	_bg_quality_option.selected = _settings.background_quality
	_particle_density_option.selected = _settings.particle_density
	_shake_slider.value = _settings.screen_shake_intensity

	# Debug
	_debug_overlay_check.button_pressed = _settings.show_debug_overlay


func _sync_resolution_option() -> void:
	var idx: int = 0
	for i: int in _settings.RESOLUTION_PRESETS.size():
		if _settings.RESOLUTION_PRESETS[i] == _settings.resolution:
			idx = i
			break
	_resolution_option.selected = idx


func _sync_fps_option() -> void:
	var idx: int = 0
	for i: int in _settings.FPS_PRESETS.size():
		if _settings.FPS_PRESETS[i] == _settings.max_fps:
			idx = i
			break
	_max_fps_option.selected = idx


func _connect_signals() -> void:
	# Audio
	_master_slider.value_changed.connect(_settings.set_master_volume)
	_sfx_slider.value_changed.connect(_settings.set_sfx_volume)
	_music_slider.value_changed.connect(_settings.set_music_volume)

	# Display
	_window_mode_option.item_selected.connect(_settings.set_window_mode)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_max_fps_option.item_selected.connect(_on_fps_selected)
	_vsync_check.toggled.connect(_settings.set_vsync)

	# Graphics
	_bg_quality_option.item_selected.connect(_settings.set_background_quality)
	_particle_density_option.item_selected.connect(_settings.set_particle_density)
	_shake_slider.value_changed.connect(_settings.set_screen_shake_intensity)

	# Debug
	_debug_overlay_check.toggled.connect(_settings.set_show_debug_overlay)


func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < _settings.RESOLUTION_PRESETS.size():
		_settings.set_resolution(_settings.RESOLUTION_PRESETS[index])


func _on_fps_selected(index: int) -> void:
	if index >= 0 and index < _settings.FPS_PRESETS.size():
		_settings.set_max_fps(_settings.FPS_PRESETS[index])


## Focus the back button (useful when parent shows the panel).
func focus_back_button() -> void:
	if _back_button:
		_back_button.grab_focus()


## Focus the first interactive control in the active tab.
func focus_first_control() -> void:
	match _active_tab:
		0:
			if _master_slider:
				_master_slider.grab_focus()
		1:
			if _window_mode_option:
				_window_mode_option.grab_focus()
		2:
			if _bg_quality_option:
				_bg_quality_option.grab_focus()
		3:
			if _debug_overlay_check:
				_debug_overlay_check.grab_focus()
