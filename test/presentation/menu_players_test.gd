extends GdUnitTestSuite
## Testet das Spieler- und Team-Untermenü: Steuerungsauswahl (Tastatur, Gamepad, AI, Aus),
## Namensbearbeitung, Teamauswahl und Scrollen.


func _menu() -> GameMenu:
	var catalog := MapCatalog.new()
	var menu := GameMenu.new()
	menu.catalog = catalog
	add_child(menu)
	auto_free(menu)
	menu.open()
	menu._enter_submenu(GameMenu.Mode.PLAYERS)
	return menu


func test_player_submenu_row_count_and_navigation() -> void:
	var menu := _menu()
	assert_int(menu._row_count()).is_equal(GameConfig.SLOT_COUNT * 3)


func test_player_controller_cycling() -> void:
	var menu := _menu()
	# Slot 0 steht per Default auf KEYBOARD_1
	assert_int(menu.config.slots[0]).is_equal(GameConfig.Controller.KEYBOARD_1)

	# Steuerung von Slot 0 ist Zeile 0
	menu._row = 0
	menu._change(1)
	# Nach KEYBOARD_1 folgt KEYBOARD_2
	assert_int(menu.config.slots[0]).is_equal(GameConfig.Controller.KEYBOARD_2)

	# Enter / Accept schaltet ebenfalls weiter
	menu._accept()
	assert_int(menu.config.slots[0]).is_equal(GameConfig.Controller.PAD_1)

	# Rückwärts schalten
	menu._change(-1)
	assert_int(menu.config.slots[0]).is_equal(GameConfig.Controller.KEYBOARD_2)


func test_player_off_and_active_slots() -> void:
	var menu := _menu()
	# Slot 2 ist standardmäßig OFF
	assert_int(menu.config.slots[2]).is_equal(GameConfig.Controller.OFF)
	assert_bool(menu.config.active_slots().has(2)).is_false()

	# Zeile für Slot 2 Steuerung ist 2 * 3 = 6
	menu._row = 6
	menu._change(1)
	# Slot 2 erhält einen freien Controller (KEYBOARD_2)
	assert_int(menu.config.slots[2]).is_not_equal(GameConfig.Controller.OFF)
	assert_bool(menu.config.active_slots().has(2)).is_true()

	# Bis zu OFF durchschalten
	while menu.config.slots[2] != GameConfig.Controller.OFF:
		menu._change(1)
	assert_int(menu.config.slots[2]).is_equal(GameConfig.Controller.OFF)
	assert_bool(menu.config.active_slots().has(2)).is_false()


func test_player_name_and_team_rows() -> void:
	var menu := _menu()
	# Zeile 1 ist Name von Slot 0
	menu._row = 1
	menu._accept()
	assert_bool(menu._editing).is_true()
	assert_str(menu._edit_kind).is_equal("name")
	assert_int(menu._edit_slot).is_equal(0)
	menu._editing = false

	# Zeile 2 ist Team von Slot 0
	menu._row = 2
	assert_int(menu.config.teams[0]).is_equal(0)
	menu._change(1)
	assert_int(menu.config.teams[0]).is_equal(1)
	menu._accept()
	assert_int(menu.config.teams[0]).is_equal(2)


func test_player_menu_rendering_and_scrolling() -> void:
	var menu := _menu()
	menu._render()
	assert_str(menu._text.text).contains("Spieler & Teams")
	assert_str(menu._text.text).contains("Steuerung")

	# Zu Slot 6 navigieren (Zeile 6 * 3 = 18)
	menu._row = 18
	menu._render()
	assert_int(menu._player_first_slot).is_greater(0)
	assert_str(menu._text.text).contains("Platz 7")
