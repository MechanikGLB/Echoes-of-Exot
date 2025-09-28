# base_player_character.gd
class_name PlayerCharacter
extends CharacterBody3D

# Константы движения
const WALK_SPEED = 5.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 5.5
const GRAVITY = 9.8
const MOUSE_SENSITIVITY = 0.002
const HIT_STAGGER = 1.0
const RESPAWN_DELAY = 5.0

# Константы камеры
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
const BASE_FOV = 90
const FOV_CHANGE = 1.5

# Состояние игрока
@export var health = 100
@export var speed = WALK_SPEED
var score = 0
var is_alive = true
var team = 0
var friendly_fire = 0

# Респаун
var respawn_position = Vector3.ZERO
var is_respawning = false
var respawn_timer = 0.0

# Сигналы
signal player_hit
signal player_died
signal player_respawned
signal score_changed(new_score)

# Камера и голова
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var aim_ray = $Head/Camera3D/AimRay
@onready var aim_ray_end = $Head/Camera3D/AimRayEnd

# Переменные для переопределения в дочерних классах
var head_bob_enabled: bool = true
var fov_change_enabled: bool = true
var can_respawn: bool = true
var custom_gravity: float = GRAVITY

# Head bobbing
var t_bob = 0.0

func _ready() -> void:
	_initialize_player()
	_setup_camera()
	_setup_collision_layers()
	_custom_ready()

# Метод для переопределения без риска сломать родительскую логику
func _custom_ready():
	pass

func _initialize_player():
	respawn_position = global_position
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _setup_camera():
	if camera:
		camera.fov = BASE_FOV

func _setup_collision_layers():
	# Скрываем тело игрока от его собственной камеры
	for child in find_children("*", "VisualInstance3D"):
		if child.has_method("set_layer_mask_value"):
			child.set_layer_mask_value(1, false)
			child.set_layer_mask_value(2, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_movement(event)

func _handle_mouse_movement(event: InputEventMouseMotion):
	if head:
		head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
	if camera:
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(70))
	
	# Поворачиваем тело вместе с головой
	var body_shape = find_child("BodyShape")
	if body_shape:
		body_shape.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

func _process(delta: float):
	_handle_respawn(delta)
	_custom_process(delta)  # Для переопределения в дочерних классах

func _custom_process(delta: float):
	# Переопределите этот метод в дочерних классах для дополнительной логики
	pass

func _handle_respawn(delta: float):
	if is_respawning:
		respawn_timer -= delta
		_update_respawn_ui()
		
		if respawn_timer <= 0:
			_respawn()

func _update_respawn_ui():
	# Переопределите для кастомного UI
	var timer_label = get_node_or_null("%UI/Dethscreen/RespawnTime")
	if timer_label and timer_label is Label:
		timer_label.text = "Возрождение через: %.1f" % respawn_timer

func _physics_process(delta: float) -> void:
	_handle_menu_input()
	
	if not is_on_floor():
		velocity.y -= custom_gravity * delta
	
	if !is_alive or is_respawning:
		return
	
	if health <= 0 and is_alive:
		_die()
	
	_handle_jump()
	_handle_sprint()
	_handle_movement(delta)
	_handle_camera_effects(delta)
	_handle_weapon_input()
	
	move_and_slide()

func _handle_menu_input():
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_menu()

func _toggle_menu():
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_hide_menu()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_show_menu()

func _show_menu():
	var ingame_menu = get_node_or_null("%UI/CanvasLayer")
	if ingame_menu:
		ingame_menu.visible = true

func _hide_menu():
	var ingame_menu = get_node_or_null("%UI/CanvasLayer")
	if ingame_menu:
		ingame_menu.visible = false

func _handle_jump():
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _handle_sprint():
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

func _handle_movement(delta: float):
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := Vector3()
	
	if head:
		direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			_play_footsteps(true)
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 10.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 10.0)
			_play_footsteps(false)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)
		_play_footsteps(false)

func _play_footsteps(playing: bool):
	var steps = $AudioStreamPlayer3D
	if steps:
		steps.stream_paused = !playing

func _handle_camera_effects(delta: float):
	if head_bob_enabled:
		_apply_head_bob(delta)
	if fov_change_enabled:
		_apply_fov_change(delta)

func _apply_head_bob(delta: float):
	if not camera: return
	
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _calculate_headbob(t_bob)

func _calculate_headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	if head_bob_enabled:
		pos.y = sin(time * BOB_FREQ) * BOB_AMP
		pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _apply_fov_change(delta: float):
	if not camera: return
	
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

func _handle_weapon_input():
	# Базовые привязки оружия - переопределите для кастомного поведения
	if Input.is_action_pressed("cursor"):
		_unlock_cursor(true)
	if Input.is_action_just_released("cursor"):
		_unlock_cursor(false)

func hit(dir: Vector3, damage: int = 10):
	emit_signal("player_hit")
	velocity += dir * HIT_STAGGER
	health -= damage
	_update_health_ui()

func _update_health_ui():
	var health_bar = get_node_or_null("%UI/Stats/HBoxContainer/Health")
	if health_bar and health_bar.has_method("set_value"):
		health_bar.value = health

func _die():
	if not can_respawn:
		return
	
	emit_signal("player_died")
	is_alive = false
	is_respawning = true
	respawn_timer = RESPAWN_DELAY
	
	_disable_character()
	_show_death_screen()

func _disable_character():
	var body_shape = find_child("BodyShape")
	if body_shape:
		if body_shape.has_method("set_disabled"):
			body_shape.set_disabled(true)
		body_shape.visible = false
	
	set_process_unhandled_input(false)

func _show_death_screen():
	var death_screen = get_node_or_null("%UI/Dethscreen")
	var death_bg = get_node_or_null("%UI/okak")
	
	if death_screen:
		death_screen.visible = true
	if death_bg:
		death_bg.visible = true
	
	_play_death_sound()

func _play_death_sound():
	var death_sound = $AudioStreamPlayer3D
	if death_sound:
		death_sound.play()

func _respawn():
	emit_signal("player_respawned")
	
	global_position = respawn_position
	velocity = Vector3.ZERO
	health = 100
	is_alive = true
	
	_enable_character()
	_hide_death_screen()
	_update_health_ui()
	
	set_process_unhandled_input(true)

func _enable_character():
	var body_shape = find_child("BodyShape")
	if body_shape:
		if body_shape.has_method("set_disabled"):
			body_shape.set_disabled(false)
		body_shape.visible = true

func _hide_death_screen():
	var death_screen = get_node_or_null("%UI/Dethscreen")
	var death_bg = get_node_or_null("%UI/okak")
	
	if death_screen:
		death_screen.visible = false
	if death_bg:
		death_bg.visible = false

func _unlock_cursor(locked: bool):
	if locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func add_score(points: int):
	score += points
	emit_signal("score_changed", score)
	_update_score_ui()

func _update_score_ui():
	var score_label = get_node_or_null("%UI/Stats/HBoxContainer2/Score")
	if score_label and score_label is Label:
		score_label.text = "%d" % score

func set_respawn_position(position: Vector3):
	respawn_position = position

# Методы для переопределения в дочерних классах
func _main_attack():
	pass

func _secondary_attack():
	pass

func _ability_ultimate():
	pass

func _ability_movement():
	pass

func _ability_secondary():
	pass

func _on_enemy_kill():
	add_score(1)
