extends CharacterBase

# ========== КОМБО СИСТЕМА ==========
var combo_step: int = 0
var combo_timer: float = 0.0
var combo_reset_time: float = 1.2
var can_attack: bool = true

# ========== НОДЫ ==========
@onready var anim_tree = $AnimationTree
var _state_machine = null

@onready var hitbox_anim = $HitboxAnimPlayer
@onready var sword_hitbox = $blockbench_export/Drake/grudverx/armos/leftarm/leftarmniz/sword/weapon_1_v/SwordHitBox

# ========== ПОЛУЧЕНИЕ STATE_MACHINE ==========
func get_state_machine():
	if _state_machine == null and anim_tree != null:
		_state_machine = anim_tree.get("parameters/StateMachine/playback")
	return _state_machine

# ========== ИНИЦИАЛИЗАЦИЯ ==========
func _custom_ready():
	combo_step = 0
	team = 1
	
	if anim_tree:
		if get_tree().current_scene.name != "character_selection":
			anim_tree.active = true
		else:
			anim_tree.active = false
		
		anim_tree.animation_finished.connect(_on_animation_finished)
		get_state_machine()

func _custom_physics_process(delta: float):
	if combo_step > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			reset_combo()

# ========== УПРАВЛЕНИЕ ==========
func _input(event):
	super._input(event)
	
	if not anim_tree or not anim_tree.active:
		return
		
	if event.is_action_pressed("primary_fire"):
		print(">>> НАЖАТИЕ primary_fire от игрока")
		advance_combo()

# ========== СИСТЕМА КОМБО ==========
var debug_call_count = 0 #удалить позже, только для дебага
func advance_combo() -> void:
	print("=== advance_combo() ===")
	print("   can_attack = ", can_attack)
	print("   combo_step ДО = ", combo_step)
	
	if not can_attack:
		print("   → не можем атаковать, выходим")
		if combo_timer > 0:
			combo_timer = combo_reset_time
			anim_tree.set("parameters/combo_timer", combo_timer)
		return
	
	# ВАЖНО: сначала проигрываем анимацию текущего шага
	var anim_names = ["attack1", "attack2", "attack3"]
	var hitbox_names = ["attack1_hitbox", "attack2_hitbox", "attack3_hitbox"]
	
	print("   Атака: ", anim_names[combo_step])
	
	# Устанавливаем параметры
	anim_tree.set("parameters/attack_request", true)
	anim_tree.set("parameters/combo_step", combo_step)
	anim_tree.set("parameters/combo_timer", combo_reset_time)
	
	# Запускаем анимации
	var sm = get_state_machine()
	if sm:
		sm.travel(anim_names[combo_step])
	
	if hitbox_anim:
		hitbox_anim.play(hitbox_names[combo_step])
	
	# ПОСЛЕ запуска анимации увеличиваем шаг для следующего раза
	combo_step = (combo_step + 1) % 3
	combo_timer = combo_reset_time
	can_attack = false
	
	print("   combo_step ПОСЛЕ = ", combo_step)
	
	# Сбрасываем request через кадр
	await get_tree().process_frame
	anim_tree.set("parameters/attack_request", false)

func _on_animation_finished(anim_name: String):
	print("=== _on_animation_finished() ===")
	print("   anim_name = ", anim_name)
	print("   can_attack ДО = ", can_attack)
	
	if anim_name in ["attack1", "attack2", "attack3"]:
		can_attack = true
		print("   → can_attack = true")
		
		if combo_timer <= 0:
			print("   → таймер истек, сброс комбо")
			reset_combo()
			anim_tree.set("parameters/combo_step", 0)
			anim_tree.set("parameters/combo_timer", 0)

func _enable_sword_attack():
	if sword_hitbox:
		var damage = [64, 399, 72][combo_step]
		var should_knockup = (combo_step == 2)
		sword_hitbox.start_attack(damage, should_knockup)

func _disable_sword_attack():
	if sword_hitbox:
		sword_hitbox.stop_attack()

func reset_combo():
	combo_step = 0
	combo_timer = 0.0

# ========== МЕТОДЫ ДЛЯ МЕНЮ ==========
func _custom_menu_state():
	print("=== _custom_menu_state() ===")
	
	if anim_tree:
		anim_tree.active = false
		print("AnimationTree деактивирован")
	
	# Останавливаем всё
	if animation_player:
		animation_player.stop()
		print("AnimationPlayer остановлен")
	if hitbox_anim:
		hitbox_anim.stop()
		print("HitboxAnimPlayer остановлен")
	
	# Проигрываем pose2 и НЕ останавливаем
	if animation_player and animation_player.has_animation("pose2"):
		print("Проигрываем pose2")
		animation_player.play("pose2")
	else:
		print("pose2 не найдена!")

# ========== МЕТОДЫ ДЛЯ ИГРЫ ==========
func _custom_game_start():
	print("=== _custom_game_start() ===")
	
	# Явно сбрасываем всё
	can_attack = true
	combo_step = 0
	combo_timer = 0.0
	debug_call_count = 0
	
	print("   combo_step сброшен в 0")
	
	# СНАЧАЛА устанавливаем позу через обычный AnimationPlayer
	if animation_player and animation_player.has_animation("static"):
		animation_player.play("static")
		await get_tree().process_frame
		animation_player.stop()
		print("static проигран через AnimationPlayer")
	
	# ПОТОМ включаем AnimationTree
	if anim_tree:
		anim_tree.active = true
		print("AnimationTree активен")
		
		var sm = get_state_machine()
		if sm:
			print("StateMachine получена")
			sm.travel("static")
			print("travel to static выполнен")
			await get_tree().process_frame
			print("Текущее состояние: ", sm.get_current_node())
			print("can_attack после всего: ", can_attack)
		else:
			print("StateMachine не получена!")
	
	if animation_player and animation_player.is_playing():
		animation_player.stop()
