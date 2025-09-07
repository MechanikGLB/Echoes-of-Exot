extends Node3D

@onready var spawns = $Map/EnemySpawns
@onready var navigation_reg = $Map/NavigationRegion3D

@export var player_path: NodePath = "^Player"

@onready var eye = $Map/NavigationRegion3D/mapbox/GLAZ/AnimationPlayer
@onready var eye2 = $Map/NavigationRegion3D/mapbox/GLAZ2/AnimationPlayer

# Отложенная инициализация
var hit_rect: ColorRect
var hitmarker: Control
var player: Node3D
var zombie = load("res://Scenes/buddy_zomb.tscn")
var instance

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	eye.play(&"eyeanimantion1")
	eye2.play(&"eyeanimantion1")
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
	var spawn_point = _get_random_child(spawns).global_position
	instance = zombie.instantiate()
	instance.position = spawn_point
	instance.zombie_hit.connect(_on_enemy_hit)
	instance.enemy_dead.connect(player._on_enemy_kill)
	navigation_reg.add_child(instance)
	
func _on_enemy_hit() -> void:
	hitmarker.visible = true
	await get_tree().create_timer(0.07).timeout
	hitmarker.visible = false

func _validate_setup():
	var errors = []
	if not player: errors.append("Player node not found")
	if not hit_rect: errors.append("HitRect not found")
	if not spawns: errors.append("EnemySpawns not found")
	if not navigation_reg: errors.append("NavigationRegion not found")
	
	if errors.size() > 0:
		push_error("Setup failed: " + ", ".join(errors))
		set_process(false)
