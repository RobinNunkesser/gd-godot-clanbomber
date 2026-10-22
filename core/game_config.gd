class_name GameConfig
extends RefCounted
## Matcheinstellungen aus dem Menü: Steuerung je Spielerplatz, Karte, Punkte zum Sieg.

enum Controller { OFF, KEYBOARD_1, KEYBOARD_2, PAD_1, PAD_2, PAD_3, PAD_4, AI }

const SLOT_COUNT := 4
const RANDOM_MAP := -1
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
	Controller.AI: "AI",
}

var slots: Array[int] = [Controller.KEYBOARD_1, Controller.AI, Controller.OFF, Controller.OFF]
var map_name := "Crossroads.map"
var points_to_win := SimConstants.POINTS_TO_WIN

const VOLUME_LEVELS: Array[String] = ["Aus", "25 %", "50 %", "75 %", "100 %"]
const VOLUME_DBS: Array[float] = [-80.0, -18.0, -10.0, -4.0, 0.0]

var music_volume: int = 4
var sfx_volume: int = 4
var _last_music_volume: int = 4
var _last_sfx_volume: int = 4


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


# Nächste/vorherige Steuerung für einen Platz. Tastatur und Gamepads sind je nur einmal vergebbar.
func cycle_slot(slot: int, step: int) -> void:
	var count := Controller.size()
	var value := slots[slot]
	for attempt in count:
		value = posmod(value + step, count)
		if value == Controller.OFF or value == Controller.AI or not slots.has(value):
			slots[slot] = value
			return


func cycle_points(step: int) -> void:
	points_to_win = clampi(points_to_win + step, MIN_POINTS, MAX_POINTS)


# Zeigt auf die nächste Karte; "" steht für Zufall und liegt vor der ersten Karte.
func cycle_map(maps: Array[String], step: int) -> void:
	var options: Array[String] = [""]
	options.append_array(maps)
	var index := options.find(map_name)
	map_name = options[posmod(index + step, options.size())]


func is_random_map() -> bool:
	return map_name == ""


# Spielerplätze (0-basiert), die mitspielen.
func active_slots() -> Array[int]:
	var result: Array[int] = []
	for slot in SLOT_COUNT:
		if slots[slot] != Controller.OFF:
			result.append(slot)
	return result


func is_startable() -> bool:
	return active_slots().size() >= SimConstants.MIN_PLAYERS_FOR_MATCH


# Gamepad-Gerätenummer (0-basiert) oder -1, wenn der Platz kein Gamepad nutzt.
func pad_device(slot: int) -> int:
	var controller := slots[slot]
	if controller >= Controller.PAD_1 and controller <= Controller.PAD_4:
		return controller - Controller.PAD_1
	return -1
