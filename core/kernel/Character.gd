class_name CharacterBase
extends CharacterBody3D

# ========== НАСТРОЙКИ ПЕРСОНАЖА ==========
@export_category("Character Settings")
#@export var max_health: int = 100
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 5.5  
@export var gravity: float = 9.8
#@export var respawn_delay: float = 5.0 
#@export var invulnerability_time: float = 2.0
@export var hit_stagger:float = 2.0

@export_category("Team Settings")
@export var team: int = 1  # 0 - команды врагов, 1+ - игрок


# ========== СОСТОЯНИЯ ==========
enum CharacterState { 
	ALIVE, 
	DEAD, 
	RESPAWNING, 
	INVULNERABLE,
	DISABLED 
}

var current_state: CharacterState = CharacterState.ALIVE
#var health: int
var speed: float
#var invulnerability_timer: float = 0.0
#var respawn_timer: float = 0.0

# ========== СИСТЕМА СПОСОБНОСТЕЙ ==========

@export var abilities: Array[AbilityResource] = []
var current_ability: AbilityResource  # Текущая используемая способность

# Для отслеживания активной способности
var is_ability_active: bool = false

# Для подброса
func knockup(_duration: float):
	
	var tween = create_tween()
	tween.tween_property(self, "velocity:y", 10.0, 0.1)
	# Здесь можно добавить эффект оглушения

#Компоненты 

@onready var health_component: HealthComponent = $HealthComponent
@onready var movement_component: MovementComponent = $MovementComponent

# ========== НОДЫ ==========

@onready var head: Node3D = $blockbench_export/Drake/torso/head2/head_2
@onready var camera: Camera3D = $blockbench_export/Drake/torso/head2/head_2/Camera3D
@onready var body_shape: CollisionShape3D = $BodyShape
@onready var body_node: Node3D = $blockbench_export
@onready var animation_player: AnimationPlayer = $blockbench_export/AnimationPlayer  

# UI ноды
@onready var UI = $"%UI"
@onready var health_bar = $"%UI/Stat_base/Health"
@onready var death_screen = $"%UI/Dethscreen"
@onready var death_bg = $"%UI/okak"
@onready var timer_label = $"%UI/Dethscreen/RespawnTime"
@onready var clock = $"%UI/sessionTimer/clock"
@onready var score_label = $"%UI/Stat_base/HBoxContainer2/Score"
@onready var damage_flash = $"%UI/DamageFlash"
@onready var invulnerability_effect = get_node_or_null("InvulnerabilityEffect")

@onready var steps = get_node_or_null("AudioStreamPlayer3D")

# ========== НАСТРОЙКИ КАМЕРЫ ==========
const SENS = 0.002
const BOB_FREQ = 1.2
const BOB_AMP = 0.02
var t_bob = 0.0
const BASE_FOV = 90
const FOV_CHANGE = 1.5

# ========== СИГНАЛЫ ==========
@warning_ignore("unused_signal")
signal hit_frame_reached  # Используется в AbilityResource для синхронизации анимации

# ========== ИНИЦИАЛИЗАЦИЯ ==========
func _ready() -> void:

	speed = walk_speed
	
	# Подключение к HealthComponent
	health_component.damaged.connect(_on_health_damaged)
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_health_died)
	health_component.respawned.connect(_on_health_respawned)
	
	# ИНИЦИАЛИЗАЦИЯ СПОСОБНОСТЕЙ
	for ability in abilities:
		ability.owner = self
	
	_update_ui()
	
	# Настройка видимости (чтобы не видеть себя)
	for child in $BodyShape.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)
	
	clock.start()
	_custom_ready()


# ========== ОСНОВНОЙ ЦИКЛ ==========
func _physics_process(delta: float) -> void:
	if current_state == CharacterState.DEAD or current_state == CharacterState.DISABLED:
		return
	
	# Обработка меню
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Обработка курсора
	if Input.is_action_pressed("cursor"):
		_unlock_cursor(true)
	if Input.is_action_just_released("cursor"):
		_unlock_cursor(false)
	
	# Обновление таймеров
	_update_timers(delta)
	
	# Обновление способностей
	for ability in abilities:
		ability.update(delta)
	
	# Физика
	#_apply_gravity(delta)
	_handle_movement(delta)
	_handle_abilities_input()
	

	
	# Визуальные эффекты
	_update_camera_effects(delta)
	_update_invulnerability_effect()
	
	_custom_physics_process(delta)
	#move_and_slide()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		#head.rotate_y(-event.relative.x * SENS)
		camera.rotate_x(-event.relative.y * SENS)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(70))
		body_shape.rotate_y(-event.relative.x * SENS)
		body_node.rotate_y(-event.relative.x * SENS)
		

# ========== ДВИЖЕНИЕ ==========
func _handle_movement(delta: float) -> void:
	if not is_character_alive() or current_state == CharacterState.RESPAWNING:
		return

	# Прыжок
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		movement_component.jump()

	# Спринт
	var sprint = Input.is_action_pressed("sprint")

	# Направление движения
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (body_shape.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	movement_component.set_move_input(direction, sprint)

	# Звук шагов
	if steps:
		steps.stream_paused = direction == Vector3.ZERO

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _update_camera_effects(delta: float) -> void:
	if is_character_alive() and current_state != CharacterState.RESPAWNING:
		t_bob += delta * velocity.length() * float(is_on_floor())
		camera.transform.origin = _headbob(t_bob)
		
		var velocity_clamped = clamp(velocity.length(), 0.5, sprint_speed * 2)
		var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
		camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

func _headbob(time: float) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

# ========== ТАЙМЕРЫ ==========
func _update_timers(delta: float) -> void:
	if current_state == CharacterState.RESPAWNING:
		update_respawn_timer(health_component.respawn_timer)

# ========== СПОСОБНОСТИ ==========
func _handle_abilities_input() -> void:
	if current_state != CharacterState.ALIVE:
		return
	
	for ability in abilities:
		if not ability.can_use():
			continue
		
		if ability.holdable and Input.is_action_pressed(ability.input_action):
			ability.on_press()
		elif not ability.holdable and Input.is_action_just_pressed(ability.input_action):
			ability.on_press()

func play_ability_animation(anim_name: String, anim_speed: float = 1.0) -> void:
	if not animation_player or not anim_name:
		return
	animation_player.play(anim_name)
	animation_player.speed_scale = anim_speed

func stop_ability_animation() -> void:
	if animation_player:
		animation_player.stop()

func get_projectile_spawn_position() -> Vector3:
	"""Позиция для спавна снарядов (можно переопределить)"""
	return camera.global_position

func set_ability_active(active: bool, ability: AbilityResource) -> void:
	is_ability_active = active
	if active:
		current_ability = ability
	elif current_ability == ability:
		current_ability = null

# ======== Командные функции ==============

func is_enemy(other: CharacterBase) -> bool:
	print(">>> is_enemy()")
	print("   this.team = ", team, " (", name, ")")
	print("   other.team = ", other.team, " (", other.name, ")")
	
	if not other:
		print("   → other null, false")
		return false
	
	if team == 0:
		var result = other.team != 0
		print("   → я команда 0, результат = ", result)
		return result
	
	if other.team == 0:
		print("   → враг команда 0, true")
		return true
	
	var result2 = team != other.team
	print("   → сравниваем команды, результат = ", result2)
	return result2

# ========== ЗДОРОВЬЕ ==========

func character_respawned() -> void:
	pass

func take_damage(amount: int, direction: Vector3 = Vector3.ZERO) -> void:
	if not health_component.can_take_damage():
		return
	
	# Отбрасывание остаётся здесь, потому что это движение
	if direction != Vector3.ZERO:
		velocity += direction * hit_stagger
	
	health_component.take_damage(amount, null, "body")

func _on_health_damaged(_amount: int, _source: Node, _zone: String) -> void:
	_show_damage_effect()

func _on_health_changed(_current: int, _max: int) -> void:
	_update_health_ui()

func _on_death() -> void:
	var okak = $"%UI/Dethscreen/AudioStreamPlayer"
	if okak:
		okak.play()
	if body_shape:
		body_shape.disabled = true
	death_bg.visible = true
	death_screen.visible = true
	set_process_unhandled_input(false)
	current_state = CharacterState.RESPAWNING

func _on_health_died(_killer: Node) -> void:
	if current_state == CharacterState.DEAD:
		return
	current_state = CharacterState.DEAD
	_on_death()

func _on_health_respawned() -> void:
	current_state = CharacterState.ALIVE
	global_position = _get_respawn_point()
	velocity = Vector3.ZERO
	
	_update_ui()
	character_respawned()
	
	if invulnerability_effect:
		invulnerability_effect.emitting = true
	if body_shape:
		body_shape.disabled = false
	
	death_bg.visible = false
	death_screen.visible = false
	set_process_unhandled_input(true)
	set_physics_process(true)

# ========== ОЧКИ ==========
func add_score(points: int) -> void:
	score_label.text = str(int(score_label.text) + points)

# ========== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ==========
func _get_respawn_point() -> Vector3:
	var spawn_points = get_tree().get_nodes_in_group("respawn_points")
	if spawn_points.size() > 0:
		return spawn_points[randi() % spawn_points.size()].global_position
	
	print("No respawn points found, using current position")
	return global_position

func get_aim_position() -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var origin = camera.project_ray_origin(mouse_pos)
	var end = origin + camera.project_ray_normal(mouse_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	return end

func _unlock_cursor(is_locked: bool) -> void:
	if is_locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		set_process_unhandled_input(false)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		set_process_unhandled_input(true)

# ========== UI МЕТОДЫ ==========
func _update_ui() -> void:
	_update_health_ui()

func _update_health_ui() -> void:
	if health_bar:
		health_bar.value = health_component.get_health()

func update_respawn_timer(time_left: float) -> void:
	if timer_label:
		timer_label.text = "Возрождение через: %.1f" % time_left

func _show_damage_effect() -> void:
	if damage_flash:
		damage_flash.visible = true
		var tween = create_tween()
		tween.tween_property(damage_flash, "color:a", 0.0, 0.3)
		tween.tween_callback(func(): 
			if damage_flash:
				damage_flash.visible = false
		)

func _update_invulnerability_effect() -> void:
	if invulnerability_effect:
		invulnerability_effect.emitting = health_component.invulnerability_timer > 0

func _stop_all_sounds():
	for child in get_children(true):
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			child.stop()

# ========== МЕТОДЫ СОСТОЯНИЙ ==========
func is_character_alive() -> bool:
	return health_component.is_alive() and current_state == CharacterState.ALIVE

func can_take_damage() -> bool:
	return current_state == CharacterState.ALIVE and health_component.can_take_damage()

func get_health_percentage() -> float:
	return health_component.get_health_percent()

func disable() -> void:
	current_state = CharacterState.DISABLED
	set_physics_process(false)

func enable() -> void:
	current_state = CharacterState.ALIVE
	set_physics_process(true)
	

func menu_state():
	disable()
	set_process_unhandled_input(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if UI:
		UI.visible = false
	
	_stop_all_sounds()
	_custom_menu_state() 

func game_start():
	current_state = CharacterState.ALIVE
	set_physics_process(true)
	set_process_unhandled_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Показываем UI
	if UI:
		UI.visible = true
	
	_custom_game_start()

# ========== ВИРТУАЛЬНЫЕ МЕТОДЫ ==========
func _custom_ready() -> void:
	pass

func _custom_physics_process(_delta: float) -> void:
	pass

func _custom_menu_state() -> void:
	pass

func _custom_game_start():
	pass
