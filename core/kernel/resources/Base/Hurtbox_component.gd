class_name HurtboxComponent extends Node

signal hit_received(packet: DamagePacket, source: Node, zone: String)

# подстрока в имени hurtbox → зона
# регистр не важен, ищем первое совпадение
const ZONE_KEYWORDS := {
	"head": "head",
	"torso": "body",
	"body": "body",
	"leg": "limb",
	"arm": "limb",
	"hand": "limb",
	"foot": "limb",
	"stup": "limb",
}

@onready var _health: HealthComponent = get_parent().get_node_or_null("HealthComponent")

# hurtbox Area3D → имя зоны
var _hurtboxes: Dictionary = {}

func _ready():
	_collect(get_parent())
	if _hurtboxes.is_empty():
		push_warning("HurtboxComponent: не найдено ни одного hurtbox-узла")

func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is Area3D and "HitBox" in child.name:
			var zone := _determine_zone(child.name)
			if zone != "":
				_hurtboxes[child] = zone
		_collect(child)

func _determine_zone(area_name: String) -> String:
	var lower := area_name.to_lower()
	for keyword in ZONE_KEYWORDS:
		if keyword in lower:
			return ZONE_KEYWORDS[keyword]
	return ""

# вызывается атакующим, когда hurtbox попал под удар
func receive_hit(packet: DamagePacket, source: Node, hit_area: Area3D) -> void:
	if not _hurtboxes.has(hit_area):
		return
	var zone: String = _hurtboxes[hit_area]
	hit_received.emit(packet, source, zone)
	if _health:
		_health.take_damage_packet(packet, source, zone)

# получить зону по узлу — на случай если атакующий хочет знать заранее
func get_zone(area: Area3D) -> String:
	return _hurtboxes.get(area, "")

# для отладки — сколько hurtbox'ов нашли
func get_hurtbox_count() -> int:
	return _hurtboxes.size()
