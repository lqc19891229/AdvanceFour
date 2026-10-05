class_name ShipModuleRuntime
extends Area2D

signal damaged(
	module_instance: ShipModuleInstance,
	amount: float,
	current_hp: float
)
signal destroyed(module_instance: ShipModuleInstance)

var module_instance: ShipModuleInstance
var damage_receiver: DamageReceiver
var collision_shape: CollisionShape2D
var visual: Sprite2D

func setup(
	module: ShipModuleInstance,
	local_position: Vector2,
	pixel_size: Vector2,
	max_hp: float
) -> void:
	module_instance = module
	position = local_position

	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true

	collision_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = pixel_size
	collision_shape.shape = shape
	add_child(collision_shape)

	damage_receiver = DamageReceiver.new()
	add_child(damage_receiver)
	damage_receiver.setup(max_hp)
	damage_receiver.damaged.connect(_on_damage_receiver_damaged)
	damage_receiver.destroyed.connect(_on_damage_receiver_destroyed)

	_build_visual(pixel_size)

func _build_visual(pixel_size: Vector2) -> void:
	if module_instance == null or module_instance.definition == null:
		return
	var texture := ModuleArtLibrary.get_base_texture(module_instance.definition)
	if texture == null:
		return

	visual = Sprite2D.new()
	visual.texture = texture
	visual.centered = true
	visual.scale = ModuleArtLibrary.get_texture_scale(
		texture,
		pixel_size - Vector2(4.0, 4.0)
	)
	if not (module_instance.definition is WeaponModuleDefinition):
		visual.rotation = float(module_instance.rotation_quarters) * PI * 0.5
	add_child(visual)

func apply_damage(amount: float) -> void:
	if damage_receiver != null:
		damage_receiver.apply_damage(amount)

func apply_projectile_damage(amount: float) -> float:
	var incoming := maxf(amount, 0.0)
	if incoming <= 0.0 or damage_receiver == null:
		return 0.0

	if is_destroyed():
		return incoming

	var protection_percent := clampf(get_protection(), 0.0, 100.0)
	var damage_after_protection := incoming * (1.0 - protection_percent / 100.0)
	if damage_after_protection <= 0.0:
		return 0.0

	var hp_before := get_hp()
	damage_receiver.apply_damage(damage_after_protection)

	if is_destroyed():
		return maxf(damage_after_protection - hp_before, 0.0)
	return 0.0

func get_hp() -> float:
	return 0.0 if damage_receiver == null else damage_receiver.get_hp()

func get_max_hp() -> float:
	return 0.0 if damage_receiver == null else damage_receiver.max_hp

func is_armor() -> bool:
	return (
		module_instance != null
		and module_instance.definition is DefenseModuleDefinition
	)

func get_protection() -> float:
	if not is_armor():
		return 0.0
	return maxf(
		(module_instance.definition as DefenseModuleDefinition).protection,
		0.0
	)

func is_destroyed() -> bool:
	return damage_receiver != null and damage_receiver.is_destroyed()

func _on_damage_receiver_damaged(amount: float, current_hp: float) -> void:
	damaged.emit(module_instance, amount, current_hp)

func _on_damage_receiver_destroyed() -> void:
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if visual != null:
		visual.modulate = Color(0.32, 0.32, 0.32, 1.0)
	destroyed.emit(module_instance)
