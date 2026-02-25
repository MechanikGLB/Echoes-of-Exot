extends Area3D

signal hit_enemy(enemy: CharacterBase)

var already_hit: Array = []  # Чтобы не ударить одного врага дважды
var damage_amount: int = 0
var knockup_enabled: bool = false
var owner_character: CharacterBase

func _ready():
	# Находим владельца (поднимаемся по дереву)
	owner_character = _find_owner_character()
	
	# Подключаем сигналы
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Настраиваем коллизию
	collision_layer = 0  # Меч не участвует в коллизиях
	collision_mask = 2   # Видит хитбоксы (слой 2)

func _find_owner_character() -> CharacterBase:
	var node = get_parent()
	while node:
		if node is CharacterBase:
			return node
		node = node.get_parent()
	return null

func _on_area_entered(area: Area3D):
	# Проверяем, что это Body_part врага
	var parent = area.get_parent()
	if parent is CharacterBase:
		_check_hit(parent, area)

func _on_body_entered(body: Node3D):
	if body is CharacterBase:
		_check_hit(body, null)

func _check_hit(character: CharacterBase, hit_area: Area3D = null):
	# Проверка: не бьем себя
	if character == owner_character:
		return
	
	# Проверка: не били ли уже в этом ударе
	if character in already_hit:
		return
	
	# Проверка по командам с новой логикой
	if not _is_valid_target(character):
		return
	
	# Все проверки пройдены
	already_hit.append(character)
	
	# Расчет урона с учетом мультипликатора части тела
	var final_damage = damage_amount
	if hit_area and hit_area.has_method("get_damage_mult"):
		final_damage = int(damage_amount * hit_area.damage_mult)
	elif hit_area and hit_area.has_signal("body_part_hit"):
		# Используем сигнал Body_part если он есть
		hit_area.hit(damage_amount)
		return  # Урон уже нанесен через сигнал
	
	# Наносим урон
	if character.has_method("take_damage"):
		var direction = Vector3.ZERO
		if knockup_enabled:
			direction = (character.global_position - owner_character.global_position).normalized()
		
		character.take_damage(final_damage, direction)
		
		if knockup_enabled and character.has_method("knockup"):
			character.knockup(1.9)
	
	emit_signal("hit_enemy", character)

func _is_valid_target(target: CharacterBase) -> bool:
	"""Проверка, можно ли атаковать цель по командной принадлежности"""
	if not owner_character or not target:
		return false
	
	# Команда 0 - общие враги
	if owner_character.team == 0:
		# Враги команды 0 атакуют всех, кроме себя
		return target.team != 0
	
	if target.team == 0:
		# Все атакуют общих врагов (команда 0)
		return true
	
	# Игроки разных команд атакуют друг друга
	return owner_character.team != target.team

func start_attack(damage: int, should_knockup: bool = false):
	already_hit.clear()
	damage_amount = damage
	knockup_enabled = should_knockup
	monitoring = true
	print("Sword attack started - damage: ", damage, " knockup: ", should_knockup)

func stop_attack():
	monitoring = false
	already_hit.clear()
	print("Sword attack stopped")
