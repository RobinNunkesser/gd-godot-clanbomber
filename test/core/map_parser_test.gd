class_name MapParserTest
extends GdUnitTestSuite

const CLASSIC := "Andreas Hundt
8
*****************
*0 +   + +   + 1*
* * * * * * * * *
*+   + + + +   +*
* * * * * * * * *
* +   + + +   + *
* * * * * * * * *
* +   + + +   + *
* * * * * * * * *
*+   + + + +   +*
* * * * * * * * *
*2 +   + +   + 3*
*****************
"

# Kandidaten für das optionale GPL-Datenpaket mit den Originalkarten (Geschwister-Repo oder CLANBOMBER_MAPS_DIR).
const ORIGINAL_MAPS_CANDIDATES := [
	"../gd-godot-clanbomber-original-maps/maps",
]


func _row(y: int, text: String) -> String:
	return text.split("\n")[2 + y]


func test_parses_classic_map() -> void:
	var map := MapParser.parse(CLASSIC)
	assert_bool(map.is_valid()).is_true()
	assert_str(map.author).is_equal("Andreas Hundt")
	assert_int(map.max_players).is_equal(8)
	assert_int(map.tiles.size()).is_equal(17 * 13)
	assert_int(map.tiles[0]).is_equal(SimTile.Type.WALL)
	assert_int(map.tiles[1 * 17 + 3]).is_equal(SimTile.Type.BOX)
	assert_int(map.tiles[1 * 17 + 2]).is_equal(SimTile.Type.GROUND)


func test_start_positions_are_ground() -> void:
	var map := MapParser.parse(CLASSIC)
	assert_dict(map.starts).has_size(4)
	assert_that(map.starts[0]).is_equal(Vector2i(1, 1))
	assert_that(map.starts[3]).is_equal(Vector2i(15, 11))
	assert_int(map.tiles[1 * 17 + 1]).is_equal(SimTile.Type.GROUND)


func test_start_cells_keep_fixed_positions() -> void:
	var map := MapParser.parse(CLASSIC)
	var rng := RandomNumberGenerator.new()
	var fixed := map.start_cells([3, 1], false, rng)
	assert_that(fixed[3]).is_equal(map.starts[3])
	assert_that(fixed[1]).is_equal(map.starts[1])


func test_start_cells_shuffle_is_seeded() -> void:
	var map := MapParser.parse(CLASSIC)
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	var active: Array[int] = [0, 1, 2, 3]
	var a := map.start_cells(active, true, rng_a)
	var b := map.start_cells(active, true, rng_b)
	assert_dict(a).is_equal(b)
	var used: Array[Vector2i] = []
	for slot in active:
		var cell: Vector2i = a[slot]
		assert_bool(map.starts.values().has(cell)).is_true()
		assert_bool(used.has(cell)).is_false()
		used.append(cell)


func test_special_tiles() -> void:
	var lines := CLASSIC.split("\n")
	lines[3] = "*S<>^vo-" + " ".repeat(8) + "*"
	var map := MapParser.parse("\n".join(lines))
	assert_bool(map.is_valid()).is_true()
	var expected := [
		SimTile.Type.WALL, SimTile.Type.ICE, SimTile.Type.ARROW_LEFT, SimTile.Type.ARROW_RIGHT,
		SimTile.Type.ARROW_UP, SimTile.Type.ARROW_DOWN, SimTile.Type.TRAP, SimTile.Type.NONE,
	]
	for x in expected.size():
		assert_int(map.tiles[1 * 17 + x]).is_equal(expected[x])


func test_random_tile_is_seeded_and_mixed() -> void:
	var lines := CLASSIC.split("\n")
	lines[3] = "*" + "R".repeat(15) + "*"
	var text := "\n".join(lines)
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	var a := MapParser.parse(text, rng_a)
	var b := MapParser.parse(text, rng_b)
	assert_array(a.tiles).is_equal(b.tiles)
	var boxes := 0
	for x in range(1, 16):
		var tile := a.tiles[1 * 17 + x]
		assert_bool(tile == SimTile.Type.BOX or tile == SimTile.Type.GROUND).is_true()
		boxes += 1 if tile == SimTile.Type.BOX else 0
	assert_bool(boxes > 0 and boxes < 15).is_true()


func test_short_lines_are_padded() -> void:
	var lines := CLASSIC.split("\n")
	lines[3] = "*0"
	var map := MapParser.parse("\n".join(lines))
	assert_bool(map.is_valid()).is_true()
	assert_int(map.tiles[1 * 17 + 10]).is_equal(SimTile.Type.GROUND)


func test_rejects_unknown_character() -> void:
	var lines := CLASSIC.split("\n")
	lines[3] = "*?" + " ".repeat(14) + "*"
	var map := MapParser.parse("\n".join(lines))
	assert_bool(map.is_valid()).is_false()
	assert_str(map.error).contains("Unbekanntes Zeichen")


func test_rejects_too_few_lines() -> void:
	assert_bool(MapParser.parse("Autor\n2\n***").is_valid()).is_false()


func test_blank_lines_before_player_count_are_skipped() -> void:
	var map := MapParser.parse(CLASSIC.replace("Hundt\n8", "Hundt\n\n8"))
	assert_bool(map.is_valid()).is_true()
	assert_int(map.max_players).is_equal(8)
	assert_int(map.tiles[0]).is_equal(SimTile.Type.WALL)


func test_rejects_invalid_player_count() -> void:
	assert_bool(MapParser.parse(CLASSIC.replace("\n8\n", "\nacht\n")).is_valid()).is_false()


# Optional: lädt alle Originalkarten aus dem GPL-Datenpaket, dem Referenzbaum oder CLANBOMBER_MAPS_DIR, falls vorhanden.
func test_loads_all_original_maps_if_available() -> void:
	var dir_path := OS.get_environment("CLANBOMBER_MAPS_DIR")
	var dir: DirAccess = null
	if not dir_path.is_empty():
		dir = DirAccess.open(dir_path)
	else:
		for candidate: String in ORIGINAL_MAPS_CANDIDATES:
			dir_path = ProjectSettings.globalize_path("res://").path_join(candidate).simplify_path()
			dir = DirAccess.open(dir_path)
			if dir != null:
				break
	if dir == null:
		push_warning("Originalkarten nicht gefunden, Test übersprungen")
		return
	var count := 0
	for file in dir.get_files():
		if not file.ends_with(".map"):
			continue
		var map := MapParser.parse(FileAccess.get_file_as_string(dir_path.path_join(file)))
		assert_bool(map.is_valid()).override_failure_message("%s: %s" % [file, map.error]).is_true()
		assert_bool(map.starts.size() >= map.max_players).override_failure_message("%s: Starts %d < Spieler %d" % [file, map.starts.size(), map.max_players]).is_true()
		count += 1
	assert_int(count).is_greater(30)
