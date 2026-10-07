extends SceneTree

# Rebuild one UI icon from the source layers, without loading module Resources.
# godot --headless --path . --script tools/generate_weapon_icon.gd -- weapon_cannon
const PIXELS_PER_CELL := 128

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		_fail("Specify one weapon module ID after --.")
		return
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tools/cache/modules.json"))
	if not (payload is Dictionary) or not payload.get("ok", false):
		_fail("Import the Excel source before generating a weapon icon.")
		return
	for module in payload.get("modules", []):
		if module.get("id", "") != arguments[0] or module.get("module_type", "") != "WEAPON":
			continue
		var dimensions := Vector2i(int(module["width"]), int(module["height"])) * PIXELS_PER_CELL
		var base := Image.load_from_file(ProjectSettings.globalize_path(String(module["texture_path"])))
		var turret := Image.load_from_file(ProjectSettings.globalize_path(String(module["turret_texture_path"])))
		if dimensions.x <= 0 or dimensions.y <= 0 or base == null or turret == null:
			_fail("Weapon dimensions or source images are invalid.")
			return
		# Match editor/runtime alignment: both layers occupy the same module rect.
		base.convert(Image.FORMAT_RGBA8)
		turret.convert(Image.FORMAT_RGBA8)
		base.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
		turret.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
		base.blend_rect(turret, Rect2i(Vector2i.ZERO, dimensions), Vector2i.ZERO)
		var output := "res://data/assets/modules/%s_icon.png" % arguments[0]
		if base.save_png(output) != OK:
			_fail("Could not save %s." % output)
			return
		print("Generated %s (%d x %d)" % [output, dimensions.x, dimensions.y])
		quit(0)
		return
	_fail("Weapon module ID was not found in the imported cache.")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
