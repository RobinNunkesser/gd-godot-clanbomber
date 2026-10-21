class_name SimBomb
extends RefCounted

var id := 0
var owner_id := 0
# Obere linke Ecke in Pixeln. Eine ruhende Bombe liegt exakt auf einer Zelle, gekickte und geworfene dazwischen.
var pos := Vector2i.ZERO
# Zelle durch Rundung zur Zellmitte. Setzen schnappt die Bombe auf die Zelle.
var cell: Vector2i:
	get:
		return Vector2i(floori((pos.x + 20) / SimConstants.CELL_SIZE), floori((pos.y + 20) / SimConstants.CELL_SIZE))
	set(value):
		pos = Vector2i(value * int(SimConstants.CELL_SIZE))
var power := 1
var timer_ms := SimConstants.BOMB_COUNTDOWN_MS
# Rollrichtung nach einem Kick (kardinal oder ZERO).
var move_dir := Vector2i.ZERO
var move_remainder_milli := 0
# Wurf: Während des Flugs steht der Zünder und die Bombe ist weder Hindernis noch Ziel von Explosionen.
var flying := false
var fly_dir := Vector2i.ZERO
var fly_remaining_px := 0
var fly_remainder_milli := 0


func snap() -> void:
	cell = cell
