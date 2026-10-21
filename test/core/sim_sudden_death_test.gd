class_name SimSuddenDeathTest
extends GdUnitTestSuite


func _world() -> SimWorld:
	var board := SimBoard.empty()
	for x in board.width:
		board.set_tile(Vector2i(x, 0), SimTile.Type.WALL)
		board.set_tile(Vector2i(x, board.height - 1), SimTile.Type.WALL)
	for y in board.height:
		board.set_tile(Vector2i(0, y), SimTile.Type.WALL)
		board.set_tile(Vector2i(board.width - 1, y), SimTile.Type.WALL)
	return SimWorld.new(board)


func _run(world: SimWorld, total_ms: int, step_ms := 10) -> void:
	var remaining := total_ms
	while remaining > 0:
		var dt := mini(step_ms, remaining)
		world.tick(dt)
		remaining -= dt


func test_nothing_happens_before_round_time_is_over() -> void:
	var world := _world()
	world.add_player(1, Vector2i(2, 2))
	_run(world, SimConstants.ROUND_TIME_MS - 10)
	assert_bool(world.is_sudden_death()).is_false()
	assert_int(world.vanishing.size()).is_equal(0)


func test_announcement_comes_first_without_destruction() -> void:
	var world := _world()
	world.round_time_ms = 0
	var announced := [0]
	world.sudden_death_started.connect(func() -> void: announced[0] += 1)
	_run(world, 20)
	assert_int(announced[0]).is_equal(1)
	assert_int(world.vanishing.size()).is_equal(0)


func test_observer_lands_and_makes_a_tile_vanish() -> void:
	var world := _world()
	world.round_time_ms = 0
	var vanishing_cells: Array[Vector2i] = []
	world.tile_vanishing.connect(func(c: Vector2i) -> void: vanishing_cells.append(c))
	_run(world, 5000)
	assert_bool(world.is_sudden_death()).is_true()
	# Ein Flug über das ganze Feld dauert höchstens ca. 0,7 s; Wände zählen als Landeziel, erzeugen aber kein Loch.
	var changed := 0
	for y in world.board.height:
		for x in world.board.width:
			var tile := world.board.get_tile(Vector2i(x, y))
			if tile == SimTile.Type.NONE or tile == SimTile.Type.VANISHING:
				changed += 1
	assert_int(changed).is_greater(0)
	assert_int(vanishing_cells.size()).is_greater(0)


func test_ground_becomes_hole_after_one_second() -> void:
	var world := _world()
	var cell := Vector2i(5, 5)
	world.vanish_tile(cell)
	assert_int(world.board.get_tile(cell)).is_equal(SimTile.Type.VANISHING)
	assert_bool(world.board.is_blocking(cell)).is_true()
	_run(world, 990)
	assert_int(world.board.get_tile(cell)).is_equal(SimTile.Type.VANISHING)
	_run(world, 20)
	assert_int(world.board.get_tile(cell)).is_equal(SimTile.Type.NONE)


func test_wall_vanishes_into_ground_and_box_breaks() -> void:
	var world := _world()
	world.board.set_tile(Vector2i(4, 4), SimTile.Type.BOX)
	var broken: Array[Vector2i] = []
	world.box_destroyed.connect(func(c: Vector2i) -> void: broken.append(c))
	world.vanish_tile(Vector2i(0, 0))
	world.vanish_tile(Vector2i(4, 4))
	world.tick(10)
	assert_int(world.board.get_tile(Vector2i(0, 0))).is_equal(SimTile.Type.GROUND)
	assert_int(world.board.get_tile(Vector2i(4, 4))).is_equal(SimTile.Type.GROUND)
	assert_array(broken).contains([Vector2i(4, 4)])


func test_player_on_hole_falls_and_dies_after_one_second() -> void:
	var world := _world()
	var player := world.add_player(1, Vector2i(5, 5))
	var deaths := [0]
	world.player_died.connect(func(_id: int, killer: int) -> void:
		assert_int(killer).is_equal(-1)
		deaths[0] += 1)
	world.vanish_tile(Vector2i(5, 5))
	_run(world, 1000)
	assert_bool(player.alive).is_true()
	assert_bool(player.is_falling()).is_true()
	_run(world, 1010)
	assert_bool(player.alive).is_false()
	assert_int(deaths[0]).is_equal(1)


func test_player_can_step_off_a_vanishing_tile_in_time() -> void:
	var world := _world()
	var player := world.add_player(1, Vector2i(5, 5))
	world.vanish_tile(Vector2i(5, 5))
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 600)
	assert_vector(Vector2(player.cell)).is_equal(Vector2(6, 5))
	_run(world, 1500)
	assert_bool(player.alive).is_true()
	assert_bool(player.is_falling()).is_false()


func test_falling_player_cannot_move() -> void:
	var world := _world()
	var player := world.add_player(1, Vector2i(5, 5))
	world.board.set_tile(Vector2i(5, 5), SimTile.Type.NONE)
	world.tick(10)
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 200)
	assert_vector(Vector2(player.cell)).is_equal(Vector2(5, 5))


func test_bomb_on_hole_disappears_without_exploding() -> void:
	var world := _world()
	var owner := world.add_player(1, Vector2i(2, 2))
	owner.cell = Vector2i(5, 5)
	var bomb := world.place_bomb(1)
	owner.cell = Vector2i(2, 2)
	var exploded := [0]
	world.bomb_exploded.connect(func(_b: SimBomb, _e: SimExplosion) -> void: exploded[0] += 1)
	world.vanish_tile(Vector2i(5, 5))
	_run(world, 1100)
	assert_array(world.bombs).is_empty()
	assert_int(exploded[0]).is_equal(0)
	assert_int(owner.active_bombs).is_equal(0)
	assert_object(bomb).is_not_null()


func test_extra_on_vanishing_tile_moves_away() -> void:
	var world := _world()
	var cell := Vector2i(5, 5)
	world.extras[cell] = SimExtra.Type.POWER
	world.vanish_tile(cell)
	assert_bool(world.extras.has(cell)).is_false()
	assert_int(world.extras.size()).is_equal(1)


func test_observer_never_targets_holes() -> void:
	var world := _world()
	for x in world.board.width:
		for y in world.board.height:
			world.board.set_tile(Vector2i(x, y), SimTile.Type.NONE)
	world.board.set_tile(Vector2i(3, 3), SimTile.Type.GROUND)
	assert_vector(Vector2(world.random_vanishable_cell())).is_equal(Vector2(3, 3))
	world.board.set_tile(Vector2i(3, 3), SimTile.Type.VANISHING)
	assert_vector(Vector2(world.random_vanishable_cell())).is_equal(Vector2(-1, -1))
