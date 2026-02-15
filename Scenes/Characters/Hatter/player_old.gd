extends CharacterBase3D

# Weapons
enum Weapons {
	PRIMARY,
	SECONDARY,
}
var current_weapon = Weapons.PRIMARY
var can_shoot = true

# Weapon instances
@onready var bullet = load("res://scenes/parts/bullet.tscn")
@onready var bullet_trail = load("res://Scenes/parts/bullet_trail.tscn")

# Components
@onready var aim_ray = $Head/Camera3D/AimRay
@onready var aim_ray_end = $Head/Camera3D/AimRayEnd

# Sounds
@onready var steps = $AudioStreamPlayer3D
@onready var pistl = $Head/Camera3D/PPGun1/AudioStreamPlayer3D

# Guns
@onready var gun_anim = $Head/Camera3D/PlasmaGun1/AnimationPlayer
@onready var pp_anim = $Head/Camera3D/PPGun1/AnimationPlayer
@onready var gun_barrel = $Head/Camera3D/PlasmaGun1/RayCast3D
@onready var pp_barrel = $Head/Camera3D/PPGun1/Meshes/Barrel
@onready var weapon_switching = $Head/Camera3D/weaponSwitch

# Переменные для совместимости
#var respawn_position = Vector3.ZERO



func _custom_ready() -> void:

	_setup_abilities()
	#respawn_position = global_position
	health_bar.value = health
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Настройка видимости для сетевой игры
	for child in $BodyShape.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)
	
	clock.start()

func _custom_physics_process(_delta: float) -> void:
	pass

func _handle_movement(delta: float) -> void:
	if not is_character_alive() or current_state == CharacterState.RESPAWNING:
		return
	
	# Прыжок
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	
	# Спринт
	if Input.is_action_pressed("sprint"):
		speed = sprint_speed
	else:
		speed = walk_speed
	
	# Получение направления движения
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Применение движения
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

# ========== СПОСОБНОСТИ ==========

func _ability_primary() -> void:
	# Основная атака - плазменная пушка
	if can_shoot:
		match current_weapon:
			Weapons.PRIMARY:
				_shoot_gun()
			Weapons.SECONDARY:
				_shoot_auto()

func _ability_secondary(_target_position: Vector3) -> void:
		pass

func _ability_1(_target_position: Vector3) -> void:
	# Q - переключение оружия
	_switch_weapon()

func _ability_2(_target_position: Vector3) -> void:
	# E - дополнительная способность (заглушка)
	pass

func _ability_ultimate(_target_position: Vector3) -> void:
	# Ультимативная способность (заглушка)
	pass

# ========== СИСТЕМА ОРУЖИЯ ==========

func _shoot_gun():
	if not gun_anim.is_playing():
		gun_anim.play("shoot")
		var instance = bullet.instantiate()
		instance.position = gun_barrel.global_position
		get_parent().add_child(instance) 
		if aim_ray.is_colliding():
			instance.set_velocity(aim_ray.get_collision_point())
		else: 
			instance.set_velocity(aim_ray_end.global_position)

func _shoot_auto():
	if not pp_anim.is_playing():
		pp_anim.play("shoot")
		pistl.play()
		var instance = bullet_trail.instantiate()
		if aim_ray.is_colliding():
			instance.init(pp_barrel.global_position, aim_ray.get_collision_point())
			get_parent().add_child(instance)
			if aim_ray.get_collider().is_in_group("enemy"):
				aim_ray.get_collider().hit(15)
				instance.trigger_particles(aim_ray.get_collision_point(),
											pp_barrel.global_position, true)
			else:
				instance.trigger_particles(aim_ray.get_collision_point(),
											pp_barrel.global_position, false)
		else:
			instance.init(pp_barrel.global_position, aim_ray_end.global_position)
			get_parent().add_child(instance)

func _switch_weapon():
	if current_weapon == Weapons.PRIMARY:
		_raise_weapon(Weapons.SECONDARY)
	else:
		_raise_weapon(Weapons.PRIMARY)

func _lower_weapon():
	match current_weapon:
		Weapons.PRIMARY:
			weapon_switching.play("plasma_lower")
		Weapons.SECONDARY:
			weapon_switching.play("pp_lower")

func _raise_weapon(new_weapon):
	can_shoot = false
	_lower_weapon()
	await get_tree().create_timer(0.4).timeout
	match new_weapon:
		Weapons.PRIMARY:
			weapon_switching.play_backwards("plasma_lower")
		Weapons.SECONDARY:
			weapon_switching.play_backwards("pp_lower")
	current_weapon = new_weapon
	can_shoot = true

# ========== МЕТОДЫ ДЛЯ СОВМЕСТИМОСТИ ==========

func get_is_alive() -> bool:
	return is_character_alive()

func get_is_respawning() -> bool:
	return current_state == CharacterState.RESPAWNING
