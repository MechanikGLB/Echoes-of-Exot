@tool
class_name CharacterActor
extends CharacterBase

# Компоненты. Могут отсутствовать — тогда их настройки не появятся в инспекторе.
@onready var movement: MovementComponent = get_node_or_null("MovementComponent")
@onready var health: HealthComponent = get_node_or_null("HealthComponent")
@onready var control: ControlComponent = get_node_or_null("ControlComponent")

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	super._ready()

# =========================================================
# Публичный API — фасад. Внешний код обращается к персонажу,
# не зная про внутренние компоненты.
# =========================================================

func take_damage(amount: int, direction: Vector3 = Vector3.ZERO) -> void:
	if not health:
		return
	if not health.can_take_damage():
		return

	# Отбрасывание живёт на персонаже, не на компоненте здоровья
	if direction != Vector3.ZERO:
		velocity += direction * hit_stagger

	health.take_damage(amount, null, "body")

func take_damage_packet(packet: DamagePacket, source: Node = null, hit_zone: String = "body") -> void:
	if not health:
		return
	health.take_damage_packet(packet, source, hit_zone)

func heal(amount: int) -> void:
	if health:
		health.heal(amount)

func kill(killer: Node = null) -> void:
	if health:
		health.kill(killer)

func is_alive() -> bool:
	return health.is_alive() if health else false

func get_health() -> int:
	return health.get_health() if health else 0

func get_health_percent() -> float:
	return health.get_health_percent() if health else 0.0

# =========================================================
# Динамический инспектор. Показывает настройки компонентов
# на корневом узле персонажа.
# =========================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	if movement:
		props.append({
			"name": "Movement",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
		})
		props.append({
			"name": "walk_speed",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,50,0.1",
		})
		props.append({
			"name": "sprint_speed",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,50,0.1",
		})
		props.append({
			"name": "jump_velocity",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,30,0.1",
		})
		props.append({
			"name": "gravity",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,50,0.1",
		})

	if health:
		props.append({
			"name": "Health",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
		})
		props.append({
			"name": "max_health",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1,10000,1",
		})
		props.append({
			"name": "invulnerability_time",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,10,0.1",
		})
		props.append({
			"name": "respawn_delay",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,30,0.1",
		})

	return props

func _get(property: StringName) -> Variant:
	if movement:
		match property:
			&"walk_speed": return movement.walk_speed
			&"sprint_speed": return movement.sprint_speed
			&"jump_velocity": return movement.jump_velocity
			&"gravity": return movement.gravity
	if health:
		match property:
			&"max_health": return health.max_health
			&"invulnerability_time": return health.invulnerability_time
			&"respawn_delay": return health.respawn_delay
	return null

func _set(property: StringName, value: Variant) -> bool:
	if movement:
		match property:
			&"walk_speed":
				movement.walk_speed = value
				return true
			&"sprint_speed":
				movement.sprint_speed = value
				return true
			&"jump_velocity":
				movement.jump_velocity = value
				return true
			&"gravity":
				movement.gravity = value
				return true
	if health:
		match property:
			&"max_health":
				health.max_health = value
				return true
			&"invulnerability_time":
				health.invulnerability_time = value
				return true
			&"respawn_delay":
				health.respawn_delay = value
				return true
	return false
