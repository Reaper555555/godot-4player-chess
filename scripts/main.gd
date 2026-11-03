extends Control

@onready var play_btn: Button = $Center/PlayBtn
@onready var quit_btn: Button = $Center/QuitBtn
@onready var lang_btn: Button = $TopBar/LangBtn
@onready var fullscreen_btn: Button = $TopBar/FullscreenBtn

func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	quit_btn.pressed.connect(_on_quit)
	lang_btn.pressed.connect(_on_lang)
	fullscreen_btn.pressed.connect(_on_fullscreen)
	_update_lang_btn()

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_quit() -> void:
	get_tree().quit()

func _on_lang() -> void:
	LocaleManager.toggle()
	_update_lang_btn()

func _update_lang_btn() -> void:
	lang_btn.text = "RU" if LocaleManager.current_locale == "en" else "EN"

func _on_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
