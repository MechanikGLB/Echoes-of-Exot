extends Node

enum GameState { INTRO, MENU, LOBBY, PLAYING, GAME_OVER }

signal state_changed(new_state: GameState)

var current_state: GameState = GameState.INTRO

func change_state(new_state: GameState):
	current_state = new_state
	state_changed.emit(current_state)
	# Здесь позже будем переключать сцены
	_apply_state(new_state)

func _apply_state(state: GameState):
	match state:
		GameState.INTRO:
			get_tree().change_scene_to_file("res://ui/intro.tscn")
		GameState.MENU:
			get_tree().change_scene_to_file("res://ui/main_menu.tscn")
		GameState.LOBBY:
			get_tree().change_scene_to_file("res://ui/lobby.tscn")
		GameState.PLAYING:
			# Сцена будет загружаться динамически, пока заглушка
			pass
		GameState.GAME_OVER:
			get_tree().change_scene_to_file("res://ui/game_over.tscn")
