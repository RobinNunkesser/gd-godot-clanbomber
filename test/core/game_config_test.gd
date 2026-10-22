extends GdUnitTestSuite


func test_default_is_human_versus_ai() -> void:
	var config := GameConfig.new()
	assert_array(config.active_slots()).is_equal([0, 1])
	assert_bool(config.is_startable()).is_true()


func test_not_startable_with_one_player() -> void:
	var config := GameConfig.new()
	config.slots[1] = GameConfig.Controller.OFF
	assert_bool(config.is_startable()).is_false()


func test_keyboard_cannot_be_assigned_twice() -> void:
	var config := GameConfig.new()
	config.slots[2] = GameConfig.Controller.OFF
	config.cycle_slot(2, 1)
	assert_int(config.slots[2]).is_equal(GameConfig.Controller.KEYBOARD_2)
	config.cycle_slot(3, 1)
	assert_int(config.slots[3]).is_equal(GameConfig.Controller.PAD_1)


func test_cycle_wraps_and_ai_can_repeat() -> void:
	var config := GameConfig.new()
	config.slots = [GameConfig.Controller.AI, GameConfig.Controller.AI, GameConfig.Controller.OFF, GameConfig.Controller.OFF]
	config.cycle_slot(0, 1)
	assert_int(config.slots[0]).is_equal(GameConfig.Controller.OFF)
	config.cycle_slot(0, -1)
	assert_int(config.slots[0]).is_equal(GameConfig.Controller.AI)


func test_points_are_clamped() -> void:
	var config := GameConfig.new()
	config.points_to_win = GameConfig.MAX_POINTS
	config.cycle_points(1)
	assert_int(config.points_to_win).is_equal(GameConfig.MAX_POINTS)
	config.points_to_win = GameConfig.MIN_POINTS
	config.cycle_points(-1)
	assert_int(config.points_to_win).is_equal(GameConfig.MIN_POINTS)


func test_map_cycle_includes_random() -> void:
	var config := GameConfig.new()
	var maps: Array[String] = ["a.map", "b.map"]
	config.map_name = "b.map"
	config.cycle_map(maps, 1)
	assert_bool(config.is_random_map()).is_true()
	config.cycle_map(maps, 1)
	assert_str(config.map_name).is_equal("a.map")
	config.cycle_map(maps, -2)
	assert_str(config.map_name).is_equal("b.map")


func test_pad_device() -> void:
	var config := GameConfig.new()
	config.slots[2] = GameConfig.Controller.PAD_2
	assert_int(config.pad_device(2)).is_equal(1)
	assert_int(config.pad_device(0)).is_equal(-1)


func test_audio_volume_cycle_and_toggle() -> void:
	var config := GameConfig.new()
	assert_int(config.music_volume).is_equal(4)
	assert_str(config.music_label()).is_equal("100 %")
	assert_bool(config.is_music_enabled()).is_true()
	
	config.cycle_music(1)
	assert_int(config.music_volume).is_equal(4)
	config.cycle_music(-2)
	assert_int(config.music_volume).is_equal(2)
	assert_str(config.music_label()).is_equal("50 %")
	
	config.toggle_music_mute()
	assert_int(config.music_volume).is_equal(0)
	assert_str(config.music_label()).is_equal("Aus")
	assert_bool(config.is_music_enabled()).is_false()
	
	config.toggle_music_mute()
	assert_int(config.music_volume).is_equal(2)
	assert_str(config.music_label()).is_equal("50 %")
	
	config.cycle_sfx(-4)
	assert_int(config.sfx_volume).is_equal(0)
	assert_bool(config.is_sfx_enabled()).is_false()
	config.toggle_sfx_mute()
	assert_int(config.sfx_volume).is_equal(4)



func test_default_names_and_custom_names() -> void:
	var config := GameConfig.new()
	assert_str(config.name_of(0)).is_equal("Spieler 1")
	config.set_name(0, "  Robin Nunkesser, der Lange  ")
	assert_str(config.name_of(0)).is_equal("Robin Nunkes")
	config.set_name(1, "[b]Hendrik[/b]")
	assert_str(config.name_of(1)).is_equal("bHendrik/b")
	config.set_name(0, "   ")
	assert_str(config.name_of(0)).is_equal("Spieler 1")


func test_team_cycle_wraps_through_no_team() -> void:
	var config := GameConfig.new()
	assert_int(config.teams[0]).is_equal(0)
	config.cycle_team(0, 1)
	assert_int(config.teams[0]).is_equal(1)
	config.cycle_team(0, -2)
	assert_int(config.teams[0]).is_equal(GameConfig.TEAM_COUNT)
	config.cycle_team(0, 1)
	assert_int(config.teams[0]).is_equal(0)
	assert_str(GameConfig.team_label(0)).is_equal("Kein Team")
	assert_str(GameConfig.team_label(1)).is_equal("Team Blood")


func test_team_with_single_member_counts_as_no_team() -> void:
	var config := GameConfig.new()
	config.teams[0] = 2
	assert_int(config.effective_team(0)).is_equal(0)
	config.teams[1] = 2
	assert_int(config.effective_team(0)).is_equal(2)
	assert_int(config.effective_team(1)).is_equal(2)


func test_team_member_on_inactive_slot_does_not_count() -> void:
	var config := GameConfig.new()
	config.teams[0] = 3
	config.teams[2] = 3
	assert_int(config.slots[2]).is_equal(GameConfig.Controller.OFF)
	assert_int(config.effective_team(0)).is_equal(0)


func test_all_players_in_one_team_is_not_startable() -> void:
	var config := GameConfig.new()
	assert_int(config.faction_count()).is_equal(2)
	config.teams[0] = 1
	config.teams[1] = 1
	assert_int(config.faction_count()).is_equal(1)
	assert_bool(config.is_startable()).is_false()
	config.slots[2] = GameConfig.Controller.AI
	assert_int(config.faction_count()).is_equal(2)
	assert_bool(config.is_startable()).is_true()


func test_round_time_cycle_is_clamped() -> void:
	var config := GameConfig.new()
	assert_int(config.round_time_s).is_equal(90)
	assert_int(config.round_time_ms()).is_equal(90000)
	config.cycle_round_time(1)
	assert_int(config.round_time_s).is_equal(120)
	config.cycle_round_time(-100)
	assert_int(config.round_time_s).is_equal(GameConfig.ROUND_TIMES[0])
	config.cycle_round_time(100)
	assert_int(config.round_time_s).is_equal(GameConfig.ROUND_TIMES[GameConfig.ROUND_TIMES.size() - 1])


func test_effective_pool_uses_selection_and_falls_back() -> void:
	var config := GameConfig.new()
	var playable: Array[String] = ["a.map", "b.map", "c.map"]
	config.map_pool = ["b.map", "x.map"]
	assert_array(config.effective_pool(playable)).is_equal(["b.map"])
	config.map_pool = ["x.map"]
	assert_array(config.effective_pool(playable)).is_equal(playable)
	config.map_pool = []
	assert_array(config.effective_pool(playable)).is_equal(playable)


func test_toggle_pool() -> void:
	var config := GameConfig.new()
	config.toggle_pool("a.map")
	assert_bool(config.is_in_pool("a.map")).is_true()
	config.toggle_pool("a.map")
	assert_bool(config.is_in_pool("a.map")).is_false()


func test_save_and_load_roundtrip() -> void:
	var path := "user://test_settings_roundtrip.cfg"
	var known: Array[String] = ["a.map", "b.map"]
	var config := GameConfig.new()
	config.slots = [GameConfig.Controller.KEYBOARD_2, GameConfig.Controller.PAD_1, GameConfig.Controller.AI, GameConfig.Controller.OFF]
	config.set_name(0, "Robin")
	config.teams = [1, 1, 0, 0]
	config.map_name = ""
	config.map_pool = ["b.map"]
	config.points_to_win = 7
	config.round_time_s = 45
	config.music_volume = 2
	config.sfx_volume = 3
	assert_int(config.save_to(path)).is_equal(OK)
	var loaded := GameConfig.new()
	loaded.load_from(path, known)
	assert_array(loaded.slots).is_equal(config.slots)
	assert_str(loaded.name_of(0)).is_equal("Robin")
	assert_array(loaded.teams).is_equal([1, 1, 0, 0])
	assert_str(loaded.map_name).is_equal("")
	assert_array(loaded.map_pool).is_equal(["b.map"])
	assert_int(loaded.points_to_win).is_equal(7)
	assert_int(loaded.round_time_s).is_equal(45)
	assert_int(loaded.music_volume).is_equal(2)
	assert_int(loaded.sfx_volume).is_equal(3)
	DirAccess.remove_absolute(path)


func test_load_ignores_unknown_maps_and_invalid_values() -> void:
	var path := "user://test_settings_invalid.cfg"
	var file := ConfigFile.new()
	file.set_value("match", "slots", [1, 1, 0, 0])
	file.set_value("match", "map", "gone.map")
	file.set_value("match", "map_pool", ["a.map", "gone.map"])
	file.set_value("match", "points_to_win", 99)
	file.set_value("match", "round_time_s", 7)
	file.set_value("audio", "music", 42)
	file.save(path)
	var known: Array[String] = ["a.map"]
	var loaded := GameConfig.new()
	loaded.load_from(path, known)
	assert_array(loaded.slots).is_equal([GameConfig.Controller.KEYBOARD_1, GameConfig.Controller.AI, GameConfig.Controller.OFF, GameConfig.Controller.OFF])
	assert_str(loaded.map_name).is_equal("Crossroads.map")
	assert_array(loaded.map_pool).is_equal(["a.map"])
	assert_int(loaded.points_to_win).is_equal(GameConfig.MAX_POINTS)
	assert_int(loaded.round_time_s).is_equal(GameConfig.DEFAULT_ROUND_TIME_S)
	assert_int(loaded.music_volume).is_equal(GameConfig.VOLUME_LEVELS.size() - 1)
	DirAccess.remove_absolute(path)


func test_load_missing_file_keeps_defaults() -> void:
	var loaded := GameConfig.new()
	var known: Array[String] = []
	loaded.load_from("user://does_not_exist.cfg", known)
	assert_int(loaded.points_to_win).is_equal(SimConstants.POINTS_TO_WIN)
