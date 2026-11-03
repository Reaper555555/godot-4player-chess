extends Node
## Simple settings: resolution + fullscreen (saved in user://settings.cfg)

const CONFIG_PATH := "user://settings.cfg"

const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var resolution_index := 2
var fullscreen := false

func _ready() -> void:
	_load()
	apply()

func _load() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	resolution_index = int(cfg.get_value("video", "resolution_index", 2))
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	resolution_index = clampi(resolution_index, 0, RESOLUTIONS.size() - 1)

func save() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("video", "resolution_index", resolution_index)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(CONFIG_PATH)

func apply() -> void:
	var size: Vector2i = RESOLUTIONS[resolution_index]
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		# Center roughly
		var screen = DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen - size) / 2)
	save()

func cycle_resolution() -> void:
	resolution_index = (resolution_index + 1) % RESOLUTIONS.size()
	apply()

func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply()

func resolution_label() -> String:
	var r: Vector2i = RESOLUTIONS[resolution_index]
	return "%dx%d" % [r.x, r.y]
