extends GdUnitTestSuite
## Team-Modus: Parteien, Punkte, Match-Sieg und Gegner-Erkennung (Regeln nach dem Original).


func _world(teams: Array[int]) -> SimWorld:
	var board := SimBoard.empty()
	for x in board.width:
		board.set_tile(Vector2i(x, 0), SimTile.Type.WALL)
		board.set_tile(Vector2i(x, board.height - 1), SimTile.Type.WALL)
	for y in board.height:
		board.set_tile(Vector2i(0, y), SimTile.Type.WALL)
		board.set_tile(Vector2i(board.width - 1, y), SimTile.Type.WALL)
	var world := SimWorld.new(board)
	for i in teams.size():
		world.add_player(i + 1, Vector2i(1 + i * 2, 2), teams[i])
	return world


func _kill(world: SimWorld, ids: Array[int]) -> void:
	for id in ids:
		world.players[id].alive = false


func test_round_continues_while_two_teams_live() -> void:
	var world := _world([1, 1, 2, 2])
	_kill(world, [2, 3])
	assert_bool(SimMatch.new().update(world)).is_false()


func test_round_ends_when_one_team_is_left() -> void:
	var world := _world([1, 1, 2, 2])
	_kill(world, [3, 4])
	var match_state := SimMatch.new()
	assert_bool(match_state.update(world)).is_true()
	assert_array(match_state.last_winners).is_equal([1, 2])
	assert_int(match_state.points_of(1)).is_equal(1)
	assert_int(match_state.points_of(2)).is_equal(1)
	assert_int(match_state.points_of(3)).is_equal(0)


func test_only_survivors_of_the_winning_team_score() -> void:
	var world := _world([1, 1, 2, 2])
	_kill(world, [2, 3, 4])
	var match_state := SimMatch.new()
	assert_bool(match_state.update(world)).is_true()
	assert_int(match_state.points_of(1)).is_equal(1)
	assert_int(match_state.points_of(2)).is_equal(0)
	assert_int(match_state.team_points(1)).is_equal(1)


func test_teamless_player_is_a_separate_party() -> void:
	var world := _world([1, 1, 0])
	var match_state := SimMatch.new()
	assert_bool(match_state.update(world)).is_false()
	_kill(world, [3])
	assert_bool(match_state.update(world)).is_true()


func test_two_teamless_players_are_opponents() -> void:
	var world := _world([0, 0])
	assert_bool(SimMatch.new().update(world)).is_false()
	_kill(world, [2])
	assert_bool(SimMatch.new().update(world)).is_true()


func test_team_wins_match_with_summed_points() -> void:
	var match_state := SimMatch.new(2)
	# Team 1 hat zwei Mitglieder und braucht 2 * 2 = 4 Punkte, also zwei volle Rundensiege.
	for round_index in 2:
		var world := _world([1, 1, 2, 2])
		_kill(world, [3, 4])
		assert_int(match_state.state).is_not_equal(SimMatch.State.MATCH_OVER)
		assert_bool(match_state.update(world)).is_true()
		match_state.start_next_round()
	assert_int(match_state.state).is_equal(SimMatch.State.MATCH_OVER)
	assert_int(match_state.winning_team).is_equal(1)
	assert_int(match_state.team_points(1)).is_equal(4)
	assert_int([1, 2].find(match_state.match_winner)).is_greater_equal(0)


func test_single_survivor_needs_more_rounds_for_team_win() -> void:
	var match_state := SimMatch.new(2)
	for round_index in 3:
		var world := _world([1, 1, 2, 2])
		_kill(world, [2, 3, 4])
		match_state.update(world)
		match_state.start_next_round()
	# Nur Spieler 1 punktet: 3 Teampunkte < 4 nötige.
	assert_int(match_state.state).is_equal(SimMatch.State.PLAYING)
	var world := _world([1, 1, 2, 2])
	_kill(world, [2, 3, 4])
	match_state.update(world)
	assert_int(match_state.state).is_equal(SimMatch.State.MATCH_OVER)
	assert_int(match_state.winning_team).is_equal(1)


func test_teamless_winner_has_no_winning_team() -> void:
	var match_state := SimMatch.new(1)
	var world := _world([0, 0])
	_kill(world, [2])
	match_state.update(world)
	assert_int(match_state.state).is_equal(SimMatch.State.MATCH_OVER)
	assert_int(match_state.winning_team).is_equal(0)
	assert_int(match_state.match_winner).is_equal(1)


func test_has_teams_only_with_team_members() -> void:
	var match_state := SimMatch.new()
	match_state.set_team(1, 0)
	match_state.set_team(2, 0)
	assert_bool(match_state.has_teams()).is_false()
	match_state.set_team(2, 3)
	assert_bool(match_state.has_teams()).is_true()


func test_is_enemy_in_ignores_teammates() -> void:
	var world := _world([1, 1, 2])
	world.players[2].cell = Vector2i(5, 5)
	world.players[3].cell = Vector2i(7, 5)
	assert_bool(world.is_enemy_in(Vector2i(5, 5), 1)).is_false()
	assert_bool(world.is_enemy_in(Vector2i(7, 5), 1)).is_true()
	assert_bool(world.is_other_player_in(Vector2i(5, 5), 1)).is_true()


func test_is_enemy_in_without_teams_counts_everyone() -> void:
	var world := _world([0, 0])
	world.players[2].cell = Vector2i(5, 5)
	assert_bool(world.is_enemy_in(Vector2i(5, 5), 1)).is_true()
	world.players[2].alive = false
	assert_bool(world.is_enemy_in(Vector2i(5, 5), 1)).is_false()
