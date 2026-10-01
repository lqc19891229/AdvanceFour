class_name PlayerShipController
extends Node

var runtime_ship: ShipRuntime

func setup(target: ShipRuntime) -> void:
	runtime_ship = target

func clear_target() -> void:
	if runtime_ship != null:
		runtime_ship.set_control_input(0.0, 0.0)
	runtime_ship = null

func _process(_delta: float) -> void:
	if runtime_ship == null or not is_instance_valid(runtime_ship):
		return

	var throttle := 0.0
	var turn := 0.0

	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		throttle -= 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		turn -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		turn += 1.0

	runtime_ship.set_control_input(throttle, turn)
