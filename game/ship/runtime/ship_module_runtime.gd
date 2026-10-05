class_name ShipModuleRuntime
extends Node2D

var module_instance: ShipModuleInstance
var visual: Sprite2D
var efficiency := 1.0

func setup(
	module: ShipModuleInstance,
	local_position: Vector2,
	pixel_size: Vector2
) -> void:
	module_instance = module
	position = local_position
	z_index = EquipmentAppearancePolicy.get_layer(module.definition)
	_build_visual(pixel_size)
	set_efficiency(1.0)

func _build_visual(pixel_size: Vector2) -> void:
	if module_instance == null or module_instance.definition == null:
		return
	if not EquipmentAppearancePolicy.should_show(module_instance.definition):
		return
	var texture := ModuleArtLibrary.get_base_texture(module_instance.definition)
	if texture == null:
		return

	visual = Sprite2D.new()
	visual.texture = texture
	visual.centered = true
	visual.scale = ModuleArtLibrary.get_texture_scale(
		texture,
		pixel_size - Vector2(8.0, 8.0)
	)
	if not (module_instance.definition is WeaponModuleDefinition):
		visual.rotation = float(module_instance.rotation_quarters) * PI * 0.5
	add_child(visual)

func set_efficiency(value: float) -> void:
	efficiency = clampf(value, 0.0, 1.0)
	if visual == null:
		return
	var brightness := 0.35 + 0.65 * efficiency
	visual.modulate = Color(brightness, brightness, brightness, 1.0)

func get_efficiency() -> float:
	return efficiency

func is_destroyed() -> bool:
	return efficiency <= 0.0
