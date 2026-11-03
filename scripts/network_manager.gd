extends Node
## NetworkManager — ENet host/client + reconnection support

signal player_connected(peer_id: int, info: Dictionary)
signal player_disconnected(peer_id: int)
signal connection_failed
signal connection_succeeded
signal server_disconnected
signal lobby_updated
signal game_started
signal chat_message_received(from_id: int, text: String, is_team: bool)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4
const MAX_OBSERVERS := 32

var peer: ENetMultiplayerPeer
var is_host := false
var my_peer_id := 0

# Lobby data: peer_id -> {name, color, team, turn_order, slot, is_observer, ready}
var players: Dictionary = {}
var observers: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS + MAX_OBSERVERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	my_peer_id = 1
	# Host registers itself later via lobby UI
	return OK

func join_game(ip: String, port: int = DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	return OK

func leave_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	my_peer_id = 0
	players.clear()
	observers.clear()

func register_player(info: Dictionary) -> void:
	# info: name, color (Color), team (int), turn_order (int), slot (String), is_observer (bool)
	if multiplayer.is_server():
		_register_player_local(multiplayer.get_unique_id(), info)
	else:
		rpc_id(1, "_request_register", info)

@rpc("any_peer", "reliable")
func _request_register(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	_register_player_local(id, info)

func _register_player_local(id: int, info: Dictionary) -> void:
	if info.get("is_observer", false):
		observers[id] = info
	else:
		# Check slot uniqueness and turn_order swap if needed
		var slot: String = info.get("slot", "")
		var order: int = info.get("turn_order", 0)
		for pid in players:
			if players[pid].get("slot") == slot and pid != id:
				# Slot taken — reject or swap? For now reject
				return
			if players[pid].get("turn_order") == order and pid != id:
				# Swap turn orders
				var old_order = players[pid]["turn_order"]
				players[pid]["turn_order"] = order
				info["turn_order"] = old_order
		players[id] = info
	_broadcast_lobby()

func _broadcast_lobby() -> void:
	rpc("_sync_lobby", players, observers)
	lobby_updated.emit()

@rpc("authority", "reliable", "call_local")
func _sync_lobby(p: Dictionary, o: Dictionary) -> void:
	players = p
	observers = o
	lobby_updated.emit()

func start_game() -> void:
	if not multiplayer.is_server():
		return
	if players.size() < 2:
		return
	rpc("_on_game_start")

@rpc("authority", "reliable", "call_local")
func _on_game_start() -> void:
	game_started.emit()

func send_chat(text: String, is_team: bool) -> void:
	rpc("_receive_chat", text, is_team)

@rpc("any_peer", "reliable", "call_local")
func _receive_chat(text: String, is_team: bool) -> void:
	var from_id := multiplayer.get_remote_sender_id()
	if from_id == 0:
		from_id = multiplayer.get_unique_id()
	chat_message_received.emit(from_id, text, is_team)

# --- Connection callbacks ---

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	if multiplayer.is_server():
		# Send current lobby state to new peer
		rpc_id(id, "_sync_lobby", players, observers)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	players.erase(id)
	observers.erase(id)
	_broadcast_lobby()
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	my_peer_id = multiplayer.get_unique_id()
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	connection_failed.emit()
	leave_game()

func _on_server_disconnected() -> void:
	server_disconnected.emit()
	leave_game()

# Reconnection helper (simplified — full state recovery later)
func request_rejoin(old_info: Dictionary) -> void:
	if multiplayer.is_server():
		return
	rpc_id(1, "_request_register", old_info)
