class_name CharacterBase
extends CharacterBody3D

# ========== НАСТРОЙКИ ПЕРСОНАЖА ==========
@export_category("Character Settings")
@export var max_health: int = 100
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 5.5  
@export var gravity: float = 9.8
@export var respawn_delay: float = 5.0 
@export var invulnerability_time: float = 2.0

# ========== СОСТОЯНИЯ ==========
enum CharacterState { 
	ALIVE, 
	DEAD, 
	RESPAWNING, 
	INVULNERABLE,
	DISABLED 
}

var current_state: CharacterState = CharacterState.ALIVE
var health: int
var speed: float
var invulnerability_timer: float = 0.0
var respawn_timer: float = 0.0

# ========== СИСТЕМА СПОСОБНОСТЕЙ ==========
class Ability:
	var name: String
	var input_action: String
	var cooldown: float
	var current_cooldown: float
	var holdable: bool
	
	func _init(p_name: String, p_action: String, p_cooldown: float, p_holdable: bool = false):
		name = p_name
		input_action = p_action
		cooldown = p_cooldown
		current_cooldown = 0.0
		holdable = p_holdable
	
	func can_use() -> bool:
		return current_cooldown <= 0.0
	
	func use():
		if not holdable:
			current_cooldown = cooldown
	
	func update(delta: float):
		if current_cooldown > 0:
			current_cooldown = max(0, current_cooldown - delta)

var abilities: Dictionary = {}

# ========== НОДЫ ==========
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var body_shape: CollisionShape3D = $BodyShape
@onready var body_node: Node3D = $blockbench_export

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

# ========== НАСТРОЙКИ КАМЕРЫ ==========
const SENS = 0.002
const BOB_FREQ = 1.5
const BOB_AMP = 0.04
var t_bob = 0.0
const BASE_FOV = 90
const FOV_CHANGE = 1.5

# ========== ИНИЦИАЛИЗАЦИЯ ==========
func _ready() -> void:
	health = max_health
	speed = walk_speed
	_setup_abilities()
	_update_ui()
	
	# Настройка видимости (чтобы не видеть себя)
	for child in $BodyShape.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)
	
	clock.start()
	_custom_ready()

func _setup_abilities():
	"""Переопределяется в наследниках для добавления способностей"""
	pass

func add_ability(name: String, input_action: String, cooldown: float, holdable: bool = false):
	abilities[name] = Ability.new(name, input_action, cooldown, holdable)

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
	
	# Обновление кулдаунов способностей
	for ability in abilities.values():
		ability.update(delta)
	
	# Физика
	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_abilities_input()
	
	# Визуальные эффекты
	_update_camera_effects(delta)
	_update_invulnerability_effect()
	
	_custom_physics_process(delta)
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * SENS)
		camera.rotate_x(-event.relative.y * SENS)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(70))
		# Вращение модели персонажа
		$BodyShape.rotate_y(-event.relative.x * SENS)
		body_node.rotate_y(-event.relative.x * SENS)

# ========== ДВИЖЕНИЕ ==========
func _handle_movement(delta: float) -> void:
	"""Переопределяется в наследниках"""
	pass

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _update_camera_effects(delta: float) -> void:
	if is_character_alive() and current_state != CharacterState.RESPAWNING:
		# Качание головы
		t_bob += delta * velocity.length() * float(is_on_floor())
		camera.transform.origin = _headbob(t_bob)
		
		# Динамическое FOV
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
	# Таймер респауна
	if current_state == CharacterState.RESPAWNING:
		respawn_timer -= delta
		update_respawn_timer(respawn_timer)
		
		if respawn_timer <= 0:
			respawn()
	
	# Таймер неуязвимости
	if invulnerability_timer > 0:
		invulnerability_timer -= delta

# ========== СПОСОБНОСТИ ==========
func _handle_abilities_input() -> void:
	if current_state != CharacterState.ALIVE:
		return
	
	for ability in abilities.values():
		if not ability.can_use():
			continue
		
		if ability.holdable and Input.is_action_pressed(ability.input_action):
			_use_ability(ability.name)
		elif not ability.holdable and Input.is_action_just_pressed(ability.input_action):
			_use_ability(ability.name)

func _use_ability(ability_name: String) -> void:
	var ability = abilities.get(ability_name)
	if not ability:
		return
	
	ability.use()
	
	match ability_name:
		"primary_fire":
			_ability_primary()
		"secondary_fire":
			_ability_secondary(get_aim_position())
		"ability_1":
			_ability_1(get_aim_position())
		"ability_2":
			_ability_2(get_aim_position())
		"ultimate":
			_ability_ultimate(get_aim_position())

# Виртуальные методы для способностей
func _ability_primary() -> void:
	pass

func _ability_secondary(_target_position: Vector3) -> void:
	pass

func _ability_1(_target_position: Vector3) -> void:
	pass

func _ability_2(_target_position: Vector3) -> void:
	pass

func _ability_ultimate(_target_position: Vector3) -> void:
	pass

# ========== ЗДОРОВЬЕ ==========
func take_damage(amount: int) -> void:
	if current_state != CharacterState.ALIVE or invulnerability_timer > 0:
		return
	
	var old_health = health
	health = max(0, health - amount)
	
	_update_health_ui()
	_show_damage_effect()
	
	if health <= 0:
		die()

func die() -> void:
	if current_state == CharacterState.DEAD:
		return
	
	current_state = CharacterState.DEAD
	_on_death()

func respawn() -> void:
	print("Respawn called - current state: ", current_state)
	
	if current_state != CharacterState.DEAD and current_state != CharacterState.RESPAWNING:
		return
	
	current_state = CharacterState.ALIVE
	invulnerability_timer = invulnerability_time
	
	# Возрождение в точке респауна или на месте
	global_position = _get_respawn_point()
	
	velocity = Vector3.ZERO
	health = max_health
	
	_update_ui()
	character_respawned()
	
	# Визуальные эффекты
	if invulnerability_effect:
		invulnerability_effect.emitting = true
	
	if body_shape:
		body_shape.disabled = false
	
	# Скрываем экран смерти
	death_bg.visible = false
	death_screen.visible = false
	
	set_process_unhandled_input(true)
	set_physics_process(true)

func _on_death() -> void:
	# Звук смерти (если есть)
	var okak = $"%UI/Dethscreen/AudioStreamPlayer"
	if okak:
		okak.play()
	
	# Отключаем коллизии
	if body_shape:
		body_shape.disabled = true
	
	# Показываем экран смерти
	death_bg.visible = true
	death_screen.visible = true
	
	# Отключаем ввод
	set_process_unhandled_input(false)
	
	# Запускаем таймер респауна
	current_state = CharacterState.RESPAWNING
	respawn_timer = respawn_delay

func character_respawned():
	"""Сигнал/событие респауна - можно переопределить в наследниках"""
	pass

# ========== ОЧКИ ==========
func add_score(points: int) -> void:
	score_label.text = str(int(score_label.text) + points)

# ========== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ==========
func _get_respawn_point() -> Vector3:
	# Поиск точек респауна
	var spawn_points = get_tree().get_nodes_in_group("respawn_points")
	if spawn_points.size() > 0:
		return spawn_points[randi() % spawn_points.size()].global_position
	
	# Если точек нет - текущая позиция
	print("No respawn points found, using current position")
	return global_position

func get_aim_position() -> Vector3:
	"""Возвращает позицию, куда смотрит камера"""
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
		health_bar.value = health

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
		invulnerability_effect.emitting = (invulnerability_timer > 0)

func _stop_all_sounds():
	"""Останавливает все звуки на персонаже"""
	for child in get_children(true):
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			child.stop()

# ========== МЕТОДЫ СОСТОЯНИЙ ==========
func is_character_alive() -> bool:
	return current_state == CharacterState.ALIVE

func can_take_damage() -> bool:
	return current_state == CharacterState.ALIVE and invulnerability_timer <= 0

func get_health_percentage() -> float:
	return float(health) / float(max_health)

func disable() -> void:
	current_state = CharacterState.DISABLED
	set_physics_process(false)

func enable() -> void:
	current_state = CharacterState.ALIVE
	set_physics_process(true)

func menu_state():
	"""Отключает управление и интерфейс для режима меню/выбора персонажа"""
	disable()  # Отключает physics process
	set_process_unhandled_input(false)  # Отключает ввод
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  # Показываем курсор
	
	# Прячем UI
	if UI:
		UI.visible = false
	
	# Останавливаем все звуки
	_stop_all_sounds()

# ========== ВИРТУАЛЬНЫЕ МЕТОДЫ ==========
func _custom_ready() -> void:
	"""Переопределяется в наследниках"""
	pass

func _custom_physics_process(_delta: float) -> void:
	"""Переопределяется в наследниках"""
	pass
