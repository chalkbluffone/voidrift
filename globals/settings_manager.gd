extends Node
class_name SettingsManagerClass

## SettingsManager - Centralized game settings management.
## Handles audio, display settings and persistence.
## Autoload this as "SettingsManager".

signal settings_changed

const SAVE_PATH := "user://settings.cfg"

# Current settings values
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var fullscreen: bool = false
var vsync: bool = true


func _ready() -> void:
	load_settings()
	apply_all_settings()


# --- Audio Settings ---

func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_set_bus_volume("Master", master_volume)
	save_settings()
	settings_changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_set_bus_volume("SFX", sfx_volume)
	save_settings()
	settings_changed.emit()


func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_set_bus_volume("Music", music_volume)
	save_settings()
	settings_changed.emit()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))


# --- Display Settings ---

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()
	settings_changed.emit()


func set_vsync(enabled: bool) -> void:
	vsync = enabled
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	save_settings()
	settings_changed.emit()


# --- Persistence ---

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.save(SAVE_PATH)


func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	
	master_volume = config.get_value("audio", "master", 1.0)
	sfx_volume = config.get_value("audio", "sfx", 1.0)
	music_volume = config.get_value("audio", "music", 1.0)
	fullscreen = config.get_value("display", "fullscreen", false)
	vsync = config.get_value("display", "vsync", true)


func apply_all_settings() -> void:
	## Apply all settings without saving (used on load).
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("Music", music_volume)

	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
