extends Node2D
## Simple straight-line move animation for pieces.

signal animation_finished

var animating := false
var from_pos: Vector2
var to_pos: Vector2
var progress := 0.0
var duration := 0.18  # seconds
var piece_data: Dictionary = {}
var callback: Callable

func start(from_cell: Vector2i, to_cell: Vector2i, piece: Dictionary, board_view: Node2D, on_finished: Callable = Callable()) -> void:
	if animating:
		return
	animateing = true
	from_pos = board_view.pos_from_cell(from_cell)
	to_pos = board_view.pos_from_cell(to_cell)
	piece_data = piece.duplicate()
	progress = 0.0
	callback = on_finished
	show()
	queue_redraw()

func _process(delta: float) -> void:
	if not animating:
		return
	progress += delta / duration
	if progress >= 1.0:
		progress = 1.0
		animating = false
		hide()
		animation_finished.emit()
		if callback.is_valid():
			callback.call()
	queue_redraw()

func _draw() -> void:
	if not animating and progress <= 0.0:
		return
	var t = ease(progress, -1.5)  # slight ease-out
	var pos = from_pos.lerp(to_pos, t)
	var color: Color = piece_data.get("color", Color.WHITE)
	var radius = 64.0 * 0.38  # match BoardView CELL_SIZE
	draw_circle(pos + Vector2(2, 3), radius, Color(0, 0, 0, 0.25))
	draw_circle(pos, radius, color)
	draw_arc(pos, radius, 0, TAU, 32, color.darkened(0.45), 3.5, true)
