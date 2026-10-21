class_name MapParser
extends RefCounted

const CHAR_TILES := {
	" ": SimTile.Type.GROUND,
	"*": SimTile.Type.WALL,
	"+": SimTile.Type.BOX,
	"S": SimTile.Type.ICE,
	"<": SimTile.Type.ARROW_LEFT,
	">": SimTile.Type.ARROW_RIGHT,
	"^": SimTile.Type.ARROW_UP,
	"v": SimTile.Type.ARROW_DOWN,
	"o": SimTile.Type.TRAP,
	"-": SimTile.Type.NONE,
}


# Parst das Plain-Text-Kartenformat ('-' = NONE: unbespielbarer Bereich außerhalb der Arena). 'R' wird zu 2/3 Box, 1/3 Ground; ohne rng deterministisch mit Seed 0.
static func parse(text: String, rng: RandomNumberGenerator = null) -> MapData:
	var data := MapData.new()
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 0
	var lines := text.replace("\r\n", "\n").split("\n")
	if lines.size() < 2:
		data.error = "Kein Kartenkopf"
		return data
	data.author = lines[0].strip_edges()
	# Einzelne Originalkarten haben Leerzeilen zwischen Autor und Spielerzahl.
	var header_end := 1
	while header_end < lines.size() and lines[header_end].strip_edges().is_empty():
		header_end += 1
	if header_end >= lines.size() or not lines[header_end].strip_edges().is_valid_int():
		data.error = "Ungültige Spielerzahl"
		return data
	data.max_players = lines[header_end].strip_edges().to_int()
	var grid_start := header_end + 1
	if lines.size() < grid_start + SimConstants.GRID_HEIGHT:
		data.error = "Zu wenige Kartenzeilen: %d" % (lines.size() - grid_start)
		return data
	data.tiles.resize(SimConstants.GRID_WIDTH * SimConstants.GRID_HEIGHT)
	for y in SimConstants.GRID_HEIGHT:
		var line: String = lines[grid_start + y].trim_suffix("\r")
		if line.length() > SimConstants.GRID_WIDTH:
			data.error = "Zeile %d zu lang (%d Zeichen)" % [y, line.length()]
			return data
		line = line.rpad(SimConstants.GRID_WIDTH, " ")
		for x in SimConstants.GRID_WIDTH:
			var ch := line[x]
			var tile: int
			if CHAR_TILES.has(ch):
				tile = CHAR_TILES[ch]
			elif ch == "R":
				tile = SimTile.Type.BOX if rng.randi() % 3 < 2 else SimTile.Type.GROUND
			elif ch >= "0" and ch <= "7":
				tile = SimTile.Type.GROUND
				data.starts[ch.to_int()] = Vector2i(x, y)
			else:
				data.error = "Unbekanntes Zeichen '%s' in Zeile %d, Spalte %d" % [ch, y, x]
				return data
			data.tiles[y * SimConstants.GRID_WIDTH + x] = tile
	return data
