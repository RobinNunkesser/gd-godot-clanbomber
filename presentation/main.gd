extends Node2D
## Spielbarer Prototyp: lädt eine Karte, speist die Simulation und liest Eingaben.
## Startmenü (Esc öffnet es): Steuerung je Platz (Tastatur 1/2, Gamepad 1-4, AI), Karte, Punkte.
## Tastatur 1: WASD + Leertaste, Tastatur 2: Pfeiltasten + Enter, Gamepad: D-Pad/linker Stick + A.
## N/P: nächste/vorherige Karte, R: Runde neu starten, F5: neues Match, M: Mute.

const MAP_DIR := "res://maps"
const PAD_DEADZONE := 0.5
const CONTINUE_LOCK_MS := 800

@onready var view3d: ArenaView3D = $ArenaView3D
@onready var sfx: Sfx = $Sfx
@onready var hud: Label = $UI/Hud
@onready var banner: Label = $UI/Banner

var _maps: Array[String] = []
var _map_index := 0
var _world: SimWorld
var _clock_ms := 0.0
var _match := SimMatch.new()
var _scoreboard := Scoreboard.new()
var _round_over := false
var _continue_unlock_at := 0
var _menu := GameMenu.new()
var _ais: Dictionary = {}
var _bgm := AudioStreamPlayer.new()
var _menu_music: AudioStream
var _game_music: AudioStream


func _ready() -> void:
	_setup_audio()
	add_child(_bgm)
	_menu_music = _load_looping_stream("res://assets/audio/music/music_menu.ogg")
	_game_music = _load_looping_stream("res://assets/audio/music/music_game.ogg")
	for file in DirAccess.get_files_at(MAP_DIR):
		if file.ends_with(".map"):
			_maps.append(file)
	_maps.sort()
	var start := _maps.find("Crossroads.map")
	_map_index = maxi(start, 0)
	$UI.add_child(_scoreboard)
	$UI.add_child(_menu)
	_menu.maps = _maps
	_menu.start_requested.connect(_start_match)
	_menu.resume_requested.connect(_resume_game)
	_menu.audio_changed.connect(_apply_audio_config)
	_apply_audio_config()
	_open_menu()


func _setup_audio() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
	_bgm.bus = "Music"


func _apply_audio_config() -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_mute(music_bus, not _menu.config.is_music_enabled())
		AudioServer.set_bus_volume_db(music_bus, _menu.config.music_db())
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_mute(sfx_bus, not _menu.config.is_sfx_enabled())
		AudioServer.set_bus_volume_db(sfx_bus, _menu.config.sfx_db())


func _load_looping_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


func _play_music(stream: AudioStream, volume_db := -8.0) -> void:
	if stream == null or _bgm.stream == stream:
		return
	_bgm.stream = stream
	_bgm.volume_db = volume_db
	_bgm.play()


func _open_menu() -> void:
	_menu.is_game_active = (_world != null and not _round_over and not _scoreboard.visible)
	_play_music(_menu_music, -8.0)
	_menu.open()


func _resume_game() -> void:
	_play_music(_game_music, -10.0)


# Lädt die Karte `step` Positionen weiter und überspringt Karten, die für die Spielerzahl nicht taugen.
func _load_map(step: int) -> void:
	if _match.state == SimMatch.State.MATCH_OVER:
		_match.reset()
	_match.start_next_round()
	_scoreboard.visible = false
	if _menu.config.is_random_map() and step != 0:
		_map_index = randi() % _maps.size()
		step = 0
	for attempt in _maps.size():
		_map_index = posmod(_map_index + step, _maps.size())
		if _try_load_current_map():
			return
		step = step if step != 0 else 1
	banner.text = "Keine passende Karte gefunden"


func _try_load_current_map() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var text := FileAccess.get_file_as_string("%s/%s" % [MAP_DIR, _maps[_map_index]])
	var data := MapParser.parse(text, rng)
	if not data.is_valid():
		return false
	var active := _menu.config.active_slots()
	for slot in active:
		if not data.starts.has(slot):
			return false
	_world = SimWorld.new(SimBoard.from_map(data), rng)
	_ais.clear()
	for slot in active:
		_world.add_player(slot + 1, data.starts[slot])
		if _menu.config.slots[slot] == GameConfig.Controller.AI:
			_ais[slot + 1] = SimAI.new(slot + 1)
	_match.register_players(_world.players.keys())
	if not _menu.config.is_random_map():
		_menu.config.map_name = _maps[_map_index]
	_connect_sounds()
	view3d.bind(_world)
	_round_over = false
	banner.text = "%s  (von %s)       [Esc] Menü  |  [M] Musik  |  [F4] SFX  |  [N] Nächste Karte  |  [R] Reset" % [_maps[_map_index].get_basename(), data.author]
	return true


func _physics_process(delta: float) -> void:
	if _world == null or _scoreboard.visible or _menu.visible:
		return
	_apply_human_input()
	_clock_ms += delta * 1000.0
	var whole := int(_clock_ms)
	_clock_ms -= whole
	for ai: SimAI in _ais.values():
		ai.update(_world, whole)
	_world.tick(whole)
	_check_round_end()
	hud.text = _status_text()


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	var is_cancel := false
	if event is InputEventKey:
		var k := event as InputEventKey
		var code := k.physical_keycode if k.keycode == 0 else k.keycode
		if code == KEY_ESCAPE:
			is_cancel = true
	elif event is InputEventJoypadButton:
		var b := event as InputEventJoypadButton
		if b.button_index == JOY_BUTTON_START:
			is_cancel = true

	if is_cancel or event.is_action_pressed("ui_cancel"):
		if _scoreboard.visible:
			_scoreboard.visible = false
			_open_menu()
			get_viewport().set_input_as_handled()
			return
		if _menu.visible:
			if _menu.is_game_active:
				_menu.resume()
			else:
				get_tree().quit()
			get_viewport().set_input_as_handled()
			return
		if _world != null:
			_open_menu()
			get_viewport().set_input_as_handled()
			return

	if _scoreboard.visible:
		_handle_scoreboard_input(event)
		return

	if _menu.visible or _world == null:
		return

	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.keycode == 0 else key.keycode
		match code:
			KEY_SPACE:
				_bomb_for_controller(GameConfig.Controller.KEYBOARD_1)
			KEY_ENTER, KEY_KP_ENTER:
				_bomb_for_controller(GameConfig.Controller.KEYBOARD_2)
			KEY_M:
				_menu.config.toggle_music_mute()
				_apply_audio_config()
				banner.text = "Musik: %s" % _menu.config.music_label()
			KEY_F4:
				_menu.config.toggle_sfx_mute()
				_apply_audio_config()
				banner.text = "Ton-Effekte: %s" % _menu.config.sfx_label()
				if _menu.config.is_sfx_enabled():
					sfx.play("ui_select")
			KEY_N:
				_load_map(1)
			KEY_P:
				_load_map(-1)
			KEY_R:
				_load_map(0)
			KEY_F5:
				_match.reset()
				_load_map(0)
			KEY_F3:
				_world.round_time_ms = mini(_world.round_time_ms, 2000)
			KEY_F1:
				_debug_spawn_extras()
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.button_index == JOY_BUTTON_A:
			_bomb_for_controller(GameConfig.Controller.PAD_1 + button.device)


func _handle_scoreboard_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.keycode == 0 else key.keycode
		if Time.get_ticks_msec() >= _continue_unlock_at and code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_continue_after_scoreboard()
		elif code == KEY_F5:
			_match.reset()
			_load_map(0)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.button_index == JOY_BUTTON_A and Time.get_ticks_msec() >= _continue_unlock_at:
			_continue_after_scoreboard()


func _continue_after_scoreboard() -> void:
	sfx.play("ui_select")
	_load_map(1 if _menu.config.is_random_map() else 0)


# Neues Match mit den Menüeinstellungen. Eine feste Karte bleibt über alle Runden gleich.
func _start_match() -> void:
	var config := _menu.config
	_menu.is_game_active = true
	_match = SimMatch.new(config.points_to_win)
	if not config.is_random_map():
		_map_index = maxi(_maps.find(config.map_name), 0)
	_load_map(1 if config.is_random_map() else 0)
	_play_music(_game_music, -10.0)
	sfx.play("ui_select")


func _bomb_for_controller(controller: int) -> void:
	var slot := _menu.config.slots.find(controller)
	if slot >= 0:
		_world.action_bomb(slot + 1)


func _apply_human_input() -> void:
	var config := _menu.config
	for slot in GameConfig.SLOT_COUNT:
		var direction := Vector2i.ZERO
		match config.slots[slot]:
			GameConfig.Controller.KEYBOARD_1:
				direction = _axis(KEY_A, KEY_D, KEY_W, KEY_S)
			GameConfig.Controller.KEYBOARD_2:
				direction = _axis(KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN)
			GameConfig.Controller.PAD_1, GameConfig.Controller.PAD_2, GameConfig.Controller.PAD_3, GameConfig.Controller.PAD_4:
				direction = _pad_axis(config.pad_device(slot))
			_:
				continue
		_world.set_move_dir(slot + 1, direction)


# D-Pad hat Vorrang vor dem linken Stick; der Stick läuft nur auf einer Achse (4 Richtungen, wie die Simulation).
func _pad_axis(device: int) -> Vector2i:
	var x := int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)) - int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT))
	var y := int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)) - int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP))
	if x != 0 or y != 0:
		return Vector2i(x, y)
	var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	if stick.length() < PAD_DEADZONE:
		return Vector2i.ZERO
	if absf(stick.x) > absf(stick.y):
		return Vector2i(int(signf(stick.x)), 0)
	return Vector2i(0, int(signf(stick.y)))


func _axis(left: Key, right: Key, up: Key, down: Key) -> Vector2i:
	var x := int(Input.is_physical_key_pressed(right)) - int(Input.is_physical_key_pressed(left))
	var y := int(Input.is_physical_key_pressed(down)) - int(Input.is_physical_key_pressed(up))
	return Vector2i(x, y)


func _on_player_died(player_id: int, _killer_id: int) -> void:
	banner.text = "Spieler %d ist tot" % player_id
	sfx.play("death")


func _connect_sounds() -> void:
	_world.player_died.connect(_on_player_died)
	_world.player_falling.connect(func(id: int) -> void:
		banner.text = "Spieler %d stürzt ab!" % id
		sfx.play("death", -2.0))
	_world.bomb_placed.connect(func(_b: SimBomb) -> void: sfx.play("bomb_place", -4.0))
	_world.bomb_exploded.connect(func(_b: SimBomb, _e: SimExplosion) -> void: sfx.play("explosion"))
	_world.box_destroyed.connect(func(_c: Vector2i) -> void: sfx.play("box_break", -6.0))
	_world.extra_collected.connect(func(_id: int, type: int) -> void:
		sfx.play("disease" if type in ArenaView3D.DISEASES else "extra_pickup"))
	_world.bomb_kicked.connect(func(_b: SimBomb) -> void: sfx.play("kick"))
	_world.bomb_thrown.connect(func(_b: SimBomb) -> void: sfx.play("throw"))
	_world.bomb_landed.connect(func(_b: SimBomb) -> void: sfx.play("land"))
	_world.bomb_trapped.connect(func(_b: SimBomb) -> void: sfx.play("trap"))
	_world.sudden_death_started.connect(func() -> void:
		banner.text = "SUDDEN DEATH!"
		sfx.play("disease"))
	_world.tile_vanishing.connect(func(_c: Vector2i) -> void: sfx.play("box_break", -3.0))


# Kurzstatus je Spieler: Bomben, Power, Skateboards, Kick/Glove, Krankheit.
func _status_text() -> String:
	var lines: Array[String] = []
	for id: int in _world.players:
		var p: SimPlayer = _world.players[id]
		var line := "P%d ★%d  B%d P%d S%d%s%s" % [id, _match.points_of(id), p.max_bombs, p.power, p.skateboards, " K" if p.can_kick else "", " G" if p.can_glove else ""]
		if p.is_diseased():
			line += " [%s %ds]" % [ArenaView3D.EXTRA_LETTERS[p.disease], ceili(p.disease_ms / 1000.0)]
		if not p.alive:
			line += "  tot"
		lines.append(line)
	var clock := "SUDDEN DEATH" if _world.is_sudden_death() else "%d s" % ceili(_world.round_time_ms / 1000.0)
	return clock + "    " + "    ".join(lines)


func _check_round_end() -> void:
	if _round_over or not _match.update(_world):
		return
	_round_over = true
	_continue_unlock_at = Time.get_ticks_msec() + CONTINUE_LOCK_MS
	sfx.play("round_end")
	_scoreboard.show_result(_match)


# Testhilfe (F1): legt jeden Extra-Typ in eine Reihe neben Spieler 1.
func _debug_spawn_extras() -> void:
	var origin: Vector2i = _world.players[1].cell
	var type := 0
	for cell in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		var target: Vector2i = origin + cell
		if not _world.board.is_blocking(target) and type < 8:
			_world.extras[target] = type
		type += 1
