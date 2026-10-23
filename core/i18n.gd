class_name I18n
extends RefCounted
## Lädt die Übersetzungen aus i18n/translations.csv und liefert Texte für die aktive Sprache.
## Deutsch ist Standard, Englisch wird bei englischer Systemsprache verwendet.

const LANGS: Array[String] = ["de", "en"]
const CSV_PATH := "res://i18n/translations.csv"

static var _messages: Dictionary = {}
static var _loaded := false
static var _lang := "de"


static func init() -> void:
	_load()
	_lang = "en" if OS.get_locale_language() == "en" else "de"
	TranslationServer.set_locale(_lang)


static func lang() -> String:
	if not _loaded:
		init()
	return _lang


static func lang_index() -> int:
	return LANGS.find(lang())


static func set_lang_index(index: int) -> void:
	_lang = LANGS[posmod(index, LANGS.size())]
	TranslationServer.set_locale(_lang)


static func text(key: String) -> String:
	if not _loaded:
		init()
	var entry: Dictionary = _messages.get(key, {})
	if entry.is_empty():
		return TranslationServer.translate(key)
	return entry.get(_lang, key)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return
	var header := file.get_csv_line()
	var locale_cols: Dictionary = {}
	for i in range(1, header.size()):
		locale_cols[header[i]] = i
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty() or row[0].is_empty():
			continue
		var entry: Dictionary = {}
		for locale: String in locale_cols:
			var col: int = locale_cols[locale]
			entry[locale] = row[col] if col < row.size() else ""
		_messages[row[0]] = entry
	file.close()
