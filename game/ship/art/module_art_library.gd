class_name ModuleArtLibrary
extends RefCounted

static func get_base_texture(definition: ShipModuleDefinition) -> Texture2D:
	if definition == null:
		return null
	return definition.texture

static func get_turret_texture(definition: ShipModuleDefinition) -> Texture2D:
	if not (definition is WeaponModuleDefinition):
		return null
	return (definition as WeaponModuleDefinition).turret_texture

static func get_texture_scale(texture: Texture2D, target_size: Vector2) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var source_size := Vector2(texture.get_size())
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2.ONE
	return target_size / source_size
