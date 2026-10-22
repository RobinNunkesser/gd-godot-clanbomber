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

