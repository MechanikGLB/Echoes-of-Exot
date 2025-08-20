extends Area3D

@export var damage_mult := 1

signal body_part_hit(dmg)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func hit(dmg):
	emit_signal("body_part_hit", damage_mult * dmg)
