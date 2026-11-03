extends Node2D
## Main game controller: input, moves, turn flow, badges, chat overlay

@onready var board_view: Node2D = $BoardView
@onready var turn_label: Label = $UI/TurnLabel
@onready var chat_log: RichTextLabel = $UI/ChatPanel/ChatLog
@onready var chat_input: LineEdit = $UI/ChatPanel/ChatInput
@onready var team_chat_check: CheckBox = $UI/ChatPanel/TeamChatCheck
@onready var badges_container: Control = $UI/Badges

var selected: Vector2i = Vector2i(-1, -1)
var is_my_turn := false

func _ready() -> void:
	# Setup board from lobby data
	var players = NetworkManager.players.duplicate(true)
	GameState.setup_initial_position(players)
	board_view.refresh()

	NetworkManager.chat_message_received.connect(_on_chat)
	chat_input.text_submitted.connect(_on_chat_submit)

	_update_turn_ui()
	_create_badges()

	# For single-player testing without network we still allow moves if host
	if NetworkManager.my_peer_id == 0:
		NetworkManager.my_peer_id = 1  # fallback

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell = board_view.cell_from_pos(get_global_mouse_position())
		_on_cell_clicked(cell)

func _on_cell_clicked(cell: Vector2i) -> void:
	if cell.x < 0:
		return

	var my_id = NetworkManager.my_peer_id
	if GameState.is_frozen(my_id):
		return
	if GameState.turn_player_id != my_id and NetworkManager.players.has(my_id):
		# Only current player can move (observers never)
		if not NetworkManager.is_host:  # temporary relax for testing
			return

	var piece = GameState.get_piece(cell.x, cell.y)

	if selected.x >= 0:
		# Try to move
		if cell in board_view.possible_moves:
			_try_move(selected, cell)
			selected = Vector2i(-1, -1)
			board_view.clear_selection()
			return
		else:
			# Deselect or reselect
			board_view.clear_selection()
			selected = Vector2i(-1, -1)

	if piece and piece.owner == my_id:
		selected = cell
		var moves = ChessLogic.get_possible_moves(GameState, cell.x, cell.y)
		board_view.set_selection(cell, moves)
		AudioManager.play("select")

func _try_move(from: Vector2i, to: Vector2i) -> void:
	var piece = GameState.get_piece(from.x, from.y)
	if piece == null:
		return
	var captured = GameState.get_piece(to.x, to.y)
	var is_capture = captured != null

	# Apply move
	piece.has_moved = true
	GameState.set_piece(to.x, to.y, piece)
	GameState.set_piece(from.x, from.y, null)

	board_view.set_last_move(from, to)
	board_view.refresh()
	AudioManager.play_move(is_capture)

	# Check for checks / mates after move
	_check_game_state_after_move(piece.owner)

	# Next turn
	GameState.next_turn()
	_update_turn_ui()

	# TODO: RPC the move to others
	# rpc("apply_remote_move", from, to)

func _check_game_state_after_move(_mover_id: int) -> void:
	for pid in GameState.players_info:
		if GameState.is_frozen(pid):
			continue
		if ChessLogic.is_checkmate(GameState, pid):
			GameState.set_frozen(pid, true)
			AudioManager.play_checkmate()
			print("Checkmate for player ", pid)
		elif ChessLogic.is_stalemate(GameState, pid):
			GameState.set_frozen(pid, true)
			print("Stalemate for player ", pid)
		elif ChessLogic.is_in_check(GameState, pid):
			AudioManager.play_check()

	# Victory check: all of one opposing team frozen?
	# Simplified for now

func _update_turn_ui() -> void:
	var pid = GameState.turn_player_id
	var name = GameState.players_info.get(pid, {}).get("name", "?")
	var frozen = GameState.is_frozen(pid)
	turn_label.text = "Ход: %s%s" % [name, " (заморожен)" if frozen else ""]
	is_my_turn = (pid == NetworkManager.my_peer_id)

func _create_badges() -> void:
	# Simple badges near corners
	var positions = {
		"top_left": Vector2(20, 10),
		"bottom_left": Vector2(20, 560),
		"top_right": Vector2(980, 10),
		"bottom_right": Vector2(980, 560),
	}
	for pid in GameState.players_info:
		var info = GameState.players_info[pid]
		var slot = info.get("slot", "bottom_left")
		var badge = Label.new()
		badge.text = "%s | T%d | #%d" % [info.get("name", "?"), info.get("team", 0), info.get("turn_order", 0)]
		badge.add_theme_color_override("font_color", info.get("color", Color.WHITE))
		badge.position = positions.get(slot, Vector2(20, 20))
		badges_container.add_child(badge)

func _on_chat(from_id: int, text: String, is_team: bool) -> void:
	var name = GameState.players_info.get(from_id, {}).get("name", "?")
	var color = GameState.players_info.get(from_id, {}).get("color", Color.WHITE)
	var prefix = "[T] " if is_team else ""
	chat_log.append_text("[color=#%s]%s%s:[/color] %s\n" % [color.to_html(false), prefix, name, text])

func _on_chat_submit(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	NetworkManager.send_chat(text, team_chat_check.button_pressed)
	chat_input.clear()
