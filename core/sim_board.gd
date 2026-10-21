class_name SimBoard
extends RefCounted

var width := SimConstants.GRID_WIDTH
var height := SimConstants.GRID_HEIGHT
var tiles: Array[int] = []


static func from_map(map: MapData) -> SimBoard:
	var board := SimBoard.new()
	board.tiles = map.tiles.duplicate()
	return board


static func empty() -> SimBoard:
	var board := SimBoard.new()
	board.tiles.resize(board.width * board.height)
	board.tiles.fill(SimTile.Type.GROUND)
	return board


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func get_tile(cell: Vector2i) -> int:
	return tiles[cell.y * width + cell.x]


func set_tile(cell: Vector2i, type: int) -> void:
	tiles[cell.y * width + cell.x] = type


# Außerhalb des Rasters gilt als blockierend.
func is_blocking(cell: Vector2i) -> bool:
	return not in_bounds(cell) or SimTile.is_blocking(get_tile(cell))
