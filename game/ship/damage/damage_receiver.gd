class_name DamageReceiver
extends Node

signal damaged(amount: float, current_hp: float)
signal destroyed

@export var max_hp := 20.0

var current_hp := 0.0
var destroyed_state := false

func _ready() -> void:
	reset()

func setup(p_max_hp: float) -> void:
	max_hp = maxf(p_max_hp, 0.0)
	reset()

func reset() -> void:
	current_hp = maxf(max_hp, 0.0)
	destroyed_state = current_hp <= 0.0

func apply_damage(amount: float) -> void:
	if destroyed_state:
		return

	var applied := maxf(amount, 0.0)
	if applied <= 0.0:
		return

	current_hp = maxf(0.0, current_hp - applied)
	damaged.emit(applied, current_hp)

	if current_hp <= 0.0:
		destroyed_state = true
		destroyed.emit()

func get_hp() -> float:
	return current_hp

func is_destroyed() -> bool:
	return destroyed_state
