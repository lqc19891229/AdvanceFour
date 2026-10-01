class_name PlayerShipController
extends Node

var runtime_ship: ShipRuntime
var fire_was_pressed := false

func setup(target: ShipRuntime) -> void:
	if runtime_ship != null and is_instance_valid(runtime_ship) and runtime_ship != target:
		runtime_ship.set_control_input(0.0, 0.0)
	runtime_ship = target
	fire_was_pressed = false

func clear_target() -> void:
	if runtime_ship != null and is_instance_valid(runtime_ship):
		runtime_ship.set_control_input(0.0, 0.0)
	runtime_ship = null
	fire_was_pressed = false

func _physics_process(_delta: float) -> void:
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

	var fire_pressed := Input.is_physical_key_pressed(KEY_SPACE)
	if fire_pressed and not fire_was_pressed:
		runtime_ship.request_fire()
	fire_was_pressed = fire_pressed
