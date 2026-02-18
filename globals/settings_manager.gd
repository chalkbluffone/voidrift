extends Node
class_name SettingsManagerClass

## SettingsManager - Centralized game settings management.
## Handles audio, display, graphics, and debug settings with persistence.
## Autoload this as "SettingsManager".

signal settings_changed

const SAVE_PATH: String = "user://settings.cfg"

## Window mode enum indices — used by the OptionButton in the options panel.
enum WindowMode {
	WINDOWED = 0,
	BORDERLESS = 1,
	EXCLUSIVE = 2,
}

## Predefined resolution presets (width × height).
const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

## Predefined FPS cap values (0 = unlimited).
const FPS_PRESETS: Array[int] = [0, 30, 60, 120, 144, 240]

# ── Audio ──────────────────────────────────────────────────────────────
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0

# ── Display ────────────────────────────────────────────────────────────
var window_mode: int = WindowMode.WINDOWED
var resolution: Vector2i = Vector2i(1920, 1080)
var vsync: bool = true
var max_fps: int = 0

# ── Graphics ───────────────────────────────────────────────────────────
var screen_shake_intensity: float = 1.0
var particle_density: int = 2  ## 0=Off, 1=Low, 2=Medium, 3=High
var background_quality: int = 1  ## 0=Low, 1=High

# ── Debug ──────────────────────────────────────────────────────────────
var show_debug_overlay: bool = false


func _ready() -> void:
	load_settings()
	apply_all_settings()


# ── Audio ──────────────────────────────────────────────────────────────

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


# ── Display ────────────────────────────────────────────────────────────

func set_window_mode(mode: int) -> void:
	window_mode = clampi(mode, 0, 2)
	_apply_window_mode()
	save_settings()
	settings_changed.emit()


func set_resolution(res: Vector2i) -> void:
	resolution = res
	if window_mode == WindowMode.WINDOWED:
		DisplayServer.window_set_size(resolution)
		_center_window()
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


func set_max_fps(value: int) -> void:
	max_fps = maxi(value, 0)
	Engine.max_fps = max_fps
	save_settings()
	settings_changed.emit()


func _apply_window_mode() -> void:
	match window_mode:
		WindowMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolution)
			_center_window()
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.EXCLUSIVE:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _center_window() -> void:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var win_size: Vector2i = DisplayServer.window_get_size()
	var pos: Vector2i = (screen_size - win_size) / 2
	DisplayServer.window_set_position(pos)


# ── Graphics ───────────────────────────────────────────────────────────

func set_screen_shake_intensity(value: float) -> void:
	screen_shake_intensity = clamp(value, 0.0, 1.0)
	save_settings()
	settings_changed.emit()


func set_particle_density(value: int) -> void:
	particle_density = clampi(value, 0, 3)
	save_settings()
	settings_changed.emit()


func set_background_quality(value: int) -> void:
	background_quality = clampi(value, 0, 1)
	save_settings()
	settings_changed.emit()


## Returns a multiplier (0.0–1.0) for particle amount scaling.
func get_particle_density_multiplier() -> float:
	match particle_density:
		0: return 0.0
		1: return 0.33
		2: return 0.66
		3: return 1.0
	return 1.0


# ── Debug ──────────────────────────────────────────────────────────────

func set_show_debug_overlay(enabled: bool) -> void:
	show_debug_overlay = enabled
	save_settings()
	settings_changed.emit()


# ── Persistence ────────────────────────────────────────────────────────

func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	# Audio
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "music", music_volume)
	# Display
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "resolution_w", resolution.x)
	config.set_value("display", "resolution_h", resolution.y)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "max_fps", max_fps)
	# Graphics
	config.set_value("graphics", "screen_shake_intensity", screen_shake_intensity)
	config.set_value("graphics", "particle_density", particle_density)
	config.set_value("graphics", "background_quality", background_quality)
	# Debug
	config.set_value("debug", "show_debug_overlay", show_debug_overlay)
	config.save(SAVE_PATH)


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	# Audio
	master_volume = float(config.get_value("audio", "master", 1.0))
	sfx_volume = float(config.get_value("audio", "sfx", 1.0))
	music_volume = float(config.get_value("audio", "music", 1.0))

	# Display — migrate old fullscreen bool → window_mode int
	if config.has_section_key("display", "window_mode"):
		window_mode = int(config.get_value("display", "window_mode", 0))
	elif config.has_section_key("display", "fullscreen"):
		var old_fs: bool = bool(config.get_value("display", "fullscreen", false))
		window_mode = WindowMode.BORDERLESS if old_fs else WindowMode.WINDOWED
	else:
		window_mode = WindowMode.WINDOWED

	var res_w: int = int(config.get_value("display", "resolution_w", 1920))
	var res_h: int = int(config.get_value("display", "resolution_h", 1080))
	resolution = Vector2i(res_w, res_h)
	vsync = bool(config.get_value("display", "vsync", true))
	max_fps = int(config.get_value("display", "max_fps", 0))

	# Graphics
	screen_shake_intensity = float(config.get_value("graphics", "screen_shake_intensity", 1.0))
	particle_density = int(config.get_value("graphics", "particle_density", 2))
	background_quality = int(config.get_value("graphics", "background_quality", 1))

	# Debug
	show_debug_overlay = bool(config.get_value("debug", "show_debug_overlay", false))


func apply_all_settings() -> void:
	## Apply all settings without saving (used on load).
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("Music", music_volume)

	_apply_window_mode()

	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	Engine.max_fps = max_fps
