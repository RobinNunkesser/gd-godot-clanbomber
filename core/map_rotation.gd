class_name MapRotation
extends RefCounted
## Turnier-Reihenfolge: mischt die ausgewählten Karten und spielt jede einmal pro Durchgang,
## bevor neu gemischt wird. Direkt nach dem Mischen wiederholt sich die letzte Karte nicht.

var _bag: Array[String] = []
var _last := ""


# Nächste Karte aus `pool` ("" bei leerem Pool). Karten, die nicht mehr im Pool sind, werden verworfen.
func next(pool: Array[String], rng: RandomNumberGenerator) -> String:
	if pool.is_empty():
		_bag.clear()
		return ""
	var filtered: Array[String] = []
	for map_name in _bag:
		if pool.has(map_name):
			filtered.append(map_name)
	_bag = filtered
	if _bag.is_empty():
		_bag = _shuffled(pool, rng)
		if _bag.size() > 1 and _bag[0] == _last:
			var swap_index := 1 + rng.randi() % (_bag.size() - 1)
			var first := _bag[0]
			_bag[0] = _bag[swap_index]
			_bag[swap_index] = first
	_last = _bag.pop_front()
	return _last


# Der Reihe nach: die Karte hinter der zuletzt gespielten, nach der letzten wieder die erste.
# Ist die zuletzt gespielte Karte nicht mehr in der Auswahl, beginnt die Folge von vorn.
func next_in_order(pool: Array[String]) -> String:
	if pool.is_empty():
		return ""
	_bag.clear()
	_last = pool[(pool.find(_last) + 1) % pool.size()]
	return _last


func reset() -> void:
	_bag.clear()
	_last = ""


# Fisher-Yates mit dem übergebenen Zufallsgenerator (Array.shuffle nutzt den globalen und wäre nicht testbar).
static func _shuffled(source: Array[String], rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = source.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: String = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result
