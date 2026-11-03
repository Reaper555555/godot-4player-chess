extends Node
## Simple audio manager. Place .ogg / .wav files in res://assets/sounds/
## Expected names: move.ogg, capture.ogg, check.ogg, checkmate.ogg, select.ogg, ui_click.ogg

var players: Dictionary = {}

func _ready() -> void:
	_load_sounds()

func _load_sounds() -> void:
	var names := ["move", "capture", "check", "checkmate", "select", "ui_click"]
	for n in names:
		var path = "res://assets/sounds/%s.ogg" % n
		if ResourceLoader.exists(path):
			var stream = load(path)
			var p = AudioStreamPlayer.new()
			p.stream = stream
			p.bus = "Master"
			add_child(p)
			players[n] = p
		else:
			# Placeholder silent player so code doesn't crash
			var p = AudioStreamPlayer.new()
			add_child(p)
			players[n] = p

func play(name: String) -> void:
	if players.has(name):
		players[name].play()

func play_move(is_capture: bool = false) -> void:
	if is_capture:
		play("capture")
	else:
		play("move")

func play_check() -> void:
	play("check")

func play_checkmate() -> void:
	play("checkmate")
