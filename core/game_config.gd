class_name GameConfig
extends RefCounted
## Matcheinstellungen aus dem Menü: Steuerung, Namen und Teams je Spielerplatz, Kartenauswahl samt Reihenfolge,
## Punkte zum Sieg, Sudden-Death-Zeit und Lautstärken. Lässt sich als ConfigFile speichern und laden.

enum Controller { OFF, KEYBOARD_1, KEYBOARD_2, PAD_1, PAD_2, PAD_3, PAD_4, PAD_5, PAD_6, PAD_7, PAD_8, AI }

const SLOT_COUNT := 8
const MIN_POINTS := 1
const MAX_POINTS := 10
const NAMES := {
	Controller.OFF: "Aus",
	Controller.KEYBOARD_1: "Tastatur 1 (WASD, Leertaste)",
	Controller.KEYBOARD_2: "Tastatur 2 (Pfeile, Enter)",
	Controller.PAD_1: "Gamepad 1",
	Controller.PAD_2: "Gamepad 2",
	Controller.PAD_3: "Gamepad 3",
	Controller.PAD_4: "Gamepad 4",
	Controller.PAD_5: "Gamepad 5",
	Controller.PAD_6: "Gamepad 6",
	Controller.PAD_7: "Gamepad 7",
	Controller.PAD_8: "Gamepad 8",
	Controller.AI: "AI",
}

# Teams wie im Original (BomberConfig::team, 0 = kein Team).
const TEAM_COUNT := 4
const TEAM_NAMES: Array[String] = ["Blood", "Gold", "Water", "Leaf"]
const TEAM_COLORS: Array[Color] = [Color("ff8080"), Color("ffd54f"), Color("64b5f6"), Color("81c784")]

const NAME_MAX_LENGTH := 12

# Sudden Death beginnt nach der Rundenzeit (Original: Config::round_time, 5-300 s, Standard 90 s).
const ROUND_TIMES: Array[int] = [15, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300]
const DEFAULT_ROUND_TIME_S := 90

const VOLUME_LEVELS: Array[String] = ["Aus", "25 %", "50 %", "75 %", "100 %"]
const VOLUME_DBS: Array[float] = [-80.0, -18.0, -10.0, -4.0, 0.0]

var slots: Array[int] = [
	Controller.KEYBOARD_1, Controller.AI, Controller.OFF, Controller.OFF,
	Controller.OFF, Controller.OFF, Controller.OFF, Controller.OFF,
]
var names: Array[String] = ["", "", "", "", "", "", "", ""]
var teams: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
# Karten, die im Match gespielt werden; nach jeder Runde folgt die nächste (zufällig oder der Reihe nach).
var map_pool: Array[String] = []
var random_order := true
# Zusätzlicher Ordner für externe Karten (z. B. das separate Originalkarten-Paket).
var external_map_dir := ""
# Startfelder bei Rundenstart zufällig unter den aktiven Spielern verteilen (Original: random_positions = true).
var random_positions := true
var points_to_win := SimConstants.POINTS_TO_WIN
var round_time_s := DEFAULT_ROUND_TIME_S

var music_volume: int = 4
var sfx_volume: int = 4
var _last_music_volume: int = 4
var _last_sfx_volume: int = 4
var screen_shake: int = 2 # 0 = Aus (0%), 1 = 50%, 2 = 100%
const SHAKE_LEVELS: Array[String] = ["0 %", "50 %", "100 %"]


# --- Externe Kartenordner ---

# Ermittelt den kanonischen Benutzer-Dokumentenordner für ClanBomber-Karten.
static func canonical_documents_map_dir() -> String:
	var doc_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if doc_dir.is_empty():
		var home := OS.get_environment("HOME") if OS.has_environment("HOME") else OS.get_environment("USERPROFILE")
		doc_dir = home.path_join("Documents") if not home.is_empty() else ""
	if doc_dir.is_empty():
		return ""
	return doc_dir.path_join("ClanBomber/maps")


# Ermittelt den anwendungsbezogenen Datenordner für ClanBomber-Karten.
static func canonical_appdata_map_dir() -> String:
	var user_data := OS.get_user_data_dir()
	if user_data.is_empty():
		return ""
	return user_data.path_join("maps")


# Kürzt für die Bildschirmanzeige Pfade unter dem Benutzerverzeichnis auf "~/".
static func contract_user_path(path: String) -> String:
	var home := OS.get_environment("HOME") if OS.has_environment("HOME") else OS.get_environment("USERPROFILE")
	if not home.is_empty():
		var norm_home := home.replace("\\", "/")
		var norm_path := path.replace("\\", "/")
		if norm_path == norm_home:
			return "~"
		if norm_path.begins_with(norm_home + "/"):
			return "~/" + norm_path.substr(norm_home.length() + 1)
	return path


# Stellt sicher, dass ein externer Kartenordner konfiguriert und auf der Festplatte vorhanden ist.
# Prüft Umgebungsvariablen, bestehende Ordner und legt beim Erststart Documents/ClanBomber/maps an.
static func ensure_default_map_dir(current_dir: String) -> String:
	var trimmed := current_dir.strip_edges()
	if not trimmed.is_empty():
		return trimmed

	# 1. Umgebungsvariable (z. B. für CI / Entwicklung)
	var env_dir := OS.get_environment("CLANBOMBER_MAPS_DIR").strip_edges()
	if not env_dir.is_empty():
		return env_dir

	# 2. Prüfen, ob Documents/ClanBomber/maps bereits existiert
	var docs_dir := canonical_documents_map_dir()
	if not docs_dir.is_empty() and DirAccess.dir_exists_absolute(docs_dir):
		return contract_user_path(docs_dir)

	# 3. Prüfen, ob AppData/maps bereits existiert
	var app_dir := canonical_appdata_map_dir()
	if not app_dir.is_empty() and DirAccess.dir_exists_absolute(app_dir):
		return app_dir

	# 4. Standard: Documents/ClanBomber/maps anlegen und initialisieren
	if not docs_dir.is_empty():
		var err := DirAccess.make_dir_recursive_absolute(docs_dir)
		if err == OK or DirAccess.dir_exists_absolute(docs_dir):
			_create_readme_if_missing(docs_dir)
			return contract_user_path(docs_dir)

	# 5. Fallback: AppData/maps anlegen
	if not app_dir.is_empty():
		var err := DirAccess.make_dir_recursive_absolute(app_dir)
		if err == OK or DirAccess.dir_exists_absolute(app_dir):
			_create_readme_if_missing(app_dir)
			return app_dir

	return ""


static func _create_readme_if_missing(dir: String) -> void:
	var readme_path := dir.path_join("README.txt")
	if not FileAccess.file_exists(readme_path):
		var file := FileAccess.open(readme_path, FileAccess.WRITE)
		if file != null:
			file.store_string(
				"ClanBomber Maps / Karten\n" +
				"========================\n\n" +
				"Hier zusaetzliche ClanBomber-Karten (.map) ablegen.\n" +
				"Drop additional ClanBomber map files (.map) here.\n\n" +
				"Originalkarten-Paket / Original maps package:\n" +
				"https://github.com/RobinNunkesser/gd-godot-clanbomber-original-maps\n"
			)
			file.close()


# --- Steuerung ---

# Nächste/vorherige Steuerung für einen Platz. Tastatur und Gamepads sind je nur einmal vergebbar.
func cycle_slot(slot: int, step: int) -> void:
	var count := Controller.size()
	var value := slots[slot]
	for attempt in count:
		value = posmod(value + step, count)
		if value == Controller.OFF or value == Controller.AI or not slots.has(value):
			slots[slot] = value
			return


# Spielerplätze (0-basiert), die mitspielen.
func active_slots() -> Array[int]:
	var result: Array[int] = []
	for slot in SLOT_COUNT:
		if slots[slot] != Controller.OFF:
			result.append(slot)
	return result


# Gamepad-Gerätenummer (0-basiert) oder -1, wenn der Platz kein Gamepad nutzt.
func pad_device(slot: int) -> int:
	var controller := slots[slot]
	if controller >= Controller.PAD_1 and controller <= Controller.PAD_8:
		return controller - Controller.PAD_1
	return -1


# --- Namen ---

func default_name(slot: int) -> String:
	return "Spieler %d" % (slot + 1)


func name_of(slot: int) -> String:
	var value := names[slot].strip_edges()
	return default_name(slot) if value.is_empty() else value


func set_name(slot: int, value: String) -> void:
	names[slot] = value.replace("[", "").replace("]", "").strip_edges().left(NAME_MAX_LENGTH)


# --- Teams ---

func cycle_team(slot: int, step: int) -> void:
	teams[slot] = posmod(teams[slot] + step, TEAM_COUNT + 1)


static func team_label(team: int) -> String:
	return "Kein Team" if team <= 0 else "Team " + TEAM_NAMES[team - 1]


# Wie im Original zählt ein Team mit nur einem aktiven Mitglied nicht als Team (ClanBomber::init_game).
func effective_team(slot: int) -> int:
	var team := teams[slot]
	if team <= 0 or slots[slot] == Controller.OFF:
		return 0
	var members := 0
	for other in SLOT_COUNT:
		if slots[other] != Controller.OFF and teams[other] == team:
			members += 1
	return team if members >= 2 else 0


# Anzahl gegnerischer Parteien: ein Team zählt einmal, jeder Einzelspieler für sich (Config::get_number_of_opponents).
func faction_count() -> int:
	var seen_teams: Dictionary = {}
	var count := 0
	for slot in active_slots():
		var team := effective_team(slot)
		if team == 0:
			count += 1
		elif not seen_teams.has(team):
			seen_teams[team] = true
			count += 1
	return count


func is_startable() -> bool:
	return faction_count() >= SimConstants.MIN_PLAYERS_FOR_MATCH


# --- Punkte und Sudden Death ---

func cycle_points(step: int) -> void:
	points_to_win = clampi(points_to_win + step, MIN_POINTS, MAX_POINTS)


func cycle_round_time(step: int) -> void:
	var index := ROUND_TIMES.find(round_time_s)
	if index < 0:
		index = ROUND_TIMES.find(DEFAULT_ROUND_TIME_S)
	round_time_s = ROUND_TIMES[clampi(index + step, 0, ROUND_TIMES.size() - 1)]


func round_time_ms() -> int:
	return round_time_s * 1000


# --- Karten ---

func order_label() -> String:
	return "Zufällig" if random_order else "Der Reihe nach"


func random_positions_label() -> String:
	return "Zufällig" if random_positions else "Fest"


func toggle_random_positions() -> void:
	random_positions = not random_positions


func select_all(playable: Array[String]) -> void:
	for map in playable:
		if not map_pool.has(map):
			map_pool.append(map)


# Nur diese Karte (Taste S im Original).
func select_only(map: String) -> void:
	map_pool = [map]


func is_in_pool(map: String) -> bool:
	return map_pool.has(map)


func toggle_pool(map: String) -> void:
	if map_pool.has(map):
		map_pool.erase(map)
	else:
		map_pool.append(map)


# Auswahl, aus der das Turnier zieht: ausgewählte Karten, die für die Spielerplätze taugen; ist keine
# davon spielbar, fallen wir auf alle spielbaren Karten zurück, damit ein Match nie an der Auswahl scheitert.
func effective_pool(playable: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for map in playable:
		if map_pool.has(map):
			result.append(map)
	return result if not result.is_empty() else playable


# --- Ton ---

func cycle_music(step: int) -> void:
	music_volume = clampi(music_volume + step, 0, VOLUME_LEVELS.size() - 1)
	if music_volume > 0:
		_last_music_volume = music_volume


func cycle_sfx(step: int) -> void:
	sfx_volume = clampi(sfx_volume + step, 0, VOLUME_LEVELS.size() - 1)
	if sfx_volume > 0:
		_last_sfx_volume = sfx_volume


func music_label() -> String:
	return VOLUME_LEVELS[music_volume]


func sfx_label() -> String:
	return VOLUME_LEVELS[sfx_volume]


func music_db() -> float:
	return VOLUME_DBS[music_volume]


func sfx_db() -> float:
	return VOLUME_DBS[sfx_volume]


func is_music_enabled() -> bool:
	return music_volume > 0


func is_sfx_enabled() -> bool:
	return sfx_volume > 0


func toggle_music_mute() -> void:
	if music_volume > 0:
		_last_music_volume = music_volume
		music_volume = 0
	else:
		music_volume = _last_music_volume if _last_music_volume > 0 else 4


func toggle_sfx_mute() -> void:
	if sfx_volume > 0:
		_last_sfx_volume = sfx_volume
		sfx_volume = 0
	else:
		sfx_volume = _last_sfx_volume if _last_sfx_volume > 0 else 4


# --- Video / Screen Shake ---

func cycle_shake(step: int) -> void:
	screen_shake = clampi(screen_shake + step, 0, SHAKE_LEVELS.size() - 1)


func shake_multiplier() -> float:
	match screen_shake:
		0:
			return 0.0
		1:
			return 0.5
		_:
			return 1.0


func shake_label() -> String:
	return SHAKE_LEVELS[screen_shake]


# --- Speichern und Laden ---

func save_to(path: String) -> Error:
	var file := ConfigFile.new()
	file.set_value("match", "slots", slots)
	file.set_value("match", "names", names)
	file.set_value("match", "teams", teams)
	file.set_value("match", "map_pool", map_pool)
	file.set_value("match", "external_map_dir", external_map_dir)
	file.set_value("match", "random_order", random_order)
	file.set_value("match", "random_positions", random_positions)
	file.set_value("match", "points_to_win", points_to_win)
	file.set_value("match", "round_time_s", round_time_s)
	file.set_value("audio", "music", music_volume)
	file.set_value("audio", "sfx", sfx_volume)
	file.set_value("video", "screen_shake", screen_shake)
	return file.save(path)


# Fehlende oder ungültige Werte behalten ihren Standard. `known_maps` filtert Karten, die es nicht mehr gibt.
func load_from(path: String, known_maps: Array[String]) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	var saved_slots: Array = file.get_value("match", "slots", [])
	if saved_slots.size() > 0 and saved_slots.size() <= SLOT_COUNT:
		var restored: Array[int] = []
		for value in saved_slots:
			restored.append(clampi(int(value), 0, Controller.size() - 1))
		while restored.size() < SLOT_COUNT:
			restored.append(Controller.OFF)
		if _has_unique_devices(restored):
			slots = restored
	var saved_names: Array = file.get_value("match", "names", [])
	for slot in mini(saved_names.size(), SLOT_COUNT):
		set_name(slot, str(saved_names[slot]))
	var saved_teams: Array = file.get_value("match", "teams", [])
	for slot in mini(saved_teams.size(), SLOT_COUNT):
		teams[slot] = clampi(int(saved_teams[slot]), 0, TEAM_COUNT)
	random_order = bool(file.get_value("match", "random_order", random_order))
	random_positions = bool(file.get_value("match", "random_positions", random_positions))
	external_map_dir = str(file.get_value("match", "external_map_dir", external_map_dir)).strip_edges()
	var saved_pool: Array = file.get_value("match", "map_pool", [])
	map_pool = []
	for value in saved_pool:
		# Bei leerer Bekanntliste bleibt die Auswahl erhalten; der Aufrufer validiert sie nach dem Karten-Scan.
		if known_maps.is_empty() or known_maps.has(str(value)):
			map_pool.append(str(value))
	points_to_win = clampi(int(file.get_value("match", "points_to_win", points_to_win)), MIN_POINTS, MAX_POINTS)
	var saved_time := int(file.get_value("match", "round_time_s", round_time_s))
	round_time_s = saved_time if ROUND_TIMES.has(saved_time) else DEFAULT_ROUND_TIME_S
	music_volume = clampi(int(file.get_value("audio", "music", music_volume)), 0, VOLUME_LEVELS.size() - 1)
	sfx_volume = clampi(int(file.get_value("audio", "sfx", sfx_volume)), 0, VOLUME_LEVELS.size() - 1)
	screen_shake = clampi(int(file.get_value("video", "screen_shake", screen_shake)), 0, SHAKE_LEVELS.size() - 1)
	if music_volume > 0:
		_last_music_volume = music_volume
	if sfx_volume > 0:
		_last_sfx_volume = sfx_volume


# Tastatur und Gamepads sind je nur einmal vergebbar; eine kaputte Datei darf das nicht aushebeln.
static func _has_unique_devices(values: Array[int]) -> bool:
	var seen: Dictionary = {}
	for value in values:
		if value == Controller.OFF or value == Controller.AI:
			continue
		if seen.has(value):
			return false
		seen[value] = true
	return true
