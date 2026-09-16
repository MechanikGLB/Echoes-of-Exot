class_name AbilityComponent extends Node

# СИГНАЛЫ
signal ability_used(ability_id: String)
signal ability_hit_frame(ability_id: String)
signal ability_hit_landed(ability_id: String, target: Node, damage: int, zone: String)
signal ability_finished(ability_id: String)
signal cooldown_started(ability_id: String, duration: float)

# ПУБЛИЧНОЕ API
func use_ability(slot: int) -> bool:
	return false

func cancel_ability() -> void:
	pass

func is_on_cooldown(ability_id: String) -> bool:
	return false

func get_cooldown_remaining(ability_id: String) -> float:
	return 0.0

func add_ability(ability: AbilityResource) -> void:
	pass

func remove_ability(ability_id: String) -> void:
	pass

func get_abilities() -> Array:
	return []
