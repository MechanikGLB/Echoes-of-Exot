class_name MovementComponent extends Node

signal velocity_changed(new_velocity: Vector3)
signal landed
signal jumped
signal movement_type_changed(new_type: String)

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 5.5
@export var gravity: float = 9.8

@export var enabled: bool = false  

var velocity: Vector3 = Vector3.ZERO
var current_speed: float = 5.0
var movement_type: String = "ground"

var _speed_modifiers: Dictionary = {}
var _jump_modifiers: Dictionary = {}
var _gravity_modifiers: Dictionary = {}

var _body: CharacterBody3D

func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if not _body:
		push_error("MovementComponent должен быть дочерним узлом CharacterBody3D")
		return
	current_speed = walk_speed

func _physics_process(delta: float) -> void:
	
	if not _body or not enabled:
		return

	# Гравитация
	if not _body.is_on_floor():
		velocity.y -= get_gravity() * delta

	# Применяем velocity к body
	_body.velocity = velocity
	_body.move_and_slide()

	# Обновляем velocity из body (после столкновений)
	velocity = _body.velocity
	velocity_changed.emit(velocity)

	if _body.is_on_floor() and velocity.y <= 0:
		landed.emit()

func set_move_input(direction: Vector3, sprint: bool = false) -> void:
	current_speed = get_sprint_speed() if sprint else get_walk_speed()
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

func jump() -> void:
	if _body and _body.is_on_floor():
		velocity.y = get_jump_velocity()
		jumped.emit()

func get_velocity() -> Vector3:
	return velocity

func set_movement_type(type: String) -> void:
	movement_type = type
	movement_type_changed.emit(type)

func set_gravity_enabled(enabled: bool) -> void:
	# Заглушка на будущее
	pass

# Модификаторы

func add_speed_modifier(id: String, multiplier: float) -> void:
	_speed_modifiers[id] = multiplier

func remove_speed_modifier(id: String) -> void:
	_speed_modifiers.erase(id)

func add_jump_modifier(id: String, multiplier: float) -> void:
	_jump_modifiers[id] = multiplier

func remove_jump_modifier(id: String) -> void:
	_jump_modifiers.erase(id)

func add_gravity_modifier(id: String, multiplier: float) -> void:
	_gravity_modifiers[id] = multiplier

func remove_gravity_modifier(id: String) -> void:
	_gravity_modifiers.erase(id)

func _get_total_multiplier(modifiers: Dictionary) -> float:
	var result := 1.0
	for mult in modifiers.values():
		result *= mult
	return result

func get_walk_speed() -> float:
	return walk_speed * _get_total_multiplier(_speed_modifiers)

func get_sprint_speed() -> float:
	return sprint_speed * _get_total_multiplier(_speed_modifiers)

func get_jump_velocity() -> float:
	return jump_velocity * _get_total_multiplier(_jump_modifiers)

func get_gravity() -> float:
	return gravity * _get_total_multiplier(_gravity_modifiers)
