class_name SimExtraPickupTest
extends GdUnitTestSuite


func _world() -> SimWorld:
	var board := SimBoard.empty()
	for x in board.width:
		board.set_tile(Vector2i(x, 0), SimTile.Type.WALL)
		board.set_tile(Vector2i(x, board.height - 1), SimTile.Type.WALL)
	for y in board.height:
		board.set_tile(Vector2i(0, y), SimTile.Type.WALL)
		board.set_tile(Vector2i(board.width - 1, y), SimTile.Type.WALL)
	var world := SimWorld.new(board)
	world.add_player(1, Vector2i(2, 2))
	return world


func _give(world: SimWorld, type: int, cell := Vector2i(2, 2)) -> void:
	world.extras[cell] = type
	world.tick(1)


func test_basic_extras_apply_and_are_consumed() -> void:
	var world := _world()
	var p: SimPlayer = world.players[1]
	_give(world, SimExtra.Type.BOMB)
	_give(world, SimExtra.Type.POWER)
	_give(world, SimExtra.Type.SKATEBOARD)
	_give(world, SimExtra.Type.KICK)
	_give(world, SimExtra.Type.GLOVE)
	assert_int(p.max_bombs).is_equal(SimConstants.START_BOMBS + 1)
	assert_int(p.power).is_equal(SimConstants.START_POWER + 1)
	assert_int(p.skateboards).is_equal(1)
	assert_bool(p.can_kick).is_true()
	assert_bool(p.can_glove).is_true()
	assert_bool(world.extras.is_empty()).is_true()


func test_extras_are_capped() -> void:
	var world := _world()
	var p: SimPlayer = world.players[1]
	p.max_bombs = SimConstants.MAX_BOMBS
	p.power = SimConstants.MAX_POWER
	p.skateboards = SimConstants.MAX_SKATEBOARDS
	_give(world, SimExtra.Type.BOMB)
	_give(world, SimExtra.Type.POWER)
	_give(world, SimExtra.Type.SKATEBOARD)
	assert_int(p.max_bombs).is_equal(SimConstants.MAX_BOMBS)
	assert_int(p.power).is_equal(SimConstants.MAX_POWER)
	assert_int(p.skateboards).is_equal(SimConstants.MAX_SKATEBOARDS)


func test_pickup_signal_and_walking_onto_extra() -> void:
	var world := _world()
	world.extras[Vector2i(3, 2)] = SimExtra.Type.POWER
	var seen: Array = []
	world.extra_collected.connect(func(id: int, type: int) -> void: seen.append([id, type]))
	world.set_move_dir(1, Vector2i.RIGHT)
	for i in 100:
		world.tick(10)
	assert_array(seen).is_equal([[1, SimExtra.Type.POWER]])


func test_dead_player_does_not_collect() -> void:
	var world := _world()
	world.players[1].alive = false
	_give(world, SimExtra.Type.POWER)
	assert_bool(world.extras.has(Vector2i(2, 2))).is_true()


func test_overdrive_adds_speed_and_expires() -> void:
	var world := _world()
	var p: SimPlayer = world.players[1]
	_give(world, SimExtra.Type.OVERDRIVE)
	assert_int(p.speed()).is_equal(90 + 600)
	world.tick(SimConstants.DISEASE_DURATION_MS)
	assert_bool(p.is_diseased()).is_false()
	assert_int(p.speed()).is_equal(90)


func test_reverse_inverts_direction() -> void:
	var world := _world()
	_give(world, SimExtra.Type.REVERSE)
	var start: Vector2i = world.players[1].pos
	world.set_move_dir(1, Vector2i.RIGHT)
	for i in 20:
		world.tick(10)
	assert_int(world.players[1].pos.x).is_less(start.x)


func test_autobomb_places_bombs_whenever_possible() -> void:
	var world := _world()
	_give(world, SimExtra.Type.AUTOBOMB)
	assert_int(world.bombs.size()).is_equal(1)
	world.tick(SimConstants.BOMB_COUNTDOWN_MS)
	assert_bool(world.players[1].alive).is_false()


func test_any_pickup_cures_and_respawns_disease_extra() -> void:
	var world := _world()
	var p: SimPlayer = world.players[1]
	_give(world, SimExtra.Type.REVERSE)
	assert_int(p.disease).is_equal(SimExtra.Type.REVERSE)
	_give(world, SimExtra.Type.POWER)
	assert_bool(p.is_diseased()).is_false()
	assert_int(p.power).is_equal(SimConstants.START_POWER + 1)
	assert_int(world.extras.size()).is_equal(1)
	assert_int(world.extras.values()[0]).is_equal(SimExtra.Type.REVERSE)


func test_new_disease_replaces_old_and_respawns_old_extra() -> void:
	var world := _world()
	var p: SimPlayer = world.players[1]
	_give(world, SimExtra.Type.REVERSE)
	_give(world, SimExtra.Type.OVERDRIVE)
	assert_int(p.disease).is_equal(SimExtra.Type.OVERDRIVE)
	assert_array(world.extras.values()).is_equal([SimExtra.Type.REVERSE])


func test_disease_spreads_on_contact() -> void:
	var world := _world()
	var other := world.add_player(2, Vector2i(2, 2))
	_give(world, SimExtra.Type.OVERDRIVE, Vector2i(5, 5))
	world.players[1].disease = SimExtra.Type.OVERDRIVE
	world.players[1].disease_ms = 5000
	world.tick(1)
	assert_int(other.disease).is_equal(SimExtra.Type.OVERDRIVE)
	assert_int(other.disease_ms).is_greater_equal(SimConstants.DISEASE_DURATION_MS - 1)


func test_death_drops_only_collected_extras() -> void:
	var world := _world()
	var p: SimPlayer = world.players[1]
	p.power = 3
	_give(world, SimExtra.Type.POWER)
	_give(world, SimExtra.Type.KICK)
	var other := world.add_player(2, Vector2i(9, 9))
	other.power = 1
	world.players[1].cell = Vector2i(8, 9)
	world.place_bomb(1)
	world.players[1].cell = Vector2i(9, 9)
	world.players[1].power = 1
	world.tick(SimConstants.BOMB_COUNTDOWN_MS)
	assert_bool(p.alive).is_false()
	assert_int(world.extras.size()).is_equal(2)
	var types: Array = world.extras.values()
	types.sort()
	assert_array(types).is_equal([SimExtra.Type.POWER, SimExtra.Type.KICK])
	assert_int(p.extra_power).is_equal(0)
