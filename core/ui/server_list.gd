extends Control


func _on_close_pressed() -> void:
	GameManager.change_state(GameManager.GameState.MENU)


func _on_create_pressed():
	NetworkManager.host_game()
	get_tree().change_scene_to_file("res://core/ui/lobby.tscn")

func _on_join_pressed():
	var ip = $VBoxContainer/LineEdit.text
	NetworkManager.join_game(ip)
	get_tree().change_scene_to_file("res://core/ui/lobby.tscn")
