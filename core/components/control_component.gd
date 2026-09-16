class_name ControlComponent extends Node

enum Mode { PLAYER, AI, HYBRID, SCRIPTED }

# СИГНАЛЫ (низкоуровневые — для MovementComponent и AbilityComponent)
signal move_input(direction: Vector3, sprint: bool)
signal jump_requested
signal ability_requested(slot: int)
signal aim_changed(direction: Vector3)

# РЕЖИМ УПРАВЛЕНИЯ
func set_mode(new_mode: Mode) -> void:
	pass

func get_mode() -> Mode:
	return Mode.PLAYER

func enable() -> void:
	pass

func disable() -> void:
	pass

# ВЫСОКОУРОВНЕВЫЕ КОМАНДЫ (для ИИ, скриптов, кат-сцен)
func move_to(target_position: Vector3) -> void:
	pass

func stop_movement() -> void:
	pass

func look_at_target(target_position: Vector3) -> void:
	pass

func request_ability(slot: int) -> void:
	pass
