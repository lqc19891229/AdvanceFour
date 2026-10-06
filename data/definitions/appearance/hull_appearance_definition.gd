class_name HullAppearanceDefinition
extends Resource

const REQUIRED_TILE_COUNT := 16

@export var appearance_id: StringName = &"human_basic"
@export var tiles: Array[Texture2D] = []

func is_valid() -> bool:
	if appearance_id == &"" or tiles.size() != REQUIRED_TILE_COUNT:
		return false
	for texture in tiles:
		if texture == null:
			return false
	return true

func get_tile(mask: int) -> Texture2D:
	if mask < 0 or mask >= REQUIRED_TILE_COUNT or mask >= tiles.size():
		return null
	return tiles[mask]
