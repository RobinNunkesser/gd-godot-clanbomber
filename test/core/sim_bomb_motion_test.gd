class_name SimBombMotionTest
extends GdUnitTestSuite

const CELL := 40


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


# Legt eine Bombe von einem Hilfsspieler (Id 9) auf die Zelle; langer Zünder, damit sie nicht explodiert.
func _bomb(world: SimWorld, cell: Vector2i) -> SimBomb:
	var helper := world.add_player(9, cell)
	helper.max_bombs = 5
	var bomb := world.place_bomb(9)
	bomb.timer_ms = 1000000
	helper.cell = Vector2i(15, 11)
	return bomb


func test_kick_rolls_bomb_until_wall_and_snaps() -> void:
	var world := _world()
	var p := world.add_player(1, Vector2i(2, 2))
	p.can_kick = true
	var bomb := _bomb(world, Vector2i(4, 2))
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 1000)
	assert_int(bomb.pos.x).is_greater(5 * CELL)
	assert_bool(bomb.move_dir != Vector2i.ZERO).is_true()
	_run(world, 5000)
	assert_that(bomb.pos).is_equal(Vector2i(15 * CELL, 2 * CELL))
	assert_that(bomb.move_dir).is_equal(Vector2i.ZERO)


func test_bomb_moves_at_bomb_speed() -> void:
	var world := _world()
	var p := world.add_player(1, Vector2i(2, 2))
	p.can_kick = true
	var bomb := _bomb(world, Vector2i(4, 2))
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 600)
	var x0 := bomb.pos.x
	_run(world, 500)
	assert_int(bomb.pos.x - x0).is_equal(80)


func test_no_kick_without_extra() -> void:
	var world := _world()
	world.add_player(1, Vector2i(2, 2))
	var bomb := _bomb(world, Vector2i(4, 2))
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 3000)
	assert_that(bomb.pos).is_equal(Vector2i(4 * CELL, 2 * CELL))
	assert_that(world.players[1].pos).is_equal(Vector2i(3 * CELL, 2 * CELL))


func test_kicked_bomb_stops_before_box_and_bomb_and_player() -> void:
	var blockers := {"box": Vector2i(8, 2), "bomb": Vector2i(8, 2), "player": Vector2i(8, 2)}
	for kind: String in blockers:
		var world := _world()
		var p := world.add_player(1, Vector2i(2, 2))
		p.can_kick = true
		var bomb := _bomb(world, Vector2i(4, 2))
		match kind:
			"box":
				world.board.set_tile(Vector2i(8, 2), SimTile.Type.BOX)
			"bomb":
				_bomb(world, Vector2i(8, 2))
			"player":
				world.add_player(5, Vector2i(8, 2))
		world.set_move_dir(1, Vector2i.RIGHT)
		_run(world, 4000)
		assert_that(bomb.pos).is_equal(Vector2i(7 * CELL, 2 * CELL))


func test_kick_works_in_all_directions() -> void:
	var dirs := {Vector2i.LEFT: Vector2i(1, 6), Vector2i.UP: Vector2i(8, 1), Vector2i.DOWN: Vector2i(8, 11)}
	for dir: Vector2i in dirs:
		var world := _world()
		var start := Vector2i(8, 6)
		var p := world.add_player(1, start - dir * 2)
		p.can_kick = true
		var bomb := _bomb(world, start)
		world.set_move_dir(1, dir)
		_run(world, 8000)
		assert_that(bomb.cell).is_equal(dirs[dir])


func test_throw_flies_four_cells_with_frozen_fuse() -> void:
	var world := _world()
	var p := world.add_player(1, Vector2i(2, 2))
	p.can_glove = true
	p.facing = Vector2i.RIGHT
	var bomb := world.action_bomb(1)
	assert_that(bomb).is_not_null()
	var fuse := bomb.timer_ms
	assert_that(world.action_bomb(1)).is_null()
	assert_bool(bomb.flying).is_true()
	assert_that(world.bomb_at(Vector2i(2, 2))).is_null()
	_run(world, 500)
	assert_bool(bomb.flying).is_true()
	assert_int(bomb.timer_ms).is_equal(fuse)
	_run(world, 600)
	assert_bool(bomb.flying).is_false()
	assert_that(bomb.pos).is_equal(Vector2i(6 * CELL, 2 * CELL))
	assert_int(bomb.timer_ms).is_less(fuse)


func test_throw_needs_glove_and_standing_still() -> void:
	var world := _world()
	var p := world.add_player(1, Vector2i(2, 2))
	p.facing = Vector2i.RIGHT
	var bomb := world.action_bomb(1)
	world.action_bomb(1)
	assert_bool(bomb.flying).is_false()
	p.can_glove = true
	p.moved = true
	world.action_bomb(1)
	assert_bool(bomb.flying).is_false()
	p.moved = false
	world.action_bomb(1)
	assert_bool(bomb.flying).is_true()


func test_throw_stops_before_wall_and_box() -> void:
	var world := _world()
	var p := world.add_player(1, Vector2i(13, 2))
	p.can_glove = true
	p.facing = Vector2i.RIGHT
	var bomb := world.action_bomb(1)
	world.action_bomb(1)
	_run(world, 2000)
	assert_that(bomb.cell).is_equal(Vector2i(15, 2))
	var world2 := _world()
	var p2 := world2.add_player(1, Vector2i(2, 2))
	p2.can_glove = true
	p2.facing = Vector2i.RIGHT
	world2.board.set_tile(Vector2i(4, 2), SimTile.Type.BOX)
	var bomb2 := world2.action_bomb(1)
	world2.action_bomb(1)
	_run(world2, 2000)
	assert_that(bomb2.cell).is_equal(Vector2i(3, 2))


func test_throw_into_adjacent_wall_does_nothing() -> void:
	var world := _world()
	var p := world.add_player(1, Vector2i(15, 2))
	p.can_glove = true
	p.facing = Vector2i.RIGHT
	var bomb := world.action_bomb(1)
	world.action_bomb(1)
	assert_bool(bomb.flying).is_false()


func test_thrown_bomb_hops_over_occupied_landing_cell() -> void:
	var world := _world()
	var p := world.add_player(1, Vector2i(2, 2))
	p.can_glove = true
	p.facing = Vector2i.RIGHT
	_bomb(world, Vector2i(6, 2))
	var bomb := world.action_bomb(1)
	world.action_bomb(1)
	_run(world, 1500)
	assert_that(bomb.cell).is_equal(Vector2i(7, 2))
	assert_bool(bomb.flying).is_false()


func test_flying_bomb_is_not_chain_detonated_or_blocking() -> void:
	var world := _world()
	var p := world.add_player(1, Vector2i(2, 2))
	p.can_glove = true
	p.facing = Vector2i.RIGHT
	var bomb := world.action_bomb(1)
	world.action_bomb(1)
	var other := _bomb(world, Vector2i(3, 2))
	other.timer_ms = 0
	world.tick(1)
	assert_bool(bomb in world.bombs).is_true()
	assert_bool(bomb.flying).is_true()
