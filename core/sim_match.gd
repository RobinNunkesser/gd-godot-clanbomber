class_name SimMatch
extends RefCounted
## Rundenverwaltung: erkennt das Rundenende, vergibt Punkte und entscheidet das Match.
## Regeln nach dem Original (Observer::step, GameStatus::analyze_game):
## Sobald höchstens ein Spieler lebt und keine Explosion mehr läuft und kein lebender
## Spieler mehr fällt, bekommt jeder Überlebende einen Punkt (bei Unentschieden keiner).

enum State { PLAYING, ROUND_OVER, MATCH_OVER }

signal round_ended(winners: Array[int])
signal match_ended(winner_id: int)

var points_to_win := SimConstants.POINTS_TO_WIN
var state := State.PLAYING
var points: Dictionary = {}
var kills: Dictionary = {}
var rounds_played := 0
var last_winners: Array[int] = []
var match_winner := -1


func _init(p_points_to_win: int = SimConstants.POINTS_TO_WIN) -> void:
	points_to_win = p_points_to_win


# Wird nach jedem Tick aufgerufen. Gibt true zurück, wenn die Runde genau jetzt endet.
func update(world: SimWorld) -> bool:
	if state != State.PLAYING or world.players.size() < SimConstants.MIN_PLAYERS_FOR_MATCH:
		return false
	var alive: Array[int] = []
	for id: int in world.players:
		var player: SimPlayer = world.players[id]
		if player.alive:
			if player.is_falling():
				return false
			alive.append(id)
	if alive.size() > 1 or not world.explosions.is_empty():
		return false
	_finish_round(world, alive)
	return true


func _finish_round(world: SimWorld, alive: Array[int]) -> void:
	rounds_played += 1
	last_winners = alive
	for id: int in world.players:
		points[id] = points.get(id, 0) + (1 if alive.has(id) else 0)
		kills[id] = kills.get(id, 0) + world.players[id].kills
	match_winner = _leader()
	state = State.MATCH_OVER if match_winner >= 0 else State.ROUND_OVER
	round_ended.emit(alive)
	if match_winner >= 0:
		match_ended.emit(match_winner)


# Pro Runde steigt höchstens ein Punktestand, daher gibt es nie zwei Spieler gleichzeitig am Ziel.
func _leader() -> int:
	for id: int in points:
		if points[id] >= points_to_win:
			return id
	return -1


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
	rounds_played = 0
	last_winners = []
	match_winner = -1
	state = State.PLAYING


# Registriert die Teilnehmer, damit das Scoreboard schon vor der ersten Runde alle zeigt.
func register_players(ids: Array) -> void:
	for id: int in ids:
		if not points.has(id):
			points[id] = 0
			kills[id] = 0
