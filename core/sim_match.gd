class_name SimMatch
extends RefCounted
## Rundenverwaltung: erkennt das Rundenende, vergibt Punkte und entscheidet das Match.
## Regeln nach dem Original (Observer::active_players/step, GameStatus::analyze_game):
## Sobald höchstens eine "Partei" lebt (ein Team zählt als eine Partei, jeder Einzelspieler als eigene),
## keine Explosion mehr läuft und kein lebender Spieler mehr fällt, bekommt jeder Überlebende einen Punkt
## (bei Unentschieden keiner). Ein Team gewinnt das Match, sobald die Summe der Teampunkte
## Mitgliederzahl * Zielpunkte erreicht (GameStatus_Team::analyze_game), ein Einzelspieler mit Zielpunkten.

enum State { PLAYING, ROUND_OVER, MATCH_OVER }

signal round_ended(winners: Array[int])
signal match_ended(winner_id: int)

var points_to_win := SimConstants.POINTS_TO_WIN
var state := State.PLAYING
var points: Dictionary = {}
var kills: Dictionary = {}
# Spieler-ID -> Team (0 = kein Team).
var teams: Dictionary = {}
var rounds_played := 0
var last_winners: Array[int] = []
# ID eines Spielers der Siegerpartei (-1 = noch kein Match-Sieger) und deren Team (0 = Einzelspieler).
var match_winner := -1
var winning_team := 0


func _init(p_points_to_win: int = SimConstants.POINTS_TO_WIN) -> void:
	points_to_win = p_points_to_win


# Wird nach jedem Tick aufgerufen. Gibt true zurück, wenn die Runde genau jetzt endet.
func update(world: SimWorld) -> bool:
	if state != State.PLAYING or world.players.size() < SimConstants.MIN_PLAYERS_FOR_MATCH:
		return false
	var alive: Array[int] = []
	var factions: Dictionary = {}
	for id: int in world.players:
		var player: SimPlayer = world.players[id]
		if player.alive:
			if player.is_falling():
				return false
			alive.append(id)
			factions[_faction_key(id, player.team)] = true
	if factions.size() > 1 or not world.explosions.is_empty() or _has_flying_bomb(world):
		return false
	_finish_round(world, alive)
	return true


static func _has_flying_bomb(world: SimWorld) -> bool:
	for bomb: SimBomb in world.bombs:
		if bomb.flying:
			return true
	return false


# Teams teilen sich eine Partei; Einzelspieler (Team 0) sind je eine eigene.
static func _faction_key(id: int, team: int) -> String:
	return "t%d" % team if team > 0 else "p%d" % id


func _finish_round(world: SimWorld, alive: Array[int]) -> void:
	rounds_played += 1
	last_winners = alive
	for id: int in world.players:
		points[id] = points.get(id, 0) + (1 if alive.has(id) else 0)
		kills[id] = kills.get(id, 0) + world.players[id].kills
		teams[id] = world.players[id].team
	_decide_match(alive)
	state = State.MATCH_OVER if match_winner >= 0 else State.ROUND_OVER
	round_ended.emit(alive)
	if match_winner >= 0:
		match_ended.emit(match_winner)


# Bevorzugt die Partei der Rundensieger; pro Runde steigt nur deren Punktestand.
func _decide_match(alive: Array[int]) -> void:
	match_winner = -1
	winning_team = 0
	for id: int in alive:
		var team := team_of(id)
		if team > 0:
			if team_points(team) >= team_size(team) * points_to_win:
				match_winner = id
				winning_team = team
				return
		elif points_of(id) >= points_to_win:
			match_winner = id
			return


func team_of(id: int) -> int:
	return teams.get(id, 0)


func has_teams() -> bool:
	for id: int in teams:
		if teams[id] > 0:
			return true
	return false


func team_size(team: int) -> int:
	var count := 0
	for id: int in teams:
		if teams[id] == team:
			count += 1
	return count


func team_points(team: int) -> int:
	var sum := 0
	for id: int in teams:
		if teams[id] == team:
			sum += points_of(id)
	return sum


func points_of(id: int) -> int:
	return points.get(id, 0)


func kills_of(id: int) -> int:
	return kills.get(id, 0)


# Spieler nach Punkten absteigend, bei Gleichstand nach Kills, dann nach Nummer.
func ranking() -> Array[int]:
	var ids: Array[int] = []
	for id: int in points:
		ids.append(id)
	ids.sort_custom(func(a: int, b: int) -> bool:
		if points[a] != points[b]:
			return points[a] > points[b]
		if kills_of(a) != kills_of(b):
			return kills_of(a) > kills_of(b)
		return a < b)
	return ids


# Bereitet die nächste Runde vor; die Punkte bleiben erhalten.
func start_next_round() -> void:
	if state == State.ROUND_OVER:
		state = State.PLAYING
		last_winners = []


func reset() -> void:
	points.clear()
	kills.clear()
	teams.clear()
	rounds_played = 0
	last_winners = []
	match_winner = -1
	winning_team = 0
	state = State.PLAYING


# Registriert die Teilnehmer, damit das Scoreboard schon vor der ersten Runde alle zeigt.
func register_players(ids: Array) -> void:
	for id: int in ids:
		if not points.has(id):
			points[id] = 0
			kills[id] = 0


# Hält die Teamzuordnung fest, damit auch das Scoreboard vor der ersten Runde Teams gruppieren kann.
func set_team(id: int, team: int) -> void:
	teams[id] = team
