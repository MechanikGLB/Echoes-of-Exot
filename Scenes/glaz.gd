extends Node3D

@onready var eye = $Node/eye2
@onready var eye1 = $Node/eye3
@export var target:Node

func _process(delta: float) -> void:
	eye.look_at(target.global_position)
	eye1.look_at(target.global_position)
