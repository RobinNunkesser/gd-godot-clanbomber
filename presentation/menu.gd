class_name GameMenu
extends PanelContainer
## Start- und Pausemenü: Steuerung je Spielerplatz, Karte, Punkte, Hilfe und Beenden.
## Bedienung mit Pfeiltasten/D-Pad, Enter/Leertaste/Gamepad A, Esc zum Weiterspielen.

signal start_requested
signal resume_requested
signal audio_changed

const ROW_MAP := GameConfig.SLOT_COUNT
const ROW_POINTS := GameConfig.SLOT_COUNT + 1
const ROW_MUSIC := GameConfig.SLOT_COUNT + 2
const ROW_SFX := GameConfig.SLOT_COUNT + 3

var config := GameConfig.new()
var maps: Array[String] = []
var is_game_active := false

var _row := 0
var _show_help := false
var _text := RichTextLabel.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(680, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	focus_mode = Control.FOCUS_NONE
	_text.focus_mode = Control.FOCUS_NONE
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("bold_font_size", 30)
	add_child(_text)
	visible = false


func open() -> void:
	visible = true
	_show_help = false
	_row = _row_resume() if is_game_active else _row_start()
	_render()


func resume() -> void:
	if is_game_active:
		visible = false
		resume_requested.emit()


func _row_resume() -> int:
	return GameConfig.SLOT_COUNT + 4 if is_game_active else -1


func _row_start() -> int:
	return GameConfig.SLOT_COUNT + 5 if is_game_active else GameConfig.SLOT_COUNT + 4


func _row_help() -> int:
	return GameConfig.SLOT_COUNT + 6 if is_game_active else GameConfig.SLOT_COUNT + 5


func _row_quit() -> int:
	return GameConfig.SLOT_COUNT + 7 if is_game_active else GameConfig.SLOT_COUNT + 6


func _row_count() -> int:
	return GameConfig.SLOT_COUNT + (6 if is_game_active else 5)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _show_help:
		if event.is_pressed():
			_show_help = false
			get_viewport().set_input_as_handled()
			_render()
		return

	var key := event as InputEventKey
	var key_code := 0
	if key != null:
		key_code = key.physical_keycode if key.keycode == 0 else key.keycode

	if event.is_action_pressed("ui_cancel") or (key != null and not key.echo and key.pressed and key_code == KEY_ESCAPE):
		if is_game_active:
			visible = false
			get_viewport().set_input_as_handled()
			resume_requested.emit()
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


func _change(step: int) -> void:
	if _row < GameConfig.SLOT_COUNT:
		config.cycle_slot(_row, step)
	elif _row == ROW_MAP:
		config.cycle_map(maps, step)
	elif _row == ROW_POINTS:
		config.cycle_points(step)
	elif _row == ROW_MUSIC:
		config.cycle_music(step)
		audio_changed.emit()
	elif _row == ROW_SFX:
		config.cycle_sfx(step)
		audio_changed.emit()


func _accept() -> void:
	if _row == _row_resume():
		resume()
	elif _row == _row_start():
		if config.is_startable():
			visible = false
			start_requested.emit()
	elif _row == _row_help():
		_show_help = true
	elif _row == _row_quit():
		get_tree().quit()
	elif _row == ROW_MUSIC or _row == ROW_SFX or _row == ROW_MAP or _row == ROW_POINTS:
		_change(1)
	else:
		_change(1)


func _render() -> void:
	if _show_help:
		_render_help()
		return
	var lines: Array[String] = ["[center][b]ClanBomber[/b][/center]", ""]
	var pads := Input.get_connected_joypads()
	for slot in GameConfig.SLOT_COUNT:
		var color: Color = ArenaView3D.PLAYER_COLORS[slot % ArenaView3D.PLAYER_COLORS.size()]
		var value := _value_text(config.slots[slot], pads)
		lines.append(_row_line(slot, "[color=#%s]Spieler %d[/color]" % [color.to_html(false), slot + 1], value))
	var map_text := "Zufall" if config.is_random_map() else config.map_name.get_basename()
	lines.append(_row_line(ROW_MAP, "Karte", map_text))
	lines.append(_row_line(ROW_POINTS, "Punkte zum Sieg", str(config.points_to_win)))
	lines.append(_row_line(ROW_MUSIC, "Musik", config.music_label()))
	lines.append(_row_line(ROW_SFX, "Ton-Effekte", config.sfx_label()))
	lines.append("")
	if is_game_active:
		lines.append(_row_line(_row_resume(), "[b]Weiterspielen (Resume)[/b]", ""))
		lines.append(_row_line(_row_start(), "[b]Neues Match starten[/b]", ""))
	else:
		var start := "Start" if config.is_startable() else "Start (mindestens 2 Spieler nötig)"
		lines.append(_row_line(_row_start(), "[b]%s[/b]" % start, ""))
	lines.append(_row_line(_row_help(), "Steuerung & Hilfe", ""))
	lines.append(_row_line(_row_quit(), "Spiel beenden", ""))
	lines.append("")
	lines.append("[center][color=#aaaaaa]↑↓ wählen, ←→ ändern, Enter / Leertaste / Gamepad A bestätigen[/color][/center]")
	_text.text = "\n".join(lines)


func _render_help() -> void:
	var lines: Array[String] = [
		"[center][b]Steuerung & Hilfe[/b][/center]",
		"",
		"[color=#ffdd44][b]Spieler 1 (Tastatur):[/b][/color]   [b]W, A, S, D[/b] = Laufen  |  [b]Leertaste[/b] = Bombe legen",
		"[color=#44ddff][b]Spieler 2 (Tastatur):[/b][/color]   [b]Pfeiltasten[/b] = Laufen  |  [b]Enter[/b] = Bombe legen",
		"[color=#66ff66][b]Gamepad (1–4):[/b][/color]         [b]D-Pad / Stick[/b] = Laufen  |  [b]A-Taste[/b] = Bombe legen",
		"",
		"[color=#ffaaee][b]Kurzbefehle im Spiel:[/b][/color]",
		"  [b]Esc[/b]        Menü aufrufen / Weiterspielen (bzw. Beenden)",
		"  [b]M[/b]          Musik stummschalten / aktivieren",
		"  [b]F4[/b]         Ton-Effekte stummschalten / aktivieren",
		"  [b]N[/b]          Nächste Karte laden (Next Map)",
		"  [b]P[/b]          Vorherige Karte laden (Previous Map)",
		"  [b]R[/b]          Aktuelle Runde neu starten",
		"  [b]F5[/b]         Neues Match starten (Punkte zurücksetzen)",
		"",
		"[center][color=#aaaaaa]Beliebige Taste / Button drücken zum Zurückkehren[/color][/center]"
	]
	_text.text = "\n".join(lines)


func _row_line(row: int, label: String, value: String) -> String:
	var marker := "▶ " if row == _row else "   "
	return "%s%s    %s" % [marker, label, "◀ %s ▶" % value if value != "" and row == _row else value]


func _value_text(controller: int, pads: Array[int]) -> String:
	var text: String = GameConfig.NAMES[controller]
	if controller >= GameConfig.Controller.PAD_1 and controller <= GameConfig.Controller.PAD_4:
		if not pads.has(controller - GameConfig.Controller.PAD_1):
			text += " (nicht verbunden)"
	return text
