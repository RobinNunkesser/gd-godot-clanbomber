extends GdUnitTestSuite
## Smoke-Test der Kartenauswahl im Menü: Rendern, Umschalten, Alle / Nur diese.


# Gültige Karte mit `starts` Startfeldern (Plätze 0..starts-1) in der zweiten Zeile.
func _map_text(starts: int) -> String:
	var rows: Array[String] = []
	for y in SimConstants.GRID_HEIGHT:
		var row := ""
		for x in SimConstants.GRID_WIDTH:
			var border := x == 0 or y == 0 or x == SimConstants.GRID_WIDTH - 1 or y == SimConstants.GRID_HEIGHT - 1
			if border:
				row += "*"
			elif y == 1 and x >= 1 and x <= starts:
				row += str(x - 1)
			else:
				row += " "
		rows.append(row)
	return "Autor\n%d\n%s" % [starts, "\n".join(rows)]


func _menu() -> GameMenu:
	var catalog := MapCatalog.new()
	catalog.add("a.map", _map_text(2))
	catalog.add("b.map", _map_text(4))
	var menu := GameMenu.new()
	menu.catalog = catalog
	menu.config.map_pool = ["a.map", "b.map"]
	add_child(menu)
	auto_free(menu)
	return menu


func test_map_submenu_renders_and_toggles() -> void:
	var menu := _menu()
	menu.open()
	menu._enter_submenu(GameMenu.Mode.MAPS)
	menu._render()
	assert_bool(menu._preview.visible).is_true()
	menu._accept_map_row()
	assert_bool(menu.config.is_in_pool("a.map")).is_false()
	menu._accept_map_row()
	assert_bool(menu.config.is_in_pool("a.map")).is_true()


func test_select_all_and_only_current_shortcuts() -> void:
	var menu := _menu()
	menu.open()
	menu._enter_submenu(GameMenu.Mode.MAPS)
	var only := InputEventKey.new()
	only.pressed = true
	only.physical_keycode = KEY_S
	assert_bool(menu._handle_map_shortcut(only)).is_true()
	assert_array(menu.config.map_pool).is_equal(["a.map"])
	var all := InputEventKey.new()
	all.pressed = true
	all.physical_keycode = KEY_A
	assert_bool(menu._handle_map_shortcut(all)).is_true()
	assert_int(menu.config.map_pool.size()).is_equal(2)
