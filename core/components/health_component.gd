class_name HealthComponent extends Node

signal damaged(amount: int, source: Node, hit_zone: String)
signal healed(amount: int)
signal health_changed(current: int, max: int)
signal died(killer: Node)
signal respawned

@export var max_health: int = 100
@export var invulnerability_time: float = 2.0
@export var respawn_delay: float = 5.0

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

func take_damage(amount: int, source: Node = null, hit_zone: String = "body") -> void:
	if not is_alive() or invulnerability_timer > 0:
		return
	health = max(0, health - amount)
	health_changed.emit(health, max_health)
	damaged.emit(amount, source, hit_zone)
	if health <= 0:
		kill(source)

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
