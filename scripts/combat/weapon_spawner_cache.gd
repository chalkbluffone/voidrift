class_name WeaponSpawnerCache
extends RefCounted

## Manages dynamic loading and caching of weapon spawner instances.
## Owned by WeaponComponent as an internal helper — not a scene-tree node.

## Cached spawner instances: {weapon_id: spawner_object}
var _spawner_cache: Dictionary = {}

## Cached GDScript resources: {script_path: GDScript}
var _spawner_script_cache: Dictionary = {}


## Detect the arg count of a spawner's spawn() method via reflection.
static func get_spawner_arg_count(spawner: Object, default: int = 3) -> int:
	var script: Script = spawner.get_script()
	var methods: Array = script.get_script_method_list() if script else []
	for m in methods:
		if m.get("name", "") == "spawn":
			return m.get("args", []).size()
	return default


## Load (or return cached) spawner for a weapon.  effects_parent is the node
## that spawned effects attach to (typically SceneTree.current_scene).
func get_or_create_spawner(weapon_id: String, weapon_data: Dictionary, effects_parent: Node) -> Variant:
	if _spawner_cache.has(weapon_id):
		return _spawner_cache[weapon_id]

	var spawner_path: String = weapon_data.get("spawner", "")
	if spawner_path.is_empty():
		return null

	var script: GDScript = null
	if _spawner_script_cache.has(spawner_path):
		script = _spawner_script_cache[spawner_path]
	else:
		if not ResourceLoader.exists(spawner_path):
			return null
		script = load(spawner_path) as GDScript
		if script == null:
			return null
		_spawner_script_cache[spawner_path] = script

	var spawner: Object = script.new(effects_parent)
	_spawner_cache[weapon_id] = spawner
	return spawner


## Clean up a single spawner (calls cleanup() if present, then removes from cache).
func cleanup_spawner(weapon_id: String) -> void:
	if not _spawner_cache.has(weapon_id):
		return
	var spawner: Object = _spawner_cache[weapon_id]
	if spawner.has_method("cleanup"):
		spawner.cleanup()
	_spawner_cache.erase(weapon_id)


## Clean up all spawners.
func cleanup_all() -> void:
	for weapon_id in _spawner_cache.keys():
		var spawner: Object = _spawner_cache[weapon_id]
		if spawner.has_method("cleanup"):
			spawner.cleanup()
	_spawner_cache.clear()


## Check whether a spawner is cached for a weapon.
func has_spawner(weapon_id: String) -> bool:
	return _spawner_cache.has(weapon_id)
