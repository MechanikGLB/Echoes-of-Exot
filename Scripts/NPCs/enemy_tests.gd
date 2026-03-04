extends CharacterBody3D

@export var hit_stagger = 1.0

var health = 1000
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

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("enemies")
	add_to_group("hittable")
	print("=== Зомби инициализация ===")
	print("   группы: ", get_groups())
	print("   team = ", team)
	
	_find_and_set_target()

func _process(delta):
	if not _is_target_valid():
		_find_and_set_target()
		return
	
	# Движение к цели
	nav_agent.set_target_position(player_target.global_position)
	var next_pos = nav_agent.get_next_path_position()
	velocity = (next_pos - global_position).normalized() * SPEED
	
	# Поворот к цели
	look_at(Vector3(player_target.global_position.x, global_position.y, player_target.global_position.z), Vector3.UP)
	
	# Анимации
	var in_range = global_position.distance_to(player_target.global_position) < ATTACK_RANGE
	anim_tree.set("parameters/conditions/attack", in_range)
	anim_tree.set("parameters/conditions/run", not in_range)
	
	move_and_slide()

func take_damage(amount: int, direction: Vector3 = Vector3.ZERO) -> void:
	print(">>> Зомби.take_damage()")
	print("   amount = ", amount)
	print("   alive = ", alive)
	print("   health до = ", health)
	print("   группы: ", get_groups())
	
	if not alive:
		print("   → уже мертв")
		return
	
	health -= amount
	print("   ✅ здоровье после = ", health)
	emit_signal("zombie_hit")
	
	if health <= 0:
		print("   💀 зомби умирает")
		die()

func die():
	alive = false
	anim_tree.set("parameters/conditions/die", true)
	emit_signal("enemy_dead")
	await get_tree().create_timer(5.0).timeout
	queue_free()

# Для совместимости со старой системой BodyPart
func _on_area_3d_body_part_hit(dmg):
	take_damage(dmg)

func _find_and_set_target():
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	
	# Берем ближайшего игрока
	var nearest = null
	var min_dist = INF
	for p in players:
		if p.has_method("is_character_alive") and p.is_character_alive():
			var dist = global_position.distance_to(p.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest = p
	
	player_target = nearest

func _is_target_valid():
	return player_target != null and is_instance_valid(player_target) and player_target.is_character_alive()

func _hit_finished():
	if _is_target_valid() and global_position.distance_to(player_target.global_position) < ATTACK_RANGE + 1.0:
		var dir = global_position.direction_to(player_target.global_position)
		player_target.take_damage(ZOMBIE_DMG, dir)
		print("Зомби атакует! Урон: ", ZOMBIE_DMG)
