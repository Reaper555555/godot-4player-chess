extends Node2D
## Main game controller: input, moves, animation, turn flow, badges, chat

@onready var board_view: Node2D = $BoardView
@onready var turn_label: Label = $UI/TurnLabel
@onready var chat_log: RichTextLabel = $UI/ChatPanel/ChatLog
@onready var chat_input: LineEdit = $UI/ChatPanel/ChatInput
@onready var team_chat_check: CheckBox = $UI/ChatPanel/TeamChatCheck
@onready var badges_container: Control = $UI/Badges
@onready var back_btn: Button = $UI/TopButtons/BackBtn
@onready var fullscreen_btn: Button = $UI/TopButtons/FullscreenBtn
@onready var lang_btn: Button = $UI/TopButtons/LangBtn

var selected: Vector2i = Vector2i(-1, -1)
var is_animating := false
var animator: Node2D

func _ready() -> void:
	# Animator
	animator = Node2D.new()
	animator.set_script(load("res://scripts/piece_animator.gd"))
	add_child(animator)
	animator.hide()

	var players = NetworkManager.players.duplicate(true)
	if players.is_empty():
		# Offline / single test fallback
		players = {
			1: {"name": "Host", "color": Color(0.9, 0.25, 0.25), "team": 1, "turn_order": 1, "slot": "bottom_left", "is_observer": false},
			2: {"name": "P2", "color": Color(0.25, 0.45, 0.9), "team": 2, "turn_order": 2, "slot": "top_left", "is_observer": false},
		}
		NetworkManager.players = players
		NetworkManager.my_peer_id = 1

	GameState.setup_initial_position(players)
	board_view.refresh()

	NetworkManager.chat_message_received.connect(_on_chat)
	NetworkManager.move_received.connect(_on_move_received)
	NetworkManager.turn_changed.connect(_on_turn_changed)
	chat_input.text_submitted.connect(_on_chat_submit)
	back_btn.pressed.connect(_on_back)
	fullscreen_btn.pressed.connect(_on_fullscreen)
	lang_btn.pressed.connect(_on_lang)

	_update_turn_ui()
	_create_badges()

func _unhandled_input(event: InputEvent) -> void:
	if is_animating:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell = board_view.cell_from_pos(get_global_mouse_position())
		_on_cell_clicked(cell)

func _on_cell_clicked(cell: Vector2i) -> void:
	if cell.x < 0:
		return

	var my_id = NetworkManager.my_peer_id
	if NetworkManager.observers.has(my_id):
		return
	if GameState.is_frozen(my_id):
		return
	if GameState.turn_player_id != my_id:
		return

	var piece = GameState.get_piece(cell.x, cell.y)

	if selected.x >= 0:
		if cell in board_view.possible_moves:
			NetworkManager.request_move(selected, cell)
			selected = Vector2i(-1, -1)
			board_view.clear_selection()
			return
		else:
			board_view.clear_selection()
			selected = Vector2i(-1, -1)

	if piece and piece.owner == my_id:
		selected = cell
		var moves = ChessLogic.get_possible_moves(GameState, cell.x, cell.y)
		board_view.set_selection(cell, moves)
		AudioManager.play("select")

func _on_move_received(from: Vector2i, to: Vector2i, _sender_id: int) -> void:
	var piece = GameState.get_piece(from.x, from.y)
	if piece == null:
		return
	var captured = GameState.get_piece(to.x, to.y)
	var is_capture = captured != null

	# Clear source so board doesn't show two pieces during animation
	GameState.set_piece(from.x, from.y, null)
	board_view.refresh()

	is_animating = true
	animator.start(from, to, piece, board_view, func():
		_finish_move(from, to, piece, is_capture)
	)

func _finish_move(from: Vector2i, to: Vector2i, piece: Dictionary, is_capture: bool) -> void:
	piece.has_moved = true
	GameState.set_piece(to.x, to.y, piece)
	board_view.set_last_move(from, to)
	board_view.refresh()
	AudioManager.play_move(is_capture)
	is_animating = false

	_check_game_state_after_move(piece.owner)

	GameState.next_turn()
	if NetworkManager.is_host or multiplayer.multiplayer_peer == null:
		NetworkManager.notify_turn_changed(GameState.turn_player_id)
	_update_turn_ui()

func _check_game_state_after_move(_mover_id: int) -> void:
	for pid in GameState.players_info:
		if GameState.is_frozen(pid):
			continue
		if ChessLogic.is_checkmate(GameState, pid):
			GameState.set_frozen(pid, true)
			AudioManager.play_checkmate()
			print("Checkmate → frozen ", pid)
		elif ChessLogic.is_stalemate(GameState, pid):
			GameState.set_frozen(pid, true)
			print("Stalemate → frozen ", pid)
		elif ChessLogic.is_in_check(GameState, pid):
			AudioManager.play_check()

func _on_turn_changed(new_id: int) -> void:
	GameState.turn_player_id = new_id
	_update_turn_ui()

func _update_turn_ui() -> void:
	var pid = GameState.turn_player_id
	var info = GameState.players_info.get(pid, {})
	var name = info.get("name", "?")
	var frozen = GameState.is_frozen(pid)
	var color: Color = info.get("color", Color.WHITE)
	turn_label.text = "Ход: %s%s" % [name, " (заморожен)" if frozen else ""]
	turn_label.add_theme_color_override("font_color", color)

func _create_badges() -> void:
	for c in badges_container.get_children():
		c.queue_free()
	var positions = {
		"top_left": Vector2(20, 8),
		"bottom_left": Vector2(20, 580),
		"top_right": Vector2(900, 8),
		"bottom_right": Vector2(900, 580),
	}
	for pid in GameState.players_info:
		var info = GameState.players_info[pid]
		var slot = info.get("slot", "bottom_left")
		var badge = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.14, 0.85)
		style.border_color = info.get("color", Color.WHITE)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		badge.add_theme_stylebox_override("panel", style)
		var label = Label.new()
		label.text = "%s  T%d  #%d" % [info.get("name", "?"), info.get("team", 0), info.get("turn_order", 0)]
		label.add_theme_color_override("font_color", info.get("color", Color.WHITE))
		badge.add_child(label)
		badge.position = positions.get(slot, Vector2(20, 20))
		badges_container.add_child(badge)

func _on_chat(from_id: int, text: String, is_team: bool) -> void:
	var info = GameState.players_info.get(from_id, NetworkManager.observers.get(from_id, {}))
	var name = info.get("name", "?")
	var color: Color = info.get("color", Color.WHITE)
	var prefix = "[T] " if is_team else ""
	chat_log.append_text("[color=#%s]%s%s:[/color] %s\n" % [color.to_html(false), prefix, name, text])

func _on_chat_submit(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	NetworkManager.send_chat(text, team_chat_check.button_pressed)
	chat_input.clear()

func _on_back() -> void:
	NetworkManager.leave_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_lang() -> void:
	LocaleManager.toggle()
	lang_btn.text = "RU" if LocaleManager.current_locale == "en" else "EN"
