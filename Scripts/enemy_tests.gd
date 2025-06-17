extends CharacterBody3D

var player = null
var state_machine
var health = 100

const SPEED = 4.0
const ATTACK_RANGE = 2
const ZOMBIE_DMG = 5

signal zombie_hit

@export var player_path := "/root/World/Map/NavigationRegion3D/Player"

@onready var nav_agent = $NavigationAgent3D
@onready var anim_tree = $AnimationTree

func _ready() -> void:
	player = get_node(player_path)
	state_machine = anim_tree.get("parameters/playback")

func _process(delta: float) -> void:
	velocity = Vector3.ZERO
	
	match state_machine.get_current_node():
		"Run":
			nav_agent.set_target_position(player.global_transform.origin)
			var next_nav_point = nav_agent.get_next_path_position()
			velocity = (next_nav_point - global_transform.origin).normalized() * SPEED
			
			rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), delta * 10.0)
		
		"Attack":
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z),Vector3.UP)
			
	
	
	anim_tree.set("parameters/conditions/attack", _target_in_range())
	anim_tree.set("parameters/conditions/run", !_target_in_range())
	
	move_and_slide()

func _target_in_range():
	return global_position.distance_to( player.global_position) < ATTACK_RANGE
	
func _hit_finished():
	if global_position.distance_to(player.global_position) < ATTACK_RANGE + 1.0:
		var dir = global_position.direction_to(player.global_position)
		player.hit(dir, ZOMBIE_DMG)


func _on_area_3d_body_part_hit(dmg: Variant) -> void:
	health -= dmg
	emit_signal("zombie_hit")
	if health <= 0:
		collision_layer = 0
		collision_mask = 0
		anim_tree.set("parameters/conditions/die", true)
		await get_tree().create_timer(5.0).timeout
		queue_free()
