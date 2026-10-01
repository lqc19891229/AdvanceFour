class_name ShipRuntime
extends Node2D

@export var cell_size := 36.0
@export var acceleration_scale := 180.0
@export var drag := 2.5

var ship_data: ShipData
var velocity := Vector2.ZERO
var move_input := Vector2.ZERO

func setup(data: ShipData) -> void:
	ship_data = data
	velocity = Vector2.ZERO
	move_input = Vector2.ZERO
	queue_redraw()

func set_move_input(direction: Vector2) -> void:
	move_input = direction.limit_length(1.0)

func get_speed() -> float:
	return velocity.length()

func _physics_process(delta: float) -> void:
	if ship_data == null:
		return

	if move_input.length_squared() > 0.0:
		var acceleration := ship_data.get_acceleration_score() * acceleration_scale
		velocity += move_input.normalized() * acceleration * delta

	velocity = velocity.move_toward(Vector2.ZERO, velocity.length() * drag * delta)
	position += velocity * delta

func _draw() -> void:
	if ship_data == null:
		return

	for module in ship_data.modules:
		var size := module.get_rotated_size()
		var rect := Rect2(
			Vector2(module.grid_position) * cell_size,
			Vector2(size) * cell_size
		)
		draw_rect(rect.grow(-2.0), _get_module_color(module.definition.module_type))
		draw_rect(rect.grow(-2.0), Color.WHITE, false, 1.0)

func _get_module_color(module_type: ShipModuleDefinition.ModuleType) -> Color:
	match module_type:
		ShipModuleDefinition.ModuleType.ENERGY:
			return Color("#d9b84c")
		ShipModuleDefinition.ModuleType.PROPULSION:
			return Color("#5aa3d8")
		ShipModuleDefinition.ModuleType.WEAPON:
			return Color("#d65f5f")
		ShipModuleDefinition.ModuleType.DEFENSE:
			return Color("#65aa78")
		ShipModuleDefinition.ModuleType.FUNCTION:
			return Color("#9a79ca")
		ShipModuleDefinition.ModuleType.CORE:
			return Color("#d98c4a")
	return Color.GRAY
