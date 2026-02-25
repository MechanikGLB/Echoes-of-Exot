extends AbilityResource

@export_category("Ability Settings")
@export var damage_step1: int = 64
@export var damage_step2: int = 399
@export var damage_step3: int = 72

func _ready():
	effect_type = EffectApplicationType.ANIMATION_FRAME
	hit_frame = 0

func _on_hit_frame():
	# Просто запускаем комбо, урон через Area3D на мече
	if owner and owner.has_method("advance_combo"):
		owner.advance_combo()
	_finish_ability()
