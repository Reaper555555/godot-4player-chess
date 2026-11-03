extends Node
## Audio manager. Looks for .ogg then .wav in res://assets/sounds/
## Names: move, capture, check, checkmate, select, ui_click
## Generate with: python3 tools/generate_sounds.py

var players: Dictionary = {}

func _ready() -> void:
	_load_sounds()

func _load_sounds() -> void:
	var names := ["move", "capture", "check", "checkmate", "select", "ui_click"]
	for n in names:
		var stream = null
		for ext in ["ogg", "wav"]:
			var path = "res://assets/sounds/%s.%s" % [n, ext]
			if ResourceLoader.exists(path):
				stream = load(path)
				break
		var p = AudioStreamPlayer.new()
		if stream:
			p.stream = stream
		p.bus = "Master"
		add_child(p)
		players[n] = p

func play(name: String) -> void:
	if players.has(name) and players[name].stream:
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
