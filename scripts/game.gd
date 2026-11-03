extends Node2D
## Main game controller

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
var waiting_promotion := false
var pending_from: Vector2i
var pending_to: Vector2i
var animator: Node2D
var draw_btn: Button
var status_label: Label
var badge_nodes: Dictionary = {}

func _ready() -> void:
	animator = Node2D.new()
	animator.set_script(load("res://scripts/piece_animator.gd"))
	add_child(animator)
	animator.hide()

	if not GameState.game_in_progress:
		var players = NetworkManager.players.duplicate(true)
		if players.is_empty():
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
	NetworkManager.draw_state_changed.connect(_on_draw_state)
	NetworkManager.state_snapshot_received.connect(_on_snapshot)
	chat_input.text_submitted.connect(_on_chat_submit)
	back_btn.pressed.connect(_on_back)
	fullscreen_btn.pressed.connect(_on_fullscreen)
	lang_btn.pressed.connect(_on_lang)

	_add_extra_ui()
	_update_turn_ui()
	_create_badges()

func _on_snapshot(_data: Dictionary) -> void:
	board_view.refresh()
	_create_badges()
	_update_turn_ui()
	status_label.text = "Состояние восстановлено / State restored"

func _add_extra_ui() -> void:
	draw_btn = Button.new()
	draw_btn.text = LocaleManager.t("draw")
	draw_btn.position = Vector2(420, 620)
	draw_btn.pressed.connect(_on_draw_offer)
	$UI.add_child(draw_btn)
	status_label = Label.new()
	status_label.position = Vector2(20, 655)
	status_label.add_theme_font_size_override("font_size", 16)
	$UI.add_child(status_label)

func _unhandled_input(event: InputEvent) -> void:
	if is_animating or waiting_promotion:
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
			var from = selected
			selected = Vector2i(-1, -1)
			board_view.clear_selection()
			if ChessLogic.is_promotion(GameState, from.x, from.y, cell.x, cell.y):
				waiting_promotion = true
				pending_from = from
				pending_to = cell
				_show_promotion_popup()
			else:
				NetworkManager.request_move(from, cell, -1)
			return
		else:
			board_view.clear_selection()
			selected = Vector2i(-1, -1)
	if piece and piece.owner == my_id:
		selected = cell
		var moves = ChessLogic.get_possible_moves(GameState, cell.x, cell.y)
		board_view.set_selection(cell, moves)
		AudioManager.play("select")

func _show_promotion_popup() -> void:
	var node = CanvasLayer.new()
	node.set_script(load("res://scripts/promotion_popup.gd"))
	add_child(node)
	node.chosen.connect(_on_promotion_chosen)

func _on_promotion_chosen(piece_type: int) -> void:
	waiting_promotion = false
	NetworkManager.request_move(pending_from, pending_to, piece_type)

func _on_move_received(from: Vector2i, to: Vector2i, _sender_id: int, promotion: int = -1) -> void:
	var piece = GameState.get_piece(from.x, from.y)
	if piece == null:
		return
	var piece_copy = piece.duplicate()
	GameState.set_piece(from.x, from.y, null)
	board_view.refresh()
	is_animating = true
	animator.start(from, to, piece_copy, board_view, func():
		_finish_move(from, to, piece_copy, promotion)
	)

func _finish_move(from: Vector2i, to: Vector2i, piece: Dictionary, promotion: int) -> void:
	GameState.set_piece(from.x, from.y, piece)
	var result = GameState.apply_move(from, to, promotion)
	board_view.set_last_move(from, to)
	board_view.refresh()
	AudioManager.play_move(result.get("captured", false))
	is_animating = false
	if result.get("promotion", false):
		status_label.text = LocaleManager.t("promotion")
	elif result.get("castle", false):
		status_label.text = "Рокировка / Castling"
	elif result.get("en_passant", false):
		status_label.text = "En passant"
	_check_game_state_after_move(piece.owner)
	GameState.next_turn()
	if NetworkManager.is_host or multiplayer.multiplayer_peer == null:
		NetworkManager.notify_turn_changed(GameState.turn_player_id)
	_update_turn_ui()

func _check_game_state_after_move(mover_id: int) -> void:
	for pid in GameState.players_info:
		if GameState.is_frozen(pid):
			continue
		if ChessLogic.is_checkmate(GameState, pid):
			GameState.set_frozen(pid, true)
			AudioManager.play_checkmate()
			status_label.text = LocaleManager.t("mate")
		elif ChessLogic.is_stalemate(GameState, pid):
			GameState.set_frozen(pid, true)
			status_label.text = LocaleManager.t("stalemate")
		elif ChessLogic.is_in_check(GameState, pid):
			AudioManager.play_check()
			status_label.text = LocaleManager.t("check")
	var team = GameState.get_team(mover_id)
	if GameState.all_opponents_frozen(team):
		status_label.text = LocaleManager.t("victory") % team
		draw_btn.disabled = true
	if GameState.both_team_stalemated(team):
		status_label.text = LocaleManager.t("draw_accepted")

func _on_turn_changed(new_id: int) -> void:
	GameState.turn_player_id = new_id
	_update_turn_ui()

func _update_turn_ui() -> void:
	var pid = GameState.turn_player_id
	var info = GameState.players_info.get(pid, {})
	var name = info.get("name", "?")
	var frozen = GameState.is_frozen(pid)
	var color: Color = info.get("color", Color.WHITE)
	var frozen_s = " (" + LocaleManager.t("frozen") + ")" if frozen else ""
	turn_label.text = "%s: %s%s" % [LocaleManager.t("turn"), name, frozen_s]
	turn_label.add_theme_color_override("font_color", color)
	_highlight_current_badge(pid)

func _highlight_current_badge(current_id: int) -> void:
	for pid in badge_nodes:
		var panel: PanelContainer = badge_nodes[pid]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
		if pid == current_id:
			style.border_color = Color(1.0, 0.9, 0.2)
			style.set_border_width_all(3)
			style.bg_color = Color(0.2, 0.18, 0.05, 0.92)
		else:
			var info = GameState.players_info.get(pid, {})
			style.border_color = info.get("color", Color.WHITE)
			style.set_border_width_all(2)
			style.bg_color = Color(0.1, 0.1, 0.14, 0.85)
		panel.add_theme_stylebox_override("panel", style)

func _create_badges() -> void:
	for c in badges_container.get_children():
		c.queue_free()
	badge_nodes.clear()
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
		badge_nodes[pid] = badge
	_highlight_current_badge(GameState.turn_player_id)

func _on_draw_offer() -> void:
	NetworkManager.propose_or_vote_draw()

func _on_draw_state(proposed_team: int, votes: Dictionary, accepted: bool) -> void:
	if accepted:
		status_label.text = LocaleManager.t("draw_accepted")
		draw_btn.disabled = true
	else:
		status_label.text = "Draw T%d: %d/%d" % [proposed_team, votes.size(), NetworkManager.players.size()]

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
	GameState.game_in_progress = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_fullscreen() -> void:
	Settings.toggle_fullscreen()

func _on_lang() -> void:
	LocaleManager.toggle()
	lang_btn.text = "RU" if LocaleManager.current_locale == "en" else "EN"
	draw_btn.text = LocaleManager.t("draw")
	_update_turn_ui()
