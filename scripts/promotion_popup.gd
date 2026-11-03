extends CanvasLayer
## Modal promotion picker. Emits chosen PieceType then frees itself.

signal chosen(piece_type: int)

var panel: PanelContainer

func _ready() -> void:
	layer = 100
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.75, 0.35)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-160, -80)
	panel.custom_minimum_size = Vector2(320, 120)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Превращение / Promotion"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var options = [
		[GameState.PieceType.QUEEN, "Ферзь / Q"],
		[GameState.PieceType.ROOK, "Ладья / R"],
		[GameState.PieceType.BISHOP, "Слон / B"],
		[GameState.PieceType.KNIGHT, "Конь / N"],
	]
	for opt in options:
		var btn = Button.new()
		btn.text = opt[1]
		btn.custom_minimum_size = Vector2(70, 40)
		var t: int = opt[0]
		btn.pressed.connect(func(): _pick(t))
		row.add_child(btn)

func _pick(piece_type: int) -> void:
	chosen.emit(piece_type)
	queue_free()
