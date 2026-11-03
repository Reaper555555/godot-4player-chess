extends RefCounted
## Pure chess move generation and validation for the 16x8 multi-player board.
## Classic rules. Frozen players' pieces cannot be captured. King safety checked per owner.

const PieceType = GameState.PieceType

static func get_possible_moves(state: GameState, from_x: int, from_y: int) -> Array[Vector2i]:
	var piece = state.get_piece(from_x, from_y)
	if piece == null:
		return []
	var owner_id: int = piece.owner
	if state.is_frozen(owner_id):
		return []  # Frozen player cannot move

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

	# Filter moves that leave own king in check
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
		return false  # Cannot capture frozen player's pieces
	# Same team? For now treat only same owner as friendly. Teams allow "friendly fire"? No — according to rules, allies can capture? Wait, classic is only own pieces protected. Teams are for victory, not for piece ownership.
	# Pieces of different owners are capturable unless frozen.
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
	var start_rank := 1 if dir == 1 else 6  # top players start rank 1, bottom rank 6

	# One step forward
	var ny = y + dir
	if _on_board(x, ny) and state.get_piece(x, ny) == null:
		moves.append(Vector2i(x, ny))
		# Two steps from start
		if y == start_rank and not piece.has_moved:
			var ny2 = y + 2 * dir
			if _on_board(x, ny2) and state.get_piece(x, ny2) == null:
				moves.append(Vector2i(x, ny2))

	# Captures
	for dx in [-1, 1]:
		var nx = x + dx
		ny = y + dir
		if _on_board(nx, ny) and _is_enemy(state, nx, ny, owner_id):
			moves.append(Vector2i(nx, ny))

	# TODO: en passant later
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
				break  # own piece
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
	# TODO: castling later
	return moves

static func _would_leave_in_check(state: GameState, from_x: int, from_y: int, to_x: int, to_y: int, owner_id: int) -> bool:
	# Make temporary move
	var original = state.get_piece(from_x, from_y)
	var captured = state.get_piece(to_x, to_y)
	state.set_piece(to_x, to_y, original)
	state.set_piece(from_x, from_y, null)

	var in_check := is_in_check(state, owner_id)

	# Undo
	state.set_piece(from_x, from_y, original)
	state.set_piece(to_x, to_y, captured)
	return in_check

static func is_in_check(state: GameState, owner_id: int) -> bool:
	var king_pos := _find_king(state, owner_id)
	if king_pos == Vector2i(-1, -1):
		return false
	# Check if any enemy piece can attack the king
	for x in GameState.BOARD_WIDTH:
		for y in GameState.BOARD_HEIGHT:
			var p = state.get_piece(x, y)
			if p == null or p.owner == owner_id:
				continue
			if state.is_frozen(p.owner):
				continue
			var attacks = _raw_attacks(state, x, y, p)
			if king_pos in attacks:
				return true
	return false

static func _find_king(state: GameState, owner_id: int) -> Vector2i:
	for x in GameState.BOARD_WIDTH:
		for y in GameState.BOARD_HEIGHT:
			var p = state.get_piece(x, y)
			if p and p.owner == owner_id and p.type == PieceType.KING:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

static func _raw_attacks(state: GameState, x: int, y: int, piece: Dictionary) -> Array[Vector2i]:
	# Similar to get_possible_moves but without check filtering and without "cannot capture frozen"
	# Simplified: reuse generation but ignore frozen check for attack detection
	match piece.type:
		PieceType.PAWN:
			var dir = state.get_forward_dir(piece.owner)
			var res: Array[Vector2i] = []
			for dx in [-1, 1]:
				var nx = x + dx
				var ny = y + dir
				if _on_board(nx, ny):
					res.append(Vector2i(nx, ny))
			return res
		PieceType.KNIGHT:
			return _knight_moves(state, x, y, piece.owner)  # approx
		# For sliding/king we can reuse with a relaxed enemy check
		_:
			return get_possible_moves(state, x, y)  # temporary, will refine
	return []

static func is_checkmate(state: GameState, owner_id: int) -> bool:
	if not is_in_check(state, owner_id):
		return false
	# Any legal move?
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
