class_name BundledMapsTest
extends GdUnitTestSuite

const MAP_DIR := "res://maps"


func _map_files() -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(MAP_DIR):
		if file.ends_with(".map"):
			files.append(file)
	return files


func test_bundled_maps_exist() -> void:
	assert_int(_map_files().size()).is_greater_equal(2)


func test_bundled_maps_are_valid() -> void:
	for file in _map_files():
		var map := MapParser.parse(FileAccess.get_file_as_string(MAP_DIR.path_join(file)))
		assert_bool(map.is_valid()).override_failure_message("%s: %s" % [file, map.error]).is_true()
		assert_bool(map.starts.size() >= map.max_players).override_failure_message("%s: zu wenige Startfelder" % file).is_true()
		assert_bool(map.starts.size() > 0).is_true()


func test_bundled_maps_starts_are_not_walled_in() -> void:
	for file in _map_files():
		var map := MapParser.parse(FileAccess.get_file_as_string(MAP_DIR.path_join(file)))
		# Inseln und getrennte Bereiche sind gewollte Designs (Bomben-Wurf, Traps), daher keine Konnektivitätsprüfung.
		for index in map.starts:
			var start: Vector2i = map.starts[index]
			var free_neighbours := 0
			for dir in SimWorld.DIRECTIONS:
				var cell := start + dir
				if cell.x < 0 or cell.y < 0 or cell.x >= SimConstants.GRID_WIDTH or cell.y >= SimConstants.GRID_HEIGHT:
					continue
				var tile := map.tiles[cell.y * SimConstants.GRID_WIDTH + cell.x]
				if tile != SimTile.Type.WALL and tile != SimTile.Type.BOX and tile != SimTile.Type.NONE:
					free_neighbours += 1
			assert_bool(free_neighbours >= 1).override_failure_message("%s: Start %d eingemauert" % [file, index]).is_true()
