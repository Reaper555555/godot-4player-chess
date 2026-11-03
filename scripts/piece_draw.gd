class_name PieceDraw
extends RefCounted
## Vector chess silhouettes. Fill = player color, stroke = black outline.

static func draw_piece(canvas: CanvasItem, center: Vector2, piece_type: int, fill: Color, size: float) -> void:
	var s := size
	var outline := Color(0.05, 0.05, 0.08, 1.0)
	var pts := _shape(piece_type, center, s)
	if pts.is_empty():
		return
	# Filled polygon
	canvas.draw_colored_polygon(pts, fill)
	# Outline
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		canvas.draw_line(a, b, outline, max(1.5, s * 0.06), true)

static func _shape(piece_type: int, c: Vector2, s: float) -> PackedVector2Array:
	match piece_type:
		GameState.PieceType.PAWN:
			return _pawn(c, s)
		GameState.PieceType.ROOK:
			return _rook(c, s)
		GameState.PieceType.KNIGHT:
			return _knight(c, s)
		GameState.PieceType.BISHOP:
			return _bishop(c, s)
		GameState.PieceType.QUEEN:
			return _queen(c, s)
		GameState.PieceType.KING:
			return _king(c, s)
		_:
			return _pawn(c, s)

static func _pawn(c: Vector2, s: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	# base
	pts.append(c + Vector2(-0.32, 0.42) * s)
	pts.append(c + Vector2(0.32, 0.42) * s)
	pts.append(c + Vector2(0.28, 0.28) * s)
	# body
	pts.append(c + Vector2(0.18, 0.10) * s)
	pts.append(c + Vector2(0.22, -0.05) * s)
	# head circle approx
	pts.append(c + Vector2(0.16, -0.22) * s)
	pts.append(c + Vector2(0.0, -0.38) * s)
	pts.append(c + Vector2(-0.16, -0.22) * s)
	pts.append(c + Vector2(-0.22, -0.05) * s)
	pts.append(c + Vector2(-0.18, 0.10) * s)
	pts.append(c + Vector2(-0.28, 0.28) * s)
	return pts

static func _rook(c: Vector2, s: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	pts.append(c + Vector2(-0.34, 0.42) * s)
	pts.append(c + Vector2(0.34, 0.42) * s)
	pts.append(c + Vector2(0.30, 0.28) * s)
	pts.append(c + Vector2(0.22, 0.28) * s)
	pts.append(c + Vector2(0.22, -0.05) * s)
	# battlements
	pts.append(c + Vector2(0.30, -0.05) * s)
	pts.append(c + Vector2(0.30, -0.32) * s)
	pts.append(c + Vector2(0.14, -0.32) * s)
	pts.append(c + Vector2(0.14, -0.18) * s)
	pts.append(c + Vector2(0.05, -0.18) * s)
	pts.append(c + Vector2(0.05, -0.32) * s)
	pts.append(c + Vector2(-0.05, -0.32) * s)
	pts.append(c + Vector2(-0.05, -0.18) * s)
	pts.append(c + Vector2(-0.14, -0.18) * s)
	pts.append(c + Vector2(-0.14, -0.32) * s)
	pts.append(c + Vector2(-0.30, -0.32) * s)
	pts.append(c + Vector2(-0.30, -0.05) * s)
	pts.append(c + Vector2(-0.22, -0.05) * s)
	pts.append(c + Vector2(-0.22, 0.28) * s)
	pts.append(c + Vector2(-0.30, 0.28) * s)
	return pts

static func _knight(c: Vector2, s: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	pts.append(c + Vector2(-0.28, 0.42) * s)
	pts.append(c + Vector2(0.30, 0.42) * s)
	pts.append(c + Vector2(0.26, 0.28) * s)
	pts.append(c + Vector2(0.12, 0.10) * s)
	pts.append(c + Vector2(0.28, -0.05) * s)
	pts.append(c + Vector2(0.32, -0.22) * s)
	pts.append(c + Vector2(0.18, -0.38) * s)
	pts.append(c + Vector2(0.02, -0.28) * s)
	pts.append(c + Vector2(-0.08, -0.40) * s)
	pts.append(c + Vector2(-0.22, -0.22) * s)
	pts.append(c + Vector2(-0.18, -0.02) * s)
	pts.append(c + Vector2(-0.28, 0.12) * s)
	pts.append(c + Vector2(-0.22, 0.28) * s)
	return pts

static func _bishop(c: Vector2, s: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	pts.append(c + Vector2(-0.30, 0.42) * s)
	pts.append(c + Vector2(0.30, 0.42) * s)
	pts.append(c + Vector2(0.26, 0.28) * s)
	pts.append(c + Vector2(0.14, 0.18) * s)
	pts.append(c + Vector2(0.20, -0.02) * s)
	pts.append(c + Vector2(0.12, -0.22) * s)
	pts.append(c + Vector2(0.0, -0.40) * s)
	pts.append(c + Vector2(-0.12, -0.22) * s)
	pts.append(c + Vector2(-0.20, -0.02) * s)
	pts.append(c + Vector2(-0.14, 0.18) * s)
	pts.append(c + Vector2(-0.26, 0.28) * s)
	return pts

static func _queen(c: Vector2, s: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	pts.append(c + Vector2(-0.34, 0.42) * s)
	pts.append(c + Vector2(0.34, 0.42) * s)
	pts.append(c + Vector2(0.28, 0.26) * s)
	pts.append(c + Vector2(0.22, 0.08) * s)
	# crown points
	pts.append(c + Vector2(0.32, -0.18) * s)
	pts.append(c + Vector2(0.16, -0.02) * s)
	pts.append(c + Vector2(0.10, -0.32) * s)
	pts.append(c + Vector2(0.0, -0.08) * s)
	pts.append(c + Vector2(-0.10, -0.32) * s)
	pts.append(c + Vector2(-0.16, -0.02) * s)
	pts.append(c + Vector2(-0.32, -0.18) * s)
	pts.append(c + Vector2(-0.22, 0.08) * s)
	pts.append(c + Vector2(-0.28, 0.26) * s)
	return pts

static func _king(c: Vector2, s: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	pts.append(c + Vector2(-0.32, 0.42) * s)
	pts.append(c + Vector2(0.32, 0.42) * s)
	pts.append(c + Vector2(0.28, 0.28) * s)
	pts.append(c + Vector2(0.18, 0.12) * s)
	pts.append(c + Vector2(0.22, -0.08) * s)
	# cross top
	pts.append(c + Vector2(0.08, -0.08) * s)
	pts.append(c + Vector2(0.08, -0.22) * s)
	pts.append(c + Vector2(0.18, -0.22) * s)
	pts.append(c + Vector2(0.18, -0.32) * s)
	pts.append(c + Vector2(0.08, -0.32) * s)
	pts.append(c + Vector2(0.08, -0.42) * s)
	pts.append(c + Vector2(-0.08, -0.42) * s)
	pts.append(c + Vector2(-0.08, -0.32) * s)
	pts.append(c + Vector2(-0.18, -0.32) * s)
	pts.append(c + Vector2(-0.18, -0.22) * s)
	pts.append(c + Vector2(-0.08, -0.22) * s)
	pts.append(c + Vector2(-0.08, -0.08) * s)
	pts.append(c + Vector2(-0.22, -0.08) * s)
	pts.append(c + Vector2(-0.18, 0.12) * s)
	pts.append(c + Vector2(-0.28, 0.28) * s)
	return pts
