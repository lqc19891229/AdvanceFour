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
		var definition := WeaponModuleDefinition.new()
		definition.turret_texture = load(String(module["turret_texture_path"])) as Texture2D
		definition.turret_size_cells = Vector2(module["turret_size_cells"][0], module["turret_size_cells"][1])
		definition.turret_pivot = Vector2(module["turret_pivot"][0], module["turret_pivot"][1])
		definition.turret_art_rotation_degrees = float(module.get("turret_art_rotation_degrees", 0.0))
		var base_size := Vector2i(int(module["width"]), int(module["height"])) * PIXELS_PER_CELL
		var base := Image.load_from_file(ProjectSettings.globalize_path(String(module["texture_path"])))
		var texture := ModuleArtLibrary.get_turret_texture(definition)
		var turret := texture.get_image() if texture != null else null
		if base_size.x <= 0 or base_size.y <= 0 or base == null or turret == null:
			_fail("Weapon dimensions or source images are invalid.")
			return
		# Same geometry as the editor and runtime, with a canvas that includes overhang.
		var base_rect := Rect2(-Vector2(base_size) * 0.5, Vector2(base_size))
		var turret_rect := ModuleArtLibrary.get_turret_draw_rect(definition, PIXELS_PER_CELL)
		var bounds := base_rect.merge(turret_rect)
		var origin := bounds.position.floor()
		var dimensions := Vector2i((bounds.end.ceil() - origin))
		var canvas := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		base.convert(Image.FORMAT_RGBA8)
		turret.convert(Image.FORMAT_RGBA8)
		base.resize(base_size.x, base_size.y, Image.INTERPOLATE_LANCZOS)
		var turret_size := Vector2i(turret_rect.size.round()).max(Vector2i.ONE)
		turret.resize(turret_size.x, turret_size.y, Image.INTERPOLATE_LANCZOS)
		canvas.blend_rect(base, Rect2i(Vector2i.ZERO, base_size), Vector2i((base_rect.position - origin).round()))
		canvas.blend_rect(turret, Rect2i(Vector2i.ZERO, turret_size), Vector2i((turret_rect.position - origin).round()))
		var output := "res://data/assets/modules/%s_icon.png" % arguments[0]
		if canvas.save_png(output) != OK:
			_fail("Could not save %s." % output)
			return
		print("Generated %s (%d x %d)" % [output, dimensions.x, dimensions.y])
		quit(0)
		return
	_fail("Weapon module ID was not found in the imported cache.")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
