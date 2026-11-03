extends Node
## NetworkManager — ENet + moves + draw + state snapshot for reconnect

signal player_connected(peer_id: int, info: Dictionary)
signal player_disconnected(peer_id: int)
signal connection_failed
signal connection_succeeded
signal server_disconnected
signal lobby_updated
signal game_started
signal chat_message_received(from_id: int, text: String, is_team: bool)
signal move_received(from: Vector2i, to: Vector2i, sender_id: int, promotion: int)
signal turn_changed(new_player_id: int)
signal draw_state_changed(proposed_team: int, votes: Dictionary, accepted: bool)
signal state_snapshot_received(data: Dictionary)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4
const MAX_OBSERVERS := 32

var peer: ENetMultiplayerPeer
var is_host := false
var my_peer_id := 0
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
	if GameState.game_in_progress:
		rpc_id(id, "_receive_state_snapshot", GameState.serialize())

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
				info["slot"] = players[id].get("slot", slot) if players.has(id) else "bottom_left"
			if players[pid].get("turn_order") == order:
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
	chat_message_received.emit(from_id, text, is_team)

func request_move(from: Vector2i, to: Vector2i, promotion: int = -1) -> void:
	if multiplayer.multiplayer_peer == null:
		move_received.emit(from, to, my_peer_id if my_peer_id != 0 else 1, promotion)
		return
	if multiplayer.is_server():
		_validate_and_apply_move(multiplayer.get_unique_id(), from, to, promotion)
	else:
		rpc_id(1, "_server_receive_move", from, to, promotion)

@rpc("any_peer", "reliable")
func _server_receive_move(from: Vector2i, to: Vector2i, promotion: int = -1) -> void:
	if not multiplayer.is_server():
		return
	_validate_and_apply_move(multiplayer.get_remote_sender_id(), from, to, promotion)

func _validate_and_apply_move(sender_id: int, from: Vector2i, to: Vector2i, promotion: int) -> void:
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
	if ChessLogic.is_promotion(GameState, from.x, from.y, to.x, to.y):
		if promotion < 0 or promotion not in [GameState.PieceType.QUEEN, GameState.PieceType.ROOK, GameState.PieceType.BISHOP, GameState.PieceType.KNIGHT]:
			promotion = GameState.PieceType.QUEEN
	else:
		promotion = -1
	rpc("_apply_move", from, to, sender_id, promotion)

@rpc("authority", "reliable", "call_local")
func _apply_move(from: Vector2i, to: Vector2i, sender_id: int, promotion: int = -1) -> void:
	move_received.emit(from, to, sender_id, promotion)

func notify_turn_changed(new_id: int) -> void:
	if multiplayer.multiplayer_peer == null:
		turn_changed.emit(new_id)
		return
	if multiplayer.is_server():
		rpc("_sync_turn", new_id)

@rpc("authority", "reliable", "call_local")
func _sync_turn(new_id: int) -> void:
	turn_changed.emit(new_id)

func propose_or_vote_draw() -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		_server_draw_vote(my_peer_id if my_peer_id != 0 else 1)
	else:
		rpc_id(1, "_server_receive_draw_vote")

@rpc("any_peer", "reliable")
func _server_receive_draw_vote() -> void:
	if not multiplayer.is_server():
		return
	_server_draw_vote(multiplayer.get_remote_sender_id())

func _server_draw_vote(voter_id: int) -> void:
	var team = GameState.get_team(voter_id)
	if GameState.draw_proposed_by_team < 0:
		GameState.draw_proposed_by_team = team
		GameState.draw_votes.clear()
	GameState.draw_votes[voter_id] = true
	var accepted = true
	for pid in players:
		if not GameState.draw_votes.get(pid, false):
			accepted = false
			break
	if players.is_empty():
		accepted = false
	rpc("_sync_draw", GameState.draw_proposed_by_team, GameState.draw_votes, accepted)

@rpc("authority", "reliable", "call_local")
func _sync_draw(proposed_team: int, votes: Dictionary, accepted: bool) -> void:
	GameState.draw_proposed_by_team = proposed_team
	GameState.draw_votes = votes
	draw_state_changed.emit(proposed_team, votes, accepted)

@rpc("authority", "reliable")
func _receive_state_snapshot(data: Dictionary) -> void:
	GameState.apply_snapshot(data)
	players = data.get("players_info", players)
	state_snapshot_received.emit(data)
	if data.get("game_in_progress", false):
		# Ensure we are on game scene
		if get_tree().current_scene == null or not str(get_tree().current_scene.scene_file_path).ends_with("game.tscn"):
			get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	if multiplayer.is_server():
		rpc_id(id, "_sync_lobby", players, observers)
		if GameState.game_in_progress:
			rpc_id(id, "_receive_state_snapshot", GameState.serialize())

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
