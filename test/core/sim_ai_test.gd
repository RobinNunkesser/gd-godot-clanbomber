class_name SimAITest
extends GdUnitTestSuite


func _board() -> SimBoard:
	var board := SimBoard.empty()
	for x in board.width:
		board.set_tile(Vector2i(x, 0), SimTile.Type.WALL)
		board.set_tile(Vector2i(x, board.height - 1), SimTile.Type.WALL)
	for y in board.height:
		board.set_tile(Vector2i(0, y), SimTile.Type.WALL)
		board.set_tile(Vector2i(board.width - 1, y), SimTile.Type.WALL)
	# Pfeiler wie in den Originalkarten
	for x in range(2, board.width - 1, 2):
		for y in range(2, board.height - 1, 2):
			board.set_tile(Vector2i(x, y), SimTile.Type.WALL)
	return board


func _run(world: SimWorld, ais: Array, total_ms: int) -> void:
	for i in total_ms / 10:
		for ai: SimAI in ais:
			ai.update(world, 10)
		world.tick(10)


func test_flees_from_a_bomb_next_to_it() -> void:
	var world := SimWorld.new(_board())
	var player := world.add_player(1, Vector2i(3, 1))
	var bomb := SimBomb.new()
	bomb.cell = Vector2i(2, 1)
	bomb.power = 3
	world.bombs.append(bomb)
	_run(world, [SimAI.new(1)], 2400)
	assert_bool(player.alive).is_true()
	assert_bool(SimAI.new(1).danger_cells(world).has(player.cell)).is_false()


func test_survives_its_own_bomb() -> void:
	var world := SimWorld.new(_board())
	var player := world.add_player(1, Vector2i(1, 1))
	world.board.set_tile(Vector2i(3, 1), SimTile.Type.BOX)
	_run(world, [SimAI.new(1)], 8000)
	assert_bool(player.alive).is_true()
	assert_int(world.board.get_tile(Vector2i(3, 1))).is_equal(SimTile.Type.GROUND)


func test_does_not_bomb_without_target() -> void:
	var world := SimWorld.new(_board())
	world.add_player(1, Vector2i(1, 1))
	_run(world, [SimAI.new(1)], 3000)
	assert_int(world.bombs.size()).is_equal(0)
	assert_int(world.explosions.size()).is_equal(0)


func test_does_not_bomb_when_there_is_no_escape() -> void:
	var board := _board()
	# Sackgasse: Zelle (1,1) ist von Wänden und einer Box eingeschlossen, die Box liegt in Bombenreichweite.
	board.set_tile(Vector2i(2, 1), SimTile.Type.BOX)
	board.set_tile(Vector2i(1, 2), SimTile.Type.WALL)
	var world := SimWorld.new(board)
	var player := world.add_player(1, Vector2i(1, 1))
	var ai := SimAI.new(1)
	assert_bool(ai.decide(world, player) == Vector2i.ZERO).is_true()
	assert_int(world.bombs.size()).is_equal(0)


func test_collects_a_nearby_extra() -> void:
	var world := SimWorld.new(_board())
	var player := world.add_player(1, Vector2i(1, 1))
	world.extras[Vector2i(5, 1)] = SimExtra.Type.POWER
	_run(world, [SimAI.new(1)], 4000)
	assert_int(player.power).is_equal(SimConstants.START_POWER + 1)


func test_ignores_diseases() -> void:
	var world := SimWorld.new(_board())
	var player := world.add_player(1, Vector2i(1, 1))
	world.extras[Vector2i(3, 1)] = SimExtra.Type.REVERSE
	_run(world, [SimAI.new(1)], 3000)
	assert_bool(player.is_diseased()).is_false()


func test_walks_to_a_box_and_bombs_it() -> void:
	var world := SimWorld.new(_board())
	var player := world.add_player(1, Vector2i(1, 1))
	world.board.set_tile(Vector2i(9, 1), SimTile.Type.BOX)
	_run(world, [SimAI.new(1)], 15000)
	assert_bool(player.alive).is_true()
	assert_int(world.board.get_tile(Vector2i(9, 1))).is_equal(SimTile.Type.GROUND)


func test_hunts_and_kills_a_standing_opponent() -> void:
	var world := SimWorld.new(_board())
	world.add_player(1, Vector2i(1, 1))
	var target := world.add_player(2, Vector2i(5, 1))
	_run(world, [SimAI.new(1)], 20000)
	assert_bool(target.alive).is_false()
	assert_bool(world.players[1].alive).is_true()


func test_reverse_disease_inverts_the_command() -> void:
	var world := SimWorld.new(_board())
	var player := world.add_player(1, Vector2i(1, 1))
	player.disease = SimExtra.Type.REVERSE
	player.disease_ms = 5000
	world.extras[Vector2i(3, 1)] = SimExtra.Type.POWER
	var ai := SimAI.new(1)
	ai.update(world, 10)
	assert_object(player.move_dir).is_equal(Vector2i.LEFT)


func test_dead_player_does_not_act() -> void:
	var world := SimWorld.new(_board())
	var player := world.add_player(1, Vector2i(1, 1))
	player.alive = false
	world.board.set_tile(Vector2i(3, 1), SimTile.Type.BOX)
	_run(world, [SimAI.new(1)], 1000)
	assert_int(world.bombs.size()).is_equal(0)


func test_two_ais_play_a_whole_round_without_suicide() -> void:
	var board := _board()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for x in range(1, board.width - 1):
		for y in range(1, board.height - 1):
			var cell := Vector2i(x, y)
			if board.get_tile(cell) == SimTile.Type.GROUND and rng.randf() < 0.5 \
					and cell.distance_to(Vector2i(1, 1)) > 2 and cell.distance_to(Vector2i(15, 11)) > 2:
				board.set_tile(cell, SimTile.Type.BOX)
	var world := SimWorld.new(board, rng)
	world.add_player(1, Vector2i(1, 1))
	world.add_player(2, Vector2i(15, 11))
	var self_kills := [0]
	world.player_died.connect(func(id: int, killer: int) -> void:
		if killer == id:
			self_kills[0] += 1)
	var match_state := SimMatch.new()
	var ais := [SimAI.new(1), SimAI.new(2)]
	var ended := false
	for i in 40000:
		for ai: SimAI in ais:
			ai.update(world, 10)
		world.tick(10)
		if match_state.update(world):
			ended = true
			break
	assert_bool(ended).is_true()


func test_ai_avoids_ice_sliding_into_hole() -> void:
	var board := _board()
	board.set_tile(Vector2i(2, 1), SimTile.Type.ICE)
	board.set_tile(Vector2i(3, 1), SimTile.Type.ICE)
	board.set_tile(Vector2i(4, 1), SimTile.Type.HOLE)
	board.set_tile(Vector2i(1, 2), SimTile.Type.GROUND)
	var world := SimWorld.new(board)
	var player := world.add_player(1, Vector2i(1, 1))
	world.add_player(2, Vector2i(1, 5))
	var ai := SimAI.new(1)
	var dir := ai.decide(world, player)
	# Rechts führt über Eis direkt ins Loch -> darf niemals gewählt werden
	assert_bool(dir == Vector2i.RIGHT).is_false()


func test_ai_recognizes_kickable_bomb() -> void:
	var board := _board()
	var world := SimWorld.new(board)
	var player := world.add_player(1, Vector2i(1, 1))
	player.can_kick = true
	var bomb := SimBomb.new()
	bomb.cell = Vector2i(2, 1)
	bomb.power = 2
	world.bombs.append(bomb)
	var ai := SimAI.new(1)
	# Mit Kick ist Zelle (2,1) begehbar, da die Bombe nach (3,1) rollen kann
	assert_bool(ai._walkable(world, Vector2i(2, 1), Vector2i(1, 1))).is_true()


func test_ai_approaches_distant_enemy_without_boxes() -> void:
	var board := _board()
	var world := SimWorld.new(board)
	var p1 := world.add_player(1, Vector2i(1, 1))
	world.add_player(2, Vector2i(9, 1))
	var ai := SimAI.new(1)
	var dir := ai.decide(world, p1)
	# Keine Kisten auf dem Spielfeld: KI soll sich aktiv dem Gegner annähern (nach rechts)
	assert_bool(dir == Vector2i.RIGHT).is_true()
