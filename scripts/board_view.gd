extends Node2D
## Draws the 16x8 board, pieces (vector), selection, possible moves, badges.

const CELL_SIZE := 64.0
const BOARD_ORIGIN := Vector2(64, 64)  # margin

var selected_cell: Vector2i = Vector2i(-1, -1)
var possible_moves: Array[Vector2i] = []
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)

# Piece drawing helpers
const PIECE_SYMBOLS := {
	GameState.PieceType.PAWN: "♟",
	GameState.PieceType.KNIGHT: "♞",
	GameState.PieceType.BISHOP: "♝",
	GameState.PieceType.ROOK: "♜",
	GameState.PieceType.QUEEN: "♛",
	GameState.PieceType.KING: "♚",
}

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	_draw_board()
	_draw_last_move()
	_draw_pieces()
	_draw_selection()
	_draw_possible_moves()

func _draw_board() -> void:
	for x in GameState.BOARD_WIDTH:
		for y in GameState.BOARD_HEIGHT:
			var rect = Rect2(BOARD_ORIGIN + Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
			var is_light = (x + y) % 2 == 0
			var col = Color(0.93, 0.84, 0.68) if is_light else Color(0.55, 0.38, 0.25)
			# Slightly different tone for the two halves
			if x >= 8:
				col = col.darkened(0.08)
			draw_rect(rect, col)
	# Outer border
	var total = Vector2(GameState.BOARD_WIDTH, GameState.BOARD_HEIGHT) * CELL_SIZE
	draw_rect(Rect2(BOARD_ORIGIN - Vector2(2, 2), total + Vector2(4, 4)), Color(0.15, 0.1, 0.05), false, 4.0)
	# Divider between two boards
	var mid_x = BOARD_ORIGIN.x + 8 * CELL_SIZE
	draw_line(Vector2(mid_x, BOARD_ORIGIN.y), Vector2(mid_x, BOARD_ORIGIN.y + 8 * CELL_SIZE), Color(0.2, 0.15, 0.1), 3.0)

func _draw_pieces() -> void:
	for x in GameState.BOARD_WIDTH:
		for y in GameState.BOARD_HEIGHT:
			var p = GameState.get_piece(x, y)
			if p == null:
				continue
			var center = BOARD_ORIGIN + Vector2(x + 0.5, y + 0.5) * CELL_SIZE
			_draw_piece(center, p)

func _draw_piece(center: Vector2, piece: Dictionary) -> void:
	var color: Color = piece.color
	var outline = color.darkened(0.45)
	var radius = CELL_SIZE * 0.38

	# Soft shadow
	draw_circle(center + Vector2(2, 3), radius, Color(0, 0, 0, 0.25))

	# Fill
	draw_circle(center, radius, color)
	# Outline
	draw_arc(center, radius, 0, TAU, 32, outline, 3.5, true)

	# Symbol (Unicode chess) — for minimal look we can keep or remove later
	var symbol = PIECE_SYMBOLS.get(piece.type, "?")
	var font = ThemeDB.fallback_font
	var font_size = int(CELL_SIZE * 0.55)
	var text_size = font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = center - text_size / 2.0 + Vector2(0, font_size * 0.35)
	# Dark or light text depending on piece brightness
	var text_col = Color.WHITE if color.get_luminance() < 0.5 else Color(0.1, 0.1, 0.1)
	draw_string(font, text_pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

func _draw_selection() -> void:
	if selected_cell.x < 0:
		return
	var center = BOARD_ORIGIN + Vector2(selected_cell.x + 0.5, selected_cell.y + 0.5) * CELL_SIZE
	draw_arc(center, CELL_SIZE * 0.45, 0, TAU, 48, Color(1.0, 0.9, 0.2, 0.9), 4.0, true)

func _draw_possible_moves() -> void:
	for m in possible_moves:
		var center = BOARD_ORIGIN + Vector2(m.x + 0.5, m.y + 0.5) * CELL_SIZE
		var target = GameState.get_piece(m.x, m.y)
		if target:
			# Capture indicator — ring
			draw_arc(center, CELL_SIZE * 0.4, 0, TAU, 32, Color(0.9, 0.2, 0.2, 0.7), 3.0, true)
		else:
			# Empty move — filled circle
			draw_circle(center, CELL_SIZE * 0.18, Color(0.2, 0.2, 0.2, 0.45))

func _draw_last_move() -> void:
	if last_move_from.x < 0:
		return
	for cell in [last_move_from, last_move_to]:
		var rect = Rect2(BOARD_ORIGIN + Vector2(cell) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
		draw_rect(rect, Color(0.95, 0.85, 0.3, 0.35))

func cell_from_pos(pos: Vector2) -> Vector2i:
	var local = pos - BOARD_ORIGIN
	var x = int(local.x / CELL_SIZE)
	var y = int(local.y / CELL_SIZE)
	if x < 0 or x >= GameState.BOARD_WIDTH or y < 0 or y >= GameState.BOARD_HEIGHT:
		return Vector2i(-1, -1)
	return Vector2i(x, y)

func pos_from_cell(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(cell.x + 0.5, cell.y + 0.5) * CELL_SIZE

func set_selection(cell: Vector2i, moves: Array[Vector2i] = []) -> void:
	selected_cell = cell
	possible_moves = moves
	queue_redraw()

func clear_selection() -> void:
	selected_cell = Vector2i(-1, -1)
	possible_moves.clear()
	queue_redraw()

func set_last_move(from: Vector2i, to: Vector2i) -> void:
	last_move_from = from
	last_move_to = to
	queue_redraw()

func refresh() -> void:
	queue_redraw()
