class_name CharacterBase3D
extends CharacterBody3D

const SENS = 0.002

# Head bobbing
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

# FOV 
const BASE_FOV = 90
const FOV_CHANGE = 1.5

# Сетевые настройки
@export_category("Network Settings")
@export var is_network_ready: bool = false
@export var sync_rate: float = 30.0

# Базовые настройки персонажа
@export_category("Character Settings")
@export var max_health: int = 100
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 5.5  
@export var gravity: float = 9.8
@export var HIT_STAGGER = 2.0
var speed = walk_speed

# Настройки респауна
@export_category("Respawn Settings")
@export var respawn_delay: float = 5.0 
@export var invulnerability_time: float = 2.0

# Настройки команд
@export_category("Team Settings")
@export var available_teams: int = 2

# Настройки системы способностей
@export_category("Ability System")
@export var abilities_config: Dictionary = {
	"primary_fire": {"input_action": "primary_fire", "cooldown": 0.1, "type": "instant", "holdable": true},
	"secondary_fire": {"input_action": "secondary_fire", "cooldown": 0.5, "type": "instant", "holdable": true},
	"ability_1": {"input_action": "ability_1", "cooldown": 6.0, "type": "mobility"},
	"ability_2": {"input_action": "ability_2", "cooldown": 8.0, "type": "utility"},
	"ultimate": {"input_action": "ultimate", "cooldown": 0.0, "type": "ultimate", "charge_required": 100}
}

# UI
@onready var UI = $"%UI"
@onready var health_bar = $"%UI/Stat_base/Health"
@onready var ingame_menu = $"%UI/CanvasLayer"
@onready var timer_label = $"%UI/Dethscreen/RespawnTime"
@onready var death_screen = $"%UI/Dethscreen"
@onready var clock = $"%UI/sessionTimer/clock"
@onready var score_label = $"%UI/Stat_base/HBoxContainer2/Score"
@onready var death_bg = $"%UI/okak"

@onready var okak = $"%UI/Dethscreen/AudioStreamPlayer"

# Константы для входных действий (исправлено - используем Dictionary вместо enum)
const InputActions = {
	"PRIMARY_FIRE": "primary_fire",
	"SECONDARY_FIRE": "secondary_fire", 
	"ABILITY_1": "ability_1",
	"ABILITY_2": "ability_2", 
	"ULTIMATE": "ultimate"
}

# Состояния персонажа
enum CharacterState { 
	ALIVE, 
	DEAD, 
	DISABLED, 
	RESPAWNING, 
	INVULNERABLE,
	USING_ABILITY 
}

var current_state: CharacterState = CharacterState.ALIVE

# Сетевые переменные
var network_id: int = -1
var player_name: String = "Player"
var health: int = 100
var score: int = 0
var team: int = 0
var ping: int = 0

# Система способностей
var ability_cooldowns: Dictionary = {}
var ultimate_charge: float = 0.0

# Временные переменные
var respawn_timer: float = 0.0
var invulnerability_timer: float = 0.0
var last_sync_time: float = 0.0

# Компоненты
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var body_shape: CollisionShape3D = $BodyShape

# Визуальные эффекты
@onready var damage_flash: ColorRect = get_node_or_null("%UI/DamageFlash")
@onready var invulnerability_effect: GPUParticles3D = get_node_or_null("InvulnerabilityEffect")

# Сигналы
signal health_changed(old_value: int, new_value: int, attacker_id: int)
signal character_died(killer_id: int)
signal character_respawned()
signal score_changed(new_score: int)
signal state_changed(new_state: CharacterState)
signal position_synced(new_position: Vector3)
signal ability_used(ability_name: String, target_position: Vector3)
signal ultimate_changed(new_charge: float)
signal team_changed(old_team: int, new_team: int)

# Сигналы
signal player_hit

# Сетевые данные для репликации
var network_data: Dictionary = {
	"position": Vector3.ZERO,
	"rotation": Vector3.ZERO,
	"velocity": Vector3.ZERO,
	"health": 100,
	"state": CharacterState.ALIVE,
	"animation": "",
	"timestamp": 0.0,
	"team": 0,
	"ultimate_charge": 0.0,
	"abilities_state": {}
}

func _ready() -> void:
	# Инициализация имени игрока
	if GlobalThings and GlobalThings.has_method("get_player_name"):
		player_name = GlobalThings.player_name
	else:
		player_name = "Player_" + str(multiplayer.get_unique_id())
	
	health = max_health
	_setup_abilities()
	_update_ui()
	
	if is_network_ready:
		_setup_network()
	_custom_ready()

## Для добавления чего либо в ready в дочерних классах
func _custom_ready() -> void:
	pass

func _setup_network() -> void:
	if network_id != -1:
		set_multiplayer_authority(network_id)

func _setup_abilities() -> void:
	# Инициализация системы способностей
	for ability_name in abilities_config:
		ability_cooldowns[ability_name] = 0.0

## Можно переопределить в дочерних physics_process
func _custom_physics_process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if current_state == CharacterState.DEAD or current_state == CharacterState.DISABLED:
		return
	
	_update_timers(delta)
	_update_ability_cooldowns(delta)
	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_abilities_input()
	_custom_physics_process(delta)
	
	if is_network_ready and _should_sync():
		_sync_network_data()
	
	move_and_slide()

func _update_timers(delta: float) -> void:
	# Таймер респауна
	if current_state == CharacterState.RESPAWNING:
		respawn_timer -= delta
		update_respawn_timer(respawn_timer)
		
		if respawn_timer <= 0:
			print("Timer finished, calling respawn()")
			respawn()
	
	# Таймер неуязвимости
	if invulnerability_timer > 0:
		invulnerability_timer -= delta

func _update_ability_cooldowns(delta: float) -> void:
	# Обновление кулдаунов способностей
	for ability_name in ability_cooldowns:
		if ability_cooldowns[ability_name] > 0:
			ability_cooldowns[ability_name] = max(0, ability_cooldowns[ability_name] - delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _handle_movement(_delta: float) -> void:
	# Базовое движение - переопределяется в дочерних классах
	pass

func _handle_abilities_input() -> void:
	if current_state != CharacterState.ALIVE:
		return
	
	# Обработка ввода для всех способностей
	for ability_name in abilities_config:
		var config = abilities_config[ability_name]
		if ability_cooldowns[ability_name] <= 0:
			# Для зажимаемых способностей используем is_action_pressed, для остальных - is_action_just_pressed
			if config.get("holdable", false):
				if Input.is_action_pressed(config.input_action):
					_use_ability(ability_name)
			else:
				if Input.is_action_just_pressed(config.input_action):
					_use_ability(ability_name)

func _use_ability(ability_name: String) -> void:
	var config = abilities_config[ability_name]
	
	# Проверка ульты
	if ability_name == "ultimate" and not can_use_ultimate():
		return
	
	# Сетевой вызов способности
	if is_network_ready:
		# Только authority может инициировать способности
		if is_multiplayer_authority():
			rpc("_execute_ability", ability_name, get_aim_position())
	else:
		_execute_ability(ability_name, get_aim_position())
	
	# Применение затрат (ТОЛЬКО ДЛЯ AUTHORITY)
	if is_multiplayer_authority() or not is_network_ready:
		if ability_name == "ultimate":
			ultimate_charge = 0.0
			ultimate_changed.emit(ultimate_charge)
		
		# Для зажимаемых способностей не применяем кулдаун автоматически
		if not config.get("holdable", false):
			ability_cooldowns[ability_name] = config.cooldown
	
	ability_used.emit(ability_name, get_aim_position())

@rpc("any_peer", "call_local", "reliable")
func _execute_ability(ability_name: String, target_position: Vector3) -> void:
	# Базовые реализации - переопределяются в дочерних классах
	match ability_name:
		"primary_fire":
			_ability_primary()
		"secondary_fire":
			_ability_secondary(target_position)
		"ability_1":
			_ability_1(target_position)
		"ability_2":
			_ability_2(target_position)
		"ultimate":
			_ability_ultimate(target_position)

# Виртуальные методы для способностей - переопределяются в дочерних классах
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

# ========== СИСТЕМА УЛЬТЫ ==========

func add_ultimate_charge(amount: float) -> void:
	if current_state != CharacterState.ALIVE:
		return
	
	var old_charge = ultimate_charge
	ultimate_charge = min(ultimate_charge + amount, 100.0)
	
	if ultimate_charge != old_charge:
		ultimate_changed.emit(ultimate_charge)
		
		# Синхронизация ульты по сети
		if is_network_ready and is_multiplayer_authority():
			rpc("sync_ultimate_charge", ultimate_charge)

@rpc("any_peer", "call_local", "reliable")
func sync_ultimate_charge(new_charge: float) -> void:
	ultimate_charge = new_charge
	ultimate_changed.emit(ultimate_charge)

func get_ultimate_percentage() -> float:
	return ultimate_charge / 100.0

func can_use_ultimate() -> bool:
	return ultimate_charge >= 100.0 and ability_cooldowns["ultimate"] <= 0

# ========== СЕТЕВЫЕ МЕТОДЫ ==========

func _should_sync() -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - last_sync_time) >= (1.0 / sync_rate)

func _sync_network_data() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Сбор данных для синхронизации
	var abilities_state = {}
	for ability_name in ability_cooldowns:
		abilities_state[ability_name] = ability_cooldowns[ability_name]
	
	network_data = {
		"position": global_position,
		"rotation": Vector3(rotation.x, rotation.y, rotation.z),
		"velocity": velocity,
		"health": health,
		"state": current_state,
		"animation": _get_current_animation(),
		"timestamp": current_time,
		"ping": ping,
		"team": team,
		"ultimate_charge": ultimate_charge,
		"abilities_state": abilities_state
	}
	
	last_sync_time = current_time
	position_synced.emit(global_position)

@rpc("any_peer", "call_local", "reliable")
func sync_character_data(data: Dictionary) -> void:
	if not is_network_ready:
		return
	
	# Только не-authority клиенты интерполируют позицию
	if not is_multiplayer_authority():
		global_position = _interpolate_position(global_position, data.position)
		rotation = Vector3(data.rotation.x, data.rotation.y, data.rotation.z)
		velocity = data.velocity
	
	# Обновление состояния (для всех)
	if data.state != current_state:
		_set_state(data.state)
	
	# Обновление здоровья (для всех)
	if data.health != health:
		var old_health = health
		health = data.health
		_update_health_ui()
		
		if health < old_health and not is_multiplayer_authority():
			_show_damage_effect()
	
	# Обновление команды
	if data.get("team", team) != team:
		set_team(data.team)
	
	# Обновление ульты
	if data.get("ultimate_charge", ultimate_charge) != ultimate_charge:
		ultimate_charge = data.ultimate_charge
		ultimate_changed.emit(ultimate_charge)
	
	# Синхронизация способностей
	if "abilities_state" in data:
		for ability_name in data.abilities_state:
			if ability_name in ability_cooldowns:
				ability_cooldowns[ability_name] = data.abilities_state[ability_name]

func _interpolate_position(current: Vector3, target: Vector3) -> Vector3:
	return current.lerp(target, 0.5)

func _get_current_animation() -> String:
	# Переопределяется в дочерних классах
	return ""

# ========== СИСТЕМА ЗДОРОВЬЯ И УРОНА ==========

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int, direction: Vector3 = Vector3.ZERO, hit_stagger: float = 1.0, attacker_id: int = -1) -> void:
	# Только сервер/authority обрабатывает урон
	if not is_multiplayer_authority():
		return
		
	if current_state != CharacterState.ALIVE or invulnerability_timer > 0:
		return
	
	var old_health = health
	health = max(0, health - amount)
	
	health_changed.emit(old_health, health, attacker_id)
	_update_health_ui()
	_show_damage_effect()
	
	# Генерация ульты от полученного урона
	add_ultimate_charge(amount * 0.5)
	
	# Эффект отдачи
	if direction != Vector3.ZERO:
		velocity += direction * hit_stagger
	
	if health <= 0:
		die(attacker_id)

# Метод для нанесения урона (вызывается другими сущностями)
func apply_damage(amount: int, attacker: CharacterBase3D) -> void:
	if is_network_ready:
		# В multiplayer только authority применяет урон
		if is_multiplayer_authority():
			take_damage(amount, Vector3.ZERO, 1.0, attacker.network_id)
	else:
		take_damage(amount, Vector3.ZERO, 1.0, -1)

@rpc("any_peer", "call_local", "reliable")
func die(killer_id: int = -1) -> void:
	if current_state == CharacterState.DEAD:
		return
	
	current_state = CharacterState.DEAD
	character_died.emit(killer_id)
	_on_death()

func respawn(respawn_position: Vector3 = Vector3.ZERO) -> void:
	print("respawn() CALLED - current state: ", current_state)
	
	if current_state != CharacterState.DEAD and current_state != CharacterState.RESPAWNING:
		print("WARNING: Respawn called but state is not DEAD or RESP! State: ", current_state)

	
	current_state = CharacterState.ALIVE
	invulnerability_timer = invulnerability_time
	
	# Если позиция НЕ указана (Vector3.ZERO) - используем случайную точку
	if respawn_position == Vector3.ZERO:
		global_position = _get_respawn_point()
		print("Respawning at random point: ", global_position)
	else:
		# Если позиция указана - используем её
		global_position = respawn_position
		print("Respawning at specific position: ", global_position)
	
	velocity = Vector3.ZERO
	health = max_health
	
	health_changed.emit(0, health, -1)
	character_respawned.emit()
	_update_ui()
	
	if invulnerability_effect:
		invulnerability_effect.emitting = true
	
	if body_shape:
		body_shape.disabled = false
		body_shape.visible = true
	
	death_bg.visible = false
	death_screen.visible = false
	
	set_process_unhandled_input(true)
	set_physics_process(true)
	set_process(true)
	
	print("RESPAWN COMPLETED - new state: ", current_state)

# ========== СИСТЕМА ОЧКОВ И КОМАНД ==========

@rpc("any_peer", "call_local", "reliable")
func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)
	_update_score_ui()

@rpc("any_peer", "call_local", "reliable")
func set_team(new_team: int) -> void:
	var old_team = team
	team = clamp(new_team, 0, available_teams - 1)
	team_changed.emit(old_team, team)

# ========== ИНТЕРФЕЙС ==========

func _update_ui() -> void:
	_update_health_ui()
	_update_score_ui()
	#_update_name_ui()
	#_update_ping_ui()

# UI методы в базовом классе
func _update_health_ui() -> void:
	if health_bar:
		health_bar.value = health

func _update_score_ui() -> void:
	if score_label:
		score_label.text = str(score)

func update_respawn_timer(time_left: float) -> void:
	if timer_label:
		timer_label.text = "Возрождение через: %.1f" % time_left

func show_death_screen(should_show: bool, killer_name: String = "") -> void:
	if death_screen:
		death_screen.visible = should_show
	if death_bg:
		death_bg.visible = should_show

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

# В CharacterBase3D.gd
func show_hit_effect() -> void:
	if damage_flash:  # У вас уже есть damage_flash в базовом классе!
		damage_flash.visible = true
		var tween = create_tween()
		tween.tween_property(damage_flash, "color:a", 0.0, 0.3)
		tween.tween_callback(func(): 
			if damage_flash:
				damage_flash.visible = false
		)

func _unlock_cursor(is_locked: bool) -> void:
	if is_locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		set_process_unhandled_input(false)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		set_process_unhandled_input(true)		

# ========== ВИРТУАЛЬНЫЕ МЕТОДЫ ==========

func _on_death() -> void:
	
	okak.play()
	
	# Отключаем коллизии и видимость
	if body_shape:
		body_shape.disabled = true
		body_shape.visible = false
	
	death_bg.visible = true
	death_screen.visible = true
	
	# Отключаем ввод
	set_process_unhandled_input(false)
	show_death_screen(true)
	
	# респавн через заданное время
	if is_multiplayer_authority() or not is_network_ready:
		# Устанавливаем состояние RESPAWNING для таймера в _update_timers
		current_state = CharacterState.RESPAWNING
		respawn_timer = respawn_delay

# Вспомогательный метод для точек респауна
func _get_respawn_point() -> Vector3:
	print("=== DEBUG RESPAWN POINT SEARCH ===")
	
	# ДИАГНОСТИКА: Покажем всю структуру сцены
	print("Current scene root: ", get_tree().current_scene.name)
	print("Current node path: ", get_path())
	
	# Ищем RespawnPoints разными способами
	var spawn_points_node = null
	
	# СПОСОБ 1: Поиск по имени в текущей сцене
	spawn_points_node = get_tree().current_scene.find_child("RespawnPoints", true, false)
	print("Found by name in scene: ", spawn_points_node != null)
	
	# СПОСОБ 2: Поиск по абсолютному пути (попробуем разные варианты)
	var possible_paths = [
		"/root/Main/Map/RespawnPoints",
		"/root/Map/RespawnPoints", 
		"/root/RespawnPoints",
		"../RespawnPoints",
	    "../../RespawnPoints"
	]
	
	for path in possible_paths:
		var node = get_node_or_null(path)
		if node:
			print("Found at path: ", path)
			spawn_points_node = node
			break
		else:
			print("Not found at path: ", path)
	
	if not spawn_points_node:
		print("ERROR: RespawnPoints not found with any path!")
		print("Available nodes at /root/Main: ", get_node_or_null("/root/Main") != null)
		if get_node_or_null("/root/Main"):
			print("Children of /root/Main: ")
			for child in get_node("/root/Main").get_children():
				print("  - ", child.name, " (", child.get_class(), ")")
		return Vector3(0, 5, 0)
	
	# ⚠️ ВАЖНО: Этот код должен быть ДО return
	var all_spawn_points = spawn_points_node.get_children()
	print("Number of spawn points found: ", all_spawn_points.size())
	
	if all_spawn_points.is_empty():
		print("ERROR: No spawn points in RespawnPoints node!")
		return Vector3(0, 5, 0)
	
	# Показываем все точки
	for i in range(all_spawn_points.size()):
		var point = all_spawn_points[i]
		print("Point ", i, ": ", point.name, " at ", point.global_position)
	
	# Выбираем случайную точку
	var random_index = randi() % all_spawn_points.size()
	var selected_point = all_spawn_points[random_index]
	var respawn_position = selected_point.global_position
	
	print("SELECTED respawn point: ", selected_point.name, " at ", respawn_position)
	print("=== END DEBUG ===")
	
	return respawn_position
	
## Чтобы возродить персонажа в конкретной точке:
## Возрождение по имени точки
func respawn_at_specific_point(point_name: String):
	var spawn_points_node = get_node("/root/Main/Map/RespawnPoints")
	for point in spawn_points_node.get_children():
		if point.point_name == point_name:
			respawn(point.global_position)
			return
	
	# Если точка не найдена - используем обычный респаун
	respawn()

func get_aim_direction() -> Vector3:
	if camera:
		return -camera.global_transform.basis.z
	return -global_transform.basis.z

func get_aim_position() -> Vector3:
	if camera:
		return camera.global_position
	return global_position

func _set_state(new_state: CharacterState) -> void:
	var _old_state = current_state
	current_state = new_state
	state_changed.emit(new_state)

func _stop_all_sounds():
	for child in get_children(true):
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			child.stop()

# ========== ПУБЛИЧНЫЕ МЕТОДЫ ==========

func menu_state():
	disable()
	if UI:
		UI.visible = false
	_stop_all_sounds()

func enable() -> void:
	current_state = CharacterState.ALIVE
	set_physics_process(true)

func disable() -> void:
	current_state = CharacterState.DISABLED
	set_physics_process(false)

func is_character_alive() -> bool:
	return current_state == CharacterState.ALIVE

func can_take_damage() -> bool:
	return current_state == CharacterState.ALIVE and invulnerability_timer <= 0

func get_health_percentage() -> float:
	return float(health) / float(max_health)

func set_player_info(info: Dictionary) -> void:
	if "name" in info:
		player_name = info.name
	if "team" in info:
		team = info.team
	if "network_id" in info:
		network_id = info.network_id
	_update_ui()

# Методы для настройки способностей
func set_ability_cooldown(ability_name: String, cooldown: float) -> void:
	if ability_name in abilities_config:
		abilities_config[ability_name].cooldown = cooldown

func get_ability_cooldown(ability_name: String) -> float:
	return ability_cooldowns.get(ability_name, 0.0)

func is_ability_ready(ability_name: String) -> bool:
	return ability_cooldowns.get(ability_name, 0.0) <= 0

# ========== СЕТЕВЫЕ УТИЛИТЫ ==========

func is_local_player() -> bool:
	return network_id == multiplayer.get_unique_id()

func get_network_info() -> Dictionary:
	return {
		"network_id": network_id,
		"player_name": player_name,
		"team": team,
		"health": health,
		"score": score,
		"state": current_state,
		"position": global_position,
		"ping": ping,
		"ultimate_charge": ultimate_charge,
		"abilities": ability_cooldowns.duplicate()
	}
