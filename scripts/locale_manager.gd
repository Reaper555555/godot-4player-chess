extends Node
## Lightweight RU/EN dictionary (no .po files required)

signal locale_changed(locale: String)

var current_locale := "ru"

const STRINGS := {
	"ru": {
		"play": "Играть",
		"quit": "Выход",
		"host": "Создать игру",
		"join": "Присоединиться",
		"ready": "Готов",
		"not_ready": "Не готов",
		"start": "Начать игру",
		"observer": "Наблюдатель",
		"team_chat": "Командный чат",
		"draw": "Предложить ничью",
		"menu": "Меню",
		"turn": "Ход",
		"frozen": "заморожен",
		"check": "Шах!",
		"mate": "Мат! Игрок заморожен",
		"stalemate": "Пат! Игрок заморожен",
		"victory": "Победа команды %d!",
		"draw_accepted": "Ничья по согласию!",
		"promotion": "Превращение",
		"resolution": "Разрешение",
	},
	"en": {
		"play": "Play",
		"quit": "Quit",
		"host": "Host game",
		"join": "Join",
		"ready": "Ready",
		"not_ready": "Not ready",
		"start": "Start game",
		"observer": "Observer",
		"team_chat": "Team chat",
		"draw": "Offer draw",
		"menu": "Menu",
		"turn": "Turn",
		"frozen": "frozen",
		"check": "Check!",
		"mate": "Checkmate! Player frozen",
		"stalemate": "Stalemate! Player frozen",
		"victory": "Team %d wins!",
		"draw_accepted": "Draw agreed!",
		"promotion": "Promotion",
		"resolution": "Resolution",
	},
}

func _ready() -> void:
	TranslationServer.set_locale(current_locale)

func set_locale(locale: String) -> void:
	if locale not in STRINGS:
		return
	current_locale = locale
	TranslationServer.set_locale(locale)
	locale_changed.emit(locale)

func toggle() -> void:
	set_locale("en" if current_locale == "ru" else "ru")

func t(key: String) -> String:
	return STRINGS.get(current_locale, {}).get(key, key)
