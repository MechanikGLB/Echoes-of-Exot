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

	
# Упрощенный вариант (рекомендуется)
func _on_map_button_pressed(map_name: String):
	print("Выбрана карта: ", map_name)
	var map_path = map_folder + map_name + ".tscn"
	
	# Загружаем и сохраняем карту в глобальные переменные
	GlobalThings.selected_map = map_name + ".tscn"
	GlobalThings.packed_map = load(map_path)
	
	if GlobalThings.packed_map:
		print("Карта '", map_name, "' загружена в GlobalThings")
		
		# Переключаемся на сцену выбора персонажа
		_switch_to_character_selection()
	else:
		push_error("Ошибка загрузки карты: " + map_path)
		_show_load_error(map_path)

func _switch_to_character_selection():
	var character_selection_path = "res://UI/character_selection.tscn"
	var character_scene = load(character_selection_path)
	
	if character_scene:
		get_tree().change_scene_to_packed(character_scene)
	else:
		# Fallback: попробуем альтернативный путь
		character_selection_path = "res://Scenes/character_selection.tscn"
		character_scene = load(character_selection_path)
		
		if character_scene:
			get_tree().change_scene_to_packed(character_scene)
		else:
			push_error("Сцена выбора персонажа не найдена!")
			# Можно показать сообщение об ошибке или вернуться в меню
			show_menu()
	
func _show_load_error(map_path: String):
	print("Не удалось загрузить карту: ", map_path)
	
func show_menu():
	menu.visible = true
	mselection.visible = false
	settings.visible = false

func show_map_selection():
	menu.visible = false
	mselection.visible = true
	settings.visible = false

func show_settings():
	menu.visible = false
	mselection.visible = false
	settings.visible = true


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
