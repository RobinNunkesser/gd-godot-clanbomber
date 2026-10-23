class_name GameMenu
extends PanelContainer
## Start- und Pausemenü: Steuerung je Spielerplatz, Kartenauswahl samt Reihenfolge, Punkte, Sudden-Death-Zeit,
## Lautstärken, Namen & Teams, Hilfe und Beenden.
## Bedienung mit Pfeiltasten/D-Pad, Enter/Leertaste/Gamepad A; Esc/B geht zurück (siehe back()).

signal start_requested
signal resume_requested
signal audio_changed
signal map_dir_changed(path: String)
signal quit_requested

enum Mode { MAIN, HELP, PLAYERS, MAPS, MATCH, SETTINGS }

const VISIBLE_MAP_ROWS := 12
const VISIBLE_PLAYER_ROWS := 12
const LANGS := ["de", "en"]

var _lang_index := 0


# Kleine Kartenvorschau neben der Kartenliste (wie im Original): Kacheln und Startplätze.
class MapPreview:
	extends Control

	const CELL := 15
	var data: MapData
	var active_slots: Array[int] = []

	func _init() -> void:
		custom_minimum_size = Vector2(SimConstants.GRID_WIDTH * CELL, SimConstants.GRID_HEIGHT * CELL)

	func _draw() -> void:
		if data == null:
			return
		for y in SimConstants.GRID_HEIGHT:
			for x in SimConstants.GRID_WIDTH:
				var rect := Rect2(x * CELL, y * CELL, CELL - 1, CELL - 1)
				draw_rect(rect, _tile_color(data.tiles[y * SimConstants.GRID_WIDTH + x]))
		for slot: int in data.starts:
			var cell: Vector2i = data.starts[slot]
			var color: Color = ArenaView3D.PLAYER_COLORS[slot % ArenaView3D.PLAYER_COLORS.size()]
			if not active_slots.has(slot):
				color = color.darkened(0.5)
			draw_circle(Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL), CELL * 0.4, color)

	static func _tile_color(type: int) -> Color:
		match type:
			SimTile.Type.WALL:
				return Color("b0b4bc")
			SimTile.Type.BOX:
				return Color("a0693a")
			SimTile.Type.ICE:
				return Color("9adcf0")
			SimTile.Type.TRAP:
				return Color("c0392b")
			SimTile.Type.HOLE, SimTile.Type.NONE:
				return Color("000000")
			SimTile.Type.ARROW_LEFT, SimTile.Type.ARROW_RIGHT, SimTile.Type.ARROW_UP, SimTile.Type.ARROW_DOWN:
				return Color("3f6fd0")
		return Color("3a3a3a")

var config := GameConfig.new()
var catalog := MapCatalog.new()
var is_game_active := false

var _mode := Mode.MAIN
var _row := 0
var _return_row := 0
var _map_scroll := 0
var _player_first_slot := 0
var _editing := false
var _edit_kind := "name"
var _edit_slot := 0
var _edit_text := ""
var _text := RichTextLabel.new()
var _preview := MapPreview.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(700, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	focus_mode = Control.FOCUS_NONE
	_text.focus_mode = Control.FOCUS_NONE
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 20)
	_text.add_theme_font_size_override("bold_font_size", 28)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := HBoxContainer.new()
	box.focus_mode = Control.FOCUS_NONE
	box.add_child(_text)
	_preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_preview.visible = false
	box.add_child(_preview)
	add_child(box)
	visible = false
	I18n.init()
	_lang_index = I18n.lang_index()


func open() -> void:
	visible = true
	_mode = Mode.MAIN
	_editing = false
	_row = _row_index("resume" if is_game_active else "start")
	_render()


func resume() -> void:
	if is_game_active:
		visible = false
		resume_requested.emit()


# Esc/B: erst Namenseingabe abbrechen, dann Untermenü/Hilfe schließen. true = Eingabe verbraucht.
func back() -> bool:
	if _editing:
		_editing = false
		_render()
		return true
	if _mode != Mode.MAIN:
		_mode = Mode.MAIN
		_row = _row_index("resume" if is_game_active else "start")
		_render()
		return true
	return false


# --- Zeilenmodell des Hauptmenüs ---

func _main_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if is_game_active:
		rows.append({"id": "resume", "label": "[b]%s[/b]" % I18n.text("MENU_RESUME"), "value": "", "adjustable": false, "gap": true})
		rows.append({"id": "start", "label": "[b]%s[/b]" % I18n.text("MENU_NEW_MATCH"), "value": "", "adjustable": false})
	else:
		var label := "[b]%s[/b]" % I18n.text("MENU_START")
		var blocker := _start_blocker()
		if not blocker.is_empty():
			label += " [color=#ff8a80](%s)[/color]" % blocker
		rows.append({"id": "start", "label": label, "value": "", "adjustable": false, "gap": true})
	rows.append({"id": "players", "label": I18n.text("MENU_PLAYERS_TEAMS"), "value": _players_summary(), "adjustable": false})
	var playable := catalog.playable(config.active_slots())
	var order := I18n.text("MENU_RANDOM") if config.random_order else I18n.text("MENU_SEQUENTIAL")
	rows.append({"id": "pool", "label": I18n.text("MENU_CARDS"), "value": "%d / %d • %s" % [config.effective_pool(playable).size(), playable.size(), order.to_lower()], "adjustable": false})
	rows.append({"id": "match", "label": I18n.text("MENU_MATCH"), "value": _match_summary(), "adjustable": false})
	rows.append({"id": "settings", "label": I18n.text("MENU_SETTINGS"), "value": _settings_summary(), "adjustable": false})
	rows.append({"id": "help", "label": I18n.text("MENU_HELP"), "value": "", "adjustable": false})
	rows.append({"id": "quit", "label": I18n.text("MENU_QUIT"), "value": "", "adjustable": false})
	return rows


func _players_summary() -> String:
	var active := config.active_slots()
	if active.is_empty():
		return I18n.text("MENU_NONE")
	var teams_used: Dictionary = {}
	for slot in active:
		var team := config.effective_team(slot)
		if team > 0:
			teams_used[team] = true
	if teams_used.size() > 0:
		return "%d • %d %s" % [active.size(), teams_used.size(), I18n.text("MENU_TEAM").strip_edges()]
	return "%d" % active.size()


func _match_summary() -> String:
	return "%d • %ds • %s" % [config.points_to_win, config.round_time_s, config.random_positions_label().to_lower()]


func _settings_summary() -> String:
	var path := config.external_map_dir
	if path.is_empty():
		path = I18n.text("MENU_STANDARD")
	else:
		path = path.get_file() if path.get_file() != "" else path.get_basename()
	return "%s/%s • %s" % [config.music_label(), config.sfx_label(), path]


func _row_index(id: String) -> int:
	var rows := _main_rows()
	for i in rows.size():
		if rows[i].id == id:
			return i
	return 0


func _row_id() -> String:
	var rows := _main_rows()
	return rows[clampi(_row, 0, rows.size() - 1)].id


func _external_dir_label() -> String:
	if _editing and _edit_kind == "mapdir":
		return "[color=#ffdd44]%s█[/color]" % _edit_text
	return config.external_map_dir if not config.external_map_dir.is_empty() else I18n.text("MENU_STANDARD")


func refresh() -> void:
	_render()


func _row_count() -> int:
	match _mode:
		Mode.PLAYERS:
			return GameConfig.SLOT_COUNT * 2
		Mode.MAPS:
			return catalog.names.size()
		Mode.MATCH:
			return 4
		Mode.SETTINGS:
			return 4
	return _main_rows().size()


# Warum man (noch) nicht starten kann; leer = alles in Ordnung.
func _start_blocker() -> String:
	if not config.is_startable():
		return I18n.text("MENU_BLOCKER_MIN_OPPONENTS")
	if catalog.playable(config.active_slots()).is_empty():
		return I18n.text("MENU_BLOCKER_NO_MAP")
	return ""



# --- Eingabe ---

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _mode == Mode.HELP:
		if event.is_pressed() and not event.is_echo():
			_mode = Mode.MAIN
			get_viewport().set_input_as_handled()
			_render()
		return
	if _editing:
		if _handle_edit_input(event):
			get_viewport().set_input_as_handled()
			_render()
		return
	if _mode == Mode.MAPS and _handle_map_shortcut(event):
		get_viewport().set_input_as_handled()
		_render()
		return
	if event.is_action_pressed("ui_up"):
		_row = posmod(_row - 1, _row_count())
	elif event.is_action_pressed("ui_down"):
		_row = posmod(_row + 1, _row_count())
	elif event.is_action_pressed("ui_left"):
		_change(-1)
	elif event.is_action_pressed("ui_right"):
		_change(1)
	elif event.is_action_pressed("ui_accept"):
		_accept()
	else:
		return
	get_viewport().set_input_as_handled()
	_render()


# Kartenauswahl wie im Original: A = alle Karten, S = nur die aktuelle Karte (Gamepad: X / Y).
func _handle_map_shortcut(event: InputEvent) -> bool:
	var all := false
	var only := false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key := event as InputEventKey
		var code := key.physical_keycode if key.keycode == 0 else key.keycode
		all = code == KEY_A
		only = code == KEY_S
	elif event is InputEventJoypadButton and event.is_pressed():
		var button := event as InputEventJoypadButton
		all = button.button_index == JOY_BUTTON_X
		only = button.button_index == JOY_BUTTON_Y
	if all:
		config.select_all(catalog.playable(config.active_slots()))
	elif only:
		var map := catalog.names[_row]
		if catalog.is_playable(map, config.active_slots()):
			config.select_only(map)
	return all or only


func _handle_edit_input(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return false
	var code := key.physical_keycode if key.keycode == 0 else key.keycode
	if code == KEY_ENTER or code == KEY_KP_ENTER:
		if key.echo:
			return false
		if _edit_kind == "mapdir":
			config.external_map_dir = _edit_text.strip_edges()
			map_dir_changed.emit(config.external_map_dir)
		else:
			config.set_name(_edit_slot, _edit_text)
		_editing = false
	elif code == KEY_BACKSPACE:
		_edit_text = _edit_text.left(_edit_text.length() - 1)
	elif key.unicode >= 32 and key.unicode != 127:
		var typed := char(key.unicode)
		var limit := 240 if _edit_kind == "mapdir" else GameConfig.NAME_MAX_LENGTH
		if typed != "[" and typed != "]" and _edit_text.length() < limit:
			_edit_text += typed
	else:
		return false
	return true


func _change(step: int) -> void:
	if _mode == Mode.PLAYERS:
		if _row % 2 == 1:
			config.cycle_team(floori(_row / 2.0), step)
		return
	if _mode == Mode.MATCH:
		match _row:
			0:
				config.cycle_points(step)
			1:
				config.cycle_round_time(step)
			2:
				config.toggle_random_positions()
			3:
				config.random_order = not config.random_order
		return
	if _mode == Mode.SETTINGS:
		match _row:
			0:
				config.cycle_music(step)
				audio_changed.emit()
			1:
				config.cycle_sfx(step)
				audio_changed.emit()
			2:
				_lang_index = posmod(_lang_index + step, LANGS.size())
				I18n.set_lang_index(_lang_index)
		return
	if _mode != Mode.MAIN:
		return
	var id := _row_id()
	if id.begins_with("slot"):
		config.cycle_slot(id.trim_prefix("slot").to_int(), step)
	elif id == "order":
		config.random_order = not config.random_order
	elif id == "positions":
		config.toggle_random_positions()
	elif id == "points":
		config.cycle_points(step)
	elif id == "time":
		config.cycle_round_time(step)
	elif id == "music":
		config.cycle_music(step)
		audio_changed.emit()
	elif id == "sfx":
		config.cycle_sfx(step)
		audio_changed.emit()


func _accept() -> void:
	match _mode:
		Mode.PLAYERS:
			if _row % 2 == 0:
				_begin_edit("name", config.names[floori(_row / 2.0)], floori(_row / 2.0))
			else:
				_change(1)
		Mode.MAPS:
			_accept_map_row()
		Mode.SETTINGS:
			if _row == 3:
				_begin_edit("mapdir", config.external_map_dir)
			elif _row == 2:
				_change(1)
		_:
			_accept_main_row()


func _accept_main_row() -> void:
	var id := _row_id()
	match id:
		"resume":
			resume()
		"start":
			if _start_blocker().is_empty():
				visible = false
				start_requested.emit()
		"help":
			_mode = Mode.HELP
		"quit":
			quit_requested.emit()
		"players":
			_enter_submenu(Mode.PLAYERS)
			_player_first_slot = 0
		"pool":
			_enter_submenu(Mode.MAPS)
			_map_scroll = 0
		"match":
			_enter_submenu(Mode.MATCH)
			_row = 0
		"settings":
			_enter_submenu(Mode.SETTINGS)
			_row = 0
		_:
			_change(1)


func _enter_submenu(mode: Mode) -> void:
	_return_row = _row
	_mode = mode
	_row = 0


func _begin_edit(kind: String, text: String, slot := 0) -> void:
	_edit_kind = kind
	_edit_slot = slot
	_editing = true
	_edit_text = text


# Leertaste / Enter / Gamepad A schaltet die Karte unter dem Cursor an oder aus.
func _accept_map_row() -> void:
	var map := catalog.names[_row]
	if catalog.is_playable(map, config.active_slots()):
		config.toggle_pool(map)


# --- Darstellung ---

func _render() -> void:
	_preview.visible = _mode == Mode.MAPS
	match _mode:
		Mode.HELP:
			_render_help()
		Mode.PLAYERS:
			_render_players()
		Mode.MAPS:
			_render_maps()
		Mode.MATCH:
			_render_match()
		Mode.SETTINGS:
			_render_settings()
		_:
			_render_main()


func _render_main() -> void:
	var lines: Array[String] = ["[center][b]ClanBomber[/b][/center]", ""]
	var rows := _main_rows()
	for i in rows.size():
		var row: Dictionary = rows[i]
		if row.get("gap", false):
			lines.append("")
		lines.append(_row_line(i, row.label, row.value, row.adjustable))
	lines.append("")
	var hint := I18n.text("MENU_PATH_HINT") if _editing and _edit_kind == "mapdir" else I18n.text("MENU_NAV_HINT")
	lines.append("[center][color=#aaaaaa]%s[/color][/center]" % hint)
	_text.text = "\n".join(lines)


func _render_players() -> void:
	var lines: Array[String] = ["[center][b]%s[/b][/center]" % I18n.text("MENU_PLAYERS_TITLE"), ""]
	var visible_slots := floori(VISIBLE_PLAYER_ROWS / 2.0)
	var current_slot := floori(_row / 2.0)
	if current_slot < _player_first_slot:
		_player_first_slot = current_slot
	elif current_slot >= _player_first_slot + visible_slots:
		_player_first_slot = current_slot - visible_slots + 1
	var first_slot := _player_first_slot
	var last_slot := mini(first_slot + visible_slots, GameConfig.SLOT_COUNT)
	if first_slot > 0:
		lines.append("[color=#888888]%s[/color]" % I18n.text("MENU_UP_MORE_PLAYERS"))
	for slot in range(first_slot, last_slot):
		var color: Color = ArenaView3D.PLAYER_COLORS[slot % ArenaView3D.PLAYER_COLORS.size()]
		lines.append("[color=#%s][b]%s %d[/b][/color]  [color=#888888](%s)[/color]" % [
			color.to_html(false), I18n.text("MENU_PLACE"), slot + 1, _controller_label(config.slots[slot])])
		var name_text := config.name_of(slot)
		if _editing and _edit_kind == "name" and _edit_slot == slot:
			name_text = "[color=#ffdd44]%s█[/color]" % _edit_text
		lines.append(_row_line(slot * 2, I18n.text("MENU_NAME"), name_text, false))
		var team := config.teams[slot]
		var team_text := _team_text(team)
		if team > 0:
			team_text = "[color=#%s]%s[/color]" % [GameConfig.TEAM_COLORS[team - 1].to_html(false), team_text]
			if config.slots[slot] != GameConfig.Controller.OFF and config.effective_team(slot) == 0:
				team_text += " [color=#888888]%s[/color]" % I18n.text("MENU_ALONE_COUNTS_AS_SINGLE")
		lines.append(_row_line(slot * 2 + 1, I18n.text("MENU_TEAM"), team_text, true))
	if last_slot < GameConfig.SLOT_COUNT:
		lines.append("[color=#888888]%s[/color]" % I18n.text("MENU_DOWN_MORE_PLAYERS"))
	lines.append("")
	var hint := I18n.text("MENU_NAME_HINT") if _editing else I18n.text("MENU_NAME_TEAM_HINT")
	lines.append("[center][color=#aaaaaa]%s[/color][/center]" % hint)
	_text.text = "\n".join(lines)


func _render_match() -> void:
	var lines: Array[String] = ["[center][b]%s[/b][/center]" % I18n.text("MENU_MATCH_TITLE"), ""]
	lines.append(_row_line(0, I18n.text("MENU_POINTS_TO_WIN"), str(config.points_to_win), true))
	lines.append(_row_line(1, I18n.text("MENU_SUDDEN_DEATH_AFTER"), "%d s" % config.round_time_s, true))
	var pos_label := I18n.text("MENU_RANDOM") if config.random_positions else I18n.text("MENU_FIXED")
	lines.append(_row_line(2, I18n.text("MENU_START_POSITIONS"), pos_label, true))
	var ord_label := I18n.text("MENU_RANDOM") if config.random_order else I18n.text("MENU_SEQUENTIAL")
	lines.append(_row_line(3, I18n.text("MENU_ORDER"), ord_label, true))
	lines.append("")
	lines.append("[center][color=#aaaaaa]%s[/color][/center]" % I18n.text("MENU_BACK").replace("Esc / B:", "↑↓ wählen, ←→ ändern, Esc / B:"))
	_text.text = "\n".join(lines)


func _render_settings() -> void:
	var lines: Array[String] = ["[center][b]%s[/b][/center]" % I18n.text("MENU_SETTINGS_TITLE"), ""]
	lines.append(_row_line(0, I18n.text("MENU_MUSIC"), config.music_label(), true))
	lines.append(_row_line(1, I18n.text("MENU_SFX"), config.sfx_label(), true))
	lines.append(_row_line(2, I18n.text("MENU_LANGUAGE"), LANGS[_lang_index], true))
	lines.append(_row_line(3, I18n.text("MENU_EXTERNAL_MAPS"), _external_dir_label(), false))
	lines.append("")
	var hint := I18n.text("MENU_PATH_HINT") if _editing and _edit_kind == "mapdir" else I18n.text("MENU_SETTINGS_HINT")
	lines.append("[center][color=#aaaaaa]%s[/color][/center]" % hint)
	_text.text = "\n".join(lines)


func _render_maps() -> void:
	var active := config.active_slots()
	var playable := catalog.playable(active)
	var lines: Array[String] = ["[center][b]%s[/b][/center]" % I18n.text("MENU_CARDS_TITLE"), ""]
	if _row < _map_scroll:
		_map_scroll = _row
	elif _row >= _map_scroll + VISIBLE_MAP_ROWS:
		_map_scroll = _row - VISIBLE_MAP_ROWS + 1
	var last := mini(_map_scroll + VISIBLE_MAP_ROWS, catalog.names.size())
	lines.append("[color=#888888]%s[/color]" % (I18n.text("MENU_MORE_CARDS") if _map_scroll > 0 else " "))
	for i in range(_map_scroll, last):
		var map := catalog.names[i]
		var box := "[lb]x]" if config.is_in_pool(map) else "[lb] ]"
		var label := "%s %s" % [box, map.get_basename()]
		if not playable.has(map):
			label = "[color=#666666]%s[/color]" % label
		elif config.is_in_pool(map):
			label = "[color=#ffdd44]%s[/color]" % label
		lines.append(_row_line(i, label, "", false))
	lines.append("[color=#888888]%s[/color]" % (I18n.text("MENU_LESS_CARDS") if last < catalog.names.size() else " "))
	lines.append("")
	var current := catalog.names[_row]
	var capacity := catalog.start_count(current)
	var limit_color := "#aaaaaa" if playable.has(current) else "#ff8a80"
	lines.append("[color=%s]%s[/color]" % [limit_color, I18n.text("MENU_MAPS_ONLY_FOR_UP_TO") % capacity])
	lines.append("[color=#aaaaaa]%s[/color]" % (I18n.text("MENU_MAPS_SELECTED") % [config.effective_pool(playable).size(), playable.size()]))
	lines.append("")
	lines.append("[color=#aaaaaa]%s[/color]" % I18n.text("MENU_MAP_SHORTCUTS"))
	lines.append("[color=#aaaaaa]%s[/color]" % I18n.text("MENU_MAP_SHORTCUTS2"))
	lines.append("[color=#aaaaaa]%s[/color]" % I18n.text("MENU_BACK"))
	_text.text = "\n".join(lines)
	_preview.data = catalog.data_of(current)
	_preview.active_slots = active
	_preview.queue_redraw()


func _render_help() -> void:
	var lines: Array[String] = [
		"[center][b]%s[/b][/center]" % I18n.text("MENU_HELP_TITLE"),
		"",
		I18n.text("MENU_HELP_P1"),
		I18n.text("MENU_HELP_P2"),
		I18n.text("MENU_HELP_PAD"),
		"",
		I18n.text("MENU_HELP_SHORTCUTS"),
		I18n.text("MENU_HELP_ESC"),
		I18n.text("MENU_HELP_M"),
		I18n.text("MENU_HELP_F4"),
		"",
		I18n.text("MENU_HELP_R"),
		I18n.text("MENU_HELP_F5"),
		"",
		I18n.text("MENU_HELP_CARDS_TEAMS"),
		I18n.text("MENU_HELP_CARDS_TEXT"),
		I18n.text("MENU_HELP_ORDER_TEXT"),
		I18n.text("MENU_HELP_POS_TEXT"),
		I18n.text("MENU_HELP_EXTERNAL_TEXT"),
		I18n.text("MENU_HELP_CLANBOMBER_DIR_TEXT"),
		I18n.text("MENU_HELP_TEAMS_TEXT"),
		"",
		I18n.text("MENU_HELP_PRESS_ANY")
	]
	_text.text = "\n".join(lines)


func _row_line(row: int, label: String, value: String, adjustable: bool) -> String:
	var marker := "▶ " if row == _row else "   "
	var shown := value
	if adjustable and value != "" and row == _row:
		shown = "◀ %s ▶" % value
	return "%s%s    %s" % [marker, label, shown]


func _value_text(controller: int, pads: Array[int]) -> String:
	var text := _controller_label(controller)
	if controller >= GameConfig.Controller.PAD_1 and controller <= GameConfig.Controller.PAD_8:
		if not pads.has(controller - GameConfig.Controller.PAD_1):
			text += " " + I18n.text("CTRL_NOT_CONNECTED")
	return text


func _controller_label(controller: int) -> String:
	match controller:
		GameConfig.Controller.OFF:
			return I18n.text("CTRL_OFF")
		GameConfig.Controller.KEYBOARD_1:
			return I18n.text("CTRL_KEYBOARD_1")
		GameConfig.Controller.KEYBOARD_2:
			return I18n.text("CTRL_KEYBOARD_2")
		_:
			if controller >= GameConfig.Controller.PAD_1 and controller <= GameConfig.Controller.PAD_8:
				return I18n.text("CTRL_PAD") % (controller - GameConfig.Controller.PAD_1 + 1)
			return GameConfig.NAMES[controller]


func _team_text(team: int) -> String:
	if team <= 0:
		return I18n.text("TEAM_NO_TEAM")
	return I18n.text("TEAM_LABEL") + GameConfig.TEAM_NAMES[team - 1]
