class_name MovementComponent extends Node

# СИГНАЛЫ
signal velocity_changed(new_velocity: Vector3)
signal landed
signal jumped
signal movement_type_changed(new_type: String)

# ПУБЛИЧНОЕ API
func set_move_input(direction: Vector3, sprint: bool = false) -> void:
	pass

func jump() -> void:
	pass

func get_velocity() -> Vector3:
	return Vector3.ZERO

func set_movement_type(type: String) -> void:
	pass
