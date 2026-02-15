extends Node3D

@onready var eye = $Node/eye2
@onready var eye1 = $Node/eye3
@export var target:Node

func _process(delta: float) -> void:
	if is_instance_valid(target):
		eye.look_at(target.global_position)
		eye1.look_at(target.global_position)

func set_player_target(p_target: Node3D) -> void:
	target = p_target
