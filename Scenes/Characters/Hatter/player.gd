extends CharacterBase

# ========== ОРУЖИЕ ==========
enum Weapons {
	PRIMARY,
	SECONDARY,
}
var current_weapon = Weapons.PRIMARY
var can_shoot = true

# Инстансы пуль - ПРАВИЛЬНЫЕ ПУТИ
@onready var bullet = load("res://scenes/parts/bullet.tscn")
@onready var bullet_trail = load("res://Scenes/parts/bullet_trail.tscn")

# Компоненты
@onready var aim_ray = $Head/Camera3D/AimRay
@onready var aim_ray_end = $Head/Camera3D/AimRayEnd

# Звуки
@onready var pistl = $Head/Camera3D/PPGun1/AudioStreamPlayer3D

# Пушки
@onready var gun_anim = $Head/Camera3D/PlasmaGun1/AnimationPlayer
@onready var pp_anim = $Head/Camera3D/PPGun1/AnimationPlayer
@onready var gun_barrel = $Head/Camera3D/PlasmaGun1/RayCast3D
@onready var pp_barrel = $Head/Camera3D/PPGun1/Meshes/Barrel
@onready var weapon_switching = $Head/Camera3D/weaponSwitch

# ========== ИНИЦИАЛИЗАЦИЯ ==========
func _custom_ready():
	# ВАЖНО: Эти настройки нужны для правильной работы!
	#_setup_abilities()
	health_bar.value = health
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Настройка видимости для камеры (чтобы не видеть себя)
	for child in $BodyShape.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)
	
	clock.start()
	
	# Устанавливаем начальное оружие
	current_weapon = Weapons.PRIMARY

#func _setup_abilities():
	## Регистрируем способности
	#add_ability("primary_fire", "primary_fire", 0.1, true)   # Основной огонь
	#add_ability("secondary_fire", "secondary_fire", 0.5, true) # Вторичный огонь
	#add_ability("ability_1", "ability_1", 0.4, false)       # Переключение оружия

# ========== ДВИЖЕНИЕ ==========
func _handle_movement(delta: float) -> void:
	super(delta)

# ========== СПОСОБНОСТИ ==========
func _ability_primary():
	if can_shoot:
		match current_weapon:
			Weapons.PRIMARY:
				_shoot_gun()
			Weapons.SECONDARY:
				_shoot_auto()

func _ability_secondary(_target_position: Vector3):
	pass

func _ability_1(_target_position: Vector3):
	_switch_weapon()

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
			var collision_point = aim_ray.get_collision_point()
			instance.init(pp_barrel.global_position, collision_point)
			get_parent().add_child(instance)
			
			var collider = aim_ray.get_collider()
			if collider and collider.is_in_group("enemy"):
				collider.hit(15)
				instance.trigger_particles(collision_point, pp_barrel.global_position, true)
			else:
				instance.trigger_particles(collision_point, pp_barrel.global_position, false)
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

# ========== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ==========
func get_is_alive() -> bool:
	return is_character_alive()

func get_is_respawning() -> bool:
	return current_state == CharacterState.RESPAWNING
