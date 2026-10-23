class_name MapCatalog
extends RefCounted
## Liest Kopf und Startplätze aller Karten einmal ein, damit das Menü nur Karten anbietet,
## die für die eingestellten Spielerplätze taugen (Platz n braucht Startfeld n-1).

# Sortierte Dateinamen aller gültigen Karten.
var names: Array[String] = []
var _data: Dictionary = {}
# Dateiname -> vollständiger Pfad der Quelle (für externe Kartenordner).
var _paths: Dictionary = {}


static func load_dir(dir: String) -> MapCatalog:
	var dirs: Array[String] = [dir]
	return load_dirs(dirs)


# Lädt mehrere Ordner. Bei gleichem Dateinamen gewinnt der zuerst geladene Ordner.
static func load_dirs(dirs: Array[String]) -> MapCatalog:
	var catalog := MapCatalog.new()
	for dir in dirs:
		if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
			continue
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".map"):
				catalog.add(file, FileAccess.get_file_as_string(dir.path_join(file)), dir)
	return catalog


# Ungültige Karten werden ausgelassen; ein bereits vorhandener Name wird nicht überschrieben.
func add(map_name: String, text: String, source_dir: String = "") -> void:
	if _data.has(map_name):
		return
	var data := MapParser.parse(text)
	if not data.is_valid():
		return
	_data[map_name] = data
	_paths[map_name] = source_dir.path_join(map_name) if not source_dir.is_empty() else map_name
	if not names.has(map_name):
		names.append(map_name)
		names.sort()


# Vollständiger Pfad einer Katalogkarte (bei testweise direkt hinzugefügten Karten nur der Name).
func file_path(map_name: String) -> String:
	return _paths.get(map_name, "")


func has_map(map_name: String) -> bool:
	return _data.has(map_name)


func data_of(map_name: String) -> MapData:
	return _data.get(map_name)


func start_count(map_name: String) -> int:
	var data: MapData = _data.get(map_name)
	return 0 if data == null else data.starts.size()


# Bietet die Karte für jeden der (0-basierten) Spielerplätze ein Startfeld?
func is_playable(map_name: String, slots: Array[int]) -> bool:
	var data: MapData = _data.get(map_name)
	if data == null:
		return false
	for slot in slots:
		if not data.starts.has(slot):
			return false
	return true


func playable(slots: Array[int]) -> Array[String]:
	var result: Array[String] = []
	for map_name in names:
		if is_playable(map_name, slots):
			result.append(map_name)
	return result
