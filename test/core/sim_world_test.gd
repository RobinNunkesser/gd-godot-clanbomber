class_name SimWorldTest
extends GdUnitTestSuite

const ORIGIN := Vector2i(5, 5)


func _world(power := 1, max_bombs := 1) -> SimWorld:
	var world := SimWorld.new(SimBoard.empty())
	var player := world.add_player(1, ORIGIN)
	player.power = power
	player.max_bombs = max_bombs
	return world


func _explode_all(world: SimWorld) -> void:
	world.tick(SimConstants.BOMB_COUNTDOWN_MS)


func test_power_two_in_open_field_reaches_two_cells_each_way() -> void:
	var world := _world(2)
	world.place_bomb(1)
	_explode_all(world)
	var cells := world.explosions[0].cells
	assert_int(cells.size()).is_equal(9)
	for expected in [Vector2i(5, 3), Vector2i(5, 7), Vector2i(3, 5), Vector2i(7, 5), ORIGIN]:
		assert_bool(expected in cells).is_true()


func test_ray_clipped_at_board_edge() -> void:
	var world := SimWorld.new(SimBoard.empty())
	world.add_player(1, Vector2i(0, 0)).power = 3
	world.place_bomb(1)
	_explode_all(world)
	assert_int(world.explosions[0].cells.size()).is_equal(1 + 3 + 3)


func test_wall_stops_ray_and_survives() -> void:
	var world := _world(3)
	world.board.set_tile(Vector2i(6, 5), SimTile.Type.WALL)
	world.place_bomb(1)
	_explode_all(world)
	assert_bool(Vector2i(6, 5) in world.explosions[0].cells).is_false()
	assert_bool(Vector2i(7, 5) in world.explosions[0].cells).is_false()
	assert_int(world.board.get_tile(Vector2i(6, 5))).is_equal(SimTile.Type.WALL)


func test_box_at_end_destroyed_but_box_behind_survives() -> void:
	var world := _world(3)
	world.board.set_tile(Vector2i(5, 3), SimTile.Type.BOX)
	world.board.set_tile(Vector2i(5, 2), SimTile.Type.BOX)
	var destroyed: Array[Vector2i] = []
	world.box_destroyed.connect(func(cell: Vector2i) -> void: destroyed.append(cell))
	world.place_bomb(1)
	_explode_all(world)
	assert_bool(Vector2i(5, 4) in world.explosions[0].cells).is_true()
	assert_bool(Vector2i(5, 3) in world.explosions[0].cells).is_false()
	assert_array(destroyed).is_equal([Vector2i(5, 3)])
	assert_int(world.board.get_tile(Vector2i(5, 3))).is_equal(SimTile.Type.GROUND)
	assert_int(world.board.get_tile(Vector2i(5, 2))).is_equal(SimTile.Type.BOX)


func test_box_exactly_at_power_distance_is_destroyed() -> void:
	var world := _world(2)
	world.board.set_tile(Vector2i(5, 3), SimTile.Type.BOX)
	world.place_bomb(1)
	_explode_all(world)
	assert_int(world.board.get_tile(Vector2i(5, 3))).is_equal(SimTile.Type.GROUND)


func test_box_beyond_power_distance_untouched() -> void:
	var world := _world(1)
	world.board.set_tile(Vector2i(5, 3), SimTile.Type.BOX)
	world.place_bomb(1)
	_explode_all(world)
	assert_int(world.board.get_tile(Vector2i(5, 3))).is_equal(SimTile.Type.BOX)


func test_extra_blocks_ray_and_is_destroyed_at_end() -> void:
	var world := _world(3)
	world.extras[Vector2i(5, 4)] = SimExtra.Type.POWER
	world.extras[Vector2i(7, 5)] = SimExtra.Type.BOMB
	world.place_bomb(1)
	_explode_all(world)
	var cells := world.explosions[0].cells
	assert_bool(Vector2i(5, 4) in cells).is_false()
	assert_bool(Vector2i(6, 5) in cells).is_true()
	assert_bool(Vector2i(7, 5) in cells).is_false()
	assert_dict(world.extras).is_empty()


func test_chain_reaction_delays_by_chain_delay() -> void:
	var world := _world(2, 2)
	world.place_bomb(1)
	world.tick(1000)
	world.players[1].cell = Vector2i(7, 5)
	world.place_bomb(1)
	world.tick(1500)
	assert_int(world.bombs.size()).is_equal(1)
	assert_int(world.bombs[0].timer_ms).is_equal(SimConstants.BOMB_CHAIN_DELAY_MS)
	world.tick(SimConstants.BOMB_CHAIN_DELAY_MS - 1)
	assert_int(world.bombs.size()).is_equal(1)
	world.tick(1)
	assert_int(world.bombs.size()).is_equal(0)


func test_chain_keeps_shorter_remaining_timer() -> void:
	var world := _world(2, 2)
	world.place_bomb(1)
	world.tick(2400)
	world.players[1].cell = Vector2i(6, 5)
	world.bombs[0].timer_ms = 100
	var other := world.place_bomb(1)
	other.timer_ms = 50
	world.tick(100)
	assert_int(world.bombs.size()).is_equal(0)


func test_victim_in_beam_dies_and_killer_scores() -> void:
	var world := _world(2)
	world.add_player(2, Vector2i(5, 3))
	var deaths: Array = []
	world.player_died.connect(func(id: int, killer: int) -> void: deaths.append([id, killer]))
	world.place_bomb(1)
	world.players[1].cell = Vector2i(9, 9)
	_explode_all(world)
	assert_bool(world.players[2].alive).is_false()
	assert_bool(world.players[1].alive).is_true()
	assert_int(world.players[1].kills).is_equal(1)
	assert_array(deaths).is_equal([[2, 1]])


func test_suicide_gives_no_kill() -> void:
	var world := _world(1)
	world.place_bomb(1)
	_explode_all(world)
	assert_bool(world.players[1].alive).is_false()
	assert_int(world.players[1].kills).is_equal(0)


func test_death_reported_once() -> void:
	var world := _world(1)
	var deaths: Array[int] = []
	world.player_died.connect(func(id: int, _killer: int) -> void: deaths.append(id))
	world.place_bomb(1)
	_explode_all(world)
	world.tick(100)
	world.tick(100)
	assert_array(deaths).has_size(1)


func test_capacity_blocks_second_bomb_until_explosion() -> void:
	var world := _world(1, 1)
	assert_object(world.place_bomb(1)).is_not_null()
	assert_object(world.place_bomb(1)).is_null()
	_explode_all(world)
	world.players[1].alive = true
	assert_object(world.place_bomb(1)).is_not_null()


func test_cannot_stack_two_bombs_on_one_cell() -> void:
	var world := _world(1, 2)
	assert_object(world.place_bomb(1)).is_not_null()
	assert_object(world.place_bomb(1)).is_null()


func test_explosion_lasts_exactly_half_second() -> void:
	var world := _world(1)
	world.players[1].cell = Vector2i(9, 9)
	world.add_player(2, Vector2i(2, 2))
	world.place_bomb(1)
	world.players[1].cell = Vector2i(9, 9)
	_explode_all(world)
	assert_int(world.explosions.size()).is_equal(1)
	world.tick(SimConstants.EXPLOSION_DURATION_MS - 1)
	assert_int(world.explosions.size()).is_equal(1)
	world.tick(1)
	assert_int(world.explosions.size()).is_equal(0)


func test_player_stepping_into_active_beam_dies() -> void:
	var world := _world(1)
	world.place_bomb(1)
	world.players[1].cell = Vector2i(9, 9)
	_explode_all(world)
	var late := world.add_player(2, Vector2i(5, 4))
	world.tick(100)
	assert_bool(late.alive).is_false()


func test_bomb_timer_is_two_and_a_half_seconds() -> void:
	var world := _world(1)
	world.players[1].cell = ORIGIN
	world.place_bomb(1)
	world.tick(SimConstants.BOMB_COUNTDOWN_MS - 1)
	assert_int(world.bombs.size()).is_equal(1)
	world.tick(1)
	assert_int(world.bombs.size()).is_equal(0)


func test_destroyed_box_may_drop_extra_seeded() -> void:
	var drops := 0
	for i in 40:
		var w := SimWorld.new(SimBoard.empty())
		w.rng.seed = i
		w.add_player(1, ORIGIN).power = 2
		w.board.set_tile(Vector2i(5, 4), SimTile.Type.BOX)
		w.place_bomb(1)
		w.players[1].cell = Vector2i(9, 9)
		w.tick(SimConstants.BOMB_COUNTDOWN_MS)
		if w.extras.has(Vector2i(5, 4)):
			drops += 1
	assert_bool(drops > 5 and drops < 35).is_true()


func test_same_seed_gives_same_drops() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 123
	var b := RandomNumberGenerator.new()
	b.seed = 123
	for i in 200:
		assert_int(SimExtra.roll(a)).is_equal(SimExtra.roll(b))
