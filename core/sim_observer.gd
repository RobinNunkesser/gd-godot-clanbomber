class_name SimObserver
extends RefCounted
## Der Observer des Sudden Death: fliegt mit 500 px/s zu zufälligen Feldern und lässt bei jeder Landung
## (außer der ersten, die nur die Ansage auslöst) das Feld unter sich verschwinden.

var _first := true
var _flying := false
var _from := Vector2i.ZERO
var target_cell := Vector2i.ZERO
var _elapsed_ms := 0
var _duration_ms := 0


# Pixelposition (obere linke Ecke der Zielzelle als Bezug) für die Anzeige.
func position_px() -> Vector2:
	var to := Vector2(target_cell) * SimConstants.CELL_SIZE
	if not _flying or _duration_ms <= 0:
		return to
	return Vector2(_from) * SimConstants.CELL_SIZE + (to - Vector2(_from) * SimConstants.CELL_SIZE) * (float(_elapsed_ms) / _duration_ms)


func step(world: SimWorld, dt_ms: int) -> void:
	if _flying:
		_elapsed_ms += dt_ms
		if _elapsed_ms < _duration_ms:
			return
		_flying = false
	if _first:
		_first = false
		world.sudden_death_started.emit()
	else:
		world.vanish_tile(target_cell)
	var next := world.random_vanishable_cell()
	if next.x < 0:
		return
	_from = target_cell
	target_cell = next
	var distance := Vector2(next - _from).length() * SimConstants.CELL_SIZE
	_duration_ms = int(distance * 1000.0 / SimConstants.OBSERVER_SPEED)
	_elapsed_ms = 0
	_flying = true
