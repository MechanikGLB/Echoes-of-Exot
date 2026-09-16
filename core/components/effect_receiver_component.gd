class_name EffectReceiverComponent extends Node

# СИГНАЛЫ
signal effect_applied(effect_id: String)
signal effect_removed(effect_id: String)
signal effect_tick(effect_id: String)

# ПУБЛИЧНОЕ API
func apply_effect(effect: StatusEffect) -> void:
	pass

func remove_effect(effect_id: String) -> void:
	pass

func has_effect(effect_id: String) -> bool:
	return false

func get_effect(effect_id: String) -> StatusEffect:
	return null

func get_active_effects() -> Array:
	return []

func clear_all() -> void:
	pass
