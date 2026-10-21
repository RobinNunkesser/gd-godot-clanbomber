class_name SimWorld
extends RefCounted

signal bomb_placed(bomb: SimBomb)
signal bomb_exploded(bomb: SimBomb, explosion: SimExplosion)
signal box_destroyed(cell: Vector2i)
signal extra_spawned(cell: Vector2i, type: int)
signal extra_destroyed(cell: Vector2i)
signal bomb_kicked(bomb: SimBomb)
signal bomb_thrown(bomb: SimBomb)
signal bomb_landed(bomb: SimBomb)
signal bomb_trapped(bomb: SimBomb)
signal extra_collected(player_id: int, type: int)
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
# Pfeilfelder: Zelle -> {chill_ms, bomb_id} (letzte Bombe, um Neuankömmlinge zu erkennen).
var _arrow_state: Dictionary = {}
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
	if clean != Vector2i.ZERO:
		player.facing = -clean if player.disease == SimExtra.Type.REVERSE else clean
	player.move_dir = clean


func is_other_player_in(cell: Vector2i, except_id: int) -> bool:
	for id in players:
		var other: SimPlayer = players[id]
		if id != except_id and other.alive and other.cell == cell:
			return true
	return false


func bomb_at(cell: Vector2i) -> SimBomb:
	for bomb in bombs:
		if not bomb.flying and bomb.cell == cell:
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


# Bomben-Taste: Mit Handschuh und stehend wird eine Bombe auf der eigenen Zelle geworfen, sonst eine gelegt.
func action_bomb(player_id: int) -> SimBomb:
	var player: SimPlayer = players.get(player_id)
	if player == null or not player.alive:
		return null
	var under := bomb_at(player.cell)
	if under != null:
		if player.can_glove and not player.moved:
			throw_bomb(under, player.facing)
		return null
	return place_bomb(player_id)


func kick_bomb(bomb: SimBomb, dir: Vector2i) -> void:
	bomb.move_dir = dir
	bomb.move_remainder_milli = 0
	bomb_kicked.emit(bomb)


# Wirft die Bombe bis zu THROW_FIELDS Zellen weit. Wände und Boxen halten sie vorher an. Gibt zurück, ob sie fliegt.
func throw_bomb(bomb: SimBomb, dir: Vector2i) -> bool:
	if bomb.flying:
		return false
	var fields := _free_fields(bomb.cell, dir, SimConstants.THROW_FIELDS)
	if fields == 0:
		return false
	bomb.snap()
	bomb.move_dir = Vector2i.ZERO
	bomb.flying = true
	bomb.fly_dir = dir
	bomb.fly_remaining_px = fields * int(SimConstants.CELL_SIZE)
	bomb.fly_remainder_milli = 0
	bomb_thrown.emit(bomb)
	return true


func _free_fields(origin: Vector2i, dir: Vector2i, max_fields: int) -> int:
	var count := 0
	for i in range(1, max_fields + 1):
		if board.is_blocking(origin + dir * i):
			break
		count += 1
	return count


func tick(dt_ms: int) -> void:
	_move_players(dt_ms)
	_slide_on_ice(dt_ms)
	_move_bombs(dt_ms)
	_collect_extras()
	_update_diseases(dt_ms)
	_age_explosions(dt_ms)
	for bomb in bombs:
		if not bomb.flying:
			bomb.timer_ms -= dt_ms
	_detonate_due_bombs()
	_resolve_pending_boxes()
	_apply_explosion_damage()


func _move_players(dt_ms: int) -> void:
	for id in players:
		var player: SimPlayer = players[id]
		if not player.alive or player.move_dir == Vector2i.ZERO:
			player.moved = false
			continue
		var dir := -player.move_dir if player.disease == SimExtra.Type.REVERSE else player.move_dir
		player.move_remainder_milli += player.speed() * dt_ms
		var span := player.move_remainder_milli / 1000
		player.move_remainder_milli -= span * 1000
		var before := player.pos
		if not SimMovement.advance(self, player, dir, span):
			player.move_remainder_milli = 0
		player.moved = player.pos != before


# Eis schiebt jede Figur mit 80 px/s in ihre letzte Blickrichtung weiter.
func _slide_on_ice(dt_ms: int) -> void:
	for id in players:
		var player: SimPlayer = players[id]
		if not player.alive or board.get_tile(player.cell) != SimTile.Type.ICE:
			player.ice_remainder_milli = 0
			continue
		player.ice_remainder_milli += SimConstants.ICE_SPEED * dt_ms
		var span := player.ice_remainder_milli / 1000
		player.ice_remainder_milli -= span * 1000
		if not SimMovement.advance(self, player, player.facing, span):
			player.ice_remainder_milli = 0


func _move_bombs(dt_ms: int) -> void:
	_update_arrows(dt_ms)
	for bomb in bombs:
		if bomb.trapped or bomb.trap_flight:
			_update_trap(bomb, dt_ms)
			continue
		if not bomb.flying and board.get_tile(bomb.cell) == SimTile.Type.TRAP:
			_trap_bomb(bomb)
			continue
		if bomb.flying:
			_fly(bomb, dt_ms)
		elif bomb.move_dir != Vector2i.ZERO:
			var speed := SimConstants.BOMB_SPEED
			if board.get_tile(bomb.cell) == SimTile.Type.ICE:
				speed += SimConstants.ICE_SPEED
			bomb.move_remainder_milli += speed * dt_ms
			var span := bomb.move_remainder_milli / 1000
			bomb.move_remainder_milli -= span * 1000
			if not SimMovement.advance_bomb(self, bomb, span):
				bomb.move_dir = Vector2i.ZERO
				bomb.move_remainder_milli = 0
				bomb.snap()


# Landet auf einer Zelle mit einer anderen Bombe, fliegt sie eine Zelle weiter oder schwebt, bis das möglich ist.
func _fly(bomb: SimBomb, dt_ms: int) -> void:
	bomb.fly_remainder_milli += SimConstants.BOMB_SPEED * dt_ms
	var span := mini(bomb.fly_remainder_milli / 1000, bomb.fly_remaining_px)
	bomb.fly_remainder_milli -= bomb.fly_remainder_milli / 1000 * 1000
	bomb.pos += bomb.fly_dir * span
	bomb.fly_remaining_px -= span
	if bomb.fly_remaining_px > 0:
		return
	bomb.snap()
	if bomb_at(bomb.cell) != null:
		if _free_fields(bomb.cell, bomb.fly_dir, 1) == 1:
			bomb.fly_remaining_px = int(SimConstants.CELL_SIZE)
		return
	bomb.flying = false
	bomb_landed.emit(bomb)


func _age_explosions(dt_ms: int) -> void:
	for explosion in explosions:
		explosion.remaining_ms -= dt_ms
	explosions = explosions.filter(func(e: SimExplosion) -> bool: return e.remaining_ms > 0)


func _detonate_due_bombs() -> void:
	while true:
		var due: SimBomb = null
		for bomb in bombs:
			if not bomb.flying and bomb.timer_ms <= 0 and (due == null or bomb.id < due.id):
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
		if not other.flying and other.cell == cell:
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
				_drop_collected_extras(player)
				var killer_id := explosion.owner_id
				if killer_id != player.id and players.has(killer_id):
					players[killer_id].kills += 1
				player_died.emit(player.id, killer_id)


# Aufnahme beim Betreten (gerundete Zelle). Jede Aufnahme heilt zuerst eine aktive Krankheit.
func _collect_extras() -> void:
	for id in players:
		var player: SimPlayer = players[id]
		if not player.alive or not extras.has(player.cell):
			continue
		var type: int = extras[player.cell]
		extras.erase(player.cell)
		_cure(player)
		_apply_extra(player, type)
		extra_collected.emit(player.id, type)


func _apply_extra(player: SimPlayer, type: int) -> void:
	match type:
		SimExtra.Type.BOMB:
			if player.max_bombs < SimConstants.MAX_BOMBS:
				player.max_bombs += 1
				player.extra_bombs += 1
		SimExtra.Type.POWER:
			if player.power < SimConstants.MAX_POWER:
				player.power += 1
				player.extra_power += 1
		SimExtra.Type.SKATEBOARD:
			if player.skateboards < SimConstants.MAX_SKATEBOARDS:
				player.skateboards += 1
				player.extra_skateboards += 1
		SimExtra.Type.KICK:
			player.can_kick = true
			player.extra_kick += 1
		SimExtra.Type.GLOVE:
			player.can_glove = true
			player.extra_gloves += 1
		SimExtra.Type.OVERDRIVE, SimExtra.Type.REVERSE, SimExtra.Type.AUTOBOMB:
			_infect(player, type)


func _infect(player: SimPlayer, type: int) -> void:
	player.disease = type
	player.disease_ms = SimConstants.DISEASE_DURATION_MS
	player.move_remainder_milli = 0


# Beim Heilen taucht das passende Krankheits-Extra wieder auf dem Feld auf.
func _cure(player: SimPlayer) -> void:
	if not player.is_diseased():
		return
	var type := player.disease
	player.disease = SimExtra.Type.NONE
	player.disease_ms = 0
	_spawn_extra_on_free_cell(type)


func _update_diseases(dt_ms: int) -> void:
	for id in players:
		var player: SimPlayer = players[id]
		if not player.alive or not player.is_diseased():
			continue
		player.disease_ms -= dt_ms
		if player.disease_ms <= 0:
			player.disease = SimExtra.Type.NONE
			player.disease_ms = 0
			continue
		if player.disease == SimExtra.Type.AUTOBOMB:
			place_bomb(player.id)
		for other_id in players:
			var other: SimPlayer = players[other_id]
			if other != player and other.alive and not other.is_diseased() and other.cell == player.cell:
				_infect(other, player.disease)


# Eingesammelte Extras fallen beim Tod auf zufällige freie Felder (Startausrüstung nicht).
func _drop_collected_extras(player: SimPlayer) -> void:
	for pair in [
		[SimExtra.Type.BOMB, player.extra_bombs], [SimExtra.Type.POWER, player.extra_power],
		[SimExtra.Type.SKATEBOARD, player.extra_skateboards], [SimExtra.Type.KICK, player.extra_kick],
		[SimExtra.Type.GLOVE, player.extra_gloves],
	]:
		for i in pair[1]:
			_spawn_extra_on_free_cell(pair[0])
	player.extra_bombs = 0
	player.extra_power = 0
	player.extra_skateboards = 0
	player.extra_kick = 0
	player.extra_gloves = 0


func _spawn_extra_on_free_cell(type: int) -> void:
	var free: Array[Vector2i] = []
	for y in board.height:
		for x in board.width:
			var cell := Vector2i(x, y)
			if not board.is_blocking(cell) and not extras.has(cell) and bomb_at(cell) == null:
				free.append(cell)
	if free.is_empty():
		return
	var target: Vector2i = free[rng.randi() % free.size()]
	extras[target] = type
	extra_spawned.emit(target, type)


# Pfeil: Eine ruhende oder passende Bombe wird in Pfeilrichtung geschoben. Eine entgegenkommende Bombe
# wird eingerastet und nach 0,5 s umgelenkt.
func _update_arrows(dt_ms: int) -> void:
	for y in board.height:
		for x in board.width:
			var cell := Vector2i(x, y)
			var dir := SimTile.arrow_direction(board.get_tile(cell))
			if dir == Vector2i.ZERO:
				continue
			var bomb := bomb_at(cell)
			var state: Dictionary = _arrow_state.get(cell, {"chill_ms": 0, "bomb_id": 0})
			if bomb == null:
				_arrow_state.erase(cell)
				continue
			var is_new: bool = state.bomb_id != bomb.id
			if bomb.move_dir != Vector2i.ZERO and bomb.move_dir != dir and bomb.move_dir == -dir and is_new:
				bomb.snap()
				bomb.move_dir = Vector2i.ZERO
				bomb.move_remainder_milli = 0
				state.chill_ms = SimConstants.ARROW_CHILL_MS
			if state.chill_ms > 0:
				state.chill_ms -= dt_ms
			elif bomb.move_dir != dir:
				bomb.move_dir = dir
				bomb.move_remainder_milli = 0
			state.bomb_id = bomb.id
			_arrow_state[cell] = state


# Fallen halten die Bombe 1 s außerhalb des Spiels, dann fliegt sie über Wände auf ein zufälliges freies Feld.
func _trap_bomb(bomb: SimBomb) -> void:
	bomb.snap()
	bomb.move_dir = Vector2i.ZERO
	bomb.flying = true
	bomb.trapped = true
	bomb.trap_ms = SimConstants.TRAP_HOLD_MS
	bomb_trapped.emit(bomb)


func _update_trap(bomb: SimBomb, dt_ms: int) -> void:
	if bomb.trapped:
		bomb.trap_ms -= dt_ms
		if bomb.trap_ms > 0:
			return
		var target := _random_passable_cell()
		if target == Vector2i(-1, -1):
			_remove_bomb(bomb)
			return
		bomb.trapped = false
		bomb.trap_flight = true
		bomb.trap_from = bomb.pos
		bomb.trap_to = target * int(SimConstants.CELL_SIZE)
		bomb.trap_elapsed_ms = 0
		var distance := Vector2(bomb.trap_to - bomb.trap_from).length()
		bomb.trap_total_ms = maxi(1, int(distance * 1000.0 / SimConstants.TRAP_FLIGHT_SPEED))
		bomb_thrown.emit(bomb)
		return
	bomb.trap_elapsed_ms += dt_ms
	if bomb.trap_elapsed_ms < bomb.trap_total_ms:
		var t := float(bomb.trap_elapsed_ms) / bomb.trap_total_ms
		bomb.pos = Vector2i((Vector2(bomb.trap_from).lerp(Vector2(bomb.trap_to), t)).round())
		return
	bomb.pos = bomb.trap_to
	bomb.trap_flight = false
	bomb.flying = false
	bomb.timer_ms = SimConstants.TRAP_FUSE_MS
	bomb_landed.emit(bomb)


func _random_passable_cell() -> Vector2i:
	var free: Array[Vector2i] = []
	for y in board.height:
		for x in board.width:
			if not board.is_blocking(Vector2i(x, y)):
				free.append(Vector2i(x, y))
	if free.is_empty():
		return Vector2i(-1, -1)
	return free[rng.randi() % free.size()]


func _remove_bomb(bomb: SimBomb) -> void:
	bombs.erase(bomb)
	var owner: SimPlayer = players.get(bomb.owner_id)
	if owner != null:
		owner.active_bombs -= 1
