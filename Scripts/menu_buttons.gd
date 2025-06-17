extends VBoxContainer

const world = preload("res://Scenes/Maps/main.tscn")

@onready var menu = $"../.."
@onready var maps = $"../../../Mapselection"

func _on_play_pressed() -> void:
	menu.visible = false
	maps.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_return_pressed() -> void:
	maps.visible = false
	menu.visible = true
