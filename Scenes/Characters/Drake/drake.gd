extends CharacterBase

# ========== КОМБО СИСТЕМА ==========
var combo_step: int = 0              # 0-первый удар, 1-второй, 2-третий
var combo_timer: float = 0.0         # таймер до сброса комбо
var combo_reset_time: float = 1.2    # время ожидания следующего удара (сек)
var can_attack: bool = true          # можно ли начать новую атаку

# ========== НОДЫ ==========
@onready var anim_tree = $AnimationTree           # управляет переходами между анимациями
var _state_machine = null                          # lazy initialization

@onready var hitbox_anim = $HitboxAnimPlayer      # анимации-пустышки с ключами урона
@onready var sword_hitbox = $blockbench_export/Sword/SwordHitBox  # Area3D на мече

# ========== ПОЛУЧЕНИЕ STATE_MACHINE ==========
func get_state_machine():
	if _state_machine == null and anim_tree != null:
		_state_machine = anim_tree.get("parameters/playback")
	return _state_machine

# ========== ИНИЦИАЛИЗАЦИЯ ==========
func _custom_ready():
	combo_step = 0
	team = 1  # команда игрока
	
	if anim_tree:
		anim_tree.active = true
		anim_tree.animation_finished.connect(_on_animation_finished)
		get_state_machine()  # инициализируем state_machine
	
	# захватываем мышь только если это не сцена выбора персонажа
	if not Engine.is_editor_hint() and get_tree().current_scene.name != "character_selection":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _custom_physics_process(delta: float):
	# сброс комбо если долго не атаковать
	if combo_step > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			reset_combo()

# ========== УПРАВЛЕНИЕ ==========
func _input(event):
	# игнорируем ввод в меню
	if not anim_tree or not anim_tree.active:
		return
		
	if event.is_action_pressed("primary_fire"):
		advance_combo()

# ========== СИСТЕМА КОМБО ==========
func advance_combo() -> void:
	var sm = get_state_machine()
	if sm == null:
		return
		
	if not can_attack:
		if combo_timer > 0:
			combo_timer = combo_reset_time
		return
		
	can_attack = false
	combo_step = (combo_step + 1) % 3
	combo_timer = combo_reset_time
	
	var anim_names = ["attack1", "attack2", "attack3"]
	var hitbox_names = ["attack1_hitbox", "attack2_hitbox", "attack3_hitbox"]
	
	sm.travel(anim_names[combo_step])
	if hitbox_anim:
		hitbox_anim.play(hitbox_names[combo_step])

# вызывается из ключей в hitbox_anim (включение урона)
func _enable_sword_attack():
	if sword_hitbox:
		var damage = [64, 399, 72][combo_step]
		var should_knockup = (combo_step == 2)  # только третий удар подбрасывает
		sword_hitbox.start_attack(damage, should_knockup)

# вызывается из ключей в hitbox_anim (выключение урона)
func _disable_sword_attack():
	if sword_hitbox:
		sword_hitbox.stop_attack()

# вызывается когда GLB анимация закончилась
func _on_animation_finished(anim_name: String):
	var sm = get_state_machine()
	if sm == null:
		return
		
	if anim_name in ["attack1", "attack2", "attack3"]:
		can_attack = true
		
		if combo_timer <= 0:
			reset_combo()
			sm.travel("static")
		else:
			sm.travel("static")

# сброс комбо в начальное состояние
func reset_combo():
	combo_step = 0
	combo_timer = 0.0

# ========== МЕТОДЫ ДЛЯ МЕНЮ ==========
func _custom_menu_state():
	# отключаем AnimationTree
	if anim_tree:
		anim_tree.active = false
	
	# останавливаем все анимации
	if animation_player:
		animation_player.stop()
	if hitbox_anim:
		hitbox_anim.stop()
	
	# проигрываем анимацию покоя для меню
	if animation_player and animation_player.has_animation("pose2"):
		animation_player.play("pose2")
	
	# фиксируем позу
	set_physics_process(false)
