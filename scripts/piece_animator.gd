extends Node2D
## Straight-line move animation with vector piece silhouette.

signal animation_finished

var animating := false
var from_pos: Vector2
var to_pos: Vector2
var progress := 0.0
var duration := 0.18
var piece_data: Dictionary = {}
var callback: Callable
var piece_size := 64.0 * 0.78

func start(from_cell: Vector2i, to_cell: Vector2i, piece: Dictionary, board_view: Node2D, on_finished: Callable = Callable()) -> void:
	if animating:
		return
	animating = true
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
	var t = ease(progress, -1.5)
	var pos = from_pos.lerp(to_pos, t)
	var color: Color = piece_data.get("color", Color.WHITE)
	var ptype: int = int(piece_data.get("type", 0))
	PieceDraw.draw_piece(self, pos, ptype, color, piece_size)
