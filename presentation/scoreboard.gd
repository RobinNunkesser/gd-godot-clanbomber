class_name Scoreboard
extends PanelContainer
## Overlay mit Punkteständen am Rundenende und nach dem Match.

var _text := RichTextLabel.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(560, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("bold_font_size", 28)
	add_child(_text)
	visible = false


func show_result(match_state: SimMatch) -> void:
	var lines: Array[String] = []
	lines.append("[center][b]%s[/b][/center]" % _headline(match_state))
	lines.append("")
	for id in match_state.ranking():
		var color: Color = ArenaView3D.PLAYER_COLORS[(id - 1) % ArenaView3D.PLAYER_COLORS.size()]
		var won := match_state.last_winners.has(id)
		lines.append("[color=#%s]Spieler %d[/color]   %s   Kills %d%s" % [
			color.to_html(false), id, _pips(match_state.points_of(id), match_state.points_to_win),
			match_state.kills_of(id), "   ◀ Rundensieg" if won else ""])
	lines.append("")
	if match_state.state == SimMatch.State.MATCH_OVER:
		lines.append("[center]Leertaste / Enter: neues Match[/center]")
	else:
		lines.append("[center]Leertaste / Enter: nächste Runde[/center]")
	_text.text = "\n".join(lines)
	visible = true


func _headline(match_state: SimMatch) -> String:
	if match_state.state == SimMatch.State.MATCH_OVER:
		return "Spieler %d gewinnt das Match!" % match_state.match_winner
	var winners := match_state.last_winners
	var who := "Unentschieden" if winners.is_empty() else "Spieler %d gewinnt die Runde" % winners[0]
	return "Runde %d: %s" % [match_state.rounds_played, who]


func _pips(points: int, target: int) -> String:
	return "●".repeat(mini(points, target)) + "○".repeat(maxi(target - points, 0))
