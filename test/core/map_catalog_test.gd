extends GdUnitTestSuite

const MAP_DIR := "res://maps"


# Baut eine gültige Karte mit `starts` Startfeldern (Plätze 0..starts-1) in der zweiten Zeile.
func _map_text(starts: int) -> String:
	var rows: Array[String] = []
	for y in SimConstants.GRID_HEIGHT:
		var row := ""
		for x in SimConstants.GRID_WIDTH:
			var border := x == 0 or y == 0 or x == SimConstants.GRID_WIDTH - 1 or y == SimConstants.GRID_HEIGHT - 1
			if border:
				row += "*"
			elif y == 1 and x >= 1 and x <= starts:
				row += str(x - 1)
			else:
				row += " "
		rows.append(row)
	return "Autor\n%d\n%s" % [starts, "\n".join(rows)]


func _catalog() -> MapCatalog:
	var catalog := MapCatalog.new()
	catalog.add("b_four.map", _map_text(4))
	catalog.add("a_two.map", _map_text(2))
	catalog.add("broken.map", "kaputt")
	return catalog


func test_names_are_sorted_and_broken_maps_skipped() -> void:
	assert_array(_catalog().names).is_equal(["a_two.map", "b_four.map"])


func test_start_count() -> void:
	var catalog := _catalog()
	assert_int(catalog.start_count("a_two.map")).is_equal(2)
	assert_int(catalog.start_count("b_four.map")).is_equal(4)
	assert_int(catalog.start_count("unknown.map")).is_equal(0)


func test_playable_depends_on_active_slots() -> void:
	var catalog := _catalog()
	var two: Array[int] = [0, 1]
	var three: Array[int] = [0, 1, 2]
	assert_array(catalog.playable(two)).is_equal(["a_two.map", "b_four.map"])
	assert_array(catalog.playable(three)).is_equal(["b_four.map"])


func test_slots_without_start_make_map_unplayable() -> void:
	var catalog := _catalog()
	var gap: Array[int] = [0, 3]
	assert_bool(catalog.is_playable("a_two.map", gap)).is_false()
	assert_bool(catalog.is_playable("b_four.map", gap)).is_true()
	assert_bool(catalog.is_playable("unknown.map", gap)).is_false()


func test_bundled_maps_are_catalogued() -> void:
	var catalog := MapCatalog.load_dir(MAP_DIR)
	assert_int(catalog.names.size()).is_greater_equal(2)
	var two: Array[int] = [0, 1]
	var four: Array[int] = [0, 1, 2, 3]
	assert_int(catalog.playable(two).size()).is_greater(0)
	assert_int(catalog.playable(four).size()).is_less_equal(catalog.playable(two).size())
