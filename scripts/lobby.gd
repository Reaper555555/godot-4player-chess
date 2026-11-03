extends Control
## Lobby UI: host/join, choose slot/color/team/turn order, ready, chat

@onready var status_label: Label = $VBox/StatusLabel
@onready var name_edit: LineEdit = $VBox/NameEdit
@onready var ip_edit: LineEdit = $VBox/IPEdit
@onready var host_btn: Button = $VBox/Buttons/HostBtn
@onready var join_btn: Button = $VBox/Buttons/JoinBtn
@onready var start_btn: Button = $VBox/StartBtn
@onready var players_list: ItemList = $VBox/PlayersList
@onready var slot_option: OptionButton = $VBox/SlotOption
@onready var team_spin: SpinBox = $VBox/TeamSpin
@onready var order_spin: SpinBox = $VBox/OrderSpin
@onready var color_picker: ColorPickerButton = $VBox/ColorPicker
@onready var observer_check: CheckBox = $VBox/ObserverCheck
@onready var ready_btn: Button = $VBox/ReadyBtn
@onready var chat_log: RichTextLabel = $VBox/ChatLog
@onready var chat_input: LineEdit = $VBox/ChatInput
@onready var team_chat_check: CheckBox = $VBox/TeamChatCheck

var my_info := {
	"name": "Player",
	"color": Color(0.9, 0.2, 0.2),
	"team": 1,
	"turn_order": 1,
	"slot": "bottom_left",
	"is_observer": false,
	"ready": false
}

func _ready() -> void:
	_setup_ui()
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.chat_message_received.connect(_on_chat)
	start_btn.disabled = true
	ready_btn.disabled = true

func _setup_ui() -> void:
	slot_option.clear()
	slot_option.add_item("Bottom Left", 0)
	slot_option.add_item("Top Left", 1)
	slot_option.add_item("Bottom Right", 2)
	slot_option.add_item("Top Right", 3)
	slot_option.item_selected.connect(_on_slot_changed)

	team_spin.min_value = 1
	team_spin.max_value = 8
	team_spin.value = 1
	team_spin.value_changed.connect(_on_team_changed)

	order_spin.min_value = 1
	order_spin.max_value = 4
	order_spin.value = 1
	order_spin.value_changed.connect(_on_order_changed)

	color_picker.color = my_info.color
	color_picker.color_changed.connect(_on_color_changed)

	observer_check.toggled.connect(_on_observer_toggled)
	name_edit.text_changed.connect(_on_name_changed)

	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	start_btn.pressed.connect(_on_start)
	ready_btn.pressed.connect(_on_ready)
	chat_input.text_submitted.connect(_on_chat_submit)

func _on_host() -> void:
	var err = NetworkManager.host_game()
	if err != OK:
		status_label.text = "Ошибка создания сервера: %s" % error_string(err)
		return
	status_label.text = "Сервер запущен. Ожидание игроков..."
	_register_myself()
	start_btn.disabled = false
	ready_btn.disabled = false

func _on_join() -> void:
	var ip = ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var err = NetworkManager.join_game(ip)
	if err != OK:
		status_label.text = "Ошибка подключения: %s" % error_string(err)
		return
	status_label.text = "Подключение..."

func _on_connected() -> void:
	status_label.text = "Подключено!"
	_register_myself()
	ready_btn.disabled = false

func _on_connection_failed() -> void:
	status_label.text = "Не удалось подключиться"

func _on_server_disconnected() -> void:
	status_label.text = "Сервер отключился"
	start_btn.disabled = true
	ready_btn.disabled = true

func _register_myself() -> void:
	my_info.name = name_edit.text.strip_edges()
	if my_info.name.is_empty():
		my_info.name = "Player_%d" % NetworkManager.my_peer_id
	NetworkManager.register_player(my_info)

func _on_slot_changed(idx: int) -> void:
	var slots = ["bottom_left", "top_left", "bottom_right", "top_right"]
	my_info.slot = slots[idx]
	_register_myself()

func _on_team_changed(v: float) -> void:
	my_info.team = int(v)
	_register_myself()

func _on_order_changed(v: float) -> void:
	my_info.turn_order = int(v)
	_register_myself()

func _on_color_changed(c: Color) -> void:
	my_info.color = c
	_register_myself()

func _on_observer_toggled(pressed: bool) -> void:
	my_info.is_observer = pressed
	_register_myself()

func _on_name_changed(_t: String) -> void:
	pass  # register on ready or button

func _on_ready() -> void:
	my_info.ready = not my_info.get("ready", false)
	ready_btn.text = "Не готов" if my_info.ready else "Готов"
	_register_myself()

func _on_start() -> void:
	if NetworkManager.is_host:
		NetworkManager.start_game()

func _on_lobby_updated() -> void:
	players_list.clear()
	for pid in NetworkManager.players:
		var p = NetworkManager.players[pid]
		var ready_str = " [готов]" if p.get("ready", false) else ""
		var text = "%s | %s | Team %d | Order %d | %s%s" % [
			p.get("name", "?"),
			p.get("slot", "?"),
			p.get("team", 0),
			p.get("turn_order", 0),
			"Observer" if p.get("is_observer", false) else "Player",
			ready_str
		]
		players_list.add_item(text)
	for pid in NetworkManager.observers:
		var p = NetworkManager.observers[pid]
		players_list.add_item("%s (наблюдатель)" % p.get("name", "?"))

func _on_game_started() -> void:
	# Switch to game scene
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_chat(from_id: int, text: String, is_team: bool) -> void:
	var name = "?"
	var color = Color.WHITE
	if NetworkManager.players.has(from_id):
		name = NetworkManager.players[from_id].get("name", "?")
		color = NetworkManager.players[from_id].get("color", Color.WHITE)
	elif NetworkManager.observers.has(from_id):
		name = NetworkManager.observers[from_id].get("name", "?")
	var prefix = "[команда] " if is_team else ""
	chat_log.append_text("[color=#%s]%s%s:[/color] %s\n" % [color.to_html(false), prefix, name, text])

func _on_chat_submit(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	NetworkManager.send_chat(text, team_chat_check.button_pressed)
	chat_input.clear()
