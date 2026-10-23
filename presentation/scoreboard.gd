class_name Scoreboard
extends PanelContainer
## Overlay mit Punkteständen am Rundenende. Hat ein Spieler oder Team die Zielpunktzahl erreicht,
## wird daraus der Sieger-Bildschirm mit den Aktionen "Neues Match" und "Zurück zum Menü".

enum Action { NEW_MATCH, MENU }

const ACTION_LABELS: Array[String] = ["SCOREBOARD_NEW_MATCH", "SCOREBOARD_BACK_TO_MENU"]
const GOLD := Color("ffd54f")

var selected := Action.NEW_MATCH

var _text := RichTextLabel.new()
var _match_over := false
var _pulse: Tween
var _last_match: SimMatch
var _last_names: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(620, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	focus_mode = Control.FOCUS_NONE
	_text.focus_mode = Control.FOCUS_NONE
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("bold_font_size", 28)
	add_child(_text)
	visible = false


func is_match_over() -> bool:
	return _match_over


func selected_action() -> Action:
	return selected


# names: Spieler-ID -> Anzeigename.
func show_result(match_state: SimMatch, names: Dictionary) -> void:
	_match_over = match_state.state == SimMatch.State.MATCH_OVER
	selected = Action.NEW_MATCH
	_set_pulse(_match_over)
	_render(match_state, names)
	visible = true


func move_selection(step: int) -> void:
	if not _match_over:
		return
	selected = posmod(selected + step, ACTION_LABELS.size()) as Action
	_render_cached()


func _render_cached() -> void:
	if _last_match != null:
		_render(_last_match, _last_names)


func _render(match_state: SimMatch, names: Dictionary) -> void:
	_last_match = match_state
	_last_names = names
	var lines: Array[String] = []
	lines.append("[center]%s[/center]" % _headline(match_state, names))
	lines.append("")
	if match_state.has_teams():
		_append_team_table(lines, match_state, names)
	else:
		for id in match_state.ranking():
			lines.append(_player_line(id, match_state, names))
	lines.append("")
	if _match_over:
		for action in ACTION_LABELS.size():
			var marker := "▶ " if action == selected else "   "
			var color := GOLD.to_html(false) if action == selected else "cccccc"
			lines.append("[center][color=#%s]%s%s[/color][/center]" % [color, marker, tr(ACTION_LABELS[action])])
		lines.append("")
		if TranslationServer.get_locale().begins_with("de"):
			lines.append("[center][color=#aaaaaa]↑↓ wählen, Leertaste / Enter / Gamepad A bestätigen[/color][/center]")
		else:
			lines.append("[center][color=#aaaaaa]↑↓ select, Space / Enter / Gamepad A confirm[/color][/center]")
	else:
		if TranslationServer.get_locale().begins_with("de"):
			lines.append("[center]Leertaste / Enter: nächste Runde[/center]")
		else:
			lines.append("[center]Space / Enter: next round[/center]")
	_text.text = "\n".join(lines)


func _headline(match_state: SimMatch, names: Dictionary) -> String:
	if _match_over:
		var who := _winner_name(match_state, names)
		return "[font_size=36][color=#%s][b]★ %s gewinnt das Match! ★[/b][/color][/font_size]" % [GOLD.to_html(false), who]
	var winners := match_state.last_winners
	if winners.is_empty():
		return "[b]Unentschieden[/b]"
	var team := match_state.team_of(winners[0])
	if team > 0:
		return "[b]%s gewinnt die Runde[/b]" % GameConfig.team_label(team)
	return "[b]%s gewinnt die Runde[/b]" % _name(winners[0], names)


func _winner_name(match_state: SimMatch, names: Dictionary) -> String:
	if match_state.winning_team > 0:
		return GameConfig.team_label(match_state.winning_team)
	return _name(match_state.match_winner, names)


func _name(id: int, names: Dictionary) -> String:
	return names.get(id, "Spieler %d" % id)


func _player_line(id: int, match_state: SimMatch, names: Dictionary) -> String:
	var color: Color = ArenaView3D.PLAYER_COLORS[(id - 1) % ArenaView3D.PLAYER_COLORS.size()]
	var won := match_state.last_winners.has(id)
	return "[color=#%s]%s[/color]   %s   Kills %d%s" % [
		color.to_html(false), _name(id, names), _pips(match_state.points_of(id), match_state.points_to_win),
		match_state.kills_of(id), "   ◀ Rundensieg" if won else ""]


# Teams gruppiert (Punkte als Durchschnitt je Mitglied wie im Original), danach die Einzelspieler.
func _append_team_table(lines: Array[String], match_state: SimMatch, names: Dictionary) -> void:
	var ranking := match_state.ranking()
	for team in range(1, GameConfig.TEAM_COUNT + 1):
		var size := match_state.team_size(team)
		if size == 0:
			continue
		var color: Color = GameConfig.TEAM_COLORS[team - 1]
		var average := match_state.team_points(team) / size
		lines.append("[color=#%s][b]%s[/b][/color]   %s" % [
			color.to_html(false), GameConfig.team_label(team), _pips(average, match_state.points_to_win)])
		for id in ranking:
			if match_state.team_of(id) == team:
				lines.append("   " + _player_line(id, match_state, names))
	var singles: Array[String] = []
	for id in ranking:
		if match_state.team_of(id) == 0:
			singles.append(_player_line(id, match_state, names))
	if not singles.is_empty():
		lines.append("[color=#aaaaaa][b]Einzelspieler[/b][/color]")
		for line in singles:
			lines.append("   " + line)


func _pips(value: int, target: int) -> String:
	var filled := mini(value, target)
	return "●".repeat(filled) + "○".repeat(maxi(target - filled, 0))


# Leichtes Pulsieren des Sieger-Bildschirms; für normale Rundenstände aus.
func _set_pulse(enabled: bool) -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	modulate = Color.WHITE
	if not enabled:
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "modulate", Color(1.2, 1.15, 0.9), 0.7).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(self, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)
