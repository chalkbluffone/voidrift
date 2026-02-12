class_name WeaponDataFlattener
extends RefCounted

## WeaponDataFlattener - Generic utility for flattening/unflattening weapon JSON data.
##
## Walks all editable sub-dictionaries (stats, shape, motion, visual, particles, base_stats)
## without any weapon-type detection. Any weapon added to weapons.json will work automatically.
##
## Usage:
##   var result = WeaponDataFlattener.flatten(weapon_data)
##   var flat_config: Dictionary = result.flat       # {key: value} for UI/spawners
##   var key_map: Dictionary = result.key_map        # {flat_key: {section, key}} for unflatten
##
##   var updated_json = WeaponDataFlattener.unflatten(flat_config, key_map, original_data)

## Sections of weapon JSON that contain editable parameters.
## Order matters for display grouping in the UI.
const EDITABLE_SECTIONS := ["stats", "base_stats", "shape", "motion", "visual", "particles"]

## Metadata keys that should NOT be flattened into editable parameters.
const METADATA_KEYS := ["description", "display_name", "enabled", "scene", "spawner", "type", "unlock_condition"]


## Flatten nested weapon JSON into a flat dictionary for UI sliders and spawners.
## Returns {"flat": Dictionary, "key_map": Dictionary}.
## key_map maps each flat key back to its original section and key name.
static func flatten(weapon_data: Dictionary) -> Dictionary:
	var flat: Dictionary = {}
	var key_map: Dictionary = {}
	
	for section in EDITABLE_SECTIONS:
		var section_data: Dictionary = weapon_data.get(section, {})
		if section_data.is_empty():
			continue
		
		for key in section_data:
			var value = section_data[key]
			var flat_key: String = _make_flat_key(section, key)
			
			# Convert hex color strings to Color objects for visual/particles sections
			if (section == "visual" or section == "particles") and value is String and _looks_like_hex_color(value):
				flat[flat_key] = hex_to_color(value)
			else:
				flat[flat_key] = value
			
			key_map[flat_key] = {"section": section, "key": key}
	
	return {"flat": flat, "key_map": key_map}


## Convert flat config + key_map back to nested weapon JSON structure.
## Deep-duplicates original, then writes each flat value back to its correct section.
static func unflatten(flat: Dictionary, key_map: Dictionary, original: Dictionary) -> Dictionary:
	var result: Dictionary = original.duplicate(true)
	
	# Ensure all sections exist
	for section in EDITABLE_SECTIONS:
		if original.has(section) and not result.has(section):
			result[section] = {}
	
	# Write each flat value back to its section
	for flat_key in flat:
		if not key_map.has(flat_key):
			# Key not in map — skip (could be a runtime-injected key like size_mult)
			continue
		
		var mapping: Dictionary = key_map[flat_key]
		var section: String = mapping["section"]
		var original_key: String = mapping["key"]
		var value = flat[flat_key]
		
		# Ensure section dict exists in result
		if not result.has(section):
			result[section] = {}
		
		# Convert Color objects back to hex strings for visual/particles sections
		if value is Color:
			result[section][original_key] = color_to_hex(value)
		else:
			result[section][original_key] = value
	
	return result


## Create a flat key from section + original key.
## Particles keys get "particles_" prefix to avoid collisions with shape/motion keys
## (e.g., "speed", "size", "spread" exist in both particles and other sections).
## All other sections use the key as-is since they rarely collide.
static func _make_flat_key(section: String, key: String) -> String:
	if section == "particles":
		# "enabled" -> "particles_enabled", "amount" -> "particles_amount", etc.
		return "particles_" + key
	return key


## Check if string looks like a hex color (starts with #)
static func _looks_like_hex_color(value: String) -> bool:
	return value.begins_with("#") and value.length() >= 4


## Convert hex color string to Color object.
static func hex_to_color(hex: String) -> Color:
	if hex.is_empty():
		return Color.WHITE
	return Color.from_string(hex, Color.WHITE)


## Convert Color object to hex string, including alpha if < 1.0.
static func color_to_hex(color: Color) -> String:
	if color.a < 1.0:
		return "#" + color.to_html(true)  # Include alpha
	return "#" + color.to_html(false)  # No alpha
