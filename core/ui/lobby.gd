extends Control

@onready var player_list = $Panel/VBoxContainer/PlayerList
@onready var ready_button = $Panel/VBoxContainer/ReadyButton
@onready var start_button = $Panel/VBoxContainer/StartButton
@onready var status_label = $Panel/VBoxContainer/StatusLabel

var players: Dictionary = {}

func _ready():
	if not multiplayer.is_server():
		start_button.visible = false
	
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	if multiplayer.is_server():
		_add_player(multiplayer.get_unique_id(), GlobalThings.player_name)
	
	_send_player_info.rpc(GlobalThings.player_name)

func _add_player(peer_id: int, player_name: String):
	players[peer_id] = {"name": player_name, "ready": false}
	_refresh_player_list()

func _remove_player(peer_id: int):
	players.erase(peer_id)
	_refresh_player_list()

func _refresh_player_list():
	player_list.clear()
	for peer_id in players:
		var info = players[peer_id]
		var status = "✓" if info["ready"] else "…"
		player_list.add_item("%s [%s]" % [info["name"], status])

@rpc("any_peer", "call_remote")
func _send_player_info(player_name: String):
	var sender_id = multiplayer.get_remote_sender_id()
	_add_player(sender_id, player_name)
	if multiplayer.is_server():
		_broadcast_player_list.rpc(players)

@rpc("authority", "call_remote")
func _broadcast_player_list(server_players: Dictionary):
	players = server_players
	_refresh_player_list()

func _on_player_connected(peer_id: int):
	status_label.text = "Игрок %d подключился" % peer_id

func _on_player_disconnected(peer_id: int):
	_remove_player(peer_id)
	status_label.text = "Игрок %d отключился" % peer_id
	_refresh_player_list()

func _on_ready_pressed():
	var my_id = multiplayer.get_unique_id()
	if players.has(my_id):
		players[my_id]["ready"] = not players[my_id]["ready"]
	_refresh_player_list()

func _on_start_pressed():
	if multiplayer.is_server():
		status_label.text = "Запуск игры..."
