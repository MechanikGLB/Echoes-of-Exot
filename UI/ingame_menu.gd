extends CanvasLayer

@onready var menu = $"."

func _on_continue_pressed() -> void:
	menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/parts/main_menu.tscn")
