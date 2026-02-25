extends AbilityResource

@export_category("Ability Settings")
@export var damage_step1: int = 64
@export var damage_step2: int = 399
@export var damage_step3: int = 72
@export var knockup_duration: float = 1.9
@export var attack_range: float = 3.0
@export var attack_angle: float = 90.0

func _apply_instant_effect():
	if not owner or not owner is CharacterBase:
		return
	
	# Сохраняем текущий шаг до увеличения
	var current_step = owner.combo_step
	
	# Переключаем на следующий удар
	if owner.has_method("advance_combo"):
		owner.advance_combo()
	
	# Наносим урон в зависимости от шага
	match current_step:
		0:
			_apply_damage(damage_step1)
		1:
			_apply_damage(damage_step2)
		2:
			_apply_damage(damage_step3)
			_apply_knockup()

func _apply_damage(damage: int):
	# owner доступен из базового класса
	if not owner:
		return
		
	# Получаем направление камеры
	var direction = -owner.camera.global_transform.basis.z
	
	# Ищем цели в конусе
	var targets = _get_targets_in_cone(direction, attack_angle, attack_range)
	
	for target in targets:
		if target.has_method("take_damage"):
			target.take_damage(damage)

func _apply_knockup():
	if not owner:
		return
		
	# Подбрасываем врагов после третьего удара
	var direction = -owner.camera.global_transform.basis.z
	var targets = _get_targets_in_cone(direction, attack_angle, attack_range)
	
	for target in targets:
		if target.has_method("knockup"):
			target.knockup(knockup_duration)

func _get_targets_in_cone(direction: Vector3, angle: float, max_dist: float) -> Array:
	if not owner:
		return []
		
	# Если у owner есть метод get_targets_in_cone - используем его
	if owner.has_method("get_targets_in_cone"):
		return owner.get_targets_in_cone(direction, angle, max_dist)
	
	# Иначе своя простая реализация
	var result = []
	var space_state = owner.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = max_dist
	query.shape = sphere
	query.transform = Transform3D(Basis(), owner.global_position)
	query.exclude = [owner]
	
	var targets = space_state.intersect_shape(query)
	for target in targets:
		var collider = target.collider
		if collider is CharacterBase:
			var to_target = (collider.global_position - owner.global_position).normalized()
			if direction.dot(to_target) > cos(deg_to_rad(angle / 2)):
				result.append(collider)
	
	return result
