extends CharacterBase

# ========== КОМБО СИСТЕМА ==========
var combo_step: int = 0
var combo_timer: float = 0.0
var combo_reset_time: float = 1.2
var can_attack: bool = true

# Для раннего выхода
var early_exit_timer: float = 0.0
var early_exit_time: float = 0.15
var current_anim_name: String = ""

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
			return_to_static()
	
	# Ранний выход из анимации - просто по таймеру
	if early_exit_timer > 0:
		early_exit_timer -= delta
		if early_exit_timer <= 0 and not can_attack:
			check_early_exit()

# ========== УПРАВЛЕНИЕ ==========
func _input(event):
	super._input(event)
	
	if not anim_tree or not anim_tree.active:
		return
		
	if event.is_action_pressed("primary_fire"):
		print(">>> НАЖАТИЕ primary_fire от игрока")
		advance_combo()

# ========== СИСТЕМА КОМБО ==========
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
	
	var anim_names = ["attack1", "attack2", "attack3"]
	var hitbox_names = ["attack1_hitbox", "attack2_hitbox", "attack3_hitbox"]
	
	print("   Атака: ", anim_names[combo_step])
	
	# Запоминаем текущую анимацию
	current_anim_name = anim_names[combo_step]
	
	# Получаем длину анимации для раннего выхода
	var anim_length = get_animation_length(current_anim_name)
	if anim_length > 0:
		# Ставим ранний выход на 80-90% анимации
		early_exit_timer = anim_length * 0.85  # 85% анимации
	else:
		early_exit_timer = 0
	
	anim_tree.set("parameters/attack_request", true)
	anim_tree.set("parameters/combo_step", combo_step)
	anim_tree.set("parameters/combo_timer", combo_reset_time)
	
	var sm = get_state_machine()
	if sm:
		sm.travel(anim_names[combo_step])
	
	if hitbox_anim:
		hitbox_anim.play(hitbox_names[combo_step])
	
	combo_step = (combo_step + 1) % 3
	combo_timer = combo_reset_time
	can_attack = false
	
	print("   combo_step ПОСЛЕ = ", combo_step)
	
	await get_tree().process_frame
	anim_tree.set("parameters/attack_request", false)

func check_early_exit():
	print("=== check_early_exit() ===")
	print("   current_anim = ", current_anim_name)
	print("   combo_timer = ", combo_timer)
	
	# Переходим в static только если таймер истек
	if combo_timer <= 0:
		print("   → ранний выход в static")
		reset_combo()
		return_to_static()

func get_animation_length(anim_name: String) -> float:
	# Безопасное получение длины анимации
	if anim_tree and anim_tree.has_method("get_animation"):
		var anim = anim_tree.get_animation(anim_name)
		if anim:
			return anim.length
	return 0.0

func _on_animation_finished(anim_name: String):
	print("=== _on_animation_finished() ===")
	print("   anim_name = ", anim_name)
	print("   can_attack ДО = ", can_attack)
	
	if anim_name in ["attack1", "attack2", "attack3"]:
		can_attack = true
		print("   → can_attack = true")
		early_exit_timer = 0.0
		current_anim_name = ""
		
		if combo_timer <= 0:
			print("   → таймер истек, возврат в static")
			reset_combo()
			return_to_static()

func return_to_static():
	print("=== return_to_static() ===")
	var sm = get_state_machine()
	if sm:
		var current_anim = sm.get_current_node()
		if current_anim != "static":
			sm.travel("static")
			print("   → переход в static из ", current_state)

func _enable_sword_attack():
	if sword_hitbox:
		var current_combo = (combo_step - 1) if combo_step > 0 else 2
		var damage = [64, 399, 72][current_combo]
		var should_knockup = (current_combo == 2)
		sword_hitbox.start_attack(damage, should_knockup)

func _disable_sword_attack():
	if sword_hitbox:
		sword_hitbox.stop_attack()

func reset_combo():
	combo_step = 0
	combo_timer = 0.0
	early_exit_timer = 0.0
	current_anim_name = ""
	anim_tree.set("parameters/combo_step", 0)
	anim_tree.set("parameters/combo_timer", 0)

# ========== МЕТОДЫ ДЛЯ МЕНЮ ==========
func _custom_menu_state():
	print("=== _custom_menu_state() ===")
	
	if anim_tree:
		anim_tree.active = false
		print("AnimationTree деактивирован")
	
	if animation_player:
		animation_player.stop()
	if hitbox_anim:
		hitbox_anim.stop()
	
	if animation_player and animation_player.has_animation("pose2"):
		animation_player.play("pose2")

# ========== МЕТОДЫ ДЛЯ ИГРЫ ==========
func _custom_game_start():
	print("=== _custom_game_start() ===")
	
	can_attack = true
	combo_step = 0
	combo_timer = 0.0
	early_exit_timer = 0.0
	current_anim_name = ""
	
	if animation_player and animation_player.has_animation("static"):
		animation_player.play("static")
		await get_tree().process_frame
		animation_player.stop()
	
	if anim_tree:
		anim_tree.active = true
		print("AnimationTree активен")
		
		var sm = get_state_machine()
		if sm:
			sm.travel("static")
			await get_tree().process_frame
	
	if animation_player and animation_player.is_playing():
		animation_player.stop()
