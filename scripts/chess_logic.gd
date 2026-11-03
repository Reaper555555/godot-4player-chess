extends RefCounted
## Pure chess move generation and validation for the 16x8 multi-player board.
## Classic rules + castling + en passant. Frozen pieces cannot be captured.

const PieceType = GameState.PieceType

static func get_possible_moves(state: GameState, from_x: int, from_y: int) -> Array[Vector2i]:
	var piece = state.get_piece(from_x, from_y)
	if piece == null:
		return []
	var owner_id: int = piece.owner
	if state.is_frozen(owner_id):
		return []

	var moves: Array[Vector2i] = []
	match piece.type:
		PieceType.PAWN:
			moves = _pawn_moves(state, from_x, from_y, owner_id)
		PieceType.KNIGHT:
			moves = _knight_moves(state, from_x, from_y, owner_id)
		PieceType.BISHOP:
			moves = _sliding_moves(state, from_x, from_y, owner_id, [[1,1],[1,-1],[-1,1],[-1,-1]])
		PieceType.ROOK:
			moves = _sliding_moves(state, from_x, from_y, owner_id, [[1,0],[-1,0],[0,1],[0,-1]])
		PieceType.QUEEN:
			moves = _sliding_moves(state, from_x, from_y, owner_id, [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]])
		PieceType.KING:
			moves = _king_moves(state, from_x, from_y, owner_id)

	var legal: Array[Vector2i] = []
	for m in moves:
		if not _would_leave_in_check(state, from_x, from_y, m.x, m.y, owner_id):
			legal.append(m)
	return legal

static func _is_enemy(state: GameState, x: int, y: int, my_id: int) -> bool:
	var p = state.get_piece(x, y)
	if p == null:
		return false
	if state.is_frozen(p.owner):
		return false
	return p.owner != my_id

static func _is_empty_or_enemy(state: GameState, x: int, y: int, my_id: int) -> bool:
	var p = state.get_piece(x, y)
	if p == null:
		return true
	return _is_enemy(state, x, y, my_id)

static func _on_board(x: int, y: int) -> bool:
	return x >= 0 and x < GameState.BOARD_WIDTH and y >= 0 and y < GameState.BOARD_HEIGHT

static func _pawn_moves(state: GameState, x: int, y: int, owner_id: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var dir := state.get_forward_dir(owner_id)
	var piece = state.get_piece(x, y)
	var start_rank := 1 if dir == 1 else 6

	var ny = y + dir
	if _on_board(x, ny) and state.get_piece(x, ny) == null:
		moves.append(Vector2i(x, ny))
		if y == start_rank and not piece.get("has_moved", false):
			var ny2 = y + 2 * dir
			if _on_board(x, ny2) and state.get_piece(x, ny2) == null:
				moves.append(Vector2i(x, ny2))

	for dx in [-1, 1]:
		var nx = x + dx
		ny = y + dir
		if _on_board(nx, ny) and _is_enemy(state, nx, ny, owner_id):
			moves.append(Vector2i(nx, ny))

	# En passant
	var ep: Vector2i = state.en_passant_target
	if ep.x >= 0:
		for dx in [-1, 1]:
			if x + dx == ep.x and y + dir == ep.y:
				moves.append(ep)
	return moves

static func _knight_moves(state: GameState, x: int, y: int, owner_id: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var deltas := [[1,2],[1,-2],[-1,2],[-1,-2],[2,1],[2,-1],[-2,1],[-2,-1]]
	for d in deltas:
		var nx = x + d[0]
		var ny = y + d[1]
		if _on_board(nx, ny) and _is_empty_or_enemy(state, nx, ny, owner_id):
			moves.append(Vector2i(nx, ny))
	return moves

static func _sliding_moves(state: GameState, x: int, y: int, owner_id: int, dirs: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for d in dirs:
		var nx = x + d[0]
		var ny = y + d[1]
		while _on_board(nx, ny):
			var p = state.get_piece(nx, ny)
			if p == null:
				moves.append(Vector2i(nx, ny))
			elif _is_enemy(state, nx, ny, owner_id):
				moves.append(Vector2i(nx, ny))
				break
			else:
				break
			nx += d[0]
			ny += d[1]
	return moves

static func _king_moves(state: GameState, x: int, y: int, owner_id: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx = x + dx
			var ny = y + dy
			if _on_board(nx, ny) and _is_empty_or_enemy(state, nx, ny, owner_id):
				moves.append(Vector2i(nx, ny))

	# Castling (same rank, king not moved, rook not moved, path empty, not in check)
	var piece = state.get_piece(x, y)
	if piece.get("has_moved", false):
		return moves
	if is_in_check(state, owner_id):
		return moves

	# Kingside: towards higher file within the player's half
	var is_left_half = x < 8
	var base = 0 if is_left_half else 8
	# Rook at base+7 (right of half), king typically at base+4
	for side in [1, -1]:  # +1 kingside-ish, -1 queenside-ish relative to king file
		var rook_x = -1
		var step = side
		var path_clear = true
		var dist = 0
		for i in range(1, 5):
			var cx = x + i * step
			if not _on_board(cx, y):
				path_clear = false
				break
			var p = state.get_piece(cx, y)
			if p != null:
				if p.type == PieceType.ROOK and p.owner == owner_id and not p.get("has_moved", false):
					rook_x = cx
					dist = i
				break
				else:
					path_clear = false
					break
		if rook_x < 0 or not path_clear or dist < 2:
			continue
		# King moves 2 squares toward rook
		var king_dest_x = x + 2 * step
		if not _on_board(king_dest_x, y):
			continue
		# Squares king passes through must not be attacked
		var safe = true
		for sq in [x + step, king_dest_x]:
			if _square_attacked(state, sq, y, owner_id):
				safe = false
				break
		if safe:
			moves.append(Vector2i(king_dest_x, y))
	return moves

static func _square_attacked(state: GameState, x: int, y: int, defender_id: int) -> bool:
	for sx in GameState.BOARD_WIDTH:
		for sy in GameState.BOARD_HEIGHT:
			var p = state.get_piece(sx, sy)
			if p == null or p.owner == defender_id:
				continue
			if state.is_frozen(p.owner):
				continue
			var attacks = _raw_attacks(state, sx, sy, p)
			if Vector2i(x, y) in attacks:
				return true
	return false

static func _would_leave_in_check(state: GameState, from_x: int, from_y: int, to_x: int, to_y: int, owner_id: int) -> bool:
	var original = state.get_piece(from_x, from_y)
	var captured = state.get_piece(to_x, to_y)
	# En passant capture removal
	var ep_captured = null
	var ep_pos = Vector2i(-1, -1)
	if original and original.type == PieceType.PAWN and to_x == state.en_passant_target.x and to_y == state.en_passant_target.y:
		var dir = state.get_forward_dir(owner_id)
		ep_pos = Vector2i(to_x, to_y - dir)
		ep_captured = state.get_piece(ep_pos.x, ep_pos.y)
		state.set_piece(ep_pos.x, ep_pos.y, null)

	state.set_piece(to_x, to_y, original)
	state.set_piece(from_x, from_y, null)

	var in_check := is_in_check(state, owner_id)

	state.set_piece(from_x, from_y, original)
	state.set_piece(to_x, to_y, captured)
	if ep_captured != null:
		state.set_piece(ep_pos.x, ep_pos.y, ep_captured)
	return in_check

static func is_in_check(state: GameState, owner_id: int) -> bool:
	var king_pos := _find_king(state, owner_id)
	if king_pos == Vector2i(-1, -1):
		return false
	return _square_attacked(state, king_pos.x, king_pos.y, owner_id)

static func _find_king(state: GameState, owner_id: int) -> Vector2i:
	for x in GameState.BOARD_WIDTH:
		for y in GameState.BOARD_HEIGHT:
			var p = state.get_piece(x, y)
			if p and p.owner == owner_id and p.type == PieceType.KING:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

static func _raw_attacks(state: GameState, x: int, y: int, piece: Dictionary) -> Array[Vector2i]:
	var owner_id = piece.owner
	match piece.type:
		PieceType.PAWN:
			var dir = state.get_forward_dir(owner_id)
			var res: Array[Vector2i] = []
			for dx in [-1, 1]:
				var nx = x + dx
				var ny = y + dir
				if _on_board(nx, ny):
					res.append(Vector2i(nx, ny))
			return res
		PieceType.KNIGHT:
			var moves: Array[Vector2i] = []
			var deltas := [[1,2],[1,-2],[-1,2],[-1,-2],[2,1],[2,-1],[-2,1],[-2,-1]]
			for d in deltas:
				var nx = x + d[0]
				var ny = y + d[1]
				if _on_board(nx, ny):
					moves.append(Vector2i(nx, ny))
			return moves
		PieceType.BISHOP:
			return _sliding_attacks(state, x, y, [[1,1],[1,-1],[-1,1],[-1,-1]])
		PieceType.ROOK:
			return _sliding_attacks(state, x, y, [[1,0],[-1,0],[0,1],[0,-1]])
		PieceType.QUEEN:
			return _sliding_attacks(state, x, y, [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]])
		PieceType.KING:
			var moves: Array[Vector2i] = []
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var nx = x + dx
					var ny = y + dy
					if _on_board(nx, ny):
						moves.append(Vector2i(nx, ny))
			return moves
	return []

static func _sliding_attacks(state: GameState, x: int, y: int, dirs: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for d in dirs:
		var nx = x + d[0]
		var ny = y + d[1]
		while _on_board(nx, ny):
			moves.append(Vector2i(nx, ny))
			if state.get_piece(nx, ny) != null:
				break
			nx += d[0]
			ny += d[1]
	return moves

static func is_checkmate(state: GameState, owner_id: int) -> bool:
	if not is_in_check(state, owner_id):
		return false
	for x in GameState.BOARD_WIDTH:
		for y in GameState.BOARD_HEIGHT:
			var p = state.get_piece(x, y)
			if p and p.owner == owner_id:
				if get_possible_moves(state, x, y).size() > 0:
					return false
	return true

static func is_stalemate(state: GameState, owner_id: int) -> bool:
	if is_in_check(state, owner_id):
		return false
	for x in GameState.BOARD_WIDTH:
		for y in GameState.BOARD_HEIGHT:
			var p = state.get_piece(x, y)
			if p and p.owner == owner_id:
				if get_possible_moves(state, x, y).size() > 0:
					return false
	return true

## Returns true if a pawn move to (to_x, to_y) should promote
static func is_promotion(state: GameState, from_x: int, from_y: int, to_x: int, to_y: int) -> bool:
	var piece = state.get_piece(from_x, from_y)
	if piece == null or piece.type != PieceType.PAWN:
		return false
	var dir = state.get_forward_dir(piece.owner)
	# Top players (dir=1) promote on rank 7, bottom (dir=-1) on rank 0
	if dir == 1:
		return to_y == 7
	else:
		return to_y == 0
