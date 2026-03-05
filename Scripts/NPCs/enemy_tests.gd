extends CharacterBody3D

var health = 100
var alive = true
var team: int = 0

var player_target: Node3D

const SPEED = 4.0
const ATTACK_RANGE = 2
const ZOMBIE_DMG = 5

signal zombie_hit
signal enemy_dead

@onready var nav_agent = $NavigationAgent3D
@onready var anim_tree = $AnimationTree
@onready var state_machine = anim_tree.get("playback")

func _ready():
	
	add_to_group("enemy")
	add_to_group("hittable")
	
	_find_and_set_target()

func _physics_process(delta):
	if not alive:
		return
		
	if not _is_target_valid():
		_find_and_set_target()
		return
	
	# Движение
	nav_agent.set_target_position(player_target.global_position)
	var next_pos = nav_agent.get_next_path_position()
	velocity = (next_pos - global_position).normalized() * SPEED
	
	# Поворот
	look_at(Vector3(player_target.global_position.x, global_position.y, player_target.global_position.z), Vector3.UP)
	
	# Анимации
	var in_range = global_position.distance_to(player_target.global_position) < ATTACK_RANGE
	anim_tree.set("parameters/conditions/attack", in_range)
	anim_tree.set("parameters/conditions/run", not in_range)
	
	move_and_slide()

func take_damage(amount, direction = Vector3.ZERO):
	if not alive:
		return
	health -= amount
	emit_signal("zombie_hit")
	if health <= 0:
		die()

func die():
	alive = false
	anim_tree.set("parameters/conditions/die", true)
	emit_signal("enemy_dead")
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _find_and_set_target():
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	player_target = players[0]  # берем первого игрока

func _is_target_valid():
	return player_target != null and player_target.is_character_alive()

func _hit_finished():
	if _is_target_valid() and global_position.distance_to(player_target.global_position) < ATTACK_RANGE + 1.0:
		player_target.take_damage(ZOMBIE_DMG)
