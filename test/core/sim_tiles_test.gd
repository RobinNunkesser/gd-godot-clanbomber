class_name SimTilesTest
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


func _bomb(world: SimWorld, cell: Vector2i) -> SimBomb:
	var helper := world.add_player(9, Vector2i(15, 11))
	helper.max_bombs = 9
	helper.cell = cell
	var bomb := world.place_bomb(9)
	bomb.timer_ms = 1000000
	helper.cell = Vector2i(15, 11)
	return bomb


func test_player_slides_on_ice_in_facing_direction() -> void:
	var world := _world()
	for x in range(3, 8):
		world.board.set_tile(Vector2i(x, 2), SimTile.Type.ICE)
	var p := world.add_player(1, Vector2i(3, 2))
	p.facing = Vector2i.RIGHT
	_run(world, 1000)
	assert_int(p.pos.x - 3 * CELL).is_equal(80)


func test_ice_adds_to_walking_speed_and_stops_at_wall() -> void:
	var world := _world()
	for x in range(1, 16):
		world.board.set_tile(Vector2i(x, 2), SimTile.Type.ICE)
	var p := world.add_player(1, Vector2i(2, 2))
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 1000)
	assert_int(p.pos.x - 2 * CELL).is_equal(170)
	world.set_move_dir(1, Vector2i.ZERO)
	_run(world, 10000)
	assert_that(p.pos).is_equal(Vector2i(15 * CELL, 2 * CELL))


func test_no_sliding_on_ground() -> void:
	var world := _world()
	var p := world.add_player(1, Vector2i(3, 2))
	p.facing = Vector2i.RIGHT
	_run(world, 1000)
	assert_that(p.pos).is_equal(Vector2i(3 * CELL, 2 * CELL))


func test_arrow_pushes_resting_bomb() -> void:
	var world := _world()
	world.board.set_tile(Vector2i(4, 2), SimTile.Type.ARROW_RIGHT)
	var bomb := _bomb(world, Vector2i(4, 2))
	_run(world, 6000)
	assert_that(bomb.pos).is_equal(Vector2i(15 * CELL, 2 * CELL))


func test_arrow_redirects_rolling_bomb_after_chill() -> void:
	var world := _world()
	world.board.set_tile(Vector2i(6, 2), SimTile.Type.ARROW_RIGHT)
	var p := world.add_player(1, Vector2i(2, 2))
	p.can_kick = true
	var bomb := _bomb(world, Vector2i(10, 2))
	bomb.pos = Vector2i(10 * CELL, 2 * CELL)
	world.kick_bomb(bomb, Vector2i.LEFT)
	_run(world, 1500)
	assert_int(bomb.pos.x).is_greater(6 * CELL)


func test_opposing_bomb_is_held_half_a_second_on_arrow() -> void:
	var world := _world()
	world.board.set_tile(Vector2i(6, 2), SimTile.Type.ARROW_RIGHT)
	var bomb := _bomb(world, Vector2i(9, 2))
	world.kick_bomb(bomb, Vector2i.LEFT)
	var held_at := -1
	for t in 300:
		world.tick(10)
		if held_at < 0 and bomb.cell == Vector2i(6, 2) and bomb.pos == Vector2i(6 * CELL, 2 * CELL):
			held_at = t
	assert_int(held_at).is_greater_equal(0)
	assert_int(bomb.pos.x).is_greater_equal(6 * CELL)


func test_arrow_redirects_perpendicular_bomb() -> void:
	var world := _world()
	world.board.set_tile(Vector2i(5, 5), SimTile.Type.ARROW_DOWN)
	var bomb := _bomb(world, Vector2i(5, 2))
	world.kick_bomb(bomb, Vector2i.DOWN)
	_run(world, 5000)
	assert_that(bomb.pos).is_equal(Vector2i(5 * CELL, 11 * CELL - 0))


func test_trap_holds_bomb_then_flies_and_detonates() -> void:
	var world := _world()
	world.board.set_tile(Vector2i(4, 2), SimTile.Type.TRAP)
	var bomb := _bomb(world, Vector2i(4, 2))
	world.tick(1)
	assert_bool(bomb.trapped).is_true()
	assert_that(world.bomb_at(Vector2i(4, 2))).is_null()
	var fuse := bomb.timer_ms
	_run(world, 900)
	assert_bool(bomb.trapped).is_true()
	assert_int(bomb.timer_ms).is_equal(fuse)
	_run(world, 200)
	assert_bool(bomb.trapped).is_false()
	assert_bool(bomb.trap_flight).is_true()
	var exploded: Array = []
	world.bomb_exploded.connect(func(b: SimBomb, _e: SimExplosion) -> void: exploded.append(b))
	_run(world, 6000)
	assert_array(exploded).contains([bomb])
	assert_bool(bomb in world.bombs).is_false()


func test_trapped_bomb_is_ignored_by_chain_reaction() -> void:
	var world := _world()
	world.board.set_tile(Vector2i(4, 2), SimTile.Type.TRAP)
	var bomb := _bomb(world, Vector2i(4, 2))
	world.tick(1)
	var other := _bomb(world, Vector2i(6, 2))
	other.timer_ms = 0
	world.tick(1)
	assert_bool(bomb in world.bombs).is_true()


func test_trap_target_is_passable_and_owner_gets_slot_back() -> void:
	var world := _world()
	world.board.set_tile(Vector2i(4, 2), SimTile.Type.TRAP)
	var owner := world.add_player(1, Vector2i(4, 2))
	var bomb := world.place_bomb(1)
	owner.cell = Vector2i(15, 11)
	_run(world, 1100)
	assert_bool(world.board.is_blocking(Vector2i(bomb.trap_to / CELL))).is_false()
	_run(world, 8000)
	assert_int(owner.active_bombs).is_equal(0)


func test_player_walks_into_hole_and_dies() -> void:
	var world := _world()
	world.board.set_tile(Vector2i(4, 2), SimTile.Type.HOLE)
	var player := world.add_player(1, Vector2i(3, 2))
	var falling_events: Array[int] = []
	world.player_falling.connect(func(pid: int) -> void: falling_events.append(pid))
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 500)
	assert_bool(player.is_falling()).is_true()
	assert_array(falling_events).contains([1])
	_run(world, 1010)
	assert_bool(player.alive).is_false()


func test_player_walks_into_none_and_dies() -> void:
	var world := _world()
	world.board.set_tile(Vector2i(4, 2), SimTile.Type.NONE)
	var player := world.add_player(1, Vector2i(3, 2))
	var falling_events: Array[int] = []
	world.player_falling.connect(func(pid: int) -> void: falling_events.append(pid))
	world.set_move_dir(1, Vector2i.RIGHT)
	_run(world, 500)
	assert_bool(player.is_falling()).is_true()
	assert_array(falling_events).contains([1])
	_run(world, 1010)
	assert_bool(player.alive).is_false()

