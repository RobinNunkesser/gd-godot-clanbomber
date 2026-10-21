class_name SimMovementTest
extends GdUnitTestSuite

const CELL := 40


# Leeres Feld mit Rahmenwand; Spieler 1 steht auf der angegebenen Zelle.
func _world(start := Vector2i(5, 5)) -> SimWorld:
	var board := SimBoard.empty()
	for x in board.width:
		board.set_tile(Vector2i(x, 0), SimTile.Type.WALL)
		board.set_tile(Vector2i(x, board.height - 1), SimTile.Type.WALL)
	for y in board.height:
		board.set_tile(Vector2i(0, y), SimTile.Type.WALL)
		board.set_tile(Vector2i(board.width - 1, y), SimTile.Type.WALL)
	var world := SimWorld.new(board)
	world.add_player(1, start)
	return world


func _run(world: SimWorld, total_ms: int, step_ms := 10) -> void:
	var remaining := total_ms
	while remaining > 0:
		var dt := mini(step_ms, remaining)
		world.tick(dt)
		remaining -= dt


func test_cell_is_rounded_to_nearest_center() -> void:
	var player := SimPlayer.new()
	player.pos = Vector2i(139, 20)
	assert_that(player.cell).is_equal(Vector2i(3, 1))
	player.pos = Vector2i(140, 60)
	assert_that(player.cell).is_equal(Vector2i(4, 2))
	player.cell = Vector2i(4, 2)
	assert_that(player.pos).is_equal(Vector2i(160, 80))


func test_moves_at_base_speed() -> void:
	var world := _world()
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 1000)
	assert_int(world.players[1].pos.x - 5 * CELL).is_equal(90)
	assert_int(world.players[1].pos.y).is_equal(5 * CELL)


func test_speed_is_independent_of_tick_rate() -> void:
	var a := _world()
	var b := _world()
	a.set_move_dir(1, Vector2i.RIGHT)
	b.set_move_dir(1, Vector2i.RIGHT)
	_run(a, 1000, 7)
	_run(b, 1000, 33)
	assert_that(a.players[1].pos).is_equal(b.players[1].pos)
	assert_int(a.players[1].pos.x - 5 * CELL).is_equal(90)


func test_skateboards_increase_speed_up_to_five() -> void:
	var world := _world(Vector2i(1, 1))
	world.players[1].skateboards = 2
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 500)
	assert_int(world.players[1].pos.x - CELL).is_equal(130 / 2 * 1 + 20)
	world.players[1].skateboards = 9
	assert_int(world.players[1].speed()).is_equal(290)


func test_stops_flush_against_wall() -> void:
	var world := _world(Vector2i(1, 1))
	world.board.set_tile(Vector2i(4, 1), SimTile.Type.WALL)
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 5000)
	assert_that(world.players[1].pos).is_equal(Vector2i(3 * CELL, CELL))


func test_stops_flush_in_all_directions() -> void:
	var expected := {
		Vector2i.RIGHT: Vector2i(15 * CELL, 6 * CELL),
		Vector2i.LEFT: Vector2i(CELL, 6 * CELL),
		Vector2i.UP: Vector2i(8 * CELL, CELL),
		Vector2i.DOWN: Vector2i(8 * CELL, 11 * CELL),
	}
	for dir: Vector2i in expected:
		var world := _world(Vector2i(8, 6))
		world.set_move_dir(1, dir)
		_run(world, 20000, 50)
		assert_that(world.players[1].pos).is_equal(expected[dir])


func test_box_blocks_movement() -> void:
	var world := _world(Vector2i(1, 1))
	world.board.set_tile(Vector2i(2, 1), SimTile.Type.BOX)
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 1000)
	assert_that(world.players[1].pos).is_equal(Vector2i(CELL, CELL))


func test_ice_and_arrow_do_not_block() -> void:
	var world := _world(Vector2i(1, 1))
	world.board.set_tile(Vector2i(2, 1), SimTile.Type.ICE)
	world.board.set_tile(Vector2i(3, 1), SimTile.Type.ARROW_LEFT)
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 2000)
	assert_int(world.players[1].pos.x).is_greater(3 * CELL)


func test_corner_slide_pushes_upper_offset_into_lane() -> void:
	# 10 px unterhalb der Spurmitte, die Zelle vorn in der unteren Nachbarspur ist blockiert.
	var world := _world(Vector2i(1, 3))
	world.board.set_tile(Vector2i(3, 4), SimTile.Type.WALL)
	world.players[1].pos = Vector2i(CELL, 3 * CELL + 10)
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 600)
	assert_int(world.players[1].pos.y).is_equal(3 * CELL)
	assert_int(world.players[1].pos.x).is_greater(CELL + 20)


func test_corner_slide_pushes_lower_offset_into_lane() -> void:
	var world := _world(Vector2i(1, 3))
	world.board.set_tile(Vector2i(3, 3), SimTile.Type.WALL)
	world.players[1].pos = Vector2i(CELL, 3 * CELL + 25)
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 600)
	assert_int(world.players[1].pos.y).is_equal(4 * CELL)


func test_slides_into_gap_of_wall_column() -> void:
	var world := _world(Vector2i(1, 4))
	for y in range(1, 12):
		if y != 4:
			world.board.set_tile(Vector2i(3, y), SimTile.Type.WALL)
	world.players[1].pos = Vector2i(CELL, 4 * CELL - 12)
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 2000)
	assert_int(world.players[1].cell.y).is_equal(4)
	assert_int(world.players[1].pos.x).is_greater(4 * CELL)


func test_no_slide_when_centre_line_is_blocked() -> void:
	var world := _world(Vector2i(1, 4))
	for y in range(1, 12):
		world.board.set_tile(Vector2i(3, y), SimTile.Type.WALL)
	world.board.set_tile(Vector2i(3, 5), SimTile.Type.GROUND)
	world.players[1].pos = Vector2i(CELL, 4 * CELL + 8)
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 2000)
	assert_int(world.players[1].pos.x).is_less_equal(2 * CELL)


func test_vertical_corner_slide() -> void:
	var world := _world(Vector2i(3, 1))
	world.board.set_tile(Vector2i(4, 3), SimTile.Type.WALL)
	world.players[1].pos = Vector2i(3 * CELL + 10, CELL)
	world.set_move_dir(1, Vector2i.DOWN)
	_run(world, 600)
	assert_int(world.players[1].pos.x).is_equal(3 * CELL)
	assert_int(world.players[1].pos.y).is_greater(CELL + 20)


func test_can_leave_own_fresh_bomb_but_not_return() -> void:
	var world := _world(Vector2i(5, 5))
	world.place_bomb(1)
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 600)
	assert_int(world.players[1].cell.x).is_greater_equal(6)
	world.set_move_dir(1, Vector2i.LEFT)
	_run(world, 1000)
	assert_int(world.players[1].pos.x).is_equal(6 * CELL)
	assert_int(world.bombs.size()).is_equal(1)


func test_bomb_on_ahead_cell_blocks() -> void:
	var world := _world(Vector2i(5, 5))
	world.add_player(2, Vector2i(6, 5)).max_bombs = 1
	world.place_bomb(2)
	world.players[2].cell = Vector2i(9, 9)
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 1000)
	assert_that(world.players[1].pos).is_equal(Vector2i(5 * CELL, 5 * CELL))


func test_players_block_each_other_but_can_leave_shared_cell() -> void:
	var world := _world(Vector2i(5, 5))
	world.add_player(2, Vector2i(6, 5))
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 1000)
	assert_that(world.players[1].pos).is_equal(Vector2i(5 * CELL, 5 * CELL))
	world.players[2].cell = Vector2i(5, 5)
	_run(world, 1000)
	assert_int(world.players[1].pos.x).is_greater(5 * CELL)


func test_dead_player_does_not_move() -> void:
	var world := _world()
	world.players[1].alive = false
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 1000)
	assert_that(world.players[1].pos).is_equal(Vector2i(5 * CELL, 5 * CELL))


func test_diagonal_input_is_reduced_to_one_axis() -> void:
	var world := _world()
	world.set_move_dir(1, Vector2i(1, 1))
	_run(world, 1000)
	assert_int(world.players[1].pos.y).is_equal(5 * CELL)
	assert_int(world.players[1].pos.x).is_greater(5 * CELL)


func test_zero_direction_stops() -> void:
	var world := _world()
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 200)
	var stopped_at: Vector2i = world.players[1].pos
	world.set_move_dir(1, Vector2i.ZERO)
	_run(world, 1000)
	assert_that(world.players[1].pos).is_equal(stopped_at)


func test_cell_for_explosion_damage_uses_rounding() -> void:
	var world := _world(Vector2i(5, 5))
	var late := world.add_player(2, Vector2i(9, 9))
	var safe := world.add_player(3, Vector2i(9, 10))
	late.pos = Vector2i(7 * CELL - 21, 5 * CELL)
	safe.pos = Vector2i(7 * CELL - 20, 5 * CELL)
	world.players[1].cell = Vector2i(5, 5)
	world.players[1].power = 1
	world.place_bomb(1)
	world.players[1].cell = Vector2i(1, 1)
	world.tick(SimConstants.BOMB_COUNTDOWN_MS)
	assert_bool(late.alive).is_false()
	assert_bool(safe.alive).is_true()
