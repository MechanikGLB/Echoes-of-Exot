class_name AbilityResource
extends Resource

# Сигналы
signal cooldown_started(duration: float)
signal cooldown_finished()
signal charged(percent: float)
signal ability_activated()

# ----------------------------------------------------------------------------
# Типы применения урона/эффекта
# ----------------------------------------------------------------------------
enum EffectApplicationType {
	INSTANT,           # Мгновенно при активации (файербол создаётся сразу)
	ANIMATION_FRAME,   # На конкретном кадре анимации (удар мечом)
	PROJECTILE,        # Снаряд, который наносит урон при столкновении
	AREA,              # Область, которая наносит урон (волна)
	PERSISTENT         # Постоянный эффект (щит, аура)
}

@export var effect_type: EffectApplicationType = EffectApplicationType.INSTANT

# ----------------------------------------------------------------------------
# Типы активации
# ----------------------------------------------------------------------------
enum ActivationType {
	SINGLE,    # Одно нажатие - одно применение
	HOLDABLE,  # Удерживание для постоянного эффекта
	CHARGED,   # Заряжается при удержании, применяется при отпускании
	TOGGLE,    # Вкл/Выкл
	PASSIVE    # Пассивный эффект, не требует активации
}

@export_group("Основные параметры")
@export var ability_name: String = "Способность"
@export_multiline var description: String = ""
@export var input_action: String = "" 
@export var holdable: bool = false
@export var icon: Texture2D
@export var activation_type: ActivationType = ActivationType.SINGLE

@export_group("Кулдаун")
@export var cooldown_time: float = 1.0
@export var can_interrupt: bool = false  # Можно ли прервать другой способностью

@export_group("Зарядка")
@export var charge_time: float = 2.0
@export var min_charge: float = 0.0
@export var max_charge: float = 1.0
@export var release_on_full_charge: bool = false

@export_group("Анимация (опционально)")
@export var animation_name: String = ""
@export var animation_speed: float = 1.0
@export var hit_frame: int = -1  # Для ANIMATION_FRAME
@export var charge_animation: String = ""  # Для CHARGED

@export_group("Снаряд/Область")
@export var projectile_scene: PackedScene  # Для PROJECTILE
@export var area_scene: PackedScene        # Для AREA
@export var area_radius: float = 5.0       # Радиус области
@export var area_duration: float = 3.0     # Время существования области

@export_group("Визуальные эффекты")
@export var use_vfx: bool = false
@export var vfx_scene: PackedScene

# ----------------------------------------------------------------------------
# Состояние
# ----------------------------------------------------------------------------
var owner: CharacterBase :
	set(value):
		owner = value
		_on_owner_set()

var is_on_cooldown: bool = false
var is_active: bool = false
var is_charging: bool = false
var current_charge: float = 0.0
var is_interrupted: bool = false  # Для отслеживания прерываний

# Таймеры
var _cooldown_timer: Timer
var _charge_timer: Timer
var _active_timer: Timer  # Для AREA/PERSISTENT

# ----------------------------------------------------------------------------
# Инициализация
# ----------------------------------------------------------------------------
func _on_owner_set():
	if not owner:
		return
	
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_finished)
	owner.add_child(_cooldown_timer)
	
	_charge_timer = Timer.new()
	_charge_timer.one_shot = false
	_charge_timer.timeout.connect(_on_charge_tick)
	owner.add_child(_charge_timer)
	
	_active_timer = Timer.new()
	_active_timer.one_shot = true
	_active_timer.timeout.connect(_on_active_timer_finished)
	owner.add_child(_active_timer)

# ----------------------------------------------------------------------------
# Основные методы (вызываются из CharacterBase)
# ----------------------------------------------------------------------------
func on_press() -> bool:
	"""Возвращает true если способность начала активацию"""
	if not owner:
		return false
		
	if is_on_cooldown:
		return false
	
	# Проверка на прерывание текущей способности
	if owner.is_ability_active and not can_interrupt:
		return false
	
	match activation_type:
		ActivationType.SINGLE:
			_activate_single()
			return true
			
		ActivationType.HOLDABLE:
			_start_hold()
			return true
			
		ActivationType.CHARGED:
			_start_charging()
			return true
			
		ActivationType.TOGGLE:
			if is_active:
				_turn_off()
			else:
				_turn_on()
			return true
			
		ActivationType.PASSIVE:
			# Пассивки активируются отдельно
			return false
	
	return false

func on_hold(delta: float) -> void:
	"""Вызывается каждый кадр при удержании"""
	if activation_type == ActivationType.HOLDABLE and is_active:
		_apply_hold_effect(delta)

func on_release() -> void:
	"""Вызывается при отпускании"""
	match activation_type:
		ActivationType.HOLDABLE:
			_stop_hold()
		
		ActivationType.CHARGED:
			_release_charge()

func update(delta: float) -> void:
	"""Ежекадровое обновление"""
	if activation_type == ActivationType.PASSIVE and is_active:
		_apply_passive_effect(delta)
	
	if is_charging:
		charged.emit(current_charge)

# ----------------------------------------------------------------------------
# SINGLE
# ----------------------------------------------------------------------------
func _activate_single() -> void:
	owner.set_ability_active(true, self)
	
	match effect_type:
		EffectApplicationType.INSTANT:
			_apply_instant_effect()
			_finish_ability()
			
		EffectApplicationType.ANIMATION_FRAME:
			_play_animation()
			# Активация произойдёт в _on_hit_frame()
			
		EffectApplicationType.PROJECTILE:
			_spawn_projectile()
			_finish_ability()
			
		EffectApplicationType.AREA:
			_spawn_area()
			_finish_ability()
			
		EffectApplicationType.PERSISTENT:
			_start_persistent_effect()

# ----------------------------------------------------------------------------
# HOLDABLE
# ----------------------------------------------------------------------------
func _start_hold() -> void:
	is_active = true
	owner.set_ability_active(true, self)
	_play_charge_animation()

func _stop_hold() -> void:
	is_active = false
	owner.stop_ability_animation()
	_finish_ability()

func _apply_hold_effect(_delta: float) -> void:
	"""Переопределяется в наследниках"""
	pass

# ----------------------------------------------------------------------------
# CHARGED
# ----------------------------------------------------------------------------
func _start_charging() -> void:
	is_charging = true
	current_charge = min_charge
	owner.set_ability_active(true, self)
	_play_charge_animation()
	_charge_timer.start(0.05)

func _release_charge() -> void:
	is_charging = false
	_charge_timer.stop()
	
	if current_charge >= min_charge:
		match effect_type:
			EffectApplicationType.INSTANT:
				_apply_instant_effect_with_charge(current_charge)
				_finish_ability()
				
			EffectApplicationType.PROJECTILE:
				_spawn_projectile_with_charge(current_charge)
				_finish_ability()
				
			EffectApplicationType.AREA:
				_spawn_area_with_charge(current_charge)
				_finish_ability()
	else:
		# Недостаточный заряд - отмена
		owner.stop_ability_animation()
		owner.set_ability_active(false, self)

func _on_charge_tick() -> void:
	current_charge = min(
		current_charge + (_charge_timer.wait_time / charge_time),
		max_charge
	)
	charged.emit(current_charge)
	
	if release_on_full_charge and current_charge >= max_charge:
		_release_charge()

# ----------------------------------------------------------------------------
# TOGGLE
# ----------------------------------------------------------------------------
func _turn_on() -> void:
	is_active = true
	owner.set_ability_active(true, self)
	_play_animation()
	_apply_toggle_effect(true)
	
	if effect_type == EffectApplicationType.PERSISTENT:
		_start_persistent_effect()

func _turn_off() -> void:
	is_active = false
	owner.stop_ability_animation()
	_apply_toggle_effect(false)
	_finish_ability()

# ----------------------------------------------------------------------------
# Завершение способности
# ----------------------------------------------------------------------------
func _finish_ability() -> void:
	owner.set_ability_active(false, self)
	ability_activated.emit()
	_start_cooldown()

func interrupt() -> void:
	"""Вызывается если способность прервана другой"""
	is_interrupted = true
	is_charging = false
	is_active = false
	_charge_timer.stop()
	_active_timer.stop()
	owner.stop_ability_animation()
	# Кулдаун НЕ начинаем

# ----------------------------------------------------------------------------
# Кулдаун
# ----------------------------------------------------------------------------
func _start_cooldown() -> void:
	is_on_cooldown = true
	cooldown_started.emit(cooldown_time)
	_cooldown_timer.start(cooldown_time)

func _on_cooldown_finished() -> void:
	is_on_cooldown = false
	cooldown_finished.emit()

# ----------------------------------------------------------------------------
# Проверки
# ----------------------------------------------------------------------------

func can_use() -> bool:
	"""Проверка возможности использования"""
	if not owner:
		return false
	
	if is_on_cooldown:
		return false
	
	if owner.is_ability_active and not can_interrupt:
		return false
	
	return true

# ----------------------------------------------------------------------------
# Анимация 
# ----------------------------------------------------------------------------

func _play_anim(anim_name: String, speed: float) -> void:
	"""Общий метод для проигрывания анимации"""
	if not anim_name or not owner:
		return
	
	owner.play_ability_animation(anim_name, speed)
	
	if hit_frame >= 0:  # Проверка только hit_frame, тип эффекта не важен
		if not owner.hit_frame_reached.is_connected(_on_hit_frame):
			owner.hit_frame_reached.connect(_on_hit_frame)

func _play_animation() -> void:
	"""Проигрывание основной анимации"""
	_play_anim(animation_name, animation_speed)

func _play_charge_animation() -> void:
	"""Проигрывание анимации зарядки"""
	_play_anim(charge_animation, 1.0)

func _on_hit_frame() -> void:
	"""Вызывается когда персонаж достигает hit_frame"""
	if effect_type == EffectApplicationType.ANIMATION_FRAME:
		_apply_instant_effect()
		_finish_ability()

# ----------------------------------------------------------------------------
# Эффекты (переопределяются в наследниках)
# ----------------------------------------------------------------------------
func _apply_instant_effect() -> void:
	"""Мгновенный эффект"""
	pass

func _apply_instant_effect_with_charge(_charge: float) -> void:
	"""Мгновенный эффект с зарядом"""
	_apply_instant_effect()

func _spawn_projectile() -> void:
	"""Создание снаряда"""
	if not projectile_scene or not owner:
		return
	
	var projectile = projectile_scene.instantiate()
	owner.get_parent().add_child(projectile)
	projectile.global_position = owner.get_projectile_spawn_position()
	
	# Передаём параметры снаряду
	if projectile.has_method("initialize"):
		projectile.initialize(self)

func _spawn_projectile_with_charge(charge: float) -> void:
	"""Создание снаряда с зарядом"""
	if not projectile_scene or not owner:
		return
	
	var projectile = projectile_scene.instantiate()
	owner.get_parent().add_child(projectile)
	projectile.global_position = owner.get_projectile_spawn_position()
	
	if projectile.has_method("initialize_with_charge"):
		projectile.initialize_with_charge(self, charge)
	else:
		if projectile.has_method("initialize"):
			projectile.initialize(self)

func _spawn_area() -> void:
	"""Создание области"""
	if not area_scene or not owner:
		return
	
	var area = area_scene.instantiate()
	owner.get_parent().add_child(area)
	area.global_position = owner.get_aim_position()
	
	if area.has_method("initialize"):
		area.initialize(self)
	
	# Запускаем таймер на уничтожение
	_active_timer.start(area_duration)

func _spawn_area_with_charge(charge: float) -> void:
	"""Создание области с зарядом"""
	if not area_scene or not owner:
		return
	
	var area = area_scene.instantiate()
	owner.get_parent().add_child(area)
	area.global_position = owner.get_aim_position()
	
	if area.has_method("initialize_with_charge"):
		area.initialize_with_charge(self, charge)
	else:
		if area.has_method("initialize"):
			area.initialize(self)
	
	_active_timer.start(area_duration)

func _start_persistent_effect() -> void:
	"""ЗАГОТОВКА: запуск постоянного эффекта (переопределяется в наследниках)"""
	# Например, аура или щит
	_active_timer.start(area_duration)

func _on_active_timer_finished() -> void:
	"""ЗАГОТОВКА: завершение активного эффекта"""
	if effect_type == EffectApplicationType.PERSISTENT:
		_turn_off()

func _apply_passive_effect(_delta: float) -> void:
	"""Пассивный эффект"""
	pass

func _apply_toggle_effect(_enabled: bool) -> void:
	"""Эффект переключения"""
	pass

# ----------------------------------------------------------------------------
# Вспомогательные методы
# ----------------------------------------------------------------------------
func reset() -> void:
	is_on_cooldown = false
	is_active = false
	is_charging = false
	is_interrupted = false
	current_charge = 0.0
	
	if _cooldown_timer:
		_cooldown_timer.stop()
	if _charge_timer:
		_charge_timer.stop()
	if _active_timer:
		_active_timer.stop()
	
	cooldown_finished.emit()

# ----------------------------------------------------------------------------
# Нанесение урона
# ----------------------------------------------------------------------------
func damage_target(target: CharacterBase, damage: float) -> void:
	"""Нанести урон цели"""
	if not target or not owner:
		return
	
	if target.has_method("take_damage"):
		target.take_damage(damage)

func damage_area(radius: float, damage: float, position: Vector3) -> void:
	"""Нанести урон по области"""
	if not owner:
		return
	
	var space_state = owner.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), position)
	query.collision_mask = 1  # Настройте под ваш проект
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var collider = result.collider
		if collider is CharacterBase and collider != owner:
			if collider.has_method("take_damage"):
				collider.take_damage(damage)

func damage_area_at_owner(radius: float, damage: float) -> void:
	"""Нанести урон по области вокруг владельца"""
	if owner:
		damage_area(radius, damage, owner.global_position)
