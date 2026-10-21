class_name BundledMapsTest
extends GdUnitTestSuite

const MAP_DIR := "res://maps"


func _map_files() -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(MAP_DIR):
		if file.ends_with(".map"):
			files.append(file)
	return files


# Zellen ohne Wall/NONE gelten als durchlaufbar, Boxen zählen mit (sprengbar).
func _reachable_from(map: MapData, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir in SimWorld.DIRECTIONS:
			var next := cell + dir
			if next.x < 0 or next.y < 0 or next.x >= SimConstants.GRID_WIDTH or next.y >= SimConstants.GRID_HEIGHT:
				continue
			var tile := map.tiles[next.y * SimConstants.GRID_WIDTH + next.x]
			if tile == SimTile.Type.WALL or tile == SimTile.Type.NONE or seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen


func test_bundled_maps_exist() -> void:
	assert_int(_map_files().size()).is_greater_equal(2)


func test_bundled_maps_are_valid() -> void:
	for file in _map_files():
		var map := MapParser.parse(FileAccess.get_file_as_string(MAP_DIR.path_join(file)))
		assert_bool(map.is_valid()).override_failure_message("%s: %s" % [file, map.error]).is_true()
		assert_bool(map.starts.size() >= map.max_players).override_failure_message("%s: zu wenige Startfelder" % file).is_true()
		assert_bool(map.starts.size() > 0).is_true()


func test_bundled_maps_starts_are_connected_and_have_room() -> void:
	for file in _map_files():
		var map := MapParser.parse(FileAccess.get_file_as_string(MAP_DIR.path_join(file)))
		var first: Vector2i = map.starts[map.starts.keys()[0]]
		var reachable := _reachable_from(map, first)
		for index in map.starts:
			var start: Vector2i = map.starts[index]
			assert_bool(reachable.has(start)).override_failure_message("%s: Start %d nicht verbunden" % [file, index]).is_true()
			var free_neighbours := 0
			for dir in SimWorld.DIRECTIONS:
				var cell := start + dir
				var tile := map.tiles[cell.y * SimConstants.GRID_WIDTH + cell.x]
				if tile != SimTile.Type.WALL and tile != SimTile.Type.BOX and tile != SimTile.Type.NONE:
					free_neighbours += 1
			assert_bool(free_neighbours >= 1).override_failure_message("%s: Start %d eingemauert" % [file, index]).is_true()
