extends GdUnitTestSuite
## Testet das Untermenü "Steuerung & Hilfe":
## - Seite 1: Steuerung, Kurzbefehle, Karten & Teams
## - Seite 2: Extras & Krankheiten mit Asset-Grafiken und Erklärungen
## - Seitenwechsel via Tastatur/Gamepad-Aktionen und Rückkehr ins Hauptmenü.


func _menu() -> GameMenu:
	var catalog := MapCatalog.new()
	var menu := GameMenu.new()
	menu.catalog = catalog
	add_child(menu)
	auto_free(menu)
	menu.open()
	return menu


func test_help_opens_on_page_0_with_controls() -> void:
	var menu := _menu()
	menu._row = menu._row_index("help")
	menu._accept()
	menu._render()

	assert_int(menu._mode).is_equal(GameMenu.Mode.HELP)
	assert_int(menu._help_page).is_equal(0)
	assert_str(menu._text.text).contains("Steuerung & Hilfe")
	assert_str(menu._text.text).contains("Steuerung & Tasten (1/2)")
	assert_str(menu._text.text).contains("Spieler 1 (Tastatur)")
	assert_str(menu._text.text).contains("Gamepad (1–8)")


func test_help_switches_to_page_1_with_pickups_and_diseases() -> void:
	var menu := _menu()
	menu._row = menu._row_index("help")
	menu._accept()

	# Rechts-Eingabe (ui_right) wechselt auf Seite 2
	var ev_right := InputEventAction.new()
	ev_right.action = "ui_right"
	ev_right.pressed = true
	menu._unhandled_input(ev_right)

	assert_int(menu._help_page).is_equal(1)
	assert_str(menu._text.text).contains("Extras & Flüche (2/2)")
	assert_str(menu._text.text).contains("res://assets/textures/drops/token_bomb.png")
	assert_str(menu._text.text).contains("Bombe")
	assert_str(menu._text.text).contains("res://assets/textures/drops/token_power.png")
	assert_str(menu._text.text).contains("Feuer")
	assert_str(menu._text.text).contains("res://assets/textures/drops/token_skate.png")
	assert_str(menu._text.text).contains("Skateboard")
	assert_str(menu._text.text).contains("res://assets/textures/drops/token_kick.png")
	assert_str(menu._text.text).contains("Tritt")
	assert_str(menu._text.text).contains("res://assets/textures/drops/token_glove.png")
	assert_str(menu._text.text).contains("Handschuh")
	assert_str(menu._text.text).contains("res://assets/textures/drops/token_overdrive.png")
	assert_str(menu._text.text).contains("Turbo")
	assert_str(menu._text.text).contains("res://assets/textures/drops/token_reverse.png")
	assert_str(menu._text.text).contains("Verwirrung")
	assert_str(menu._text.text).contains("res://assets/textures/drops/token_autobomb.png")
	assert_str(menu._text.text).contains("Durchfall")

	# Links-Eingabe wechselt zurück auf Seite 1
	var ev_left := InputEventAction.new()
	ev_left.action = "ui_left"
	ev_left.pressed = true
	menu._unhandled_input(ev_left)

	assert_int(menu._help_page).is_equal(0)
	assert_str(menu._text.text).contains("Steuerung & Tasten (1/2)")


func test_help_accept_navigation_and_exit() -> void:
	var menu := _menu()
	menu._row = menu._row_index("help")
	menu._accept()

	# Enter / ui_accept auf Seite 0 wechselt auf Seite 1
	var ev_accept := InputEventAction.new()
	ev_accept.action = "ui_accept"
	ev_accept.pressed = true
	menu._unhandled_input(ev_accept)
	assert_int(menu._mode).is_equal(GameMenu.Mode.HELP)
	assert_int(menu._help_page).is_equal(1)

	# Zweites Enter / ui_accept auf Seite 1 schließt die Hilfe und kehrt ins Hauptmenü zurück
	menu._unhandled_input(ev_accept)
	assert_int(menu._mode).is_equal(GameMenu.Mode.MAIN)
