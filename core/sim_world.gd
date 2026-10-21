class_name SimWorld
extends RefCounted

signal bomb_placed(bomb: SimBomb)
signal bomb_exploded(bomb: SimBomb, explosion: SimExplosion)
signal box_destroyed(cell: Vector2i)
signal extra_spawned(cell: Vector2i, type: int)
signal extra_destroyed(cell: Vector2i)
signal player_died(player_id: int, killer_id: int)

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var board: SimBoard
var rng: RandomNumberGenerator
var players: Dictionary = {}
var bombs: Array[SimBomb] = []
var explosions: Array[SimExplosion] = []
# Vector2i -> SimExtra.Type
var extras: Dictionary = {}
# Extra-Typen, die nicht aus Boxen fallen (z. B. Kick/Glove als Startausrüstung).
var disabled_extras: Array = []

var _next_bomb_id := 1
# Vom Strahl getroffene Boxen bleiben bis zum Tick-Ende blockierend; erst dann Drop.
var _pending_boxes: Dictionary = {}


func _init(p_board: SimBoard, p_rng: RandomNumberGenerator = null) -> void:
	board = p_board
	if p_rng == null:
		p_rng = RandomNumberGenerator.new()
		p_rng.seed = 0
	rng = p_rng


func add_player(id: int, cell: Vector2i) -> SimPlayer:
	var player := SimPlayer.new()
	player.id = id
	player.cell = cell
	players[id] = player
	return player


# Setzt die gewünschte Bewegungsrichtung. Diagonale Eingaben werden auf die horizontale Achse reduziert.
func set_move_dir(player_id: int, dir: Vector2i) -> void:
	var player: SimPlayer = players.get(player_id)
	if player == null:
		return
	var clean := Vector2i(signi(dir.x), 0) if dir.x != 0 else Vector2i(0, signi(dir.y))
	if clean != player.move_dir:
		player.move_remainder_milli = 0
	player.move_dir = clean


func is_other_player_in(cell: Vector2i, except_id: int) -> bool:
	for id in players:
		var other: SimPlayer = players[id]
		if id != except_id and other.alive and other.cell == cell:
			return true
	return false


func bomb_at(cell: Vector2i) -> SimBomb:
	for bomb in bombs:
		if bomb.cell == cell:
			return bomb
	return null


func place_bomb(player_id: int) -> SimBomb:
	var player: SimPlayer = players.get(player_id)
	if player == null or not player.can_place_bomb():
		return null
	if board.is_blocking(player.cell) or bomb_at(player.cell) != null:
		return null
	var bomb := SimBomb.new()
	bomb.id = _next_bomb_id
	_next_bomb_id += 1
	bomb.owner_id = player_id
	bomb.cell = player.cell
	bomb.power = player.power
	bombs.append(bomb)
	player.active_bombs += 1
	bomb_placed.emit(bomb)
	return bomb


func tick(dt_ms: int) -> void:
	_move_players(dt_ms)
	_age_explosions(dt_ms)
	for bomb in bombs:
		bomb.timer_ms -= dt_ms
	_detonate_due_bombs()
	_resolve_pending_boxes()
	_apply_explosion_damage()


func _move_players(dt_ms: int) -> void:
	for id in players:
		var player: SimPlayer = players[id]
		if not player.alive or player.move_dir == Vector2i.ZERO:
			continue
		player.move_remainder_milli += player.speed() * dt_ms
		var span := player.move_remainder_milli / 1000
		player.move_remainder_milli -= span * 1000
		if not SimMovement.advance(self, player, player.move_dir, span):
			player.move_remainder_milli = 0


func _age_explosions(dt_ms: int) -> void:
	for explosion in explosions:
		explosion.remaining_ms -= dt_ms
	explosions = explosions.filter(func(e: SimExplosion) -> bool: return e.remaining_ms > 0)


func _detonate_due_bombs() -> void:
	while true:
		var due: SimBomb = null
		for bomb in bombs:
			if bomb.timer_ms <= 0 and (due == null or bomb.id < due.id):
				due = bomb
		if due == null:
			return
		_detonate(due)


func _detonate(bomb: SimBomb) -> void:
	bombs.erase(bomb)
	var owner: SimPlayer = players.get(bomb.owner_id)
	if owner != null:
		owner.active_bombs -= 1
	var explosion := SimExplosion.new()
	explosion.owner_id = bomb.owner_id
	explosion.origin = bomb.cell
	explosion.cells.append(bomb.cell)
	for dir in DIRECTIONS:
		_cast_ray(explosion, bomb.power, dir)
	for cell in explosion.cells:
		_chain_bomb_at(cell)
	explosions.append(explosion)
	bomb_exploded.emit(bomb, explosion)


# Stoppt vor Blockierern und vor Extras; nur dieses erste Hindernis wird zerstört.
func _cast_ray(explosion: SimExplosion, power: int, dir: Vector2i) -> void:
	for step in range(1, power + 1):
		var cell := explosion.origin + dir * step
		if not board.in_bounds(cell):
			return
		var tile := board.get_tile(cell)
		if SimTile.is_blocking(tile):
			if SimTile.is_destructible(tile):
				_pending_boxes[cell] = true
			return
		if extras.has(cell):
			extras.erase(cell)
			extra_destroyed.emit(cell)
			return
		explosion.cells.append(cell)


func _chain_bomb_at(cell: Vector2i) -> void:
	for other in bombs:
		if other.cell == cell:
			other.timer_ms = mini(other.timer_ms, SimConstants.BOMB_CHAIN_DELAY_MS)


func _resolve_pending_boxes() -> void:
	for cell: Vector2i in _pending_boxes:
		board.set_tile(cell, SimTile.Type.GROUND)
		box_destroyed.emit(cell)
		var drop := SimExtra.roll(rng, disabled_extras)
		if drop != SimExtra.Type.NONE:
			extras[cell] = drop
			extra_spawned.emit(cell, drop)
	_pending_boxes.clear()


func _apply_explosion_damage() -> void:
	for explosion in explosions:
		for player_id in players:
			var player: SimPlayer = players[player_id]
			if player.alive and player.cell in explosion.cells:
				player.alive = false
				var killer_id := explosion.owner_id
				if killer_id != player.id and players.has(killer_id):
					players[killer_id].kills += 1
				player_died.emit(player.id, killer_id)
