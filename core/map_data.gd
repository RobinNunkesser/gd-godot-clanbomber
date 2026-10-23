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


# Startzellen für die aktiven (0-basierten) Plätze. Bei `randomize` werden die vorhandenen Startfelder
# deterministisch unter den aktiven Plätzen gemischt.
func start_cells(active_slots: Array[int], randomize: bool, rng: RandomNumberGenerator) -> Dictionary:
	var cells: Array[Vector2i] = []
	for slot in active_slots:
		cells.append(starts[slot])
	if randomize:
		for i in range(cells.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp := cells[i]
			cells[i] = cells[j]
			cells[j] = tmp
	var result: Dictionary = {}
	for i in active_slots.size():
		result[active_slots[i]] = cells[i]
	return result
