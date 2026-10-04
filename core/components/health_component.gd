class_name HealthComponent extends Node

signal damaged(packet: DamagePacket, source: Node, hit_zone: String)
signal healed(amount: int)
signal health_changed(current: int, max: int)
signal died(killer: Node)
signal respawned

@export var max_health: int = 100
@export var invulnerability_time: float = 2.0
@export var respawn_delay: float = 5.0

# тип урона → множитель. 1.0 = без изменений, 0.5 = половина, 2.0 = двойной.
# отсутствующий тип в словаре трактуется как 1.0
@export var resistances: Dictionary = {}

var health: int = 100
var invulnerability_timer: float = 0.0
var respawn_timer: float = 0.0

func _ready():
	health = max_health

func _process(delta):
	if invulnerability_timer > 0:
		invulnerability_timer -= delta
	if respawn_timer > 0:
		respawn_timer -= delta
		if respawn_timer <= 0:
			respawn()

# основной вход для нового кода
func take_damage_packet(packet: DamagePacket, source: Node = null, hit_zone: String = "body") -> void:
	if not is_alive() or invulnerability_timer > 0:
		return
	if packet == null or packet.is_empty():
		return

	var final_damage := _apply_resistances(packet)
	if final_damage <= 0:
		return

	health = max(0, health - final_damage)
	health_changed.emit(health, max_health)
	damaged.emit(packet, source, hit_zone)

	if health <= 0:
		kill(source)

# обёртка для старого кода, который передаёт int
func take_damage(amount: int, source: Node = null, hit_zone: String = "body") -> void:
	var packet := DamagePacket.new()
	packet.add(DamageType.Kind.PHYSICAL, amount)
	take_damage_packet(packet, source, hit_zone)

func heal(amount: int) -> void:
	if not is_alive():
		return
	health = min(max_health, health + amount)
	health_changed.emit(health, max_health)
	healed.emit(amount)

func kill(killer: Node = null) -> void:
	if not is_alive():
		return
	health = 0
	died.emit(killer)
	respawn_timer = respawn_delay

func respawn() -> void:
	health = max_health
	invulnerability_timer = invulnerability_time
	health_changed.emit(health, max_health)
	respawned.emit()

func is_alive() -> bool:
	return health > 0

func can_take_damage() -> bool:
	return is_alive() and invulnerability_timer <= 0

func get_health() -> int:
	return health

func get_max_health() -> int:
	return max_health

func get_health_percent() -> float:
	return float(health) / float(max_health) if max_health > 0 else 0.0

func _apply_resistances(packet: DamagePacket) -> int:
	var total := 0
	for entry in packet.entries:
		var mult := 1.0
		if resistances.has(entry.type):
			mult = resistances[entry.type]
		total += int(round(entry.amount * mult))
	return total
