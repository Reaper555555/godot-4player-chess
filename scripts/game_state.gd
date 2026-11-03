extends Node
## Global game state — board, pieces, turn order, frozen players, en passant, etc.

enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum Slot { TOP_LEFT, BOTTOM_LEFT, TOP_RIGHT, BOTTOM_RIGHT }

const BOARD_WIDTH := 16
const BOARD_HEIGHT := 8

const SLOT_FORWARD := {
	Slot.TOP_LEFT: 1,
	Slot.BOTTOM_LEFT: -1,
	Slot.TOP_RIGHT: 1,
	Slot.BOTTOM_RIGHT: -1,
}

var current_turn_order: int = 1
var turn_player_id: int = 0
var frozen_players: Dictionary = {}
var board: Array = []
var players_info: Dictionary = {}
var move_history: Array = []
var en_passant_target: Vector2i = Vector2i(-1, -1)
var draw_votes: Dictionary = {}
var draw_proposed_by_team: int = -1
var game_in_progress := false

func _ready() -> void:
	_init_empty_board()

func _init_empty_board() -> void:
	board.clear()
	board.resize(BOARD_WIDTH)
	for x in BOARD_WIDTH:
		board[x] = []
		board[x].resize(BOARD_HEIGHT)
		for y in BOARD_HEIGHT:
			board[x][y] = null
	en_passant_target = Vector2i(-1, -1)
	draw_votes.clear()
	draw_proposed_by_team = -1

func setup_initial_position(players: Dictionary) -> void:
	_init_empty_board()
	players_info.clear()
	for k in players:
		players_info[int(k)] = players[k]
	frozen_players.clear()
	move_history.clear()
	game_in_progress = true

	for pid in players_info:
		var info = players_info[pid]
		var slot: Slot = _slot_from_string(str(info.get("slot", "bottom_left")))
		var color: Color = info.get("color", Color.WHITE)
		_place_full_set(int(pid), slot, color)

	var ordered := []
	for pid in players_info:
		ordered.append({"id": int(pid), "order": int(players_info[pid].get("turn_order", 99))})
	ordered.sort_custom(func(a, b): return a.order < b.order)
	if ordered.size() > 0:
		turn_player_id = ordered[0].id
		current_turn_order = ordered[0].order
	else:
		turn_player_id = 0

func _slot_from_string(s: String) -> Slot:
	match s.to_lower():
		"top_left": return Slot.TOP_LEFT
		"bottom_left": return Slot.BOTTOM_LEFT
		"top_right": return Slot.TOP_RIGHT
		"bottom_right": return Slot.BOTTOM_RIGHT
		_: return Slot.BOTTOM_LEFT

func _place_full_set(owner_id: int, slot: Slot, color: Color) -> void:
	var is_top := slot == Slot.TOP_LEFT or slot == Slot.TOP_RIGHT
	var is_left := slot == Slot.TOP_LEFT or slot == Slot.BOTTOM_LEFT
	var base_x := 0 if is_left else 8
	var pawn_rank := 1 if is_top else 6
	var back_rank := 0 if is_top else 7
	var back_pieces := [
		PieceType.ROOK, PieceType.KNIGHT, PieceType.BISHOP,
		PieceType.QUEEN, PieceType.KING,
		PieceType.BISHOP, PieceType.KNIGHT, PieceType.ROOK
	]
	for i in 8:
		var x = base_x + i
		board[x][back_rank] = {
			"type": back_pieces[i],
			"owner": owner_id,
			"color": color,
			"has_moved": false
		}
		board[x][pawn_rank] = {
			"type": PieceType.PAWN,
			"owner": owner_id,
			"color": color,
			"has_moved": false
		}

func get_piece(x: int, y: int) -> Variant:
	if x < 0 or x >= BOARD_WIDTH or y < 0 or y >= BOARD_HEIGHT:
		return null
	return board[x][y]

func set_piece(x: int, y: int, piece: Variant) -> void:
	if x < 0 or x >= BOARD_WIDTH or y < 0 or y >= BOARD_HEIGHT:
		return
	board[x][y] = piece

func is_frozen(peer_id: int) -> bool:
	return frozen_players.get(int(peer_id), false)

func set_frozen(peer_id: int, frozen: bool) -> void:
	var id = int(peer_id)
	if frozen:
		frozen_players[id] = true
	else:
		frozen_players.erase(id)

func next_turn() -> void:
	var orders := []
	for pid in players_info:
		var id = int(pid)
		if not is_frozen(id):
			orders.append({"id": id, "order": int(players_info[pid].get("turn_order", 99))})
	if orders.is_empty():
		# Solo / all frozen: stay on current if possible
		if players_info.has(turn_player_id) or players_info.has(str(turn_player_id)):
			return
		return
	orders.sort_custom(func(a, b): return a.order < b.order)
	var idx := 0
	for i in orders.size():
		if orders[i].id == int(turn_player_id):
			idx = i
			break
	var next_idx = (idx + 1) % orders.size()
	turn_player_id = orders[next_idx].id
	current_turn_order = orders[next_idx].order

func get_player_slot(peer_id: int) -> Slot:
	var id = int(peer_id)
	var s = players_info.get(id, players_info.get(str(id), {})).get("slot", "bottom_left")
	return _slot_from_string(str(s))

func get_forward_dir(peer_id: int) -> int:
	var slot = get_player_slot(peer_id)
	return SLOT_FORWARD.get(slot, -1)

func apply_move(from: Vector2i, to: Vector2i, promotion_type: int = -1) -> Dictionary:
	var piece = get_piece(from.x, from.y)
	if piece == null:
		return {}
	var result := {
		"captured": false,
		"castle": false,
		"en_passant": false,
		"promotion": false,
	}
	var owner_id: int = int(piece.owner)
	var dir = get_forward_dir(owner_id)

	if piece.type == PieceType.PAWN and to == en_passant_target:
		var cap_y = to.y - dir
		set_piece(to.x, cap_y, null)
		result.en_passant = true
		result.captured = true

	var captured_piece = get_piece(to.x, to.y)
	if captured_piece != null:
		result.captured = true

	if piece.type == PieceType.KING and abs(to.x - from.x) == 2 and to.y == from.y:
		var step = 1 if to.x > from.x else -1
		var rook_x = -1
		for i in range(1, 5):
			var cx = from.x + i * step
			var p = get_piece(cx, from.y)
			if p and p.type == PieceType.ROOK and int(p.owner) == owner_id:
				rook_x = cx
				break
		if rook_x >= 0:
			var rook = get_piece(rook_x, from.y)
			set_piece(rook_x, from.y, null)
			rook.has_moved = true
			var new_rook_x = to.x - step
			set_piece(new_rook_x, from.y, rook)
			result.castle = true

	piece.has_moved = true
	set_piece(to.x, to.y, piece)
	set_piece(from.x, from.y, null)

	en_passant_target = Vector2i(-1, -1)
	if piece.type == PieceType.PAWN and abs(to.y - from.y) == 2:
		en_passant_target = Vector2i(from.x, from.y + dir)

	if piece.type == PieceType.PAWN:
		var promote_rank = 7 if dir == 1 else 0
		if to.y == promote_rank:
			result.promotion = true
			if promotion_type >= 0:
				piece.type = promotion_type
			else:
				piece.type = PieceType.QUEEN

	move_history.append({"from": from, "to": to, "result": result})
	return result

func get_team(peer_id: int) -> int:
	var id = int(peer_id)
	return int(players_info.get(id, players_info.get(str(id), {})).get("team", 0))

func all_opponents_frozen(my_team: int) -> bool:
	var any_opponent := false
	for pid in players_info:
		var t = get_team(int(pid))
		if t != my_team:
			any_opponent = true
			if not is_frozen(int(pid)):
				return false
	return any_opponent

func both_team_stalemated(team: int) -> bool:
	var members := []
	for pid in players_info:
		if get_team(int(pid)) == team:
			members.append(int(pid))
	if members.is_empty():
		return false
	for pid in members:
		if not is_frozen(pid):
			return false
	return true

func serialize() -> Dictionary:
	var cells: Array = []
	for x in BOARD_WIDTH:
		for y in BOARD_HEIGHT:
			var p = board[x][y]
			if p == null:
				continue
			cells.append({
				"x": x, "y": y,
				"type": int(p.type),
				"owner": int(p.owner),
				"color": p.color.to_html(true),
				"has_moved": bool(p.get("has_moved", false)),
			})
	var pinfo := {}
	for k in players_info:
		pinfo[str(int(k))] = players_info[k]
	return {
		"turn_player_id": int(turn_player_id),
		"current_turn_order": current_turn_order,
		"frozen": frozen_players.keys().map(func(x): return int(x)),
		"en_passant": [en_passant_target.x, en_passant_target.y],
		"players_info": pinfo,
		"cells": cells,
		"draw_proposed_by_team": draw_proposed_by_team,
		"draw_votes": draw_votes,
		"game_in_progress": game_in_progress,
	}

func apply_snapshot(data: Dictionary) -> void:
	_init_empty_board()
	players_info.clear()
	var raw = data.get("players_info", {})
	for k in raw:
		players_info[int(k)] = raw[k]
	turn_player_id = int(data.get("turn_player_id", 0))
	current_turn_order = int(data.get("current_turn_order", 1))
	frozen_players.clear()
	for pid in data.get("frozen", []):
		frozen_players[int(pid)] = true
	var ep = data.get("en_passant", [-1, -1])
	en_passant_target = Vector2i(int(ep[0]), int(ep[1]))
	draw_proposed_by_team = int(data.get("draw_proposed_by_team", -1))
	draw_votes = data.get("draw_votes", {}).duplicate(true)
	game_in_progress = bool(data.get("game_in_progress", false))
	for c in data.get("cells", []):
		var col = Color.html(str(c.get("color", "#ffffff")))
		board[int(c.x)][int(c.y)] = {
			"type": int(c.type),
			"owner": int(c.owner),
			"color": col,
			"has_moved": bool(c.get("has_moved", false)),
		}
