extends CharacterBody3D

var speed = WALK_SPEED
const WALK_SPEED = 5.0
const SPRINT = 10.0
const JUMP_VELOCITY = 5.5
const GRAVITY = 9.8
const SENS = 0.002
const HIT_STAGGER = 1.0
const RESPAWN_DELAY = 5.0

var health = 100
var score = 0
var is_alive = true

#respawning
var respawn_position = Vector3.ZERO
var is_respawning = false
var respawn_timer = 0.0

#signal
signal player_hit

#Head bobbing
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

#FOV 
const BASE_FOV = 90
const FOV_CHANGE = 1.5

#shooting
var bullet = load("res://scenes/bullet.tscn")
var bullet_trail = load("res://scenes/bullet_trail.tscn")
var instance

enum weapons {
	PRIMARY,
	SECONDARY
}
var weapon = weapons.PRIMARY
var can_shoot = true

#Camera
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var aimRay = $Head/Camera3D/AimRay
@onready var aim_ray_end = $Head/Camera3D/AimRayEnd

#Guns
@onready var gun_anim = $Head/Camera3D/PlasmaGun1/AnimationPlayer
@onready var pp_anim = $Head/Camera3D/PPGun1/AnimationPlayer
@onready var gun_barrel = $Head/Camera3D/PlasmaGun1/RayCast3D
@onready var pp_barrel = $Head/Camera3D/PPGun1/Meshes/Barrel
@onready var weapon_switching = $Head/Camera3D/weaponSwitch

#UI
@onready var health_bar = $"%UI/Stats/HBoxContainer/Health"
@onready var ingame_menu = $"%UI/CanvasLayer"
@onready var timer_label = $"%UI/Dethscreen/RespawnTime"
@onready var death_screen = $"%UI/Dethscreen"
@onready var clock = $"%UI/sessionTimer/clock"
@onready var score_label = $"%UI/Stats/HBoxContainer2/Score"
@onready var death_bg = $"%UI/okak"

func _ready() -> void:
	respawn_position = global_position
	health_bar.value = health
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	for child in $BodyShape.find_children("*","VisualInstance3D"):
		child.set_layer_mask_value(1,false)
		child.set_layer_mask_value(2,true)
	clock.start()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENS)
		camera.rotate_x(-event.relative.y * SENS)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80),deg_to_rad(70))
		$BodyShape.rotate_y(-event.relative.x * SENS)
		


func _process(delta: float):
	if is_respawning:
		respawn_timer -= delta
		timer_label.text = "Возрождение через: %.1f" % respawn_timer
		
		if respawn_timer <= 0:
			_respawn()
			is_respawning = false
			death_screen.visible = false
			death_bg.visible = false

func _physics_process(delta: float) -> void:
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		ingame_menu.visible = true
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if !is_alive or is_respawning:
		return
		
	if health <= 0 and is_alive:
		_die()
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		

	# Handle sprint
	if Input.is_action_pressed("sprint"):
		speed = SPRINT
	else:
		speed = WALK_SPEED

	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := Vector3()
	direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 10.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 10.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)
	
	#cam bobbing
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	#FOV settings
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov,target_fov, delta * 8.0)
	
	#Shooting
	if Input.is_action_pressed(&"shoot") and can_shoot:
		match weapon:	
			weapons.PRIMARY:
				_shoot_Gun()
			weapons.SECONDARY:
				_shoot_auto()
	
	if Input.is_action_just_pressed(&"primary") and weapon != weapons.PRIMARY:
		_raise_weapon(weapons.PRIMARY)
	if Input.is_action_just_pressed(&"secondary") and weapon != weapons.SECONDARY:
		_raise_weapon(weapons.SECONDARY)
	
	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ/2) * BOB_AMP
	return pos

func hit(dir, dmg = 10):
	
	emit_signal("player_hit")
	velocity += dir * HIT_STAGGER
	health -= dmg
	health_bar.value = health

func _die():
	
	is_alive = false
	is_respawning = true
	respawn_timer = RESPAWN_DELAY
	
	# Отключаем коллизии и видимость
	$BodyShape.disabled = true
	$BodyShape.visible = false
	death_bg.visible = true
	death_screen.visible = true
	
	

	set_process_unhandled_input(false)

func _respawn():
	print("Respawning player...")
	# Восстанавливаем здоровье
	global_position = respawn_position
	velocity = Vector3.ZERO
	health = 100
	health_bar.value = health
	
	# Включаем коллизии и видимость
	$BodyShape.disabled = false
	$BodyShape.visible = true
	
	# Включаем управление
	set_process_unhandled_input(true)
	
	is_alive = true

func _shoot_Gun():
	if !gun_anim.is_playing():
		gun_anim.play("shoot")
		instance = bullet.instantiate()
		instance.position = gun_barrel.global_position
		get_parent().add_child(instance) 
		if aimRay.is_colliding():
			instance.set_velocity(aimRay.get_collision_point())
		else: 
			instance.set_velocity(aim_ray_end.global_position)
				 
func _shoot_auto():
	if !pp_anim.is_playing():
		pp_anim.play(&"shoot")
		instance = bullet_trail.instantiate()
		if aimRay.is_colliding():
			instance.init(pp_barrel.global_position, aimRay.get_collision_point())
			get_parent().add_child(instance)
			if aimRay.get_collider().is_in_group("enemy"):
				aimRay.get_collider().hit(15)
				instance.trigger_particles(aimRay.get_collision_point(),
											pp_barrel.global_position, true)
			else:
				instance.trigger_particles(aimRay.get_collision_point(),
											pp_barrel.global_position, false)
		else:
			instance.init(pp_barrel.global_position, aim_ray_end.global_position)
			get_parent().add_child(instance)

func _lower_weapon():
	match weapon:
		weapons.PRIMARY:
			weapon_switching.play(&"plasma_lower")
		weapons.SECONDARY:
			weapon_switching.play(&"pp_lower")

func _raise_weapon(new_gun):
	can_shoot = false
	_lower_weapon()
	await get_tree().create_timer(0.3).timeout
	match new_gun:
		weapons.PRIMARY:
			weapon_switching.play_backwards(&"plasma_lower")
		weapons.SECONDARY:
			weapon_switching.play_backwards(&"pp_lower")
	weapon = new_gun
	can_shoot = true

func _on_enemy_kill():
	score += 1
	score_label.text = "%d" % score
