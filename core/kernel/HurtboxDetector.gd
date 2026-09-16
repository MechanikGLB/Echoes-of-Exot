extends Area3D

var already_hit: Array = []
var damage_amount: int = 0
var knockup_enabled: bool = false
var owner_character: Node3D

func _ready():
	owner_character = _find_owner_character()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2

func _find_owner_character() -> Node3D:
	var node = get_parent()
	while node:
		if node.is_in_group("player") or node.is_in_group("enemy") or node.has_method("take_damage"):
			return node
		node = node.get_parent()
	return null

func _on_area_entered(area: Area3D):
	var node = area.get_parent()
	while node:
		if node.has_method("take_damage") or node.is_in_group("hittable") or node.is_in_group("destructible"):
			_check_hit(node)
			return
		node = node.get_parent()

func _on_body_entered(body: Node3D):
	var node = body
	while node:
		if node.has_method("take_damage") or node.is_in_group("hittable") or node.is_in_group("destructible"):
			_check_hit(node)
			return
		node = node.get_parent()

func _check_hit(node: Node3D):
	if node == owner_character:
		return
	if node in already_hit:
		return
	
	# Определяем, можно ли бить этот объект
	var can_hit = false
	
	# Игрок бьет врагов
	if owner_character and owner_character.is_in_group("player"):
		if node.is_in_group("enemy") or node.is_in_group("destructible"):
			can_hit = true
	
	# Враг бьет игрока
	elif owner_character and owner_character.is_in_group("enemy"):
		if node.is_in_group("player"):
			can_hit = true
	
	# Нейтральные объекты бьют всех?
	elif owner_character and owner_character.is_in_group("neutral"):
		if node.is_in_group("player") or node.is_in_group("enemy"):
			can_hit = true
	
	# Универсальные хиттаблы
	if node.is_in_group("hittable") or node.is_in_group("destructible"):
		can_hit = true
	
	if not can_hit:
		return
	
	already_hit.append(node)
	
	# Универсальная обработка урона
	if node.has_method("take_damage"):
		var direction = Vector3.ZERO
		if knockup_enabled and node.has_method("knockup"):
			direction = (node.global_position - owner_character.global_position).normalized()
		node.take_damage(damage_amount, direction)
		
		if knockup_enabled and node.has_method("knockup"):
			node.knockup(1.9)
	
	elif node.has_signal("damaged"):
		node.emit_signal("damaged", damage_amount, owner_character)
	
	elif node.is_in_group("destructible"):
		print("💥 Разрушаемый объект уничтожен")
		node.queue_free()

func start_attack(damage: int, should_knockup: bool = false):
	already_hit.clear()
	damage_amount = damage
	knockup_enabled = should_knockup
	monitoring = true

func stop_attack():
	monitoring = false
	already_hit.clear()
