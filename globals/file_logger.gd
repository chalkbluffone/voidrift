extends Node

## FileLogger - Writes log output to a file for debugging.
## Autoload as "FileLogger" in project settings.

const LOG_FILE_PATH_EDITOR := "res://debug_log.txt"
const LOG_FILE_PATH_EXPORT := "user://debug_log.txt"
const MAX_LOG_SIZE := 1024 * 1024  # 1MB max before truncating

var _file: FileAccess = null
var _log_path: String = ""

func _ready() -> void:
	# Use res:// in editor (writable project root), user:// in exported builds
	var log_file_path: String = LOG_FILE_PATH_EDITOR if OS.has_feature("editor") else LOG_FILE_PATH_EXPORT
	
	# Get the actual path for display
	_log_path = ProjectSettings.globalize_path(log_file_path)
	
	# Delete existing log file on startup
	if FileAccess.file_exists(log_file_path):
		DirAccess.remove_absolute(_log_path)
	
	# Open file for writing (overwrite on each run)
	_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if _file == null:
		push_error("[FileLogger] Failed to open log file: " + _log_path)
		return
	
	# Write header
	var header := "=== Voidrift Debug Log ===\n"
	header += "Started: %s\n" % Time.get_datetime_string_from_system()
	header += "Log path: %s\n" % _log_path
	header += "=" .repeat(40) + "\n\n"
	_file.store_string(header)
	_file.flush()
	
	print("[FileLogger] Logging to: " + _log_path)


func _exit_tree() -> void:
	if _file:
		log_info("FileLogger", "Session ended")
		_file.close()


func _write(text: String) -> void:
	if _file:
		var timestamp := Time.get_time_string_from_system()
		_file.store_string("[%s] %s\n" % [timestamp, text])
		_file.flush()  # Flush immediately so we don't lose data on crash


## Log an info message
func log_info(source: String, message: String) -> void:
	var text := "[INFO][%s] %s" % [source, message]
	_write(text)
	print(text)


## Log a warning message
func log_warn(source: String, message: String) -> void:
	var text := "[WARN][%s] %s" % [source, message]
	_write(text)
	push_warning(text)


## Log an error message
func log_error(source: String, message: String) -> void:
	var text := "[ERROR][%s] %s" % [source, message]
	_write(text)
	push_error(text)


## Log a debug message (only in debug builds)
func log_debug(source: String, message: String) -> void:
	if OS.is_debug_build():
		var text := "[DEBUG][%s] %s" % [source, message]
		_write(text)
		print(text)


## Log with custom level
func log_custom(level: String, source: String, message: String) -> void:
	var text := "[%s][%s] %s" % [level, source, message]
	_write(text)
	print(text)


## Log a dictionary or array nicely formatted
func log_data(source: String, label: String, data: Variant) -> void:
	var text := "[DATA][%s] %s: %s" % [source, label, JSON.stringify(data, "  ")]
	_write(text)
	print(text)


## Get the log file path (for displaying to user)
func get_log_path() -> String:
	return _log_path


## Quick static-like access for common logging
func info(msg: String) -> void:
	log_info("Game", msg)

func warn(msg: String) -> void:
	log_warn("Game", msg)

func error(msg: String) -> void:
	log_error("Game", msg)

func debug(msg: String) -> void:
	log_debug("Game", msg)
