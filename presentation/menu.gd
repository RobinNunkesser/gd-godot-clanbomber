class_name GameMenu
extends PanelContainer
## Startmenü: Steuerung je Spielerplatz, Karte, Punkte. Bedienung mit Pfeiltasten/D-Pad, Enter/Leertaste/A.

signal start_requested

const ROW_MAP := GameConfig.SLOT_COUNT
const ROW_POINTS := GameConfig.SLOT_COUNT + 1
const ROW_START := GameConfig.SLOT_COUNT + 2
const ROW_HELP := GameConfig.SLOT_COUNT + 3
const ROW_QUIT := GameConfig.SLOT_COUNT + 4
const ROW_COUNT := GameConfig.SLOT_COUNT + 5

var config := GameConfig.new()
var maps: Array[String] = []
var _row := 0
var _show_help := false
var _text := RichTextLabel.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(680, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
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
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _show_help:
		if event.is_pressed():
			_show_help = false
			get_viewport().set_input_as_handled()
			_render()
		return
	if event.is_action_pressed("ui_up"):
		_row = posmod(_row - 1, ROW_COUNT)
	elif event.is_action_pressed("ui_down"):
		_row = posmod(_row + 1, ROW_COUNT)
	elif event.is_action_pressed("ui_left"):
		_change(-1)
	elif event.is_action_pressed("ui_right"):
		_change(1)
	elif event.is_action_pressed("ui_accept"):
		_accept()
	elif event.is_action_pressed("ui_cancel"):
		if config.is_startable():
			visible = false
			start_requested.emit()
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


func _accept() -> void:
	if _row == ROW_START:
		if config.is_startable():
			visible = false
			start_requested.emit()
	elif _row == ROW_HELP:
		_show_help = true
	elif _row == ROW_QUIT:
		get_tree().quit()
	elif _row >= ROW_MAP:
		if config.is_startable():
			visible = false
			start_requested.emit()
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
	lines.append("")
	var start := "Start" if config.is_startable() else "Start (mindestens 2 Spieler nötig)"
	lines.append(_row_line(ROW_START, "[b]%s[/b]" % start, ""))
	lines.append(_row_line(ROW_HELP, "Steuerung & Hilfe", ""))
	lines.append(_row_line(ROW_QUIT, "Spiel beenden", ""))
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
		"  [b]Esc[/b]        Menü / Pause aufrufen",
		"  [b]F2[/b]         Ansicht umschalten (3D / 2D)",
		"  [b]R[/b]          Aktuelle Runde neu starten",
		"  [b]F5[/b]         Neues Match starten (Punkte zurücksetzen)",
		"  [b]N / P[/b]      Nächste / vorherige Karte laden",
		"  [b]M[/b]          Musik stummschalten (Mute)",
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
