extends Control
## Pre-connect centered entry. After Host/Join — board lobby with corner slots.

const SLOT_KEYS := ["top_left", "top_right", "bottom_left", "bottom_right"]
const SLOT_LABELS := {
	"top_left": "Верх-лево",
	"top_right": "Верх-право",
	"bottom_left": "Низ-лево",
	"bottom_right": "Низ-право",
}
const PRESET_COLORS := [
	Color(0.92, 0.25, 0.22),
	Color(0.22, 0.55, 0.95),
	Color(0.25, 0.82, 0.40),
	Color(0.95, 0.78, 0.18),
	Color(0.85, 0.35, 0.85),
	Color(0.20, 0.85, 0.85),
	Color(0.95, 0.55, 0.20),
	Color(0.75, 0.75, 0.80),
]
const BACK_ORDER := [
	GameState.PieceType.ROOK, GameState.PieceType.KNIGHT, GameState.PieceType.BISHOP,
	GameState.PieceType.QUEEN, GameState.PieceType.KING,
	GameState.PieceType.BISHOP, GameState.PieceType.KNIGHT, GameState.PieceType.ROOK,
]

var entry_panel: PanelContainer
var lobby_root: Control
var status_label: Label
var name_edit: LineEdit
var ip_edit: LineEdit
var host_btn: Button
var join_btn: Button
var start_btn: Button
var observe_btn: Button
var ready_btn: Button
var leave_slot_btn: Button
var unassigned_list: ItemList
var chat_log: RichTextLabel
var chat_input: LineEdit
var team_chat_check: CheckBox
var board_preview: Control
var slots_layer: Control
var slot_panels: Dictionary = {}
var color_row: HBoxContainer

var my_info := {
	"name": "Player",
	"color": PRESET_COLORS[0],
	"team": 1,
	"turn_order": 1,
	"slot": "",
	"is_observer": false,
	"ready": false,
}
var connected := false
var _suppress_param := false

func _ready() -> void:
	_build_ui()
	NetworkManager.lobby_updated.connect(_refresh)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(func():
		status_label.text = "Не удалось подключиться"
		connected = false
		_show_entry()
	)
	NetworkManager.server_disconnected.connect(func():
		status_label.text = "Сервер отключился"
		connected = false
		_show_entry()
	)
	NetworkManager.game_started.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))
	NetworkManager.chat_message_received.connect(_on_chat)
	_show_entry()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var bg = ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.10)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# ===== ENTRY (centered) =====
	entry_panel = PanelContainer.new()
	entry_panel.set_anchors_preset(PRESET_CENTER)
	entry_panel.custom_minimum_size = Vector2(420, 280)
	var ep_style = StyleBoxFlat.new()
	ep_style.bg_color = Color(0.12, 0.12, 0.16)
	ep_style.set_corner_radius_all(12)
	ep_style.set_border_width_all(2)
	ep_style.border_color = Color(0.35, 0.35, 0.45)
	ep_style.content_margin_left = 28
	ep_style.content_margin_right = 28
	ep_style.content_margin_top = 24
	ep_style.content_margin_bottom = 24
	entry_panel.add_theme_stylebox_override("panel", ep_style)
	# center with anchors
	entry_panel.anchor_left = 0.5
	entry_panel.anchor_right = 0.5
	entry_panel.anchor_top = 0.5
	entry_panel.anchor_bottom = 0.5
	entry_panel.offset_left = -210
	entry_panel.offset_right = 210
	entry_panel.offset_top = -150
	entry_panel.offset_bottom = 150
	add_child(entry_panel)

	var ev = VBoxContainer.new()
	ev.add_theme_constant_override("separation", 12)
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	entry_panel.add_child(ev)

	var title = Label.new()
	title.text = "4-Player Chess"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55))
	ev.add_child(title)

	status_label = Label.new()
	status_label.text = "Введите ник и создайте / войдите в игру"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	ev.add_child(status_label)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Ник"
	name_edit.text = "Reaper"
	ev.add_child(name_edit)

	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "IP сервера (пусто = 127.0.0.1)"
	ev.add_child(ip_edit)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	ev.add_child(btn_row)

	host_btn = Button.new()
	host_btn.text = "Создать игру"
	host_btn.custom_minimum_size = Vector2(150, 36)
	host_btn.pressed.connect(_on_host)
	btn_row.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "Присоединиться"
	join_btn.custom_minimum_size = Vector2(150, 36)
	join_btn.pressed.connect(_on_join)
	btn_row.add_child(join_btn)

	# ===== LOBBY (hidden until connected) =====
	lobby_root = Control.new()
	lobby_root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	lobby_root.visible = false
	add_child(lobby_root)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	lobby_root.add_child(margin)

	var main = VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	margin.add_child(main)

	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	main.add_child(top_bar)
	var lobby_status = Label.new()
	lobby_status.name = "LobbyStatus"
	lobby_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_status.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55))
	top_bar.add_child(lobby_status)
	observe_btn = Button.new()
	observe_btn.text = "Наблюдать"
	observe_btn.pressed.connect(_on_observe)
	top_bar.add_child(observe_btn)
	leave_slot_btn = Button.new()
	leave_slot_btn.text = "Освободить слот"
	leave_slot_btn.pressed.connect(_leave_slot)
	top_bar.add_child(leave_slot_btn)
	ready_btn = Button.new()
	ready_btn.text = "Готов"
	ready_btn.pressed.connect(_on_ready)
	top_bar.add_child(ready_btn)
	start_btn = Button.new()
	start_btn.text = "Начать игру"
	start_btn.pressed.connect(_on_start)
	top_bar.add_child(start_btn)

	var mid = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	main.add_child(mid)

	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(180, 0)
	mid.add_child(left)
	var lt = Label.new()
	lt.text = "Нераспределённые"
	left.add_child(lt)
	unassigned_list = ItemList.new()
	unassigned_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(unassigned_list)
	var cl = Label.new()
	cl.text = "Ваш цвет"
	left.add_child(cl)
	color_row = HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 4)
	left.add_child(color_row)
	for i in PRESET_COLORS.size():
		var b = Button.new()
		b.custom_minimum_size = Vector2(24, 24)
		var st = StyleBoxFlat.new()
		st.bg_color = PRESET_COLORS[i]
		st.set_corner_radius_all(12)
		st.set_border_width_all(2)
		st.border_color = Color(0.05, 0.05, 0.08)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		var col = PRESET_COLORS[i]
		b.pressed.connect(func():
			my_info.color = col
			if my_info.slot != "" or my_info.is_observer:
				_register()
			_refresh()
		)
		color_row.add_child(b)

	var center = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(center)

	board_preview = Control.new()
	board_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_preview.custom_minimum_size = Vector2(640, 360)
	board_preview.draw.connect(_draw_board)
	center.add_child(board_preview)

	slots_layer = Control.new()
	slots_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	slots_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	board_preview.add_child(slots_layer)
	board_preview.resized.connect(_layout_slots)
	call_deferred("_layout_slots")

	for key in SLOT_KEYS:
		var p = _make_slot_panel(key)
		slot_panels[key] = p
		slots_layer.add_child(p)

	# Chat
	var chat_box = VBoxContainer.new()
	chat_box.custom_minimum_size = Vector2(0, 100)
	main.add_child(chat_box)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.custom_minimum_size = Vector2(0, 60)
	chat_box.add_child(chat_log)
	var chat_row = HBoxContainer.new()
	chat_box.add_child(chat_row)
	team_chat_check = CheckBox.new()
	team_chat_check.text = "Команда"
	chat_row.add_child(team_chat_check)
	chat_input = LineEdit.new()
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.placeholder_text = "Сообщение..."
	chat_input.text_submitted.connect(_on_chat_submit)
	chat_row.add_child(chat_input)

func _show_entry() -> void:
	entry_panel.visible = true
	lobby_root.visible = false

func _show_lobby() -> void:
	entry_panel.visible = false
	lobby_root.visible = true
	var ls = lobby_root.find_child("LobbyStatus", true, false) as Label
	if ls:
		ls.text = "Выберите свободный слот у угла доски или нажмите «Наблюдать»"
	_refresh()

func _make_slot_panel(slot_key: String) -> PanelContainer:
	var p = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	st.set_border_width_all(2)
	st.border_color = Color(0.45, 0.45, 0.55)
	st.set_corner_radius_all(8)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(190, 110)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)

	var claim = Button.new()
	claim.name = "ClaimBtn"
	claim.text = SLOT_LABELS[slot_key] + " — свободно"
	claim.pressed.connect(_on_slot_clicked.bind(slot_key))
	v.add_child(claim)

	var name_l = Label.new()
	name_l.name = "NameL"
	name_l.text = ""
	v.add_child(name_l)

	var team_ob = OptionButton.new()
	team_ob.name = "TeamOB"
	for i in range(1, 5):
		team_ob.add_item("Команда %d" % i, i)
	team_ob.item_selected.connect(func(_i): _on_slot_team(slot_key))
	v.add_child(team_ob)

	var order_ob = OptionButton.new()
	order_ob.name = "OrderOB"
	for i in range(1, 5):
		order_ob.add_item("Ход %d" % i, i)
	order_ob.item_selected.connect(func(_i): _on_slot_order(slot_key))
	v.add_child(order_ob)

	var readonly = Label.new()
	readonly.name = "ReadOnly"
	readonly.visible = false
	readonly.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(readonly)

	return p

func _layout_slots() -> void:
	var r = board_preview.size
	if r.x < 10 or r.y < 10:
		return
	var positions = {
		"top_left": Vector2(4, 4),
		"top_right": Vector2(max(4, r.x - 194), 4),
		"bottom_left": Vector2(4, max(4, r.y - 114)),
		"bottom_right": Vector2(max(4, r.x - 194), max(4, r.y - 114)),
	}
	for key in SLOT_KEYS:
		if slot_panels.has(key):
			slot_panels[key].position = positions[key]

func _draw_board() -> void:
	var r = board_preview.size
	var margin_x = 210.0
	var margin_y = 120.0
	var bw = r.x - margin_x * 2
	var bh = r.y - margin_y * 2
	if bw < 20 or bh < 20:
		return
	var cell_w = bw / 16.0
	var cell_h = bh / 8.0
	for x in 16:
		for y in 8:
			var light = ((x + y) % 2 == 0)
			var col = Color(0.90, 0.82, 0.66) if light else Color(0.48, 0.34, 0.22)
			board_preview.draw_rect(Rect2(margin_x + x * cell_w, margin_y + y * cell_h, cell_w, cell_h), col)
	board_preview.draw_rect(
		Rect2(margin_x - 2, margin_y - 2, bw + 4, bh + 4),
		Color(0.12, 0.09, 0.06), false, 3.0
	)

	var slot_home := {
		"top_left": {"base_x": 0, "back": 0, "pawn": 1},
		"top_right": {"base_x": 8, "back": 0, "pawn": 1},
		"bottom_left": {"base_x": 0, "back": 7, "pawn": 6},
		"bottom_right": {"base_x": 8, "back": 7, "pawn": 6},
	}
	for key in SLOT_KEYS:
		var home = slot_home[key]
		var owner_info = _player_in_slot(key)
		var fill: Color
		var empty := owner_info == null
		if empty:
			fill = Color(0.55, 0.55, 0.58)
		else:
			fill = owner_info.get("color", Color.WHITE)
		for i in 8:
			var cx = home.base_x + i
			var px = margin_x + (cx + 0.5) * cell_w
			var size = min(cell_w, cell_h) * 0.85
			# back rank
			var py_b = margin_y + (home.back + 0.5) * cell_h
			var ptype = BACK_ORDER[i]
			if empty:
				# striped look: grey fill + dark
				PieceDraw.draw_piece(board_preview, Vector2(px, py_b), ptype, Color(0.62, 0.62, 0.65), size)
			else:
				PieceDraw.draw_piece(board_preview, Vector2(px, py_b), ptype, fill, size)
			# pawns
			var py_p = margin_y + (home.pawn + 0.5) * cell_h
			if empty:
				PieceDraw.draw_piece(board_preview, Vector2(px, py_p), GameState.PieceType.PAWN, Color(0.62, 0.62, 0.65), size)
			else:
				PieceDraw.draw_piece(board_preview, Vector2(px, py_p), GameState.PieceType.PAWN, fill, size)

func _player_in_slot(slot_key: String) -> Variant:
	for pid in NetworkManager.players:
		var p = NetworkManager.players[pid]
		if str(p.get("slot", "")) == slot_key and not p.get("is_observer", false):
			return p
	return null

func _pid_in_slot(slot_key: String) -> int:
	for pid in NetworkManager.players:
		var p = NetworkManager.players[pid]
		if str(p.get("slot", "")) == slot_key and not p.get("is_observer", false):
			return int(pid)
	return -1

func _on_host() -> void:
	var err: Error = NetworkManager.host_game()
	if err != OK:
		status_label.text = "Ошибка сервера: %s (%d)" % [error_string(err), err]
		return
	connected = true
	my_info.slot = ""
	my_info.is_observer = false
	my_info.ready = false
	_register()
	_show_lobby()

func _on_join() -> void:
	var ip = ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var err: Error = NetworkManager.join_game(ip)
	if err != OK:
		status_label.text = "Ошибка Join: %s (%d)" % [error_string(err), err]
		return
	status_label.text = "Подключение к %s..." % ip

func _on_connected() -> void:
	connected = true
	my_info.slot = ""
	my_info.is_observer = false
	_register()
	_show_lobby()

func _register() -> void:
	my_info.name = name_edit.text.strip_edges()
	if my_info.name.is_empty():
		my_info.name = "Player"
	NetworkManager.register_player(my_info.duplicate(true))

func _on_slot_clicked(slot_key: String) -> void:
	if not connected:
		return
	var occ = _player_in_slot(slot_key)
	var my_id = NetworkManager.my_peer_id
	var mine = NetworkManager.players.get(my_id, {})
	if occ and str(mine.get("slot", "")) != slot_key:
		var ls = lobby_root.find_child("LobbyStatus", true, false) as Label
		if ls:
			ls.text = "Слот занят"
		return
	my_info.slot = slot_key
	my_info.is_observer = false
	_register()
	_refresh()

func _on_slot_team(slot_key: String) -> void:
	if _suppress_param:
		return
	if my_info.slot != slot_key:
		return
	var panel: PanelContainer = slot_panels[slot_key]
	var ob: OptionButton = panel.find_child("TeamOB", true, false)
	var id = ob.get_selected_id()
	my_info.team = id if id > 0 else ob.selected + 1
	_register()

func _on_slot_order(slot_key: String) -> void:
	if _suppress_param:
		return
	if my_info.slot != slot_key:
		return
	var panel: PanelContainer = slot_panels[slot_key]
	var ob: OptionButton = panel.find_child("OrderOB", true, false)
	var id = ob.get_selected_id()
	my_info.turn_order = id if id > 0 else ob.selected + 1
	_register()

func _leave_slot() -> void:
	my_info.slot = ""
	my_info.is_observer = false
	my_info.ready = false
	ready_btn.text = "Готов"
	_register()
	_refresh()

func _on_observe() -> void:
	if not connected:
		return
	my_info.is_observer = true
	my_info.slot = ""
	my_info.ready = false
	ready_btn.text = "Готов"
	_register()
	_refresh()

func _on_ready() -> void:
	if my_info.slot == "" and not my_info.is_observer:
		var ls = lobby_root.find_child("LobbyStatus", true, false) as Label
		if ls:
			ls.text = "Сначала выберите слот или наблюдайте"
		return
	my_info.ready = not my_info.get("ready", false)
	ready_btn.text = "Не готов" if my_info.ready else "Готов"
	_register()

func _on_start() -> void:
	if NetworkManager.is_host:
		NetworkManager.start_game()

func _refresh() -> void:
	if not lobby_root.visible:
		return
	_suppress_param = true
	unassigned_list.clear()
	var taken := {}
	for pid in NetworkManager.players:
		var p = NetworkManager.players[pid]
		var slot = str(p.get("slot", ""))
		if slot != "" and not p.get("is_observer", false):
			taken[slot] = {"info": p, "pid": pid}
		elif not p.get("is_observer", false):
			unassigned_list.add_item("%s" % p.get("name", "?"))
	for pid in NetworkManager.observers:
		var p = NetworkManager.observers[pid]
		unassigned_list.add_item("%s [набл.]" % p.get("name", "?"))

	var my_id = NetworkManager.my_peer_id
	for key in SLOT_KEYS:
		var panel: PanelContainer = slot_panels[key]
		var claim: Button = panel.find_child("ClaimBtn", true, false)
		var name_l: Label = panel.find_child("NameL", true, false)
		var team_ob: OptionButton = panel.find_child("TeamOB", true, false)
		var order_ob: OptionButton = panel.find_child("OrderOB", true, false)
		var readonly: Label = panel.find_child("ReadOnly", true, false)
		var st: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
		var entry = taken.get(key, null)
		if entry:
			var p = entry.info
			var pid = entry.pid
			var c: Color = p.get("color", Color.WHITE)
			var is_mine = (int(pid) == int(my_id))
			st.border_color = c
			st.bg_color = Color(c.r * 0.2, c.g * 0.2, c.b * 0.2, 0.95)
			claim.text = SLOT_LABELS[key]
			claim.disabled = not is_mine
			name_l.text = "%s%s" % [p.get("name", "?"), " ✓" if p.get("ready", false) else ""]
			name_l.add_theme_color_override("font_color", c.lightened(0.3))
			if is_mine:
				team_ob.visible = true
				order_ob.visible = true
				readonly.visible = false
				_select_id(team_ob, int(p.get("team", 1)))
				_select_id(order_ob, int(p.get("turn_order", 1)))
				team_ob.disabled = false
				order_ob.disabled = false
			else:
				team_ob.visible = false
				order_ob.visible = false
				readonly.visible = true
				readonly.text = "Команда %d · Ход %d" % [int(p.get("team", 0)), int(p.get("turn_order", 0))]
		else:
			st.border_color = Color(0.45, 0.45, 0.55)
			st.bg_color = Color(0.1, 0.1, 0.14, 0.95)
			claim.text = SLOT_LABELS[key] + " — свободно"
			claim.disabled = false
			name_l.text = ""
			team_ob.visible = false
			order_ob.visible = false
			readonly.visible = false
		panel.add_theme_stylebox_override("panel", st)

	board_preview.queue_redraw()
	start_btn.disabled = not NetworkManager.is_host or not connected
	_suppress_param = false

func _select_id(ob: OptionButton, id: int) -> void:
	for i in ob.item_count:
		if ob.get_item_id(i) == id:
			ob.select(i)
			return
	if id >= 1 and id <= ob.item_count:
		o.select(id - 1)

func _on_chat(from_id: int, text: String, is_team: bool) -> void:
	var name = "?"
	var color = Color.WHITE
	if NetworkManager.players.has(from_id):
		name = NetworkManager.players[from_id].get("name", "?")
		color = NetworkManager.players[from_id].get("color", Color.WHITE)
	elif NetworkManager.observers.has(from_id):
		name = NetworkManager.observers[from_id].get("name", "?")
	var prefix = "[T] " if is_team else ""
	chat_log.append_text("[color=#%s]%s%s:[/color] %s\n" % [color.to_html(false), prefix, name, text])

func _on_chat_submit(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	NetworkManager.send_chat(text, team_chat_check.button_pressed)
	chat_input.clear()
