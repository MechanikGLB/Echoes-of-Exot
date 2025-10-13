extends Node3D

const character_folder = "res://Scenes/Characters/"
const border_img = "res://Assets/textures/UIs/reserve_ico.png"


@onready var button_container = $Control/Panel/MarginContainer/VBoxContainer/Panel/GridContainer
@onready var show_plate = $Scene/Floor/Plate/Show_plate #стенд для модельки персонажа

var current_character_instance

func _ready() -> void:
	if not FileAccess.file_exists(border_img):
		push_error("Запасное изображение не найдено по пути: " + border_img)
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
		if is_instance_valid(child):
			child.queue_free()
	
	# Небольшая задержка для гарантии очистки
	await get_tree().process_frame
	
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
		var character_name = character_file.get_basename()
		var image_path = character_folder.path_join(character_name).path_join(character_name + ".png")
		
		if FileAccess.file_exists(image_path):
			print("использовано основное изображение: ", image_path)
			var image_texture = load(image_path)
			texture_rect.texture = image_texture
		else:
			# Запасное изображение, если основное не найдено
			print("использовано запасное изображение: ", border_img)
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
	
	var character_name = character_file.get_basename()
	var character_scene_path = character_folder.path_join(character_name).path_join(character_file)
	
	# Загружаем для GlobalThings
	var packed_scene = load(character_scene_path) as PackedScene
	if packed_scene:
		GlobalThings.selected_character = packed_scene
		print("Персонаж успешно загружен: ", character_scene_path)
	else:
		push_error("Не удалось загрузить сцену персонажа: " + character_scene_path)
		GlobalThings.selected_character = null
	
	# Показываем модельку
	_show_character_model(character_scene_path, character_name)

# Вынести в отдельный метод для чистоты
func _show_character_model(scene_path: String, character_name: String):
	if current_character_instance:
		current_character_instance.queue_free()
		current_character_instance = null
	
	var character_scene = load(scene_path)
	if character_scene:
		current_character_instance = character_scene.instantiate()
		show_plate.add_child(current_character_instance)
		current_character_instance.position = Vector3.ZERO
		
		_play_character_animation(current_character_instance, character_name)

func _play_character_animation(character_instance: Node, character_name: String):
	var animation_player = character_instance.get_node(character_name + "/AnimationPlayer") as AnimationPlayer
	
	if animation_player:
		print("Найден AnimationPlayer для ", character_name)
		
		var pose_animations = ["pose2", "Pose2", "idle", "Idle"]
		var played = false
		
		for anim_name in pose_animations:
			if animation_player.has_animation(anim_name):
				animation_player.play(anim_name)
				print("Запущена анимация: ", anim_name)
				played = true
				break
		
		if not played:
			print("Не найдено подходящих анимаций для показа")
	else:
		print("AnimationPlayer не найден по пути: ", character_name + "/AnimationPlayer")

func _on_return_pressed() -> void:
	var main_menu_path = "res://Scenes/main_menu.tscn"
	var menu_scene = load(main_menu_path)
	
	if menu_scene:
		get_tree().change_scene_to_packed(menu_scene)
	else:
		push_error("Сцена выбора персонажа не найдена!")


func _on_confirm_pressed() -> void:
	if GlobalThings.packed_map:
		get_tree().change_scene_to_packed(GlobalThings.packed_map)
	else:
		push_error("карта не выбрана") 
