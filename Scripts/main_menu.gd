extends Node3D

@onready var camera_pivot = $CameraPivot
@onready var map_folder = "res://Scenes/Maps/"
@onready var button_container = $Menu/Mapselection/MapChoose/ScrollContainer/GridContainer
@onready var menu = $Menu/MainMenu
@onready var mselection = $Menu/Mapselection
@onready var mapGrid = $Menu/Mapselection/MapChoose/ScrollContainer/GridContainer
@onready var settings =$Menu/Control
# const world = preload("res://Scenes/Maps/main.tscn")

var current_map = null
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
	for child in mapGrid.get_children():
		child.queue_free()
		
		# Получаем список доступных карт
	var available_maps = get_available_maps()
	
	# Создаем кнопки для каждой карты
	for map_name in available_maps:
		var button = Button.new()
		button.text = map_name
		button.custom_minimum_size = Vector2(200, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Подключаем сигнал нажатия
		button.pressed.connect(_on_map_button_pressed.bind(map_name))
		
		# Добавляем кнопку в контейнер
		mapGrid.add_child(button)

	
func _on_map_button_pressed(map_name: String):
	print("Выбрана карта: ", map_name)
	var map_path = "res://Scenes/Maps/%s.tscn" % map_name
	# Асинхронная загрузка с обработкой ошибок
	ResourceLoader.load_threaded_request(map_path)
	
	var progress = []
	var loaded_scene
	
	while true:
		var status = ResourceLoader.load_threaded_get_status(map_path, progress)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				print("Загрузка: ", progress[0] * 100, "%")
				await get_tree().create_timer(0.1).timeout
			ResourceLoader.THREAD_LOAD_LOADED:
				loaded_scene = ResourceLoader.load_threaded_get(map_path)
				break
			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("Ошибка загрузки карты!")
				return
	
	if loaded_scene:
		get_tree().change_scene_to_packed(loaded_scene)
	

func _on_play_pressed() -> void:
	map_refresh()
	menu.visible = false
	mselection.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_return_pressed() -> void:
	mselection.visible = false
	menu.visible = true
	
func _on_refresh_pressed() -> void:
	map_refresh()


func _on_settings_pressed() -> void:
	settings.visible= true
