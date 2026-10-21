class_name SimMatchTest
extends GdUnitTestSuite


func _world(player_count := 2) -> SimWorld:
	var board := SimBoard.empty()
	for x in board.width:
		board.set_tile(Vector2i(x, 0), SimTile.Type.WALL)
		board.set_tile(Vector2i(x, board.height - 1), SimTile.Type.WALL)
	for y in board.height:
		board.set_tile(Vector2i(0, y), SimTile.Type.WALL)
		board.set_tile(Vector2i(board.width - 1, y), SimTile.Type.WALL)
	var world := SimWorld.new(board)
	for i in player_count:
		world.add_player(i + 1, Vector2i(1 + i * 2, 2))
	return world


func test_round_continues_while_two_players_live() -> void:
	var match_state := SimMatch.new()
	assert_bool(match_state.update(_world())).is_false()
	assert_int(match_state.state).is_equal(SimMatch.State.PLAYING)


func test_single_player_world_never_ends() -> void:
	var match_state := SimMatch.new()
	assert_bool(match_state.update(_world(1))).is_false()


func test_survivor_gets_a_point() -> void:
	var world := _world()
	var match_state := SimMatch.new()
	world.players[2].alive = false
	assert_bool(match_state.update(world)).is_true()
	assert_int(match_state.points_of(1)).is_equal(1)
	assert_int(match_state.points_of(2)).is_equal(0)
	assert_array(match_state.last_winners).contains_exactly([1])
	assert_int(match_state.state).is_equal(SimMatch.State.ROUND_OVER)


func test_draw_gives_no_points() -> void:
	var world := _world()
	var match_state := SimMatch.new()
	world.players[1].alive = false
	world.players[2].alive = false
	assert_bool(match_state.update(world)).is_true()
	assert_int(match_state.points_of(1)).is_equal(0)
	assert_int(match_state.points_of(2)).is_equal(0)
	assert_array(match_state.last_winners).is_empty()


func test_round_waits_for_running_explosion() -> void:
	var world := _world()
	var match_state := SimMatch.new()
	world.players[2].alive = false
	world.explosions.append(SimExplosion.new())
	assert_bool(match_state.update(world)).is_false()
	world.explosions.clear()
	assert_bool(match_state.update(world)).is_true()


func test_round_waits_for_falling_survivor() -> void:
	var world := _world()
	var match_state := SimMatch.new()
	world.players[2].alive = false
	world.players[1].fall_ms = 500
	assert_bool(match_state.update(world)).is_false()
	world.players[1].fall_ms = -1
	assert_bool(match_state.update(world)).is_true()


func test_round_is_awarded_only_once() -> void:
	var world := _world()
	var match_state := SimMatch.new()
	world.players[2].alive = false
	match_state.update(world)
	assert_bool(match_state.update(world)).is_false()
	assert_int(match_state.points_of(1)).is_equal(1)


func test_kills_accumulate_over_rounds() -> void:
	var match_state := SimMatch.new()
	for round_index in 2:
		var world := _world()
		world.players[2].alive = false
		world.players[1].kills = 1
		match_state.update(world)
		match_state.start_next_round()
	assert_int(match_state.kills_of(1)).is_equal(2)
	assert_int(match_state.rounds_played).is_equal(2)


func test_next_round_keeps_points() -> void:
	var match_state := SimMatch.new()
	var world := _world()
	world.players[2].alive = false
	match_state.update(world)
	match_state.start_next_round()
	assert_int(match_state.state).is_equal(SimMatch.State.PLAYING)
	assert_int(match_state.points_of(1)).is_equal(1)


func test_match_is_won_at_target_points() -> void:
	var match_state := SimMatch.new(2)
	var ended := [-1]
	match_state.match_ended.connect(func(id: int) -> void: ended[0] = id)
	for round_index in 2:
		var world := _world()
		world.players[2].alive = false
		match_state.update(world)
		match_state.start_next_round()
	assert_int(match_state.state).is_equal(SimMatch.State.MATCH_OVER)
	assert_int(match_state.match_winner).is_equal(1)
	assert_int(ended[0]).is_equal(1)


func test_ranking_sorts_by_points_then_kills() -> void:
	var match_state := SimMatch.new()
	match_state.points = {1: 1, 2: 3, 3: 1}
	match_state.kills = {1: 0, 2: 0, 3: 2}
	assert_array(match_state.ranking()).contains_exactly([2, 3, 1])


func test_reset_clears_everything() -> void:
	var match_state := SimMatch.new()
	var world := _world()
	world.players[2].alive = false
	match_state.update(world)
	match_state.reset()
	assert_int(match_state.points_of(1)).is_equal(0)
	assert_int(match_state.rounds_played).is_equal(0)
	assert_int(match_state.state).is_equal(SimMatch.State.PLAYING)


func test_supports_eight_players() -> void:
	var world := _world(8)
	var match_state := SimMatch.new()
	for id in range(2, 9):
		world.players[id].alive = false
	assert_bool(match_state.update(world)).is_true()
	assert_int(match_state.points_of(1)).is_equal(1)
	assert_int(match_state.points.size()).is_equal(8)
