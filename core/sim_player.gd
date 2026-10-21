class_name SimPlayer
extends RefCounted

var id := 0
# Obere linke Ecke der 40×40-Figur in ganzzahligen Pixeln (Raster-Pixelkoordinaten).
var pos := Vector2i.ZERO
# Zelle durch Rundung zur Zellmitte: floor((pos + 20) / 40). Setzen zentriert die Figur auf der Zelle.
var cell: Vector2i:
	get:
		return Vector2i(floori((pos.x + 20) / SimConstants.CELL_SIZE), floori((pos.y + 20) / SimConstants.CELL_SIZE))
	set(value):
		pos = Vector2i(value * int(SimConstants.CELL_SIZE))
var alive := true
var max_bombs := SimConstants.START_BOMBS
var active_bombs := 0
var power := SimConstants.START_POWER
var skateboards := 0
var kills := 0
# Letzte Blickrichtung (bestimmt die Wurfrichtung) und ob die Figur im letzten Tick gelaufen ist.
var facing := Vector2i.DOWN
var moved := false
var ice_remainder_milli := 0
var can_kick := false
var can_glove := false
# Aufgesammelte Extras (ohne Startausrüstung); sie fallen beim Tod wieder aus.
var extra_bombs := 0
var extra_power := 0
var extra_skateboards := 0
var extra_kick := 0
var extra_gloves := 0
# Aktive Krankheit (SimExtra.Type.OVERDRIVE/REVERSE/AUTOBOMB) oder NONE.
var disease: int = SimExtra.Type.NONE
var disease_ms := 0
# Gewünschte Bewegungsrichtung (kardinal oder ZERO).
var move_dir := Vector2i.ZERO
# Bruchrest in Tausendstel-Pixeln, damit Geschwindigkeit unabhängig von der Tickrate exakt bleibt.
var move_remainder_milli := 0


func speed() -> int:
	var value := SimConstants.BASE_PLAYER_SPEED + SimConstants.SKATEBOARD_SPEED_BONUS * mini(skateboards, SimConstants.MAX_SKATEBOARDS)
	if disease == SimExtra.Type.OVERDRIVE:
		value += SimConstants.OVERDRIVE_SPEED_BONUS
	return value


func is_diseased() -> bool:
	return disease != SimExtra.Type.NONE


func can_place_bomb() -> bool:
	return alive and active_bombs < max_bombs
