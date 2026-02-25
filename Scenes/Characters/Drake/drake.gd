extends CharacterBase

# Для серии ударов ЛКМ
var combo_step: int = 0
var combo_timer: float = 0.0
var combo_reset_time: float = 2.0  # Время до сброса комбо

# Для заряженной атаки
var is_charging: bool = false
var charge_time: float = 0.0
var max_charge_time: float = 1.5

func _ready():
	# Важно! Вызываем родительский _ready
	super()
	
	# Здесь можно добавить инициализацию, специфичную для Дрейка
	combo_step = 0

func _custom_physics_process(delta: float):
	
	# Таймер сброса комбо
	if combo_step > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_step = 0
	
	# Обработка заряженной атаки
	if is_charging:
		charge_time += delta
		if charge_time >= max_charge_time:
			_trigger_charged_attack()

# Переопределяем метод получения позиции для снарядов
func get_projectile_spawn_position() -> Vector3:
	# Для Дрейка можно использовать позицию меча
	if has_node("SwordTip"):
		return $SwordTip.global_position
	return camera.global_position

# Вспомогательные методы для комбо
func advance_combo() -> void:
	combo_step = (combo_step + 1) % 3
	combo_timer = combo_reset_time
	
	# Запускаем соответствующую анимацию
	match combo_step:
		0:
			animation_player.play("attack1")
		1:
			animation_player.play("attack2")
		2:
			animation_player.play("attack3")

func reset_combo() -> void:
	combo_step = 0
	combo_timer = 0.0

func _trigger_charged_attack():
	# Срабатывает когда зарядка достигла максимума
	is_charging = false
	charge_time = 0.0
	# Здесь логика заряженной атаки
	animation_player.play("sword_charged")
	# Наносим урон и т.д.

# Методы для способностей (будут вызываться из ресурсов)
func apply_damage_in_cone(damage: int, angle: float, max_distance: float) -> void:
	# Поиск целей в конусе перед персонажем
	var direction = -camera.global_transform.basis.z
	var targets = get_targets_in_cone(direction, angle, max_distance)
	
	for target in targets:
		if target.has_method("take_damage"):
			target.take_damage(damage)

func get_targets_in_cone(direction: Vector3, angle: float, max_distance: float) -> Array:
	# Возвращает массив целей в конусе
	var result = []
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = max_distance
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	query.exclude = [self]
	
	var targets = space_state.intersect_shape(query)
	for target in targets:
		var collider = target.collider
		if collider is CharacterBase:
			var to_target = (collider.global_position - global_position).normalized()
			if direction.dot(to_target) > cos(deg_to_rad(angle / 2)):
				result.append(collider)
	
	return result
