extends Node3D

@export var spawner_handler: Node3D
@onready var spawns = $Map/EnemySpawns
@onready var navigation_reg = $Map/NavigationRegion3D

@export var player_path: NodePath = "^Player"
@export var player_spawn_points: NodePath = "$Map/PlayerSpawns"

@onready var eye = $Map/NavigationRegion3D/mapbox/GLAZ/AnimationPlayer
@onready var eye2 = $Map/NavigationRegion3D/mapbox/GLAZ2/AnimationPlayer
@onready var skel = $blockbench_export/AnimationPlayer
@onready var character = GlobalThings.selected_character

# Отложенная инициализация
var hit_rect: ColorRect
var hitmarker: Control
var player: Node3D
var zombie = load("res://Scenes/buddy_zomb.tscn")
var instance

const MAXENEMIES = 20;
var enemiescount = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	skel.play(&"waiting")
	eye.play(&"eyeanimantion1")
	eye2.play(&"eyeanimantion1")
	
	# спавним игрока
	if character:
		var spawn_points_node = get_node_or_null(player_spawn_points)
		if spawn_points_node:
			if spawn_player(character, spawn_points_node):
				print("Игрок успешно заспавнен")
			else:
				push_error("Не удалось заспавнить игрока")
		else:
			push_error("Точки спавна игрока не найдены")
	else:
		push_error("Персонаж не выбран в GlobalThings.selected_character")
		
	 # Инициализация узлов с проверкой
	player = get_node_or_null(player_path)
	if player:
		var ui = player.get_node_or_null("%UI")
		if ui:
			hit_rect = ui.get_node_or_null("ColorRect")
			hitmarker = ui.get_node_or_null("Hitmarker")
	_validate_setup()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_player_player_hit() -> void:
	hit_rect.visible = true
	await get_tree().create_timer(0.2).timeout
	hit_rect.visible = false

func  _get_random_child(parent_node):
	var random_id = randi() % parent_node.get_child_count()
	return parent_node.get_child(random_id)


func _on_zombie_spawn_timer_timeout() -> void:
	if enemiescount >= MAXENEMIES:
		return
	
	var spawn_point_node = _get_random_child(spawns)
	if not spawn_point_node:
		return
	
	# Добавляем случайное смещение
	var spawn_point = spawn_point_node.global_position
	spawn_point.x += randf_range(-1.0, 1.0)
	spawn_point.z += randf_range(-1.0, 1.0)
	
	instance = zombie.instantiate()
	instance.position = spawn_point
	
	# Безопасное подключение сигналов
	if instance.has_signal("zombie_hit"):
		instance.zombie_hit.connect(_on_enemy_hit)
	if instance.has_signal("enemy_dead"):
		instance.enemy_dead.connect(_on_enemy_dead)
	
	if player and player.has_method("_on_enemy_kill"):
		instance.enemy_dead.connect(player._on_enemy_kill)
	
	navigation_reg.add_child(instance)
	enemiescount += 1
	
func _on_enemy_hit() -> void:
	hitmarker.visible = true
	await get_tree().create_timer(0.07).timeout
	hitmarker.visible = false

func _on_enemy_dead():
	enemiescount -= 1

func _validate_setup():
	var errors = []
	if not player: errors.append("Player node not found")
	if not hit_rect: errors.append("HitRect not found")
	if not spawns: errors.append("EnemySpawns not found")
	if not navigation_reg: errors.append("NavigationRegion not found")
	
	if errors.size() > 0:
		push_error("Setup failed: " + ", ".join(errors))
		set_process(false)

# Функция спавна игрока
func spawn_player(player_scene: PackedScene, spawn_points_node: Node3D) -> bool:
	if player_scene == null or spawn_points_node == null:
		push_error("Player scene or spawn points node is null")
		return false
	
	# Фильтруем только Node3D точки спавна
	var spawn_points: Array[Node3D] = []
	for child in spawn_points_node.get_children():
		if child is Node3D:
			spawn_points.append(child)
	
	if spawn_points.is_empty():
		push_error("No valid spawn points found")
		return false
	
	var random_spawn_point = spawn_points[randi() % spawn_points.size()]
	var player_instance = player_scene.instantiate()
	
	player_instance.global_transform = random_spawn_point.global_transform
	get_tree().current_scene.add_child(player_instance)
	
	# Обновляем ссылку на игрока
	player = player_instance
	
	return true
