@tool
class_name HitBoxManager
extends Node

# Ссылки на редактор
var editor_plugin: EditorPlugin
var editor_interface: EditorInterface

# UI элементы
var dock: Control
var target_node: Node3D
var create_button: Button
var clear_button: Button
var visibility_button: Button
var info_label: Label
var shape_combo: OptionButton
var size_spinbox: SpinBox
var layer_checkboxes: Array[CheckBox] = []
var show_debug_checkbox: CheckBox

# Конфигурация
var shape_options = ["Auto Detect", "Capsule", "Box", "Sphere", "Cylinder", "Convex Polygon"]
var limb_names = ["body", "head", "arm", "leg", "hand", "foot", "chest", "back", 
				  "shoulder", "hip", "thigh", "calf", "forearm", "bicep", "torso", "pelvis"]

func create_dock_panel() -> Control:
	print("[HitBox Manager] Creating dock panel...")
	
	var vbox = VBoxContainer.new()
	vbox.name = "HitBoxCreatorDock"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	
	# Заголовок
	var title = Label.new()
	title.text = "Character HitBox Setup"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Информация о формате имен
	var format_info = Label.new()
	format_info.text = "Node naming rules:\n• body_1, body_2... (hitbox between them)\n• arm_1_v, arm_2_v (visible to player)\n• head_v (visible, no hitbox)\n• weapon, camera (ignored)"
	format_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	format_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	format_info.add_theme_font_size_override("font_size", 10)
	vbox.add_child(format_info)
	
	vbox.add_child(HSeparator.new())
	
	# Выбор формы
	var shape_label = Label.new()
	shape_label.text = "Collision Shape:"
	vbox.add_child(shape_label)
	
	shape_combo = OptionButton.new()
	for shape_name in shape_options:
		shape_combo.add_item(shape_name)
	shape_combo.selected = 0
	shape_combo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(shape_combo)
	
	# Размер
	var size_label = Label.new()
	size_label.text = "Extra Size:"
	vbox.add_child(size_label)
	
	size_spinbox = SpinBox.new()
	size_spinbox.min_value = 0.0
	size_spinbox.max_value = 5.0
	size_spinbox.step = 0.05
	size_spinbox.value = 0.15
	size_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(size_spinbox)
	
	# Слои коллизии
	var layers_label = Label.new()
	layers_label.text = "Collision Layers:"
	vbox.add_child(layers_label)
	
	var layers_grid = GridContainer.new()
	layers_grid.columns = 2
	layers_grid.add_theme_constant_override("h_separation", 10)
	layers_grid.add_theme_constant_override("v_separation", 5)
	
	for i in range(10):
		var checkbox = CheckBox.new()
		checkbox.text = "Layer %d" % (i + 1)
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		if i == 2:  # Layer 3 по умолчанию
			checkbox.button_pressed = true
		
		layer_checkboxes.append(checkbox)
		layers_grid.add_child(checkbox)
	
	vbox.add_child(layers_grid)
	
	# Настройка отладки
	show_debug_checkbox = CheckBox.new()
	show_debug_checkbox.text = "Show Debug Mesh"
	show_debug_checkbox.button_pressed = true
	vbox.add_child(show_debug_checkbox)
	
	# Информация
	info_label = Label.new()
	info_label.text = "Select a character root node"
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(info_label)
	
	vbox.add_child(HSeparator.new())
	
	# Кнопки
	create_button = Button.new()
	create_button.text = "Create HitBoxes & Setup Visibility"
	create_button.pressed.connect(_create_hitboxes_and_setup)
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(create_button)
	
	clear_button = Button.new()
	clear_button.text = "Clear All HitBoxes"
	clear_button.pressed.connect(_clear_hitboxes)
	clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(clear_button)
	
	visibility_button = Button.new()
	visibility_button.text = "Toggle Preview Visibility"
	visibility_button.pressed.connect(_toggle_preview_visibility)
	visibility_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(visibility_button)
	
	dock = vbox
	print("[HitBox Manager] Dock panel created successfully")
	return vbox

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
	
	# Настраиваем видимость
	var visibility_changes = _setup_visibility(nodes_3d)
	print("[HitBox Manager] Visibility changes: ", visibility_changes)
	
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

func _setup_visibility(nodes: Array) -> int:
	var changes = 0
	
	for node in nodes:
		if not node is Node3D:
			continue
		
		if "_v" in node.name:
			if not node.visible:
				node.visible = true
				changes += 1
				print("[HitBox Manager] Made visible: ", node.name)
	
	return changes

func _create_limb_hitboxes(nodes: Array, collision_mask: int, scene_root: Node) -> int:
	var created_count = 0
	var limb_groups = {}
	
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
			
			if not limb_groups.has(limb_name):
				limb_groups[limb_name] = {}
			
			limb_groups[limb_name][limb_number] = node
			print("[HitBox Manager] Found limb: ", limb_name, "_", limb_number, " (", node.name, ")")
	
	print("[HitBox Manager] Limb groups found: ", limb_groups.size())
	
	if limb_groups.is_empty():
		info_label.text = "No limb nodes found"
		return 0
	
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
	area.position = center - target_node.global_position  # Локальная позиция относительно родителя
	
	# Ориентируем по направлению
	var direction = (node2.global_position - node1.global_position).normalized()
	if direction.length() > 0.001:
		# Используем безопасную ориентацию
		area.basis = Basis.looking_at(direction, Vector3.UP)
	
	# Добавляем в иерархию - сначала добавляем в сцену, потом устанавливаем детей
	area.add_child(shape_node)
	
	# Добавляем к целевому узлу
	target_node.add_child(area)
	
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

func _toggle_preview_visibility():
	print("[HitBox Manager] Toggling preview visibility...")
	
	if not target_node:
		printerr("[HitBox Manager] No target node selected!")
		return
	
	var nodes_to_toggle = []
	
	for child in HitBoxUtils.get_all_children(target_node):
		if child is Node3D and "_v" in child.name:
			nodes_to_toggle.append(child)
			print("[HitBox Manager] Found _v node: ", child.name)
	
	if nodes_to_toggle.size() > 0:
		var first_node = nodes_to_toggle[0]
		var make_visible = not first_node.visible
		
		print("[HitBox Manager] Setting visibility to: ", make_visible)
		
		for node in nodes_to_toggle:
			if node is Node3D:
				node.visible = make_visible
		
		info_label.text = "%s visibility for %d _v nodes" % [
			"Shown" if make_visible else "Hidden",
			nodes_to_toggle.size()
		]
	else:
		info_label.text = "No _v nodes found"
		print("[HitBox Manager] No _v nodes found")
