extends CanvasLayer

const SAVE_PATH = "user://radiant_arc_settings.cfg"

# Reference to the settings we're modifying
var settings: Dictionary = {
	"arc_angle_deg": 90.0,
	"radius": 42.0,
	"thickness": 18.0,
	"taper": 0.5,
	"length_scale": 0.75,
	"distance": 25.0,
	"duration": 0.8,
	"sweep_speed": 1.2,
	"glow_strength": 3.0,
	"fade_in": 0.08,
	"fade_out": 0.15,
}

signal settings_changed(settings: Dictionary)


func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		for key in settings.keys():
			if config.has_section_key("arc", key):
				settings[key] = config.get_value("arc", key)
		print("Radiant Arc settings loaded from ", SAVE_PATH)


func _save_settings() -> void:
	var config = ConfigFile.new()
	for key in settings.keys():
		config.set_value("arc", key, settings[key])
	config.save(SAVE_PATH)
	print("Radiant Arc settings saved to ", SAVE_PATH)

var _panel: PanelContainer
var _sliders: Dictionary = {}
var _labels: Dictionary = {}

func _ready() -> void:
	# Load saved settings first
	_load_settings()
	
	# Ensure this renders above everything
	layer = 100
	
	# Create the UI
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -50
	_panel.offset_bottom = -50
	add_child(_panel)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 0)
	_panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Radiant Arc Debug (F1 to toggle)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Add sliders for each setting
	_add_slider(vbox, "arc_angle_deg", 30.0, 360.0, 1.0)
	_add_slider(vbox, "radius", 10.0, 150.0, 1.0)
	_add_slider(vbox, "thickness", 5.0, 80.0, 1.0)
	_add_slider(vbox, "taper", 0.0, 1.0, 0.05)
	_add_slider(vbox, "length_scale", 0.25, 3.0, 0.05)
	_add_slider(vbox, "distance", 0.0, 100.0, 1.0)
	_add_slider(vbox, "duration", 0.1, 2.0, 0.05)
	_add_slider(vbox, "sweep_speed", 0.5, 5.0, 0.1)
	_add_slider(vbox, "glow_strength", 0.5, 10.0, 0.1)
	_add_slider(vbox, "fade_in", 0.0, 0.5, 0.01)
	_add_slider(vbox, "fade_out", 0.0, 0.5, 0.01)
	
	_panel.visible = false


func _add_slider(parent: Control, setting_name: String, min_val: float, max_val: float, step: float) -> void:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	
	# Label with name and value
	var label = Label.new()
	label.custom_minimum_size = Vector2(180, 0)
	label.text = "%s: %.2f" % [setting_name, settings[setting_name]]
	hbox.add_child(label)
	_labels[setting_name] = label
	
	# Slider
	var slider = HSlider.new()
	slider.custom_minimum_size = Vector2(120, 0)
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = settings[setting_name]
	slider.value_changed.connect(_on_slider_changed.bind(setting_name))
	hbox.add_child(slider)
	_sliders[setting_name] = slider


func _on_slider_changed(value: float, setting_name: String) -> void:
	settings[setting_name] = value
	_labels[setting_name].text = "%s: %.2f" % [setting_name, value]
	_save_settings()  # Auto-save on every change
	settings_changed.emit(settings)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_panel.visible = not _panel.visible
			get_viewport().set_input_as_handled()


func get_settings() -> Dictionary:
	return settings.duplicate()
