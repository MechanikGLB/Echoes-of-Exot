extends Node3D

@onready var hit_rect = $UI/ColorRect
@onready var spawns = $Map/EnemySpawns
@onready var navigation_reg = $Map/NavigationRegion3D

@onready var hitmarker = $UI/Hitmarker

var zombie = load("res://Scenes/buddy_zomb.tscn")
var instance

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	

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
	navigation_reg.add_child(instance)
	
func _on_enemy_hit() -> void:
	hitmarker.visible = true
	await get_tree().create_timer(0.07).timeout
	hitmarker.visible = false
