class_name ShipModuleDefinition
extends Resource

enum ModuleType { ENERGY, PROPULSION, WEAPON, DEFENSE, FUNCTION, CORE }

var id: StringName
var display_name: String
var type: ModuleType
var size: Vector2i = Vector2i.ONE
var mass: float = 0.0
var max_hp: float = 100.0
var energy_output: float = 0.0
var energy_cost: float = 0.0
var thrust: float = 0.0
var firepower: float = 0.0
var protection: float = 0.0
var special_text: String = ""

func _init(p_id: StringName = &"", p_display_name: String = "", p_type: ModuleType = ModuleType.FUNCTION,
	p_size: Vector2i = Vector2i.ONE, p_mass: float = 0.0, p_max_hp: float = 100.0,
	p_energy_output: float = 0.0, p_energy_cost: float = 0.0, p_thrust: float = 0.0,
	p_firepower: float = 0.0, p_protection: float = 0.0, p_special_text: String = "") -> void:
	id = p_id
	display_name = p_display_name
	type = p_type
	size = p_size
	mass = p_mass
	max_hp = p_max_hp
	energy_output = p_energy_output
	energy_cost = p_energy_cost
	thrust = p_thrust
	firepower = p_firepower
	protection = p_protection
	special_text = p_special_text
