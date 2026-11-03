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

# Draw voting: peer_id -> true if accepted
var draw_votes: Dictionary = {}
var draw_proposed_by_team: int = -1

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
	players_info = players.duplicate(true)
	frozen_players.clear()
	move_history.clear()

	for pid in players:
		var info = players[pid]
		var slot: Slot = _slot_from_string(info.get("slot", "bottom_left"))
		var color: Color = info.get("color", Color.WHITE)
		_place_full_set(pid, slot, color)

	var ordered := []
	for pid in players:
		ordered.append({"id": pid, "order": players[pid].get("turn_order", 99)})
	ordered.sort_custom(func(a, b): return a.order < b.order)
	if ordered.size() > 0:
		turn_player_id = ordered[0].id
		current_turn_order = ordered[0].order

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
	return frozen_players.get(peer_id, false)

func set_frozen(peer_id: int, frozen: bool) -> void:
	if frozen:
		frozen_players[peer_id] = true
	else:
		frozen_players.erase(peer_id)

func next_turn() -> void:
	var orders := []
	for pid in players_info:
		if not is_frozen(pid):
			orders.append({"id": pid, "order": players_info[pid].get("turn_order", 99)})
	if orders.is_empty():
		return
	orders.sort_custom(func(a, b): return a.order < b.order)
	var idx := 0
	for i in orders.size():
		if orders[i].id == turn_player_id:
			idx = i
			break
	var next_idx = (idx + 1) % orders.size()
	turn_player_id = orders[next_idx].id
	current_turn_order = orders[next_idx].order

func get_player_slot(peer_id: int) -> Slot:
	var s = players_info.get(peer_id, {}).get("slot", "bottom_left")
	return _slot_from_string(s)

func get_forward_dir(peer_id: int) -> int:
	var slot = get_player_slot(peer_id)
	return SLOT_FORWARD.get(slot, -1)

## Apply a validated move, handling castling, en passant, promotion.
## promotion_type: PieceType or -1 to keep as is / ask later
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
	var owner_id: int = piece.owner
	var dir = get_forward_dir(owner_id)

	# En passant capture
	if piece.type == PieceType.PAWN and to == en_passant_target:
		var cap_y = to.y - dir
		set_piece(to.x, cap_y, null)
		result.en_passant = true
		result.captured = true

	var captured_piece = get_piece(to.x, to.y)
	if captured_piece != null:
		result.captured = true

	# Castling: king moves 2 squares horizontally
	if piece.type == PieceType.KING and abs(to.x - from.x) == 2 and to.y == from.y:
		var step = 1 if to.x > from.x else -1
		# Find rook in that direction on same rank
		var rook_x = -1
		for i in range(1, 5):
			var cx = from.x + i * step
			var p = get_piece(cx, from.y)
			if p and p.type == PieceType.ROOK and p.owner == owner_id:
				rook_x = cx
				break
		if rook_x >= 0:
			var rook = get_piece(rook_x, from.y)
			set_piece(rook_x, from.y, null)
			rook.has_moved = true
			var new_rook_x = to.x - step  # rook lands next to king
			set_piece(new_rook_x, from.y, rook)
			result.castle = true

	# Move piece
	piece.has_moved = true
	set_piece(to.x, to.y, piece)
	set_piece(from.x, from.y, null)

	# Update en passant target
	en_passant_target = Vector2i(-1, -1)
	if piece.type == PieceType.PAWN and abs(to.y - from.y) == 2:
		en_passant_target = Vector2i(from.x, from.y + dir)

	# Promotion
	if piece.type == PieceType.PAWN:
		var promote_rank = 7 if dir == 1 else 0
		if to.y == promote_rank:
			result.promotion = true
			if promotion_type >= 0:
				piece.type = promotion_type
			else:
				piece.type = PieceType.QUEEN  # default

	move_history.append({"from": from, "to": to, "result": result})
	return result

func get_team(peer_id: int) -> int:
	return players_info.get(peer_id, {}).get("team", 0)

func all_opponents_frozen(my_team: int) -> bool:
	var any_opponent := false
	for pid in players_info:
		var t = get_team(pid)
		if t != my_team:
			any_opponent = true
			if not is_frozen(pid):
				return false
	return any_opponent

func both_team_stalemated(team: int) -> bool:
	var members := []
	for pid in players_info:
		if get_team(pid) == team:
			members.append(pid)
	if members.is_empty():
		return false
	for pid in members:
		if not is_frozen(pid):
			return false
	return true
