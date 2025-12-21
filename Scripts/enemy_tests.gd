extends CharacterBody3D

var state_machine
var health = 100
var alive = true

var player_target: Node3D

const SEE_RANGE = 90.0
const SPEED = 4.0
const ATTACK_RANGE = 2
const ZOMBIE_DMG = 5

signal zombie_hit
signal enemy_dead

@onready var nav_agent = $NavigationAgent3D
@onready var anim_tree = $AnimationTree

func _ready() -> void:
	state_machine = anim_tree.get("parameters/playback")
	_find_and_set_target()

func _process(delta: float) -> void:
	# Если state_machine не инициализирован, выходим
	if state_machine == null:
		return
		
	velocity = Vector3.ZERO
	
	# Если цели нет или она невалидна - ищем новую
	if not _is_target_valid():
		_find_and_set_target()
		return
	
	match state_machine.get_current_node():
		"Run":
			if global_transform.origin.distance_to(player_target.global_transform.origin) <= SEE_RANGE:
				nav_agent.set_target_position(player_target.global_transform.origin)
				var next_nav_point = nav_agent.get_next_path_position()
				velocity = (next_nav_point - global_transform.origin).normalized() * SPEED
				
				rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), delta * 10.0)
		
		"Attack":
			look_at(Vector3(player_target.global_position.x, global_position.y, player_target.global_position.z), Vector3.UP)
	
	anim_tree.set("parameters/conditions/attack", _target_in_range())
	anim_tree.set("parameters/conditions/run", !_target_in_range() and _is_target_valid())
	
	move_and_slide()

func _find_and_set_target() -> void:
	var players = get_tree().get_nodes_in_group("players")
	if not players.is_empty():
		var nearest_player = _find_nearest_player(players)
		if nearest_player:
			player_target = nearest_player

func set_player_target(target: Node3D) -> void:
	player_target = target

func _target_in_range() -> bool:
	if not _is_target_valid():
		return false
	return global_position.distance_to(player_target.global_position) < ATTACK_RANGE

func _is_target_valid() -> bool:
	return (player_target != null and 
			is_instance_valid(player_target) and 
			player_target.has_method("is_character_alive") and 
			player_target.is_character_alive())

func _hit_finished():
	if _is_target_valid() and global_position.distance_to(player_target.global_position) < ATTACK_RANGE + 1.0:
		var dir = global_position.direction_to(player_target.global_position)
		player_target.take_damage(ZOMBIE_DMG, dir, player_target.HIT_STAGGER)

func _find_nearest_player(players: Array) -> Node3D:
	var nearest_player = null
	var min_distance = INF
	
	for player in players:
		if is_instance_valid(player) and player.has_method("is_character_alive") and player.is_character_alive():
			var distance = global_position.distance_to(player.global_position)
			if distance < min_distance:
				min_distance = distance
				nearest_player = player
	
	return nearest_player

func _on_area_3d_body_part_hit(dmg: Variant) -> void:
	if !alive:
		return
	health -= dmg
	emit_signal("zombie_hit")
	if health <= 0:
		collision_layer = 0
		collision_mask = 0
		anim_tree.set("parameters/conditions/die", true)
		emit_signal("enemy_dead")
		alive = false
		await get_tree().create_timer(5.0).timeout
		queue_free()
