extends Node2D
## Spielbarer Prototyp: lädt eine Karte, speist die Simulation und liest Eingaben.
## Spieler 1: WASD + Leertaste, Spieler 2: Pfeiltasten + Enter. N/P: nächste/vorherige Karte, R: Neustart.

const MAP_DIR := "res://maps"

@onready var view: ArenaView = $ArenaView
@onready var banner: Label = $UI/Banner

var _maps: Array[String] = []
var _map_index := 0
var _world: SimWorld
var _clock_ms := 0.0
var _round_over := false


func _ready() -> void:
	for file in DirAccess.get_files_at(MAP_DIR):
		if file.ends_with(".map"):
			_maps.append(file)
	_maps.sort()
	var start := _maps.find("crossroads.map")
	_map_index = maxi(start, 0)
	_load_map()


func _load_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var text := FileAccess.get_file_as_string("%s/%s" % [MAP_DIR, _maps[_map_index]])
	var data := MapParser.parse(text, rng)
	if not data.is_valid():
		banner.text = "%s: %s" % [_maps[_map_index], data.error]
		return
	_world = SimWorld.new(SimBoard.from_map(data), rng)
	for slot in mini(2, data.starts.size()):
		if data.starts.has(slot):
			_world.add_player(slot + 1, data.starts[slot])
	_world.player_died.connect(_on_player_died)
	view.world = _world
	_round_over = false
	banner.text = "%s  (von %s)" % [_maps[_map_index].get_basename(), data.author]
	view.queue_redraw()


func _physics_process(delta: float) -> void:
	if _world == null:
		return
	_world.set_move_dir(1, _axis(KEY_A, KEY_D, KEY_W, KEY_S))
	_world.set_move_dir(2, _axis(KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN))
	_clock_ms += delta * 1000.0
	var whole := int(_clock_ms)
	_clock_ms -= whole
	_world.tick(whole)
	_check_round_end()
	view.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _world == null:
		return
	match key.keycode:
		KEY_SPACE:
			_world.action_bomb(1)
		KEY_ENTER, KEY_KP_ENTER:
			_world.action_bomb(2)
		KEY_N:
			_map_index = (_map_index + 1) % _maps.size()
			_load_map()
		KEY_P:
			_map_index = (_map_index - 1 + _maps.size()) % _maps.size()
			_load_map()
		KEY_R:
			_load_map()
		KEY_F1:
			_debug_spawn_extras()


func _axis(left: Key, right: Key, up: Key, down: Key) -> Vector2i:
	var x := int(Input.is_physical_key_pressed(right)) - int(Input.is_physical_key_pressed(left))
	var y := int(Input.is_physical_key_pressed(down)) - int(Input.is_physical_key_pressed(up))
	return Vector2i(x, y)


func _on_player_died(player_id: int, _killer_id: int) -> void:
	banner.text = "Spieler %d ist tot" % player_id


func _check_round_end() -> void:
	if _round_over or _world.players.size() < 2:
		return
	var alive: Array[int] = []
	for id: int in _world.players:
		if _world.players[id].alive:
			alive.append(id)
	if alive.size() <= 1:
		_round_over = true
		banner.text = "Runde vorbei: %s  (R = Neustart, N = nächste Karte)" % (
			"Spieler %d gewinnt" % alive[0] if alive.size() == 1 else "Unentschieden")


# Testhilfe (F1): legt jeden Extra-Typ in eine Reihe neben Spieler 1.
func _debug_spawn_extras() -> void:
	var origin: Vector2i = _world.players[1].cell
	var type := 0
	for cell in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		var target: Vector2i = origin + cell
		if not _world.board.is_blocking(target) and type < 8:
			_world.extras[target] = type
		type += 1
