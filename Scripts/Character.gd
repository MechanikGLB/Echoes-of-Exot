extends CharacterBody3D
class_name Character_base

@export var speed = WALK_SPEED

const WALK_SPEED = 5.0
const SPRINT = 10.0
const JUMP_VELOCITY = 5.5
const GRAVITY = 9.8
const SENS = 0.002
const HIT_STAGGER = 1.0
const RESPAWN_DELAY = 5.0

#player prefs
@export var health = 1000
var score = 0
var is_alive = true
var can_attach = true
var can_move = true

var team = 0
var friendly_fire = 0

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
		if (Input.mouse_mode == Input.MOUSE_MODE_VISIBLE) or (ingame_menu.visible == true):
			ingame_menu.visible = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
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
			steps.stream_paused = false
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 10.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 10.0)
			steps.stream_paused = true
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)
		steps.stream_paused = true
	
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


func _main_attack(): #ЛКМ, атака
	pass

func _secondary_attack(): #ПКМ, способность
	pass

func _abil_ultimate(): # E? ульта
	pass

func _abil_movement(): # Shift, перемещение, особое
	pass

func _abil_secondary(): # Q, кьюшка, дополнительная способность
	pass

func _mouse_unlock(): # Alt, 
	if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _mouse_lock(): # Alt, 
	if (Input.mouse_mode == Input.MOUSE_MODE_VISIBLE):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
