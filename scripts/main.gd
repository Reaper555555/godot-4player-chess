extends Control

@onready var play_btn: Button = $Center/PlayBtn
@onready var quit_btn: Button = $Center/QuitBtn
@onready var lang_btn: Button = $TopBar/LangBtn
@onready var fullscreen_btn: Button = $TopBar/FullscreenBtn

var res_btn: Button

func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	quit_btn.pressed.connect(_on_quit)
	lang_btn.pressed.connect(_on_lang)
	fullscreen_btn.pressed.connect(_on_fullscreen)
	_update_lang_btn()

	res_btn = Button.new()
	res_btn.text = Settings.resolution_label()
	res_btn.pressed.connect(_on_resolution)
	$TopBar.add_child(res_btn)
	$TopBar.move_child(res_btn, 0)

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_quit() -> void:
	get_tree().quit()

func _on_lang() -> void:
	LocaleManager.toggle()
	_update_lang_btn()
	play_btn.text = LocaleManager.t("play") + " / Play" if LocaleManager.current_locale == "ru" else "Play / Играть"
	quit_btn.text = LocaleManager.t("quit")

func _update_lang_btn() -> void:
	lang_btn.text = "RU" if LocaleManager.current_locale == "en" else "EN"

func _on_fullscreen() -> void:
	Settings.toggle_fullscreen()

func _on_resolution() -> void:
	Settings.cycle_resolution()
	res_btn.text = Settings.resolution_label()
