extends Node3D

@onready var camera_pivot = $CameraPivot
@onready var map_folder = "res://Scenes/Maps/"
@onready var button_container = $Menu/Mapselection/MapChoose/ScrollContainer/GridContainer

var current_map: Node = null
var selected_character: Node = null

var rotation_speed = 8

func _process(delta: float) -> void:
	camera_pivot.rotation_degrees.y += delta * rotation_speed

func get_available_maps() -> Array:
	var maps = []
	var dir = DirAccess.open(map_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				maps.append(file_name.trim_suffix(".tscn"))
			file_name = dir.get_next()
	return maps

func map_refresh():
	# Очищаем старые кнопки
	for child in button_container.get_children():
		child.queue_free()
	
func character_scan():
	pass
