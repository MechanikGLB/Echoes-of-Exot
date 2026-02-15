extends CharacterBase

func _setup_abilities():
	# Добавляем способности Дрейка
	add_ability("primary_fire", "primary_fire", 0.5, true)  # Огненное дыхание
	add_ability("ability_1", "ability_1", 3.0, false)      # Рывок крыльями
	# и т.д.

func _ability_primary():
	# Реализация огненного дыхания
	pass

func _ability_1(_target_position: Vector3):
	# Реализация рывка
	pass

func _custom_physics_process(_delta: float):
	pass
	# Уникальная логика Дрейка (например, планирование)
	#if not is_on_floor() and Input.is_action_pressed("glide"):
		#gravity = 2.0  # Замедленное падение
	#else:
		#gravity = 9.8
