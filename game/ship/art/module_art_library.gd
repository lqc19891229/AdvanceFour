class_name ModuleArtLibrary
extends RefCounted

const MODULE_ART_ROOT := "res://game/ship/art/modules/"

static func get_base_texture(definition: ShipModuleDefinition) -> Texture2D:
	if definition == null:
		return null

	var suffix := "_base.png" if definition is WeaponModuleDefinition else ".png"
	return _load_texture("%s%s%s" % [
		MODULE_ART_ROOT,
		String(definition.id),
		suffix
	])

static func get_turret_texture(definition: ShipModuleDefinition) -> Texture2D:
	if not (definition is WeaponModuleDefinition):
		return null
	return _load_texture("%s%s_turret.png" % [
		MODULE_ART_ROOT,
		String(definition.id)
	])

static func get_texture_scale(texture: Texture2D, target_size: Vector2) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var source_size := Vector2(texture.get_size())
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2.ONE
	return target_size / source_size

static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
