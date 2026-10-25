class_name SimAI
extends RefCounted
## Einfache Heuristik-AI (ohne Zufall, daher reproduzierbar). Ersatz für Controller_AI des Originals.
## Je Tick: 1. aus Gefahrenzonen fliehen, 2. Bombe legen, wenn sie eine Box oder einen Gegner trifft
## und ein Fluchtweg existiert, 3. Extras einsammeln, 4. zu einer sinnvollen Bombenposition laufen.
## Gefahr wird zeitlich bewertet: Eine Gefahrenzelle darf nur betreten werden, wenn man sie vor der Detonation wieder verlässt.
## Nicht berücksichtigt: Kick, Glove, Eis, Pfeile, Fallen und Löcher als Wegpunkte (sie gelten als Hindernis).

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const MAX_PICKUP_DISTANCE := 8
# Entscheidungsintervall; hält die Kosten niedrig und die Reaktion trotzdem schnell.
const THINK_MS := 50
# Zeitreserve vor einer Detonation, in ms.
const SAFETY_MS := 150

var player_id := 0
var _think_timer_ms := 0


func _init(p_player_id: int = 0) -> void:
	player_id = p_player_id


# Setzt Bewegung und legt ggf. eine Bombe für den eigenen Spieler. Pro Tick aufrufen.
func update(world: SimWorld, dt_ms: int) -> void:
	var player: SimPlayer = world.players.get(player_id)
	if player == null or not player.alive or player.is_falling():
		if player != null:
			world.set_move_dir(player_id, Vector2i.ZERO)
		return
	_think_timer_ms -= dt_ms
	if _think_timer_ms > 0:
		return
	_think_timer_ms = THINK_MS
	var dir := decide(world, player)
	world.set_move_dir(player_id, -dir if player.disease == SimExtra.Type.REVERSE else dir)


# Liefert die gewünschte Laufrichtung (ZERO = stehen). Kann dabei eine Bombe legen.
func decide(world: SimWorld, player: SimPlayer) -> Vector2i:
	var danger := danger_cells(world)
	var here := player.cell
	if danger.has(here):
		var flee := _search(world, player, here, func(c: Vector2i) -> bool: return not danger.has(c), false, danger)
		return flee[0]
	if player.can_glove and world.bomb_at(here) != null:
		for step in range(2, SimConstants.THROW_FIELDS + 1):
			var target := here + player.facing * step
			if not world.board.in_bounds(target) or world.board.is_blocking(target):
				break
			if world.is_enemy_in(target, player_id):
				world.action_bomb(player_id)
				return Vector2i.ZERO
	if _bomb_is_useful(world, player, here) and _has_escape(world, player, here, danger):
		world.action_bomb(player_id)
		return Vector2i.ZERO
	var pickup := _search(world, player, here, func(c: Vector2i) -> bool: return _is_good_extra(world, c),
		true, danger, MAX_PICKUP_DISTANCE)
	if pickup[0] != Vector2i.ZERO:
		return pickup[0]
	if player.can_place_bomb():
		var hunt := _search(world, player, here, func(c: Vector2i) -> bool:
			return _bomb_is_useful(world, player, c) and _has_escape(world, player, c, danger),
			true, danger)
		if hunt[0] != Vector2i.ZERO:
			return hunt[0]
	var approach := _search(world, player, here, func(c: Vector2i) -> bool:
		for dir in DIRECTIONS:
			if world.is_enemy_in(c + dir, player_id):
				return true
		return false, true, danger)
	return approach[0]


# Zeit in ms bis zur Detonation je gefährdeter Zelle (kleinster Wert). Laufende Explosionen zählen als 0.
# Liegt eine Bombe im Wirkungsbereich einer früheren, detoniert sie nach BOMB_CHAIN_DELAY_MS (Kettenreaktion).
func danger_cells(world: SimWorld) -> Dictionary:
	var danger: Dictionary = {}
	for explosion in world.explosions:
		for cell in explosion.cells:
			danger[cell] = 0
	var fuses: Array = []
	for bomb in world.bombs:
		if not bomb.flying:
			fuses.append([bomb.cell, bomb.power, maxi(bomb.timer_ms, 0)])
	for pass_index in fuses.size():
		var changed := false
		for source in fuses:
			for cell in blast_cells(world, source[0], source[1]):
				for other in fuses:
					if other[0] == cell and other[2] > source[2] + SimConstants.BOMB_CHAIN_DELAY_MS:
						other[2] = source[2] + SimConstants.BOMB_CHAIN_DELAY_MS
						changed = true
		if not changed:
			break
	for source in fuses:
		_merge_blast(world, danger, source[0], source[1], source[2])
	return danger


static func _merge_blast(world: SimWorld, danger: Dictionary, origin: Vector2i, power: int, fuse_ms: int) -> void:
	for cell in blast_cells(world, origin, power):
		danger[cell] = mini(danger.get(cell, fuse_ms), fuse_ms)


# Zellen, die eine Bombe mit gegebener Stärke trifft (Ursprung eingeschlossen). Stoppt vor Blockierern.
# Extras zählen konservativ nicht als Hindernis: Wer das Extra aufsammelt, steht danach in der Flamme.
static func blast_cells(world: SimWorld, origin: Vector2i, power: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [origin]
	for dir in DIRECTIONS:
		for step in range(1, power + 1):
			var cell := origin + dir * step
			if not world.board.in_bounds(cell) or world.board.is_blocking(cell):
				break
			cells.append(cell)
	return cells


func _walkable(world: SimWorld, cell: Vector2i, own_cell: Vector2i) -> bool:
	if not world.board.in_bounds(cell) or world.board.is_blocking(cell):
		return false
	var tile := world.board.get_tile(cell)
	if SimTile.is_hole(tile) or tile == SimTile.Type.TRAP:
		return false
	if world.extras.has(cell) and not _is_good_extra(world, cell):
		return false
	if cell != own_cell:
		if world.is_other_player_in(cell, player_id):
			return false
		var bomb := world.bomb_at(cell)
		if bomb != null:
			var player: SimPlayer = world.players.get(player_id)
			if player != null and player.can_kick:
				var kick_dir := cell - own_cell
				if kick_dir.length_squared() == 1:
					var behind := cell + kick_dir
					if world.board.in_bounds(behind) and not world.board.is_blocking(behind) and world.bomb_at(behind) == null:
						return true
			return false
	return true


# Ermittelt das Ziel beim Schlittern über Eis in Richtung dir.
static func slide_destination(world: SimWorld, start: Vector2i, dir: Vector2i) -> Vector2i:
	var curr := start
	while world.board.in_bounds(curr) and world.board.get_tile(curr) == SimTile.Type.ICE:
		var next := curr + dir
		if not world.board.in_bounds(next) or world.board.is_blocking(next) or world.bomb_at(next) != null:
			break
		curr = next
		if world.board.get_tile(curr) != SimTile.Type.ICE:
			break
	return curr


# Breitensuche vom Start zum nächsten Ziel. Rückgabe: [erste Richtung, Weglänge]; Weglänge -1, wenn nichts erreichbar ist.
# strict: Gefahrenzellen sind tabu. Sonst darf eine Gefahrenzelle betreten werden, wenn man sie rechtzeitig wieder verlässt.
func _search(world: SimWorld, player: SimPlayer, start: Vector2i, is_goal: Callable,
		strict: bool, danger: Dictionary, max_distance := 1000) -> Array:
	var cell_ms := int(SimConstants.CELL_SIZE * 1000.0 / player.speed())
	var first: Dictionary = {start: Vector2i.ZERO}
	var distance: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cell != start and is_goal.call(cell):
			return [first[cell], distance[cell]]
		if distance[cell] >= max_distance:
			continue
		for dir in DIRECTIONS:
			var next := cell + dir
			if not _walkable(world, next, player.cell):
				continue
			var dest := next
			if world.board.get_tile(next) == SimTile.Type.ICE:
				dest = slide_destination(world, next, dir)
				if not world.board.in_bounds(dest) or SimTile.is_hole(world.board.get_tile(dest)) or world.board.get_tile(dest) == SimTile.Type.TRAP:
					continue
			if first.has(dest):
				continue
			var steps: int = distance[cell] + 1
			if danger.has(dest) and (strict or (steps + 1) * cell_ms / 2 + SAFETY_MS >= danger[dest]):
				continue
			first[dest] = dir if cell == start else first[cell]
			distance[dest] = steps
			queue.append(dest)
	return [Vector2i.ZERO, -1]


func _is_good_extra(world: SimWorld, cell: Vector2i) -> bool:
	if not world.extras.has(cell):
		return false
	var type: int = world.extras[cell]
	return type != SimExtra.Type.OVERDRIVE and type != SimExtra.Type.REVERSE and type != SimExtra.Type.AUTOBOMB


# Eine Bombe lohnt sich, wenn ihre Flammen eine Box oder einen lebenden Gegner erreichen.
func _bomb_is_useful(world: SimWorld, player: SimPlayer, cell: Vector2i) -> bool:
	if not player.can_place_bomb() or world.bomb_at(cell) != null:
		return false
	for dir in DIRECTIONS:
		for step in range(1, player.power + 1):
			var target := cell + dir * step
			if not world.board.in_bounds(target):
				break
			if world.board.is_blocking(target):
				if SimTile.is_destructible(world.board.get_tile(target)):
					return true
				break
			if world.is_enemy_in(target, player_id):
				return true
	return false


# Gibt es nach dem Legen einer Bombe auf `cell` rechtzeitig eine sichere Zelle?
# Der Weg darf durch die neue Flammenzone führen, solange er sie vor der Detonation verlässt.
func _has_escape(world: SimWorld, player: SimPlayer, cell: Vector2i, danger: Dictionary) -> bool:
	var combined := danger.duplicate()
	_merge_blast(world, combined, cell, player.power, SimConstants.BOMB_COUNTDOWN_MS)
	var result := _search(world, player, cell, func(c: Vector2i) -> bool: return not combined.has(c),
		false, combined)
	return result[1] > 0
