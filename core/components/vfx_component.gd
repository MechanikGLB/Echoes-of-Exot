class_name VFXComponent extends Node

# ЭКСПОРТ (реализация, для подгонки конкретных персонажей)
@export var hit_vfx: PackedScene
@export var death_vfx: PackedScene
@export var ability_vfx: Dictionary = {}  # ability_id -> PackedScene

# ПУБЛИЧНОЕ API
func play_hit_vfx(world_position: Vector3, zone: String) -> void:
	pass

func play_death_vfx(world_position: Vector3) -> void:
	pass

func play_ability_vfx(ability_id: String, world_position: Vector3) -> void:
	pass
