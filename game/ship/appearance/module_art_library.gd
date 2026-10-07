class_name ModuleArtLibrary
extends RefCounted

# New turret textures point up at zero rotation, matching the ship's forward axis.
const WEAPON_FORWARD := Vector2.UP
static var _upright_textures: Dictionary = {}

static func get_base_texture(definition: ShipModuleDefinition) -> Texture2D:
	if definition == null:
		return null
	return definition.texture

static func get_turret_texture(definition: ShipModuleDefinition) -> Texture2D:
	if not (definition is WeaponModuleDefinition):
		return null
	var weapon := definition as WeaponModuleDefinition
	var texture := weapon.turret_texture
	if texture == null:
		return null
	var quarters := posmod(roundi(weapon.turret_art_rotation_degrees / 90.0), 4)
	if quarters == 0:
		return texture
	var key := "%d:%d" % [texture.get_instance_id(), quarters]
	if not _upright_textures.has(key):
		var image := texture.get_image()
		if image == null:
			return texture
		if image.is_compressed():
			image.decompress()
		for quarter in range(quarters):
			image.rotate_90(CLOCKWISE)
		_upright_textures[key] = ImageTexture.create_from_image(image)
	return _upright_textures[key]

static func get_turret_draw_size(weapon: WeaponModuleDefinition, pixels_per_cell: float) -> Vector2:
	var texture := get_turret_texture(weapon)
	var target := weapon.turret_size_cells * pixels_per_cell
	if texture == null:
		return target
	var source := Vector2(texture.get_size())
	# Fit the configured canvas with uniform scaling; never stretch rectangular art.
	return source * minf(target.x / source.x, target.y / source.y)

static func get_turret_draw_rect(weapon: WeaponModuleDefinition, pixels_per_cell: float) -> Rect2:
	var draw_size := get_turret_draw_size(weapon, pixels_per_cell)
	var pivot := Vector2(weapon.turret_pivot.x, 1.0 - weapon.turret_pivot.y)
	return Rect2(-pivot * draw_size, draw_size)

static func get_turret_muzzle_offset(weapon: WeaponModuleDefinition, pixels_per_cell: float) -> Vector2:
	var delta := weapon.turret_muzzle - weapon.turret_pivot
	return Vector2(delta.x, -delta.y) * get_turret_draw_size(weapon, pixels_per_cell)

static func get_texture_scale(texture: Texture2D, target_size: Vector2) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var source_size := Vector2(texture.get_size())
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2.ONE
	return target_size / source_size
