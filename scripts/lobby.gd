extends Control
## Board-centered lobby: unassigned pool, click empty slot, observers, host/join.

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

var status_label: Label
var name_edit: LineEdit
var ip_edit: LineEdit
var host_btn: Button
var join_btn: Button
var start_btn: Button
var observe_btn: Button
var ready_btn: Button
var unassigned_list: ItemList
var chat_log: RichTextLabel
var chat_input: LineEdit
var team_chat_check: CheckBox
var board_preview: Control
var slot_panels: Dictionary = {}  # slot_key -> PanelContainer
var param_panel: PanelContainer
var param_slot_label: Label
var team_option: OptionButton
var order_option: OptionButton
var color_row: HBoxContainer
var leave_slot_btn: Button

var my_info := {
	"name": "Player",
	"color": PRESET_COLORS[0],
	"team": 1,
	"turn_order": 1,
	"slot": "",
	"is_observer": false,
	"ready": false,
}
var editing_slot := ""
var connected := false

func _ready() -> void:
	_build_ui()
	NetworkManager.lobby_updated.connect(_refresh)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(func(): status_label.text = "Не удалось подключиться"; connected = false)
	NetworkManager.server_disconnected.connect(func(): status_label.text = "Сервер отключился"; connected = false; _set_lobby_enabled(false))
	NetworkManager.game_started.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))
	NetworkManager.chat_message_received.connect(_on_chat)
	_set_lobby_enabled(false)
	_refresh()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.11)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var root = MarginContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_top", 12)
	root.add_theme_constant_override("margin_bottom", 12)
	add_child(root)

	var main = VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)

	status_label = Label.new()
	status_label.text = "Не подключено — создайте или присоединитесь к игре"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55))
	main.add_child(status_label)

	# Connection bar
	var conn = HBoxContainer.new()
	conn.alignment = BoxContainer.ALIGNMENT_CENTER
	conn.add_theme_constant_override("separation", 8)
	main.add_child(conn)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Ник"
	name_edit.custom_minimum_size = Vector2(140, 0)
	name_edit.text = "Reaper"
	conn.add_child(name_edit)

	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "IP (пусто = 127.0.0.1)"
	ip_edit.custom_minimum_size = Vector2(180, 0)
	conn.add_child(ip_edit)

	host_btn = Button.new()
	host_btn.text = "Создать (Host)"
	host_btn.pressed.connect(_on_host)
	conn.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "Войти (Join)"
	join_btn.pressed.connect(_on_join)
	conn.add_child(join_btn)

	# Middle: board + side panels
	var mid = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 12)
	main.add_child(mid)

	# Left: unassigned + observers
	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(200, 0)
	left.add_theme_constant_override("separation", 6)
	mid.add_child(left)

	var left_title = Label.new()
	left_title.text = "Нераспределённые"
	left_title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	left.add_child(left_title)

	unassigned_list = ItemList.new()
	unassigned_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	unassigned_list.custom_minimum_size = Vector2(0, 200)
	left.add_child(unassigned_list)

	observe_btn = Button.new()
	observe_btn.text = "Наблюдать"
	observe_btn.pressed.connect(_on_observe)
	left.add_child(observe_btn)

	ready_btn = Button.new()
	ready_btn.text = "Готов"
	ready_btn.pressed.connect(_on_ready)
	left.add_child(ready_btn)

	start_btn = Button.new()
	start_btn.text = "Начать игру"
	start_btn.pressed.connect(_on_start)
	left.add_child(start_btn)

	# Center: board preview with 4 corner slots
	var center = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(center)

	board_preview = Control.new()
	board_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_preview.custom_minimum_size = Vector2(520, 320)
	board_preview.draw.connect(_draw_board)
	center.add_child(board_preview)

	# Overlay slot buttons at corners via separate layer
	var slots_layer = Control.new()
	slots_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	board_preview.add_child(slots_layer)
	# Will position on resize
	board_preview.resized.connect(_layout_slots.bind(slots_layer))
	call_deferred("_layout_slots", slots_layer)

	for key in SLOT_KEYS:
		var p = _make_slot_panel(key)
		slot_panels[key] = p
		slots_layer.add_child(p)

	# Right: params for selected empty/own slot
	param_panel = PanelContainer.new()
	param_panel.custom_minimum_size = Vector2(220, 0)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.12, 0.16)
	ps.set_corner_radius_all(8)
	ps.content_margin_left = 10
	ps.content_margin_right = 10
	ps.content_margin_top = 10
	ps.content_margin_bottom = 10
	param_panel.add_theme_stylebox_override("panel", ps)
	mid.add_child(param_panel)

	var pv = VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	param_panel.add_child(pv)

	param_slot_label = Label.new()
	param_slot_label.text = "Выберите пустой слот"
	pv.add_child(param_slot_label)

	var team_l = Label.new()
	team_l.text = "Команда"
	pv.add_child(team_l)
	team_option = OptionButton.new()
	for i in range(1, 5):
		team_option.add_item("Команда %d" % i, i)
	team_option.item_selected.connect(func(_i): _apply_params())
	pv.add_child(team_option)

	var order_l = Label.new()
	order_l.text = "Порядок хода"
	pv.add_child(order_l)
	order_option = OptionButton.new()
	for i in range(1, 5):
		order_option.add_item("Ход %d" % i, i)
	order_option.item_selected.connect(func(_i): _apply_params())
	pv.add_child(order_option)

	var color_l = Label.new()
	color_l.text = "Цвет"
	pv.add_child(color_l)
	color_row = HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 6)
	pv.add_child(color_row)
	for i in PRESET_COLORS.size():
		var b = Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		var st = StyleBoxFlat.new()
		st.bg_color = PRESET_COLORS[i]
		st.set_corner_radius_all(14)
		st.set_border_width_all(2)
		st.border_color = Color(1, 1, 1, 0.35)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		var col = PRESET_COLORS[i]
		b.pressed.connect(func(): my_info.color = col; _apply_params(); _refresh())
		color_row.add_child(b)

	leave_slot_btn = Button.new()
	leave_slot_btn.text = "Освободить слот"
	leave_slot_btn.pressed.connect(_leave_slot)
	pv.add_child(leave_slot_btn)

	# Chat
	var chat_box = VBoxContainer.new()
	chat_box.custom_minimum_size = Vector2(0, 110)
	main.add_child(chat_box)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.custom_minimum_size = Vector2(0, 70)
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

func _make_slot_panel(slot_key: String) -> PanelContainer:
	var p = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.1, 0.14, 0.92)
	st.set_border_width_all(2)
	st.border_color = Color(0.45, 0.45, 0.55)
	st.set_corner_radius_all(8)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(150, 56)
	var btn = Button.new()
	btn.name = "Btn"
	btn.flat = true
	btn.text = SLOT_LABELS[slot_key] + "\n(пусто)"
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_slot_clicked.bind(slot_key))
	p.add_child(btn)
	return p

func _layout_slots(layer: Control) -> void:
	var r = board_preview.get_rect().size
	if r.x < 10 or r.y < 10:
		return
	var positions = {
		"top_left": Vector2(8, 8),
		"top_right": Vector2(max(8, r.x - 158), 8),
		"bottom_left": Vector2(8, max(8, r.y - 64)),
		"bottom_right": Vector2(max(8, r.x - 158), max(8, r.y - 64)),
	}
	for key in SLOT_KEYS:
		if slot_panels.has(key):
			slot_panels[key].position = positions[key]

func _draw_board() -> void:
	var r = board_preview.size
	var margin = 70.0
	var bw = r.x - margin * 2
	var bh = r.y - margin * 2
	if bw < 10 or bh < 10:
		return
	var cell_w = bw / 16.0
	var cell_h = bh / 8.0
	for x in 16:
		for y in 8:
			var light = ((x + y) % 2 == 0)
			var col = Color(0.72, 0.68, 0.58) if light else Color(0.32, 0.36, 0.42)
			board_preview.draw_rect(Rect2(margin + x * cell_w, margin + y * cell_h, cell_w, cell_h), col)
	# Draw simple piece markers for occupied / empty slots
	var slot_home := {
		"top_left": {"base_x": 0, "back": 0, "pawn": 1},
		"top_right": {"base_x": 8, "back": 0, "pawn": 1},
		"bottom_left": {"base_x": 0, "back": 7, "pawn": 6},
		"bottom_right": {"base_x": 8, "back": 7, "pawn": 6},
	}
	for key in SLOT_KEYS:
		var home = slot_home[key]
		var owner_info = _player_in_slot(key)
		for i in 8:
			var cx = home.base_x + i
			for rank in [home.back, home.pawn]:
				var px = margin + (cx + 0.5) * cell_w
				var py = margin + (rank + 0.5) * cell_h
				var rad = min(cell_w, cell_h) * 0.28
				if owner_info:
					var c: Color = owner_info.get("color", Color.WHITE)
					board_preview.draw_circle(Vector2(px, py), rad, c)
				else:
					# striped empty
					board_preview.draw_circle(Vector2(px, py), rad, Color(0.55, 0.55, 0.55))
					board_preview.draw_circle(Vector2(px, py), rad * 0.55, Color(0.2, 0.2, 0.22))

func _player_in_slot(slot_key: String) -> Variant:
	for pid in NetworkManager.players:
		var p = NetworkManager.players[pid]
		if str(p.get("slot", "")) == slot_key and not p.get("is_observer", false):
			return p
	return null

func _set_lobby_enabled(on: bool) -> void:
	observe_btn.disabled = not on
	ready_btn.disabled = not on
	start_btn.disabled = not on or not NetworkManager.is_host

func _on_host() -> void:
	var err: Error = NetworkManager.host_game()
	if err != OK:
		status_label.text = "Ошибка сервера: %s (%d)" % [error_string(err), err]
		return
	connected = true
	status_label.text = "Сервер запущен (порт 7777). Выберите слот или наблюдайте."
	my_info.slot = ""
	my_info.is_observer = false
	my_info.ready = false
	_register()
	_set_lobby_enabled(true)
	start_btn.disabled = false

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
	status_label.text = "Подключено. Выберите слот или наблюдайте."
	my_info.slot = ""
	my_info.is_observer = false
	_register()
	_set_lobby_enabled(true)

func _register() -> void:
	my_info.name = name_edit.text.strip_edges()
	if my_info.name.is_empty():
		my_info.name = "Player"
	NetworkManager.register_player(my_info.duplicate(true))

func _on_slot_clicked(slot_key: String) -> void:
	if not connected:
		status_label.text = "Сначала Host или Join"
		return
	var occ = _player_in_slot(slot_key)
	if occ and int(NetworkManager.players.find_key(occ) if false else -1):
		pass
	# Allow take if empty or own
	var my_id = NetworkManager.my_peer_id
	var mine = NetworkManager.players.get(my_id, {})
	if occ and mine.get("slot", "") != slot_key:
		# occupied by other
		status_label.text = "Слот занят"
		return
	editing_slot = slot_key
	my_info.slot = slot_key
	my_info.is_observer = false
	param_slot_label.text = "Слот: %s" % SLOT_LABELS[slot_key]
	_register()
	_refresh()

func _apply_params() -> void:
	if my_info.slot == "" and not my_info.is_observer:
		return
	my_info.team = team_option.get_selected_id()
	if my_info.team <= 0:
		my_info.team = team_option.selected + 1
	my_info.turn_order = order_option.get_selected_id()
	if my_info.turn_order <= 0:
		my_info.turn_order = order_option.selected + 1
	_register()

func _leave_slot() -> void:
	my_info.slot = ""
	my_info.is_observer = false
	my_info.ready = false
	editing_slot = ""
	param_slot_label.text = "Выберите пустой слот"
	_register()
	_refresh()

func _on_observe() -> void:
	if not connected:
		return
	my_info.is_observer = true
	my_info.slot = ""
	my_info.ready = false
	editing_slot = ""
	param_slot_label.text = "Режим: наблюдатель"
	_register()
	_refresh()

func _on_ready() -> void:
	if my_info.slot == "" and not my_info.is_observer:
		status_label.text = "Сначала выберите слот или наблюдайте"
		return
	my_info.ready = not my_info.get("ready", false)
	ready_btn.text = "Не готов" if my_info.ready else "Готов"
	_register()

func _on_start() -> void:
	if NetworkManager.is_host:
		NetworkManager.start_game()

func _refresh() -> void:
	unassigned_list.clear()
	var taken_slots := {}
	for pid in NetworkManager.players:
		var p = NetworkManager.players[pid]
		var slot = str(p.get("slot", ""))
		if slot != "" and not p.get("is_observer", false):
			taken_slots[slot] = p
		elif not p.get("is_observer", false):
			unassigned_list.add_item("%s (идёт в слот...)" % p.get("name", "?"))
	for pid in NetworkManager.observers:
		var p = NetworkManager.observers[pid]
		unassigned_list.add_item("%s [наблюдатель]" % p.get("name", "?"))

	for key in SLOT_KEYS:
		var panel: PanelContainer = slot_panels[key]
		var btn: Button = panel.get_node("Btn")
		var occ = taken_slots.get(key, null)
		var st: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
		if occ:
			var c: Color = occ.get("color", Color.WHITE)
			st.border_color = c
			st.bg_color = Color(c.r * 0.25, c.g * 0.25, c.b * 0.25, 0.95)
			btn.text = "%s\n%s  T%d  #%d%s" % [
				SLOT_LABELS[key],
				occ.get("name", "?"),
				int(occ.get("team", 0)),
				int(occ.get("turn_order", 0)),
				" ✓" if occ.get("ready", false) else "",
			]
			btn.add_theme_color_override("font_color", c.lightened(0.35))
		else:
			st.border_color = Color(0.45, 0.45, 0.55)
			st.bg_color = Color(0.1, 0.1, 0.14, 0.92)
			btn.text = "%s\n(свободен)" % SLOT_LABELS[key]
			btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		panel.add_theme_stylebox_override("panel", st)

	board_preview.queue_redraw()
	start_btn.disabled = not NetworkManager.is_host or not connected

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
