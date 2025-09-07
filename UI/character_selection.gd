extends Node3D

@onready var character_folder = "res://Scenes/Characters/"
@onready var button_container = $Control/Panel/MarginContainer/VBoxContainer/Panel/GridContainer
@onready var show_plate = $Scene/Floor/Plate/Show_plate #стенд для модельки персонажа
@onready var border_img = "res://Assets/textures/IMGs/Иконка аугментации.png"
@onready var character_contents

var current_character_instance
var character_model

func _ready() -> void:
	char_refresh()


func get_available_chars() -> Array:
	var characters = []
	var dir = DirAccess.open(character_folder)
	if dir:
		dir.list_dir_begin()
		var folder_name = dir.get_next()
		while folder_name != "":
			if dir.current_is_dir() and folder_name != "." and folder_name != "..":
				# Проверяем существует ли файл с именем папки + .tscn
				var tscn_path = character_folder.path_join(folder_name).path_join(folder_name + ".tscn")
				if FileAccess.file_exists(tscn_path):
					characters.append(folder_name + ".tscn")
			
			folder_name = dir.get_next()
		
		dir.list_dir_end()
	
	return characters

func char_refresh():
	# Очищаем старые кнопки
	for child in button_container.get_children():
		child.queue_free()
	
	# Получаем список доступных персонажей
	var available_characters = get_available_chars()
	
	# Создаем кнопки для каждого персонажа
	for character_file in available_characters:
		# Создаем контейнер для кнопки с картинкой
		var button_container_node = VBoxContainer.new()
		button_container_node.custom_minimum_size = Vector2(200, 60)
		
		# Создаем текстуру для изображения персонажа
		var texture_rect = TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(100, 100)
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		
		# Загружаем изображение персонажа (предполагаем, что оно в той же папке)
		var character_name = character_file.trim_suffix(".tscn")
		var character_folder_path = character_folder.path_join(character_name)
		var image_path = character_folder_path.path_join(character_name + ".png")
		
		if FileAccess.file_exists(image_path):
			var image_texture = load(image_path)
			texture_rect.texture = image_texture
		else:
			# Запасное изображение, если основное не найдено
			texture_rect.texture = load(border_img)
		
		
		# Создаем кнопку
		var button = Button.new()
		button.text = character_name
		button.custom_minimum_size = Vector2(100, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Подключаем сигнал нажатия
		button.pressed.connect(_on_character_button_pressed.bind(character_file))
		
		# Добавляем элементы в контейнер
		button_container_node.add_child(texture_rect)
		button_container_node.add_child(button)
		
		# Добавляем контейнер в основной контейнер
		button_container.add_child(button_container_node)

# Функция обработки нажатия на кнопку персонажа
func _on_character_button_pressed(character_file: String):
	print("Выбран персонаж: ", character_file)
	
	if current_character_instance:
		current_character_instance.queue_free()
		current_character_instance = null
	
	var character_name = character_file.trim_suffix(".tscn")
	var character_scene_path = character_folder.path_join(character_name).path_join(character_file)
	var character_scene = load(character_scene_path)
	
	if character_scene:
		current_character_instance = character_scene.instantiate()
		show_plate.add_child(current_character_instance)
		current_character_instance.position = Vector3.ZERO
		
		# Прямой доступ - предполагаем, что структура: CharacterName/AnimationPlayer
		var animation_player = current_character_instance.get_node(character_name + "/AnimationPlayer") as AnimationPlayer
		
		if animation_player:
			print("Найден AnimationPlayer для ", character_name)
			
			if animation_player.has_animation("pose2"):
				animation_player.play("pose2")
				print("Запущена анимация pose2")
			if animation_player.has_animation("Pose2"):
				animation_player.play("Pose2")
				print("Запущена анимация pose2")
			else:
				print("Анимация pose2 не найдена")
		else:
			print("AnimationPlayer не найден по пути: ", character_name + "/AnimationPlayer")
	else:
		print("Ошибка загрузки сцены")
