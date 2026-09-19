class_name DamagePacket
extends Resource

@export var entries: Array[DamageEntry] = []

func add(type: DamageType.Kind, amount: int) -> void:
	var e := DamageEntry.new()
	e.type = type
	e.amount = amount
	entries.append(e)

func get_amount_of(type: DamageType.Kind) -> int:
	var total := 0
	for e in entries:
		if e.type == type:
			total += e.amount
	return total

func get_total() -> int:
	var total := 0
	for e in entries:
		total += e.amount
	return total

func is_empty() -> bool:
	return entries.is_empty()
