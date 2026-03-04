extends Area3D

var already_hit: Array = []
var damage_amount: int = 0
var knockup_enabled: bool = false
var owner_character: CharacterBase

func _ready():
	owner_character = _find_owner_character()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2

func _find_owner_character() -> CharacterBase:
	var node = get_parent()
	while node:
		if node is CharacterBase:
			return node
		node = node.get_parent()
	return null

func _on_area_entered(area: Area3D):
	var parent = area.get_parent()
	if parent is CharacterBase:
		_check_hit(parent)

func _on_body_entered(body: Node3D):
	if body is CharacterBase:
		_check_hit(body)

func _check_hit(character: CharacterBase):
	if character == owner_character:
		return
	if character in already_hit:
		return
	if not owner_character or not owner_character.is_enemy(character):
		return
	
	already_hit.append(character)
	
	if character.has_method("take_damage"):
		var direction = Vector3.ZERO
		if knockup_enabled:
			direction = (character.global_position - owner_character.global_position).normalized()
		
		print("💥 ПОПАДАНИЕ! Урон: ", damage_amount, " по ", character.name)
		print("   ХП врага до: ", character.health)
		character.take_damage(damage_amount, direction)
		print("   ХП врага после: ", character.health)
		
		if knockup_enabled and character.has_method("knockup"):
			character.knockup(1.9)
			print("   + ПОДБРОС")


func start_attack(damage: int, should_knockup: bool = false):
	already_hit.clear()
	damage_amount = damage
	knockup_enabled = should_knockup
	monitoring = true

func stop_attack():
	monitoring = false
	already_hit.clear()
