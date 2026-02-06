@tool
class_name HitBoxManager
extends Node

#TODO: хитбоксы можно создать повторно и они дублируются(исправить)
#TODO: видимость исправить

# Ссылки на редактор
var editor_plugin: EditorPlugin
var editor_interface: EditorInterface

# UI элементы
const UI_SECTION_SEPARATION = 12
const UI_CONTROL_SEPARATION = 8
const UI_GRID_SEPARATION = 4

var dock: Control
var target_node: Node3D
var create_button: Button
var clear_button: Button
var visibility_button: Button
var info_label: Label
var shape_combo: OptionButton
var size_spinbox: SpinBox
var layer_checkboxes: Array[CheckBox] = []
var render_layer_checkboxes: Array[CheckBox] = []
var show_debug_checkbox: CheckBox

# Конфигурация
var shape_options = ["Auto Detect", "Capsule", "Box", "Sphere", "Cylinder", "Convex Polygon"]
var limb_names = ["body", "head", "arm", "leg", "hand", "foot", "chest", "back", 
				  "shoulder", "hip", "thigh", "calf", "forearm", "bicep", "torso", "pelvis"]


#======================================================
# Методы для интерфейса

func create_dock_panel() -> Control:
	print("[HitBox Manager] Creating dock panel...")
	
	# Основной контейнер со скроллом
	var scroll = ScrollContainer.new()
	scroll.name = "HitBoxCreatorScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "HitBoxCreatorMain"
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", UI_SECTION_SEPARATION)
	main_vbox.add_theme_constant_override("margin_left", 8)
	main_vbox.add_theme_constant_override("margin_right", 8)
	main_vbox.add_theme_constant_override("margin_top", 8)
	main_vbox.add_theme_constant_override("margin_bottom", 8)
	
	scroll.add_child(main_vbox)
	
	# Собираем UI из компонентов
	main_vbox.add_child(_create_header_section())
	main_vbox.add_child(_create_separator())
	main_vbox.add_child(_create_info_section())
	main_vbox.add_child(_create_separator())
	main_vbox.add_child(_create_settings_section())
	main_vbox.add_child(_create_separator())
	main_vbox.add_child(_create_visibility_section())
	main_vbox.add_child(_create_separator())
	main_vbox.add_child(_create_advanced_section())
	main_vbox.add_child(_create_separator())
	main_vbox.add_child(_create_actions_section())
	main_vbox.add_child(_create_separator())
	main_vbox.add_child(_create_status_section())
	
	dock = scroll
	print("[HitBox Manager] Dock panel created successfully")
	return scroll

func _create_section_header(title: String, tooltip: String = "") -> Label:
	var header = Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 12)
	if tooltip:
		header.tooltip_text = tooltip
	return header

func _create_labeled_control(label_text: String, control: Control) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UI_CONTROL_SEPARATION)
	
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	hbox.add_child(label)
	hbox.add_child(control)
	
	return hbox

func _create_shape_selector() -> OptionButton:
	shape_combo = OptionButton.new()
	for shape_name in shape_options:
		shape_combo.add_item(shape_name)
	shape_combo.selected = 0
	shape_combo.custom_minimum_size.x = 150
	return shape_combo

func _create_size_selector() -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	
	size_spinbox = SpinBox.new()
	size_spinbox.min_value = 0.0
	size_spinbox.max_value = 5.0
	size_spinbox.step = 0.05
	size_spinbox.value = 0.15
	size_spinbox.custom_minimum_size.x = 80
	
	var unit_label = Label.new()
	unit_label.text = "м"
	
	hbox.add_child(size_spinbox)
	hbox.add_child(unit_label)
	
	return hbox

func _create_layers_grid() -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", UI_GRID_SEPARATION)
	grid.add_theme_constant_override("v_separation", UI_GRID_SEPARATION)
	grid.custom_minimum_size = Vector2(10, 120)
	
	layer_checkboxes.clear()
	for i in range(20): 
		
		var checkbox = CheckBox.new()
		checkbox.text = str(i + 1)
		checkbox.custom_minimum_size.x = 32
		checkbox.custom_minimum_size.y = 24
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		if i == 2:  # Слой 3 по умолчанию
			checkbox.button_pressed = true
		
		layer_checkboxes.append(checkbox)
		grid.add_child(checkbox)
		
	return grid

func _create_separator() -> HSeparator:
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", UI_SECTION_SEPARATION)
	return separator

func _create_header_section() -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UI_CONTROL_SEPARATION)
	
	var icon = Label.new()
	icon.add_theme_font_size_override("font_size", 16)
	
	var title = Label.new()
	title.text = "HITBOX CREATOR"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	hbox.add_child(icon)
	hbox.add_child(title)
	
	return hbox

func _create_info_section() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UI_CONTROL_SEPARATION)
	
	var header = _create_section_header(" Формат имен узлов", "Правила именования узлов для автоматического определения")
	
	var info_text = """• body_1, body_2... (хитбокс на основе меша)
• limb_1, limb_2... (хитбокс между узлами)
• *_v (видимые игроку узлы)
• weapon, camera, light (игнорируются)"""
	
	var label = Label.new()
	label.text = info_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	
	vbox.add_child(header)
	vbox.add_child(label)
	
	return vbox

func _create_settings_section() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UI_CONTROL_SEPARATION)
	
	var header = _create_section_header("⚙️ Основные настройки", "Настройки создания коллизий")
	vbox.add_child(header)
	
	# Форма коллизии
	var shape_row = _create_labeled_control("Форма:", _create_shape_selector())
	vbox.add_child(shape_row)
	
	# Дополнительный размер
	var size_row = _create_labeled_control("Доп. размер:", _create_size_selector())
	vbox.add_child(size_row)
	
	# Слои коллизии
	var layers_label = Label.new()
	layers_label.text = "Слои коллизии:"
	vbox.add_child(layers_label)
	
	vbox.add_child(_create_layers_grid())
	
	return vbox

func _create_advanced_section() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UI_CONTROL_SEPARATION)
	
	var header = _create_section_header("🔧 Дополнительно", "Расширенные настройки")
	vbox.add_child(header)
	
	show_debug_checkbox = CheckBox.new()
	show_debug_checkbox.text = " Показать отладочные меши"
	show_debug_checkbox.button_pressed = true
	show_debug_checkbox.tooltip_text = "Показывать визуальные меши для коллизий"
	
	vbox.add_child(show_debug_checkbox)
	
	return vbox

func _create_actions_section() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UI_CONTROL_SEPARATION)
	
	var buttons_row = HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", UI_GRID_SEPARATION)
	
	create_button = Button.new()
	create_button.text = "Создать"
	create_button.pressed.connect(_create_hitboxes_and_setup)
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_button.custom_minimum_size.y = 32
	
	clear_button = Button.new()
	clear_button.text = "Очистить"
	clear_button.pressed.connect(_clear_hitboxes)
	clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_button.custom_minimum_size.y = 32
	
	visibility_button = Button.new()
	visibility_button.text = "Видимость"
	visibility_button.pressed.connect(_toggle_preview_visibility)
	visibility_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visibility_button.custom_minimum_size.y = 32
	
	buttons_row.add_child(create_button)
	buttons_row.add_child(clear_button)
	buttons_row.add_child(visibility_button)
	
	vbox.add_child(buttons_row)
	
	return vbox

func _create_status_section() -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UI_CONTROL_SEPARATION)
	hbox.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	
	var status_bg = StyleBoxFlat.new()
	status_bg.bg_color = Color(0.1, 0.1, 0.1, 0.3)
	hbox.add_theme_stylebox_override("panel", status_bg)
	
	var status_icon = Label.new()
	status_icon.text = "ℹ️"
	
	info_label = Label.new()
	info_label.text = "Выберите корневой узел персонажа"
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.add_theme_font_size_override("font_size", 11)
	
	hbox.add_child(status_icon)
	hbox.add_child(info_label)
	
	return hbox

func _create_visibility_section() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UI_CONTROL_SEPARATION)
	
	var header = _create_section_header("👁️ Видимость (Render Layers)", "Настройки видимости для игрока")
	vbox.add_child(header)
	
	# Описание
	var desc_label = Label.new()
	desc_label.text = "Ноды с _v получат выбранные слои отрисовки"
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_label)
	
	# Сетка слоёв отрисовки
	var layers_label = Label.new()
	layers_label.text = "Слои отрисовки для _v нод:"
	vbox.add_child(layers_label)
	
	vbox.add_child(_create_render_layers_grid())
	
	return vbox

func _create_render_layers_grid() -> GridContainer:
	"""Создает сетку для выбора слоёв отрисовки (видимости)"""
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", UI_GRID_SEPARATION)
	grid.add_theme_constant_override("v_separation", UI_GRID_SEPARATION)
	grid.custom_minimum_size = Vector2(10, 120)
	
	render_layer_checkboxes.clear()
	for i in range(20):  # Godot 4.x имеет 20 слоёв рендера
		var checkbox = CheckBox.new()
		checkbox.text = str(i + 1)
		checkbox.custom_minimum_size.x = 32
		checkbox.custom_minimum_size.y = 24
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# По умолчанию включаем первый слой для видимых нод
		if i == 0:  # Слой 1 по умолчанию для видимых мешей
			checkbox.button_pressed = true
		
		render_layer_checkboxes.append(checkbox)
		grid.add_child(checkbox)
		
	return grid

#======================================================
# Дальше пойдут методы для хитбоксов

func _on_selection_changed():
	print("[HitBox Manager] Selection changed")
	_update_info()

func _update_info():
	var selection = editor_interface.get_selection().get_selected_nodes()
	print("[HitBox Manager] Selection count: ", selection.size())
	
	if selection.size() > 0:
		target_node = selection[0] as Node3D
		if target_node:
			info_label.text = "Selected: %s" % target_node.name
			print("[HitBox Manager] Selected node: ", target_node.name)
			
			var hitbox_count = 0
			var v_nodes_count = 0
			
			for child in HitBoxUtils.get_all_children(target_node):
				if child is Node3D:
					if "HitBox" in child.name:
						hitbox_count += 1
					if "_v" in child.name:
						v_nodes_count += 1
			
			var info_parts = []
			if hitbox_count > 0:
				info_parts.append("%d hitboxes" % hitbox_count)
			if v_nodes_count > 0:
				info_parts.append("%d _v nodes" % v_nodes_count)
			
			if info_parts.size() > 0:
				info_label.text += " (" + ", ".join(info_parts) + ")"
	else:
		target_node = null
		info_label.text = "Select a character root node"
		print("[HitBox Manager] No node selected")

func _create_hitboxes_and_setup():
	print("[HitBox Manager] Creating hitboxes...")
	
	if not target_node:
		printerr("[HitBox Manager] No target node selected!")
		info_label.text = "ERROR: Select a character root node first"
		return
	
	var collision_mask = _get_selected_collision_layers()
	if collision_mask == 0:
		info_label.text = "Select at least one collision layer"
		return
	
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		printerr("[HitBox Manager] No scene root!")
		info_label.text = "ERROR: No scene opened"
		return
	
	print("[HitBox Manager] Scene root: ", scene_root.name)
	print("[HitBox Manager] Target node: ", target_node.name)
	print("[HitBox Manager] Collision mask: ", collision_mask)
	
	var all_nodes = HitBoxUtils.get_all_children(target_node)
	print("[HitBox Manager] Total children: ", all_nodes.size())
	
	var nodes_3d = []
	for node in all_nodes:
		if node is Node3D:
			nodes_3d.append(node)
	
	print("[HitBox Manager] 3D nodes: ", nodes_3d.size())
	
	# Настраиваем видимость через слои отрисовки
	var visibility_changes = _setup_visibility_via_layers(nodes_3d)
	print("[HitBox Manager] Visibility changes via layers: ", visibility_changes)
	
	# Создаем хитбоксы
	var hitboxes_created = _create_limb_hitboxes(nodes_3d, collision_mask, scene_root)
	print("[HitBox Manager] Hitboxes created: ", hitboxes_created)
	
	info_label.text = "Setup complete: %d hitboxes created, %d visibility changes" % [
		hitboxes_created,
		visibility_changes
	]
	
	# Обновляем сцену
	editor_interface.get_resource_filesystem().scan()
	editor_interface.save_scene()
	
	print("[HitBox Manager] Done!")

func _create_limb_hitboxes(nodes: Array, collision_mask: int, scene_root: Node) -> int:
	var created_count = 0
	var limb_groups = {}
	var body_meshes = []
	
	# Группируем ноды
	for node in nodes:
		if not node is Node3D:
			continue
		
		if HitBoxUtils.should_skip_node(node.name):
			print("[HitBox Manager] Skipping node: ", node.name)
			continue
		
		var limb_data = HitBoxUtils.parse_limb_name(node.name, limb_names)
		if not limb_data.is_empty():
			var limb_name = limb_data["limb_name"]
			var limb_number = limb_data["limb_number"]
			var is_body = limb_data.get("is_body", false)
			
			if is_body and node is MeshInstance3D:
				body_meshes.append({
					"node": node,
					"number": limb_number, 
					"name": node.name
				})
				print("[HitBox Manager] Found body mesh: ", node.name)
			else:
				if not limb_groups.has(limb_name):
					limb_groups[limb_name] = {}
			
				limb_groups[limb_name][limb_number] = node
				print("[HitBox Manager] Found limb: ", limb_name, "_", limb_number, " (", node.name, ")")
	
	print("[HitBox Manager] Limb groups found: ", limb_groups.size())
	print("[HitBox Manager] Body meshes found: ", body_meshes.size())
	
	if limb_groups.is_empty():
		info_label.text = "No limb nodes found"
		return 0
	print("___________________________________________________________")
	
	for body_data in body_meshes:
		var body_node = body_data["node"]
		
		print("[HitBox Manager] Creating hitbox for body mesh: ", body_node.name)
		
		if _create_body_hitbox(body_node, collision_mask, scene_root):
			created_count += 1
	
	# Создаем хитбоксы
	for limb_name in limb_groups:
		var limb_nodes = limb_groups[limb_name]
		var numbers = []
		
		for number in limb_nodes.keys():
			numbers.append(number)
		numbers.sort()
		
		print("[HitBox Manager] Creating hitboxes for ", limb_name, ": ", numbers)
		
		for i in range(len(numbers) - 1):
			var node1 = limb_nodes[numbers[i]]
			var node2 = limb_nodes[numbers[i + 1]]
			
			print("[HitBox Manager] Creating hitbox between ", node1.name, " and ", node2.name)
			
			if _create_hitbox_between_nodes(
				limb_name + "_" + str(numbers[i]) + "_to_" + str(numbers[i + 1]),
				node1,
				node2,
				collision_mask,
				scene_root
			):
				created_count += 1
				print("[HitBox Manager] Hitbox created successfully")
	
	return created_count

func _create_hitbox_between_nodes(hitbox_name: String, node1: Node3D, node2: Node3D, 
								collision_mask: int, scene_root: Node) -> bool:
	if not node1 or not node2:
		printerr("[HitBox Manager] Invalid nodes for hitbox")
		return false
	
	print("[HitBox Manager] Creating hitbox: ", hitbox_name)
	
	# Создаем Area3D
	var area = Area3D.new()
	area.name = hitbox_name + "_HitBox"
	area.collision_layer = collision_mask
	area.collision_mask = 0
	
	# Создаем CollisionShape
	var shape_node = CollisionShape3D.new()
	shape_node.name = "CollisionShape"
	
	# Создаем форму коллизии
	var collision_shape = _create_collision_shape_between_nodes(node1, node2)
	if not collision_shape:
		printerr("[HitBox Manager] Failed to create collision shape")
		area.queue_free()
		return false
	
	shape_node.shape = collision_shape
	
	# Позиционируем посередине между нодами
	var center = (node1.global_position + node2.global_position) * 0.5
	area.position = node1.to_local(center) # Локальная позиция относительно родителя
	
	# Ориентируем по направлению
	var local_direction = node1.to_local(node2.global_position) - node1.to_local(node1.global_position)
	if local_direction.length() > 0.001:
		area.basis = Basis.looking_at(local_direction.normalized(), Vector3.UP)
		var shape_type = shape_combo.get_item_text(shape_combo.selected)
		
		if shape_type == "Capsule" or shape_type == "Auto Detect" or shape_type == "Cylinder":
			var rotation_correction = Basis.from_euler(Vector3(PI/2, 0, 0))
			area.basis = area.basis * rotation_correction
	
	# Добавляем в иерархию - сначала добавляем в сцену, потом устанавливаем детей
	area.add_child(shape_node)
	
	# Добавляем к целевому узлу
	node1.add_child(area)
	
	# ТОЛЬКО ПОСЛЕ ДОБАВЛЕНИЯ В СЦЕНУ устанавливаем владельцев!
	if Engine.is_editor_hint():
		# Устанавливаем владельцев правильно
		_set_node_owner_recursive(area, scene_root)
	
	print("[HitBox Manager] Added hitbox to scene: ", area.name)
	
	# Добавляем скрипт для отладки
	_add_debug_script(area)
	
	return true

func _set_node_owner_recursive(node: Node, owner: Node):
	"""Рекурсивно устанавливает владельца для ноды и всех ее детей"""
	if not node or not owner:
		return
	
	node.owner = owner
	for child in node.get_children():
		_set_node_owner_recursive(child, owner)

func _create_collision_shape_between_nodes(node1: Node3D, node2: Node3D) -> Shape3D:
	var shape_type = shape_combo.get_item_text(shape_combo.selected)
	var distance = node1.global_position.distance_to(node2.global_position)
	var extra_size = size_spinbox.value
	
	distance = max(distance, 0.01)
	
	print("[HitBox Manager] Creating shape: ", shape_type, ", distance: ", distance, ", extra: ", extra_size)
	
	match shape_type:
		"Auto Detect", "Capsule":
			var shape = CapsuleShape3D.new()
			shape.height = distance + extra_size * 2
			shape.radius = extra_size
			print("[HitBox Manager] Created capsule: height=", shape.height, ", radius=", shape.radius)
			return shape
		"Box":
			var shape = BoxShape3D.new()
			shape.size = Vector3(extra_size * 2, extra_size * 2, distance + extra_size * 2)
			print("[HitBox Manager] Created box: size=", shape.size)
			return shape
		"Sphere":
			var shape = SphereShape3D.new()
			shape.radius = distance * 0.5 + extra_size
			print("[HitBox Manager] Created sphere: radius=", shape.radius)
			return shape
		"Cylinder":
			var shape = CylinderShape3D.new()
			shape.height = distance + extra_size * 2
			shape.radius = extra_size
			print("[HitBox Manager] Created cylinder: height=", shape.height, ", radius=", shape.radius)
			return shape
		"Convex Polygon":
			var shape = BoxShape3D.new()
			shape.size = Vector3(extra_size * 2, extra_size * 2, distance + extra_size * 2)
			print("[HitBox Manager] Created box (convex fallback): size=", shape.size)
			return shape
	
	printerr("[HitBox Manager] Unknown shape type: ", shape_type)
	return null

func _add_debug_script(area: Area3D):
	if not show_debug_checkbox.button_pressed:
		return
	
	print("[HitBox Manager] Adding debug script to ", area.name)
	
	var debug_script = GDScript.new()
	debug_script.source_code = """
@tool
extends Area3D

@export var debug_color: Color = Color(0, 1, 0, 0.3)
@export var show_debug: bool = true

var debug_mesh: MeshInstance3D

func _ready():
	if Engine.is_editor_hint():
		_create_debug_mesh()

func _create_debug_mesh():
	var shape_node = get_node_or_null("CollisionShape")
	if not shape_node or not shape_node.shape:
		return
	
	debug_mesh = MeshInstance3D.new()
	debug_mesh.name = "DebugMesh"
	
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = debug_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var shape = shape_node.shape
	
	if shape is CapsuleShape3D:
		var capsule = CapsuleMesh.new()
		capsule.radius = shape.radius
		capsule.height = shape.height
		capsule.material = material
		debug_mesh.mesh = capsule
	elif shape is BoxShape3D:
		var box = BoxMesh.new()
		box.size = shape.size
		box.material = material
		debug_mesh.mesh = box
	elif shape is SphereShape3D:
		var sphere = SphereMesh.new()
		sphere.radius = shape.radius
		sphere.height = shape.radius * 2
		sphere.material = material
		debug_mesh.mesh = sphere
	elif shape is CylinderShape3D:
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = shape.radius
		cylinder.bottom_radius = shape.radius
		cylinder.height = shape.height
		cylinder.material = material
		debug_mesh.mesh = cylinder
	
	add_child(debug_mesh)
	
	if get_tree().edited_scene_root:
		debug_mesh.owner = get_tree().edited_scene_root
	
	debug_mesh.visible = show_debug

func _process(_delta):
	if Engine.is_editor_hint() and debug_mesh:
		debug_mesh.visible = show_debug
"""
	
	var result = debug_script.reload()
	if result == OK:
		area.set_script(debug_script)
		print("[HitBox Manager] Debug script added")
	else:
		printerr("[HitBox Manager] Failed to compile debug script")

func _get_selected_collision_layers() -> int:
	var mask = 0
	for i in range(layer_checkboxes.size()):
		if layer_checkboxes[i].button_pressed:
			mask |= 1 << i
	print("[HitBox Manager] Selected layers mask: ", mask)
	return mask

func _clear_hitboxes():
	print("[HitBox Manager] Clearing hitboxes...")
	
	if not target_node:
		printerr("[HitBox Manager] No target node selected!")
		return
	
	var hitboxes_to_remove = []
	
	# Находим все хитбоксы
	for child in HitBoxUtils.get_all_children(target_node):
		if child is Node3D and "HitBox" in child.name:
			hitboxes_to_remove.append(child)
			print("[HitBox Manager] Found hitbox to remove: ", child.name)
	
	if hitboxes_to_remove.is_empty():
		info_label.text = "No hitboxes found"
		print("[HitBox Manager] No hitboxes found")
		return
	
	# Удаляем хитбоксы
	for hitbox in hitboxes_to_remove:
		var parent = hitbox.get_parent()
		if parent:
			parent.remove_child(hitbox)
			hitbox.queue_free()
			print("[HitBox Manager] Removed hitbox: ", hitbox.name)
	
	info_label.text = "Removed %d hitbox(es)" % hitboxes_to_remove.size()
	
	# Обновляем сцену
	editor_interface.get_resource_filesystem().scan()
	editor_interface.save_scene()
	
	print("[HitBox Manager] Hitboxes cleared")

func _create_body_hitbox(body_node: MeshInstance3D, collision_mask: int, scene_root: Node) -> bool:
	"""Создает хитбокс для body MeshInstance3D"""
	
	if not body_node.mesh:
		print("[HitBox Manager] Body mesh is empty: ", body_node.name)
		return false
	
	print("[HitBox Manager] Creating hitbox for body: ", body_node.name)
	
	# Создаем Area3D
	var area = Area3D.new()
	area.name = body_node.name + "_HitBox"
	area.collision_layer = collision_mask
	area.collision_mask = 0
	
	# Создаем CollisionShape
	var shape_node = CollisionShape3D.new()
	shape_node.name = "CollisionShape"
	
	# Создаем форму из меша
	var collision_shape = _create_collision_shape_from_mesh(body_node.mesh)
	if not collision_shape:
		print("[HitBox Manager] Failed to create collision shape from mesh")
		area.queue_free()
		return false
	
	shape_node.shape = collision_shape
	area.add_child(shape_node)
	
	# Для body меша хитбокс должен быть в том же месте
	# Но body_node уже может быть MeshInstance3D, поэтому:
	if body_node.get_parent():
		# Добавляем к родителю body_node
		body_node.get_parent().add_child(area)
		# Позиционируем так же как body_node
		area.position = body_node.position
		area.basis = body_node.basis
	else:
		# На всякий случай
		body_node.add_child(area)
		area.position = Vector3.ZERO
		area.basis = Basis()
	
	# Устанавливаем владельца
	if Engine.is_editor_hint():
		_set_node_owner_recursive(area, scene_root)
	
	# Добавляем скрипт для отладки
	_add_debug_script(area)
	
	print("[HitBox Manager] Created body hitbox: ", area.name)
	return true

func _create_collision_shape_from_mesh(mesh: Mesh) -> Shape3D:
	"""Создает форму коллизии из меша для body узлов"""
	
	var extra_size = size_spinbox.value
	
	print("[HitBox Manager] Creating collision shape from mesh for body")
	print("[HitBox Manager] Mesh vertices: ", mesh.get_faces().size() / 3 if mesh.get_faces() else 0)
	
	# Вариант 1: Выпуклая оболочка (convex hull)
	var convex_shape = mesh.create_convex_shape()
	if convex_shape:
		print("[HitBox Manager] Created convex shape for body")
		return convex_shape
	
	# Вариант 2: Триангулированная форма (trimesh)
	var trimesh_shape = mesh.create_trimesh_shape()
	if trimesh_shape:
		print("[HitBox Manager] Created trimesh shape for body")
		return trimesh_shape
	
	# Вариант 3: Запасной вариант - простой бокс по AABB
	printerr("[HitBox Manager] Failed to create convex/trimesh shape, using fallback box")
	var aabb = mesh.get_aabb()
	var fallback_shape = BoxShape3D.new()
	fallback_shape.size = aabb.size + Vector3.ONE * extra_size * 2
	print("[HitBox Manager] Created fallback box: size=", fallback_shape.size)
	
	return fallback_shape

func _setup_visibility_via_layers(nodes: Array) -> int:
	var changes = 0
	var mask = _get_selected_render_layers()
	
	for node in nodes:
		if node is MeshInstance3D:
			if "_v" in node.name:
				if node.layers != mask:
					node.layers = mask
					node.visible = true
					changes += 1
			elif node.layers != 0:
				node.layers = 0
				node.visible = true
				changes += 1
	
	return changes

func _get_selected_render_layers() -> int:
	"""Возвращает битовую маску выбранных слоёв отрисовки"""
	var mask = 0
	for i in range(render_layer_checkboxes.size()):
		if render_layer_checkboxes[i].button_pressed:
			mask |= 1 << i
	print("[HitBox Manager] Selected render layers mask: ", mask)
	return mask

func _toggle_preview_visibility():
	if not target_node:
		return
	
	var mask = _get_selected_render_layers()
	var v_meshes = 0
	
	for child in HitBoxUtils.get_all_children(target_node):
		if child is MeshInstance3D:
			if "_v" in child.name:
				child.layers = mask
				child.visible = true
				v_meshes += 1
			else:
				child.layers = 0
				child.visible = true
	
	if v_meshes > 0:
		info_label.text = "%d _v meshes set to layers %s" % [v_meshes, _render_layers_to_string(mask)]
	else:
		info_label.text = "No _v meshes found"

func _render_layers_to_string(mask: int) -> String:
	"""Конвертирует битовую маску слоёв в строку вида '1, 3, 4'"""
	var layers = []
	for i in range(20):
		if mask & (1 << i):
			layers.append(str(i + 1))
	return ", ".join(layers) if layers.size() > 0 else "none"
