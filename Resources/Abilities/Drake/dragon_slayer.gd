extends AbilityResource

func _ready():
	effect_type = EffectApplicationType.ANIMATION_FRAME
	hit_frame = 0

func _on_hit_frame():
	#if owner and owner.has_method("advance_combo"):
		#owner.advance_combo()
	_finish_ability()
