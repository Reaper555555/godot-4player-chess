extends Node
## Global game state — board, pieces, turn order, frozen players, etc.

enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum Slot { TOP_LEFT, BOTTOM_LEFT, TOP_RIGHT, BOTTOM_RIGHT }

const BOARD_WIDTH := 16
const BOARD_HEIGHT := 8

# Slot -> direction of pawns (1 = up/decreasing rank, -1 = down/increasing rank)
const SLOT_FORWARD := {
	Slot.TOP_LEFT: 1,
	Slot.BOTTOM_LEFT: -1,
	Slot.TOP_RIGHT: 1,
	Slot.BOTTOM_RIGHT: -1,
}

# Slot -> home ranks for pieces (rank 0 is top of board visually? We use rank 0 = top)
# Standard: bottom player has pieces on ranks 6-7 (if 0=top), top on 0-1.

var current_turn_order: int = 1  # 1..4
var turn_player_id: int = 0
var frozen_players: Dictionary = {}  # peer_id -> true if checkmated/stalemated
var board: Array = []  # 16x8, each cell: null or {type, owner_id, color, has_moved}
var players_info: Dictionary = {}  # peer_id -> full info from lobby
var move_history: Array = []

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

func setup_initial_position(players: Dictionary) -> void:
	## players: peer_id -> {slot, color, team, turn_order, name}
	_init_empty_board()
	players_info = players.duplicate(true)
	frozen_players.clear()
	move_history.clear()

	for pid in players:
		var info = players[pid]
		var slot: Slot = _slot_from_string(info.get("slot", "bottom_left"))
		var color: Color = info.get("color", Color.WHITE)
		_place_full_set(pid, slot, color)

	# Determine first player by lowest turn_order
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

	# Back rank order (same for adjacent, mirrored for opposite as classic)
	# Classic white (bottom): R N B Q K B N R
	# Classic black (top):   r n b q k b n r  (files a-h)
	# For consistency we use the same relative order from left of their half.
	var back_pieces := [
		PieceType.ROOK, PieceType.KNIGHT, PieceType.BISHOP,
		PieceType.QUEEN, PieceType.KING,
		PieceType.BISHOP, PieceType.KNIGHT, PieceType.ROOK
	]

	for i in 8:
		var x = base_x + i
		# Back rank
		board[x][back_rank] = {
			"type": back_pieces[i],
			"owner": owner_id,
			"color": color,
			"has_moved": false
		}
		# Pawns
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
	# Find next non-frozen player by turn_order
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
