extends Node
## NetworkManager — ENet host/client + reconnection + move sync

signal player_connected(peer_id: int, info: Dictionary)
signal player_disconnected(peer_id: int)
signal connection_failed
signal connection_succeeded
signal server_disconnected
signal lobby_updated
signal game_started
signal chat_message_received(from_id: int, text: String, is_team: bool)
signal move_received(from: Vector2i, to: Vector2i, sender_id: int)
signal turn_changed(new_player_id: int)

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
		players.erase(id)
	else:
		observers.erase(id)
		var slot: String = info.get("slot", "")
		var order: int = info.get("turn_order", 0)
		for pid in players.keys():
			if pid == id:
				continue
			if players[pid].get("slot") == slot:
				# Slot taken — keep previous owner, ignore new request for slot
				info["slot"] = players[id].get("slot", slot) if players.has(id) else "bottom_left"
			if players[pid].get("turn_order") == order:
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
	if players.size() < 1:
		return
	rpc("_on_game_start", players)

@rpc("authority", "reliable", "call_local")
func _on_game_start(p: Dictionary) -> void:
	players = p
	game_started.emit()

func send_chat(text: String, is_team: bool) -> void:
	rpc("_receive_chat", text, is_team)

@rpc("any_peer", "reliable", "call_local")
func _receive_chat(text: String, is_team: bool) -> void:
	var from_id := multiplayer.get_remote_sender_id()
	if from_id == 0:
		from_id = multiplayer.get_unique_id()
	# Team chat filter can be done on receiver side later
	chat_message_received.emit(from_id, text, is_team)

# ========== MOVE SYNC ==========

## Client requests a move. Server validates and broadcasts.
func request_move(from: Vector2i, to: Vector2i) -> void:
	if multiplayer.is_server():
		_validate_and_apply_move(multiplayer.get_unique_id(), from, to)
	else:
		rpc_id(1, "_server_receive_move", from, to)

@rpc("any_peer", "reliable")
func _server_receive_move(from: Vector2i, to: Vector2i) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_validate_and_apply_move(sender, from, to)

func _validate_and_apply_move(sender_id: int, from: Vector2i, to: Vector2i) -> void:
	# Basic authority checks (full validation is in GameState / ChessLogic on all peers)
	if GameState.turn_player_id != sender_id:
		return
	if GameState.is_frozen(sender_id):
		return
	var piece = GameState.get_piece(from.x, from.y)
	if piece == null or piece.owner != sender_id:
		return
	var legal = ChessLogic.get_possible_moves(GameState, from.x, from.y)
	if to not in legal:
		return
	# Broadcast to everyone (including self via call_local)
	rpc("_apply_move", from, to, sender_id)

@rpc("authority", "reliable", "call_local")
func _apply_move(from: Vector2i, to: Vector2i, sender_id: int) -> void:
	move_received.emit(from, to, sender_id)

func notify_turn_changed(new_id: int) -> void:
	if multiplayer.is_server():
		rpc("_sync_turn", new_id)

@rpc("authority", "reliable", "call_local")
func _sync_turn(new_id: int) -> void:
	turn_changed.emit(new_id)

# ========== CONNECTION ==========

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	if multiplayer.is_server():
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

func request_rejoin(old_info: Dictionary) -> void:
	if multiplayer.is_server():
		return
	rpc_id(1, "_request_register", old_info)
