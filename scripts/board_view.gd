extends Node2D
## Draws the unified 16x8 board, vector pieces, selection, moves, badges.

const CELL_SIZE := 64.0
const BOARD_ORIGIN := Vector2(64, 48)

var selected_cell: Vector2i = Vector2i(-1, -1)
var possible_moves: Array[Vector2i] = []
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)

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
			var col = Color(0.90, 0.82, 0.66) if is_light else Color(0.48, 0.34, 0.22)
			draw_rect(rect, col)
	var total = Vector2(GameState.BOARD_WIDTH, GameState.BOARD_HEIGHT) * CELL_SIZE
	draw_rect(Rect2(BOARD_ORIGIN - Vector2(3, 3), total + Vector2(6, 6)), Color(0.12, 0.09, 0.06), false, 5.0)

func _draw_pieces() -> void:
	for x in GameState.BOARD_WIDTH:
		for y in GameState.BOARD_HEIGHT:
			var p = GameState.get_piece(x, y)
			if p == null:
				continue
			var center = BOARD_ORIGIN + Vector2(x + 0.5, y + 0.5) * CELL_SIZE
			var fill: Color = p.color
			# Dim frozen players slightly
			if GameState.is_frozen(int(p.owner)):
				fill = fill.darkened(0.35)
			PieceDraw.draw_piece(self, center, int(p.type), fill, CELL_SIZE * 0.78)

func _draw_selection() -> void:
	if selected_cell.x < 0:
		return
	var center = BOARD_ORIGIN + Vector2(selected_cell.x + 0.5, selected_cell.y + 0.5) * CELL_SIZE
	draw_arc(center, CELL_SIZE * 0.46, 0, TAU, 48, Color(1.0, 0.92, 0.25, 0.95), 3.5, true)

func _draw_possible_moves() -> void:
	for m in possible_moves:
		var center = BOARD_ORIGIN + Vector2(m.x + 0.5, m.y + 0.5) * CELL_SIZE
		var target = GameState.get_piece(m.x, m.y)
		if target:
			draw_arc(center, CELL_SIZE * 0.40, 0, TAU, 32, Color(0.9, 0.2, 0.2, 0.75), 3.0, true)
		else:
			draw_circle(center, CELL_SIZE * 0.16, Color(0.15, 0.15, 0.15, 0.50))

func _draw_last_move() -> void:
	if last_move_from.x < 0:
		return
	for cell in [last_move_from, last_move_to]:
		var rect = Rect2(BOARD_ORIGIN + Vector2(cell) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
		draw_rect(rect, Color(0.95, 0.85, 0.3, 0.32))

func cell_from_pos(pos: Vector2) -> Vector2i:
	var local = pos - BOARD_ORIGIN
	var x = int(floor(local.x / CELL_SIZE))
	var y = int(floor(local.y / CELL_SIZE))
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
