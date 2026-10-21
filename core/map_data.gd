class_name MapData
extends RefCounted

var author := ""
var max_players := 0
# Zeilenweise, Index = y * GRID_WIDTH + x, Werte aus SimTile.Type.
var tiles: Array[int] = []
# Spielerindex (0-7) -> Vector2i
var starts: Dictionary = {}
var error := ""


func is_valid() -> bool:
	return error.is_empty()
