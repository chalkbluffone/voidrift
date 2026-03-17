extends SceneTree

func _init() -> void:
	# Dump ALL BulletFactory2D properties to find movement-related config
	var factory: Object = ClassDB.instantiate(&"BulletFactory2D")
	if factory:
		print("=== BulletFactory2D ALL properties ===")
		for prop in factory.get_property_list():
			var name: String = prop.get("name", "")
			if name in ["script", "Script Variables"]:
				continue
			if name.begins_with("metadata") or name.begins_with("Node"):
				continue
			print("  ", name, " = ", factory.get(name))
	quit()
