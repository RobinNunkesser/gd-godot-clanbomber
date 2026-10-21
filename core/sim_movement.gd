class_name SimMovement
extends RefCounted

const CELL := int(SimConstants.CELL_SIZE)
const HALF := CELL / 2


# Bewegt die Figur um bis zu span Pixel in Richtung dir. Gibt zurück, ob alle Schritte möglich waren.
static func advance(world: SimWorld, player: SimPlayer, dir: Vector2i, span: int) -> bool:
	for i in span:
		if not _step(world, player, dir):
			return false
	return true


static func _step(world: SimWorld, player: SimPlayer, dir: Vector2i) -> bool:
	var ahead := _cell_at(_lead_point(player.pos, dir))
	if world.board.is_blocking(ahead):
		return false
	# Eine Bombe blockiert nur, wenn die Figur nicht schon (zu mehr als der Hälfte) auf deren Zelle steht.
	var bomb := world.bomb_at(ahead) if ahead != player.cell else null
	if bomb != null:
		if player.can_kick and bomb.move_dir == Vector2i.ZERO:
			world.kick_bomb(bomb, dir)
		return false
	if ahead != player.cell and world.is_other_player_in(ahead, player.id):
		return false
	player.pos += dir
	_slide_into_lane(world, player, dir)
	return true


# Rollt eine gekickte Bombe um bis zu span Pixel. Gibt zurück, ob alle Schritte möglich waren.
static func advance_bomb(world: SimWorld, bomb: SimBomb, span: int) -> bool:
	for i in span:
		var ahead := _cell_at(_lead_point(bomb.pos, bomb.move_dir))
		if world.board.is_blocking(ahead):
			return false
		if ahead != bomb.cell and (world.bomb_at(ahead) != null or world.is_other_player_in(ahead, -1)):
			return false
		bomb.pos += bomb.move_dir
	return true


# Corner-Sliding: Ragt die Figur seitlich in eine Nachbarspur, deren nächste Zelle blockiert ist,
# wird sie pro Schritt 1 px zur Hauptspur (der gerundeten Zelle) geschoben.
static func _slide_into_lane(world: SimWorld, player: SimPlayer, dir: Vector2i) -> void:
	var horizontal := dir.x != 0
	var lateral := player.pos.y if horizontal else player.pos.x
	var offset := posmod(lateral, CELL)
	if offset == 0:
		return
	var lane := floori(float(lateral) / CELL)
	var nudge: int
	if offset > HALF - 1:
		nudge = 1
	else:
		lane += 1
		nudge = -1
	var lead := _cell_at(_lead_point(player.pos, dir))
	var neighbour := Vector2i(lead.x, lane) if horizontal else Vector2i(lane, lead.y)
	if world.board.is_blocking(neighbour):
		if horizontal:
			player.pos.y += nudge
		else:
			player.pos.x += nudge


# Pixel direkt hinter der Vorderkante, auf der Mittellinie der Figur.
static func _lead_point(pos: Vector2i, dir: Vector2i) -> Vector2i:
	if dir.x > 0:
		return Vector2i(pos.x + CELL, pos.y + HALF)
	if dir.x < 0:
		return Vector2i(pos.x - 1, pos.y + HALF)
	if dir.y > 0:
		return Vector2i(pos.x + HALF, pos.y + CELL)
	return Vector2i(pos.x + HALF, pos.y - 1)


static func _cell_at(point: Vector2i) -> Vector2i:
	return Vector2i(floori(float(point.x) / CELL), floori(float(point.y) / CELL))
