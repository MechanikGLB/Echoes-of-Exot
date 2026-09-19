class_name ControlComponent extends Node

enum Mode { PLAYER, AI, HYBRID, SCRIPTED }

signal move_input(input_vector: Vector2, sprint: bool)
signal jump_requested
signal ability_requested(slot: int)
signal aim_changed(direction: Vector3)

@export var mode: Mode = Mode.PLAYER
@export var enabled: bool = true

var _body: CharacterBody3D
var _move_target: Vector3 = Vector3.ZERO
var _has_move_target: bool = false

func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if not _body:
		push_error("ControlComponent должен быть дочерним узлом CharacterBody3D")

func _process(_delta: float) -> void:
	if not enabled or not _body:
		return

	match mode:
		Mode.PLAYER:
			_process_player_input()
		Mode.SCRIPTED:
			_process_scripted_input()
		Mode.AI:
			_process_ai_input()
		Mode.HYBRID:
			_process_player_input()
			_process_ai_input()

func _process_player_input() -> void:
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var sprint := Input.is_action_pressed("sprint")
	move_input.emit(input_dir, sprint)

	if Input.is_action_just_pressed("ui_accept"):
		jump_requested.emit()

func _process_scripted_input() -> void:
	# TODO: реализовать move_to → локальный input_vector
	pass

func _process_ai_input() -> void:
	# TODO: подключить AI-мозг
	pass

# ========== РЕЖИМЫ ==========

func set_mode(new_mode: Mode) -> void:
	mode = new_mode

func get_mode() -> Mode:
	return mode

func enable() -> void:
	enabled = true

func disable() -> void:
	enabled = false

# ========== ВЫСОКОУРОВНЕВЫЕ КОМАНДЫ ==========

func move_to(target_position: Vector3) -> void:
	_move_target = target_position
	_has_move_target = true
	mode = Mode.SCRIPTED

func stop_movement() -> void:
	_has_move_target = false
	move_input.emit(Vector2.ZERO, false)

func look_at_target(_target_position: Vector3) -> void:
	# TODO
	pass

func request_ability(slot: int) -> void:
	ability_requested.emit(slot)
