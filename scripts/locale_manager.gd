extends Node
## Simple locale switcher (RU / EN)

signal locale_changed(locale: String)

var current_locale := "ru"

func _ready() -> void:
	TranslationServer.set_locale(current_locale)

func set_locale(locale: String) -> void:
	if locale not in ["ru", "en"]:
		return
	current_locale = locale
	TranslationServer.set_locale(locale)
	locale_changed.emit(locale)

func toggle() -> void:
	if current_locale == "ru":
		set_locale("en")
	else:
		set_locale("ru")

func tr_key(key: String) -> String:
	return tr(key)
