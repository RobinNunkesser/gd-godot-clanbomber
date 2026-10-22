class_name MapCatalog
extends RefCounted
## Liest Kopf und Startplätze aller Karten einmal ein, damit das Menü nur Karten anbietet,
## die für die eingestellten Spielerplätze taugen (Platz n braucht Startfeld n-1).

# Sortierte Dateinamen aller gültigen Karten.
var names: Array[String] = []
var _data: Dictionary = {}


static func load_dir(dir: String) -> MapCatalog:
	var catalog := MapCatalog.new()
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".map"):
			catalog.add(file, FileAccess.get_file_as_string(dir.path_join(file)))
	return catalog


# Ungültige Karten werden ausgelassen.
func add(map_name: String, text: String) -> void:
	var data := MapParser.parse(text)
	if not data.is_valid():
		return
	_data[map_name] = data
	if not names.has(map_name):
		names.append(map_name)
		names.sort()


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
