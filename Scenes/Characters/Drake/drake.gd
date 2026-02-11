extends CharacterBase3D

func _custom_ready() -> void:
	_setup_abilities()
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
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 10.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 10.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)
