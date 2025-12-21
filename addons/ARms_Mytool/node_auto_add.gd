@tool
extends EditorPlugin
class_name NodeAutoAddPlugin

var button: Button
var dock: Control


func _enter_tree() -> void:
	print("NodeAutoAddPlugin: Loading...")
	
	# Создаем док-панель с настройками
	create_dock()
	
	print("NodeAutoAddPlugin: Loaded successfully")

func create_dock() -> void:
	# Создаем контейнер
	dock = VBoxContainer.new()
	dock.name = "NodeAutoAddDock"
	
	# Заголовок
	var label = Label.new()
	label.text = "Node Auto-Add"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dock.add_child(label)
	
	# Кнопка сканирования
	button = Button.new()
	button.text = "Scan and Add Nodes"
	button.pressed.connect(_on_scan_pressed)
	dock.add_child(button)
	
	# Поле для фильтра по имени
	var name_filter_label = Label.new()
	name_filter_label.text = "Name contains:"
	dock.add_child(name_filter_label)
	
	var name_filter = LineEdit.new()
	name_filter.placeholder_text = "enemy, player, etc."
	name_filter.name = "NameFilter"
	dock.add_child(name_filter)
	
	# Тип узла для поиска
	var type_label = Label.new()
	type_label.text = "Node Type:"
	dock.add_child(type_label)
	
	var type_option = OptionButton.new()
	type_option.add_item("Sprite2D")
	type_option.add_item("Node2D")
	type_option.add_item("MeshInstance3D")
	type_option.add_item("All Types")
	type_option.name = "TypeOption"
	dock.add_child(type_option)
	
	# Тип узла для добавления
	var add_type_label = Label.new()
	add_type_label.text = "Add Node Type:"
	dock.add_child(add_type_label)
	
	var add_type_option = OptionButton.new()
	add_type_option.add_item("Area2D")
	add_type_option.add_item("CollisionShape2D")
	add_type_option.add_item("AnimationPlayer")
	add_type_option.add_item("Timer")
	add_type_option.name = "AddTypeOption"
	dock.add_child(add_type_option)
	
	# Отступ
	dock.add_child(Control.new())
	
	# Добавляем док в интерфейс
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	
	print("NodeAutoAddPlugin: Dock created")

func _exit_tree() -> void:
	# Удаляем док при выгрузке плагина
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
	
	print("NodeAutoAddPlugin: Unloaded")

func _on_scan_pressed() -> void:
	print("NodeAutoAddPlugin: Starting scan...")
	
	# Получаем интерфейс редактора
	var editor_interface := get_editor_interface()
	var scene_root := editor_interface.get_edited_scene_root()
	
	if not scene_root:
		push_warning("No scene is currently open!")
		print("NodeAutoAddPlugin: No scene open")
		return
	
	print("NodeAutoAddPlugin: Scanning scene: ", scene_root.name)
	
	# Получаем значения из UI
	var name_filter: LineEdit = dock.get_node("NameFilter")
	var type_option: OptionButton = dock.get_node("TypeOption")
	var add_type_option: OptionButton = dock.get_node("AddTypeOption")
	
	var filter_text: String = name_filter.text
	var node_type: String = type_option.get_item_text(type_option.selected)
	var add_node_type: String = add_type_option.get_item_text(add_type_option.selected)
	
	# Сканируем сцену
	var modified_count := scan_and_modify_scene(
		scene_root, 
		filter_text,
		node_type,
		add_node_type
	)
	
	# Обновляем инспектор
	editor_interface.inspect_object(scene_root)
	
	# Показываем результат
	print("NodeAutoAddPlugin: Modified ", modified_count, " nodes")
	
	if modified_count > 0:
		# Сохраняем сцену
		var scene_path := scene_root.scene_file_path
		if scene_path:
			print("NodeAutoAddPlugin: Saving scene...")
			editor_interface.save_scene()
	
	# Уведомление в редакторе
	get_editor_interface().get_base_control().show_notification(
		"Modified " + str(modified_count) + " nodes",
		2
	)

func scan_and_modify_scene(
	node: Node, 
	name_filter: String,
	search_type: String,
	add_type: String
) -> int:
	var count := 0
	
	# Проверяем текущий узел
	if should_process_node(node, name_filter, search_type):
		print("NodeAutoAddPlugin: Processing node: ", node.name)
		
		# Добавляем нужный узел
		if add_node_to(node, add_type):
			count += 1
	
	# Рекурсивно обходим детей
	for child in node.get_children():
		count += scan_and_modify_scene(child, name_filter, search_type, add_type)
	
	return count

func should_process_node(node: Node, name_filter: String, search_type: String) -> bool:
	# Проверяем фильтр по типу
	if search_type != "All Types":
		if node.get_class() != search_type:
			return false
	
	# Проверяем фильтр по имени
	if name_filter and name_filter != "":
		if name_filter.to_lower() not in node.name.to_lower():
			return false
	
	# Дополнительные проверки
	if node.name.begins_with("_"):
		return false
	
	return true

func add_node_to(parent: Node, node_type: String) -> bool:
	# Проверяем, нет ли уже такого узла
	for child in parent.get_children():
		if child.get_class() == node_type:
			print("NodeAutoAddPlugin: Node already has ", node_type, ", skipping")
			return false
	
	var new_node: Node
	
	# Создаем узел в зависимости от типа
	match node_type:
		"Area2D":
			new_node = Area2D.new()
			new_node.name = parent.name + "Area"
			
			# Добавляем CollisionShape2D по умолчанию
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 32.0
			shape.shape = circle
			new_node.add_child(shape)
			
			# Устанавливаем owner для дочернего узла
			shape.owner = get_editor_interface().get_edited_scene_root()
			
		"CollisionShape2D":
			new_node = CollisionShape2D.new()
			new_node.name = parent.name + "Collision"
			
			# Настраиваем форму
			if parent is Sprite2D:
				var rect := RectangleShape2D.new()
				if parent.texture:
					rect.size = parent.texture.get_size()
				else:
					rect.size = Vector2(64, 64)
				new_node.shape = rect
			else:
				var circle := CircleShape2D.new()
				circle.radius = 32.0
				new_node.shape = circle
				
		"AnimationPlayer":
			new_node = AnimationPlayer.new()
			new_node.name = parent.name + "Animations"
			
		"Timer":
			new_node = Timer.new()
			new_node.name = parent.name + "Timer"
			new_node.wait_time = 1.0
			new_node.autostart = false
			
		_:
			print("NodeAutoAddPlugin: Unknown node type: ", node_type)
			return false
	
	if new_node:
		# Добавляем узел
		parent.add_child(new_node)
		
		# Устанавливаем owner (ВАЖНО для сохранения в сцене!)
		new_node.owner = get_editor_interface().get_edited_scene_root()
		
		# Перемещаем в нужное место в иерархии
		move_node_in_hierarchy(new_node)
		
		print("NodeAutoAddPlugin: Added ", node_type, " to ", parent.name)
		return true
	
	return false

func move_node_in_hierarchy(node: Node) -> void:
	# Пытаемся переместить узел вверх для удобства
	var parent = node.get_parent()
	if parent and parent.get_child_count() > 1:
		parent.move_child(node, 0)

# Функция для ручного вызова из консоли
func manual_scan() -> void:
	print("Manual scan called")
	_on_scan_pressed()
