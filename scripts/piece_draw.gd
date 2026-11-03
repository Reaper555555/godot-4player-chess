class_name PieceDraw
extends RefCounted
## Detailed vector chess silhouettes. Fill = player color, stroke = black.

static func draw_piece(canvas: CanvasItem, center: Vector2, piece_type: int, fill: Color, size: float) -> void:
	var s := size
	var outline := Color(0.02, 0.02, 0.04, 1.0)
	var pts := _shape(piece_type, center, s)
	if pts.size() < 3:
		return
	canvas.draw_colored_polygon(pts, fill)
	var w := maxf(1.4, s * 0.045)
	for i in pts.size():
		canvas.draw_line(pts[i], pts[(i + 1) % pts.size()], outline, w, true)

static func _shape(piece_type: int, c: Vector2, s: float) -> PackedVector2Array:
	match piece_type:
		0: return _pawn(c, s)
		1: return _knight(c, s)
		2: return _bishop(c, s)
		3: return _rook(c, s)
		4: return _queen(c, s)
		5: return _king(c, s)
		_: return _pawn(c, s)

static func _pawn(c: Vector2, s: float) -> PackedVector2Array:
	var p: PackedVector2Array = []
	# wide base pedestal
	p.append(c + Vector2(-0.34, 0.44) * s)
	p.append(c + Vector2(0.34, 0.44) * s)
	p.append(c + Vector2(0.30, 0.36) * s)
	p.append(c + Vector2(-0.30, 0.36) * s)
	# collar
	p.append(c + Vector2(-0.22, 0.30) * s)
	p.append(c + Vector2(0.22, 0.30) * s)
	p.append(c + Vector2(0.18, 0.22) * s)
	# stem
	p.append(c + Vector2(0.12, 0.06) * s)
	p.append(c + Vector2(0.14, -0.06) * s)
	# ball head (more points)
	for i in 10:
		var a = -PI * 0.15 + float(i) / 9.0 * (PI + PI * 0.3)
		p.append(c + Vector2(cos(a), -0.22 + sin(a) * 0.85) * Vector2(0.17, 0.20) * s + Vector2(0, -0.02) * s)
	p.append(c + Vector2(-0.14, -0.06) * s)
	p.append(c + Vector2(-0.12, 0.06) * s)
	p.append(c + Vector2(-0.18, 0.22) * s)
	p.append(c + Vector2(-0.22, 0.30) * s)
	return p

static func _rook(c: Vector2, s: float) -> PackedVector2Array:
	var p: PackedVector2Array = []
	# base
	p.append(c + Vector2(-0.36, 0.44) * s)
	p.append(c + Vector2(0.36, 0.44) * s)
	p.append(c + Vector2(0.32, 0.34) * s)
	p.append(c + Vector2(-0.32, 0.34) * s)
	# body
	p.append(c + Vector2(-0.22, 0.28) * s)
	p.append(c + Vector2(0.22, 0.28) * s)
	p.append(c + Vector2(0.22, -0.02) * s)
	# merlons: 4 equal battlements
	var tops := [-0.30, -0.12, 0.06, 0.24]
	var w := 0.10
	for t in tops:
		p.append(c + Vector2(t + w, -0.02) * s)
		p.append(c + Vector2(t + w, -0.30) * s)
		p.append(c + Vector2(t, -0.30) * s)
		p.append(c + Vector2(t, -0.14) * s)
	# close left side
	p.append(c + Vector2(-0.30, -0.02) * s)
	p.append(c + Vector2(-0.22, -0.02) * s)
	p.append(c + Vector2(-0.22, 0.28) * s)
	p.append(c + Vector2(-0.32, 0.34) * s)
	return p

static func _knight(c: Vector2, s: float) -> PackedVector2Array:
	var p: PackedVector2Array = []
	# base
	p.append(c + Vector2(-0.30, 0.44) * s)
	p.append(c + Vector2(0.32, 0.44) * s)
	p.append(c + Vector2(0.28, 0.34) * s)
	p.append(c + Vector2(-0.24, 0.34) * s)
	# neck / chest
	p.append(c + Vector2(-0.10, 0.22) * s)
	p.append(c + Vector2(0.08, 0.18) * s)
	p.append(c + Vector2(0.16, 0.02) * s)
	# snout
	p.append(c + Vector2(0.34, -0.08) * s)
	p.append(c + Vector2(0.36, -0.18) * s)
	p.append(c + Vector2(0.22, -0.22) * s)
	# forehead / ear
	p.append(c + Vector2(0.12, -0.34) * s)
	p.append(c + Vector2(0.02, -0.42) * s)
	p.append(c + Vector2(-0.06, -0.34) * s)
	p.append(c + Vector2(-0.04, -0.22) * s)
	# mane back
	p.append(c + Vector2(-0.18, -0.28) * s)
	p.append(c + Vector2(-0.28, -0.12) * s)
	p.append(c + Vector2(-0.24, 0.06) * s)
	p.append(c + Vector2(-0.16, 0.20) * s)
	p.append(c + Vector2(-0.24, 0.34) * s)
	return p

static func _bishop(c: Vector2, s: float) -> PackedVector2Array:
	var p: PackedVector2Array = []
	# base
	p.append(c + Vector2(-0.32, 0.44) * s)
	p.append(c + Vector2(0.32, 0.44) * s)
	p.append(c + Vector2(0.28, 0.34) * s)
	p.append(c + Vector2(-0.28, 0.34) * s)
	# collar
	p.append(c + Vector2(-0.18, 0.28) * s)
	p.append(c + Vector2(0.18, 0.28) * s)
	# body diamond
	p.append(c + Vector2(0.14, 0.12) * s)
	p.append(c + Vector2(0.20, -0.06) * s)
	p.append(c + Vector2(0.10, -0.24) * s)
	# mitre tip with notch (classic bishop cut)
	p.append(c + Vector2(0.04, -0.34) * s)
	p.append(c + Vector2(0.0, -0.44) * s)
	p.append(c + Vector2(-0.04, -0.34) * s)
	p.append(c + Vector2(-0.10, -0.24) * s)
	p.append(c + Vector2(-0.20, -0.06) * s)
	p.append(c + Vector2(-0.14, 0.12) * s)
	p.append(c + Vector2(-0.18, 0.28) * s)
	return p

static func _queen(c: Vector2, s: float) -> PackedVector2Array:
	var p: PackedVector2Array = []
	# base
	p.append(c + Vector2(-0.36, 0.44) * s)
	p.append(c + Vector2(0.36, 0.44) * s)
	p.append(c + Vector2(0.30, 0.32) * s)
	p.append(c + Vector2(-0.30, 0.32) * s)
	# body
	p.append(c + Vector2(-0.20, 0.22) * s)
	p.append(c + Vector2(0.20, 0.22) * s)
	p.append(c + Vector2(0.16, 0.04) * s)
	# 5 crown points
	var tips := [-0.32, -0.16, 0.0, 0.16, 0.32]
	var valleys := [-0.24, -0.08, 0.08, 0.24]
	for i in tips.size():
		if i > 0:
			p.append(c + Vector2(valleys[i - 1], -0.06) * s)
		p.append(c + Vector2(tips[i], -0.36 - (0.06 if i == 2 else 0.0)) * s)
	p.append(c + Vector2(-0.16, 0.04) * s)
	p.append(c + Vector2(-0.20, 0.22) * s)
	return p

static func _king(c: Vector2, s: float) -> PackedVector2Array:
	var p: PackedVector2Array = []
	# base
	p.append(c + Vector2(-0.34, 0.44) * s)
	p.append(c + Vector2(0.34, 0.44) * s)
	p.append(c + Vector2(0.30, 0.34) * s)
	p.append(c + Vector2(-0.30, 0.34) * s)
	# body
	p.append(c + Vector2(-0.18, 0.26) * s)
	p.append(c + Vector2(0.18, 0.26) * s)
	p.append(c + Vector2(0.16, 0.06) * s)
	p.append(c + Vector2(0.20, -0.08) * s)
	# cross
	p.append(c + Vector2(0.06, -0.08) * s)
	p.append(c + Vector2(0.06, -0.20) * s)
	p.append(c + Vector2(0.16, -0.20) * s)
	p.append(c + Vector2(0.16, -0.30) * s)
	p.append(c + Vector2(0.06, -0.30) * s)
	p.append(c + Vector2(0.06, -0.42) * s)
	p.append(c + Vector2(-0.06, -0.42) * s)
	p.append(c + Vector2(-0.06, -0.30) * s)
	p.append(c + Vector2(-0.16, -0.30) * s)
	p.append(c + Vector2(-0.16, -0.20) * s)
	p.append(c + Vector2(-0.06, -0.20) * s)
	p.append(c + Vector2(-0.06, -0.08) * s)
	p.append(c + Vector2(-0.20, -0.08) * s)
	p.append(c + Vector2(-0.16, 0.06) * s)
	p.append(c + Vector2(-0.18, 0.26) * s)
	return p
