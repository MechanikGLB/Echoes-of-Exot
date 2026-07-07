extends Node

const DEFAULT_PORT = 10567
var peer: ENetMultiplayerPeer = null

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)

func _ready():
	multiplayer.multiplayer_peer = null

func host_game(port: int = DEFAULT_PORT):
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port)
	if error != OK:
		print("Ошибка создания сервера")
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Сервер запущен на порту %d" % port)

func join_game(ip: String, port: int = DEFAULT_PORT):
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	if error != OK:
		print("Ошибка подключения к серверу")
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id: int):
	print("Игрок %d подключился" % id)
	player_connected.emit(id)

func _on_peer_disconnected(id: int):
	print("Игрок %d отключился" % id)
	player_disconnected.emit(id)
