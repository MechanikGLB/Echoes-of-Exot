class_name AnimationComponent extends Node

signal hit_frame_reached(ability_id: String)
signal hit_frame_ended(ability_id: String)
signal ability_finished(ability_id: String)
signal animation_event(event_name: String, args: Array)

@export var animation_tree_path: NodePath
@export var hitbox_player_path: NodePath
@export var state_machine_param: String = "parameters/StateMachine/playback"

var _tree: AnimationTree
var _hitbox_player: AnimationPlayer
var _current_ability_id: String = ""

func _ready() -> void:
	_tree = get_node_or_null(animation_tree_path)
	_hitbox_player = get_node_or_null(hitbox_player_path)
	if _hitbox_player:
		_hitbox_player.animation_finished.connect(_on_hitbox_animation_finished)

# --- Основная анимация через StateMachine ---

func travel_state(state_name: String) -> void:
	if not _tree:
		return
	var sm = _tree.get(state_machine_param)
	if sm:
		sm.travel(state_name)

func set_tree_param(path: String, value: Variant) -> void:
	if _tree:
		_tree.set(path, value)

func get_tree_param(path: String) -> Variant:
	return _tree.get(path) if _tree else null

func enable() -> void:
	if _tree:
		_tree.active = true

func disable() -> void:
	if _tree:
		_tree.active = false

func is_active() -> bool:
	return _tree.active if _tree else false

# --- Hitbox-плеер: короткие анимации-тайминги ---

func play_hitbox(ability_id: String, animation_name: String) -> void:
	_current_ability_id = ability_id
	if _hitbox_player and animation_name:
		_hitbox_player.play(animation_name)

func stop_hitbox() -> void:
	if _hitbox_player:
		_hitbox_player.stop()

func get_animation_length(animation_name: String) -> float:
	if _hitbox_player and _hitbox_player.has_animation(animation_name):
		return _hitbox_player.get_animation(animation_name).length
	return 0.0

# --- Коллбеки из Method Track ---
# Вызывается из анимаций через track method = "_on_animation_event"
# args[0] — имя события ("hit_frame", "hit_end", любое другое)

func _on_animation_event(event_name: String = "", args: Array = []) -> void:
	match event_name:
		"hit_frame":
			hit_frame_reached.emit(_current_ability_id)
		"hit_end":
			hit_frame_ended.emit(_current_ability_id)
		_:
			animation_event.emit(event_name, args)

func _on_hitbox_animation_finished(_anim_name: String) -> void:
	ability_finished.emit(_current_ability_id)
