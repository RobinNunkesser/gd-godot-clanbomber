class_name ArenaView
extends Node2D
## Platzhalter-Präsentation in 2D-Draufsicht. Liest nur den Zustand der Simulation.

const CELL := int(SimConstants.CELL_SIZE)
const PLAYER_COLORS: Array[Color] = [
	Color("e8504a"), Color("4a90e8"), Color("5bc45b"), Color("e8c84a"),
	Color("b06ae0"), Color("e88a4a"), Color("4ac8c8"), Color("d0d0d0"),
]
const EXTRA_COLORS := {
	SimExtra.Type.POWER: Color("ff7043"), SimExtra.Type.BOMB: Color("90a4ae"),
	SimExtra.Type.SKATEBOARD: Color("66bb6a"), SimExtra.Type.KICK: Color("42a5f5"),
	SimExtra.Type.GLOVE: Color("ab47bc"), SimExtra.Type.OVERDRIVE: Color("ffee58"),
	SimExtra.Type.REVERSE: Color("8d6e63"), SimExtra.Type.AUTOBOMB: Color("ec407a"),
}

var world: SimWorld


func _draw() -> void:
	if world == null:
		return
	_draw_board()
	for cell: Vector2i in world.extras:
		var c: Color = EXTRA_COLORS.get(world.extras[cell], Color.WHITE)
		draw_circle(_center(cell), 12.0, c)
	for bomb in world.bombs:
		var pulse := 1.0 + 0.1 * sin(bomb.timer_ms * 0.02)
		draw_circle(_center(bomb.cell), 14.0 * pulse, Color("212121"))
		draw_circle(_center(bomb.cell) + Vector2(-4, -4), 3.0, Color("757575"))
	for explosion in world.explosions:
		for cell in explosion.cells:
			draw_rect(Rect2(Vector2(cell * CELL) + Vector2(4, 4), Vector2(CELL - 8, CELL - 8)), Color(1.0, 0.65, 0.1, 0.9))
	for id: int in world.players:
		var player: SimPlayer = world.players[id]
		if not player.alive:
			continue
		var rect := Rect2(Vector2(player.pos) + Vector2(4, 4), Vector2(CELL - 8, CELL - 8))
		draw_rect(rect, PLAYER_COLORS[(id - 1) % PLAYER_COLORS.size()])
		draw_rect(rect, Color.BLACK, false, 2.0)
		if player.is_diseased():
			draw_rect(rect.grow(3), EXTRA_COLORS[player.disease], false, 3.0)


func _draw_board() -> void:
	for y in world.board.height:
		for x in world.board.width:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell * CELL), Vector2(CELL, CELL))
			var tile := world.board.get_tile(cell)
			match tile:
				SimTile.Type.NONE:
					continue
				SimTile.Type.WALL:
					draw_rect(rect, Color("455a64"))
					draw_rect(rect, Color("263238"), false, 2.0)
				SimTile.Type.BOX:
					draw_rect(rect, Color("a1887f"))
					draw_rect(rect.grow(-6), Color("8d6e63"))
				_:
					draw_rect(rect, Color("c5e1a5") if (x + y) % 2 == 0 else Color("b5d395"))
					_draw_floor_marker(tile, rect)


func _draw_floor_marker(tile: int, rect: Rect2) -> void:
	var c := rect.get_center()
	match tile:
		SimTile.Type.ICE:
			draw_rect(rect, Color(0.7, 0.9, 1.0, 0.7))
		SimTile.Type.TRAP:
			draw_circle(c, 14.0, Color("3e2723"))
		SimTile.Type.ARROW_LEFT:
			draw_colored_polygon([c + Vector2(-12, 0), c + Vector2(8, -12), c + Vector2(8, 12)], Color("5d4037"))
		SimTile.Type.ARROW_RIGHT:
			draw_colored_polygon([c + Vector2(12, 0), c + Vector2(-8, -12), c + Vector2(-8, 12)], Color("5d4037"))
		SimTile.Type.ARROW_UP:
			draw_colored_polygon([c + Vector2(0, -12), c + Vector2(-12, 8), c + Vector2(12, 8)], Color("5d4037"))
		SimTile.Type.ARROW_DOWN:
			draw_colored_polygon([c + Vector2(0, 12), c + Vector2(-12, -8), c + Vector2(12, -8)], Color("5d4037"))


func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL) + Vector2(CELL, CELL) / 2.0
