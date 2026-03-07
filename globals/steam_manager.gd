extends Node

## SteamManager — Initializes the Steamworks SDK via GodotSteam GDExtension.
## Autoload as "SteamManager" in project settings. Loaded after SettingsManager.
##
## Requires the GodotSteam GDExtension addon in addons/godotsteam/.
## During development without the addon, this gracefully logs a warning and
## continues so the game remains playable without Steam.
##
## All Steam API calls use dynamic method invocation via the _steam singleton
## reference to avoid parse errors when the GDExtension is not installed.

var _steam_available: bool = false
var _steam: Object = null


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		FileLogger.log_warn("SteamManager", "GodotSteam not found — running without Steam integration")
		return

	_steam = Engine.get_singleton("Steam")

	var init_result: Dictionary = _steam.call("steamInitEx")
	var status: int = int(init_result.get("status", 1))

	if status != 0:
		var verbal: String = String(init_result.get("verbal", "unknown error"))
		FileLogger.log_error("SteamManager", "Steam init failed (status %d): %s" % [status, verbal])
		_steam = null
		return

	_steam_available = true
	var steam_id: int = _steam.call("getSteamID")
	FileLogger.log_info("SteamManager", "Steam initialized — user ID: %d" % steam_id)


func _process(_delta: float) -> void:
	if _steam_available and _steam != null:
		_steam.call("run_callbacks")


## Returns true if the Steam SDK was successfully initialized.
func is_steam_active() -> bool:
	return _steam_available
