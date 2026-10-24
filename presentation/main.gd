extends Node2D
## Spielbarer Prototyp: lädt eine Karte, speist die Simulation und liest Eingaben.
## Startmenü (Esc öffnet es): Steuerung je Platz (Tastatur 1/2, Gamepad 1-8, AI), Kartenauswahl, Punkte.
## Tastatur 1: WASD + Leertaste, Tastatur 2: Pfeiltasten + Enter, Gamepad: D-Pad/linker Stick + A.
## R: Runde neu starten, F5: neues Match, M: Mute. (N = nächste Karte, F1/F3: Testhilfen, nicht in der Bedienung genannt.)

const MAP_DIR := "res://maps"
const USER_MAP_DIR := "user://maps"
const SETTINGS_PATH := "user://settings.cfg"
const PAD_DEADZONE := 0.5
const CONTINUE_LOCK_MS := 800
const INTRO_DURATION_S := 0.9
const HURRY_LIMIT_MS := 20000
const HURRY_BEEP_INTERVAL_MS := 900

@onready var view3d: ArenaView3D = $ArenaView3D
@onready var sfx: Sfx = $Sfx
@onready var hud: Label = get_node_or_null("UI/Hud")
@onready var banner: Label = get_node_or_null("UI/Banner")

var _catalog := MapCatalog.new()
var _rotation := MapRotation.new()
var _rng := RandomNumberGenerator.new()
var _current_map := ""
var _world: SimWorld
var _clock_ms := 0.0
var _match := SimMatch.new()
var _scoreboard := Scoreboard.new()
var _round_over := false
var _intro := false
var _hurry_started := false
var _hurry_beep_at := 0
var _hurry_threshold_ms := HURRY_LIMIT_MS
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
	_rng.randomize()
	_menu.config.load_from(SETTINGS_PATH, [] as Array[String])
	if _menu.config.external_map_dir.is_empty():
		_menu.config.external_map_dir = OS.get_environment("CLANBOMBER_MAPS_DIR").strip_edges()
	_rebuild_catalog()
	$UI.add_child(_scoreboard)
	$UI.add_child(_menu)
	_menu.start_requested.connect(_start_match)
	_menu.resume_requested.connect(_resume_game)
	_menu.quit_requested.connect(_quit_game)
	_menu.audio_changed.connect(_apply_audio_config)
	_menu.map_dir_changed.connect(_on_map_dir_changed)
	_apply_audio_config()
	_open_menu()


# Bündelt die mitgelieferten, den konfigurierten externen und den benutzerdefinierten Kartenordner.
func _rebuild_catalog() -> void:
	var dirs: Array[String] = [MAP_DIR]
	var external := _expanded_path(_menu.config.external_map_dir)
	if not external.is_empty():
		dirs.append(external)
	dirs.append(USER_MAP_DIR)
	_catalog = MapCatalog.load_dirs(dirs)
	_menu.catalog = _catalog
	var known: Array[String] = []
	for map in _menu.config.map_pool:
		if _catalog.names.has(map):
			known.append(map)
	_menu.config.map_pool = known
	if _menu.config.map_pool.is_empty():
		_menu.config.map_pool = _catalog.names.duplicate()


func _expanded_path(path: String) -> String:
	var value := path.strip_edges()
	var home := OS.get_environment("HOME")
	if value == "~":
		value = home
	elif value.begins_with("~/"):
		value = home.path_join(value.substr(2))
	return value


func _on_map_dir_changed(_path: String) -> void:
	_menu.config.save_to(SETTINGS_PATH)
	_rebuild_catalog()
	_menu.refresh()


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
	if view3d != null and view3d.effects != null:
		view3d.effects.shake_multiplier = _menu.config.shake_multiplier()


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
	Engine.time_scale = 1.0
	if view3d != null and view3d.effects != null:
		view3d.effects.cancel_hitstop()
	_stop_all_rumble()
	_menu.is_game_active = (_world != null and not _round_over and not _scoreboard.visible)
	_play_music(_menu_music, -8.0)
	_menu.open()


func _resume_game() -> void:
	Engine.time_scale = 1.0
	if view3d != null and view3d.effects != null:
		view3d.effects.cancel_hitstop()
	_menu.config.save_to(SETTINGS_PATH)
	_play_music(_game_music, -10.0)


func _quit_game() -> void:
	_menu.config.save_to(SETTINGS_PATH)
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_menu.config.save_to(SETTINGS_PATH)


# Anzeigenamen der Spieler (Spieler-ID = Platz + 1).
func _names() -> Dictionary:
	var result: Dictionary = {}
	for slot in GameConfig.SLOT_COUNT:
		result[slot + 1] = _menu.config.name_of(slot)
	return result


func _player_name(id: int) -> String:
	return _menu.config.name_of(id - 1)


# Lädt die Karte für die nächste Runde: mit `advance` die nächste Karte der Kartenauswahl (zufällig oder der
# Reihe nach laut Menü), sonst dieselbe Karte neu.
func _load_map(advance: bool) -> void:
	if _match.state == SimMatch.State.MATCH_OVER:
		_match.reset()
	_match.start_next_round()
	_scoreboard.visible = false
	var config := _menu.config
	var playable := _catalog.playable(config.active_slots())
	if playable.is_empty():
		banner.text = I18n.text("MENU_BLOCKER_NO_MAP") if TranslationServer.get_locale().begins_with("de") else "No suitable map found"
		return
	var map_name := _current_map
	if advance or not playable.has(map_name):
		var pool := config.effective_pool(playable)
		map_name = _rotation.next(pool, _rng) if config.random_order else _rotation.next_in_order(pool)
	if not _try_load_map(map_name):
		if TranslationServer.get_locale().begins_with("de"):
			banner.text = "Karte %s konnte nicht geladen werden" % map_name.get_basename()
		else:
			banner.text = "Map %s could not be loaded" % map_name.get_basename()


func _try_load_map(map_name: String) -> bool:
	var path := _catalog.file_path(map_name)
	if path.is_empty() or not FileAccess.file_exists(path):
		path = "%s/%s" % [MAP_DIR, map_name]
	var text := FileAccess.get_file_as_string(path)
	var data := MapParser.parse(text, _rng)
	if not data.is_valid():
		return false
	var config := _menu.config
	var active := config.active_slots()
	for slot in active:
		if not data.starts.has(slot):
			return false
	_world = SimWorld.new(SimBoard.from_map(data), _rng)
	_world.round_time_ms = config.round_time_ms()
	_hurry_threshold_ms = mini(HURRY_LIMIT_MS, maxi(3000, _world.round_time_ms - 5000))
	_ais.clear()
	var starts := data.start_cells(active, config.random_positions, _rng)
	for slot in active:
		var team := config.effective_team(slot)
		var start: Vector2i = starts[slot]
		_world.add_player(slot + 1, start, team)
		_match.set_team(slot + 1, team)
		if config.slots[slot] == GameConfig.Controller.AI:
			_ais[slot + 1] = SimAI.new(slot + 1)
	_match.register_players(_world.players.keys())
	_current_map = map_name
	_connect_sounds()
	view3d.bind(_world)
	view3d.effects.shake_multiplier = _menu.config.shake_multiplier()
	view3d.play_intro(INTRO_DURATION_S)
	_intro = true
	_round_over = false
	_hurry_started = false
	_hurry_beep_at = 0
	banner.modulate = Color.WHITE
	banner.text = "%s%s" % [map_name.get_basename(), I18n.text("BANNER_MAP_BY") % data.author]
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.offset_left = 8.0
	banner.offset_right = -8.0
	banner.visible = true
	_showing_map_banner = true
	_update_countdown()
	return true


func _physics_process(delta: float) -> void:
	if _world == null or _scoreboard.visible or _menu.visible:
		return
	if _intro:
		if view3d.is_intro_running():
			_update_countdown()
			return
		_intro = false
		_showing_map_banner = false
		sfx.play("land")
	_apply_human_input()
	_clock_ms += delta * 1000.0
	var whole := int(_clock_ms)
	_clock_ms -= whole
	for ai: SimAI in _ais.values():
		ai.update(_world, whole)
	_world.tick(whole)
	_update_hurry()
	_update_countdown()
	_check_round_end()


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
			if not _menu.back():
				if _menu.is_game_active:
					_menu.resume()
				else:
					_quit_game()
			get_viewport().set_input_as_handled()
			return
		if _world != null:
			_open_menu()
			get_viewport().set_input_as_handled()
			return

	if _scoreboard.visible:
		_handle_scoreboard_input(event)
		return

	if _menu.visible or _world == null or _intro:
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
				_load_map(true)  # Testhilfe: nächste Karte der Auswahl
			KEY_R:
				_load_map(false)
			KEY_F5:
				_match.reset()
				_load_map(false)
			KEY_F3:
				_world.round_time_ms = mini(_world.round_time_ms, 2000)
			KEY_F1:
				_debug_spawn_extras()
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.button_index == JOY_BUTTON_A:
			_bomb_for_controller(GameConfig.Controller.PAD_1 + button.device)


func _handle_scoreboard_input(event: InputEvent) -> void:
	if _scoreboard.is_match_over():
		_handle_match_over_input(event)
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.keycode == 0 else key.keycode
		if Time.get_ticks_msec() >= _continue_unlock_at and code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_continue_after_scoreboard()
		elif code == KEY_F5:
			_match.reset()
			_load_map(false)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.button_index == JOY_BUTTON_A and Time.get_ticks_msec() >= _continue_unlock_at:
			_continue_after_scoreboard()


# Sieger-Bildschirm: ↑↓ wählen zwischen I18n.text("SCOREBOARD_NEW_MATCH") und I18n.text("SCOREBOARD_BACK_TO_MENU"), Leertaste/Enter/A bestätigt.
func _handle_match_over_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_scoreboard.move_selection(-1)
		sfx.play("ui_select", -8.0)
	elif event.is_action_pressed("ui_down"):
		_scoreboard.move_selection(1)
		sfx.play("ui_select", -8.0)
	elif Time.get_ticks_msec() >= _continue_unlock_at and _is_confirm(event):
		match _scoreboard.selected_action():
			Scoreboard.Action.NEW_MATCH:
				_start_match()
			Scoreboard.Action.MENU:
				sfx.play("ui_select")
				_scoreboard.visible = false
				_open_menu()
	elif event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_F5:
		_start_match()


func _is_confirm(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.keycode == 0 else key.keycode
		return code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
	return false


func _continue_after_scoreboard() -> void:
	sfx.play("ui_select")
	_load_map(true)


# Neues Match mit den Menüeinstellungen; die Karten laufen nach der Kartenauswahl (zufällig oder der Reihe nach),
# nach jeder Runde folgt die nächste.
func _start_match() -> void:
	Engine.time_scale = 1.0
	if view3d != null and view3d.effects != null:
		view3d.effects.cancel_hitstop()
	_stop_all_rumble()
	var config := _menu.config
	config.save_to(SETTINGS_PATH)
	_menu.is_game_active = true
	_match = SimMatch.new(config.points_to_win)
	_rotation.reset()
	_current_map = ""
	_load_map(true)
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
			GameConfig.Controller.PAD_1, GameConfig.Controller.PAD_2, GameConfig.Controller.PAD_3, GameConfig.Controller.PAD_4, GameConfig.Controller.PAD_5, GameConfig.Controller.PAD_6, GameConfig.Controller.PAD_7, GameConfig.Controller.PAD_8:
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
	banner.text = I18n.text("BANNER_PLAYER_DIED") % _player_name(player_id)
	sfx.play("death")
	if view3d != null and view3d.effects != null:
		view3d.effects.hitstop(0.065, 0.05)
	_rumble_player(player_id, 0.9, 0.7, 0.4)


func _connect_sounds() -> void:
	_world.player_died.connect(_on_player_died)
	_world.player_falling.connect(func(id: int) -> void:
		banner.text = I18n.text("BANNER_PLAYER_FELL") % _player_name(id)
		sfx.play("death", -2.0)
		_rumble_player(id, 0.5, 0.5, 0.25))
	_world.bomb_placed.connect(func(_b: SimBomb) -> void: sfx.play("bomb_place", -4.0))
	_world.bomb_exploded.connect(func(_b: SimBomb, e: SimExplosion) -> void:
		sfx.play("explosion")
		if view3d != null and view3d.effects != null:
			view3d.effects.hitstop(0.035, 0.05)
		_rumble_explosion(e.origin))
	_world.box_destroyed.connect(func(_c: Vector2i) -> void: sfx.play("box_break", -6.0))
	_world.extra_collected.connect(func(_id: int, type: int) -> void:
		sfx.play("disease" if type in ArenaView3D.DISEASES else "extra_pickup"))
	_world.bomb_kicked.connect(func(_b: SimBomb) -> void: sfx.play("kick"))
	_world.bomb_thrown.connect(func(_b: SimBomb) -> void: sfx.play("throw"))
	_world.bomb_landed.connect(func(_b: SimBomb) -> void: sfx.play("land"))
	_world.bomb_trapped.connect(func(_b: SimBomb) -> void: sfx.play("trap"))
	_world.sudden_death_started.connect(func() -> void:
		banner.text = I18n.text("SUDDEN_DEATH") + "!"
		sfx.play("disease"))
	_world.tile_vanishing.connect(func(_c: Vector2i) -> void: sfx.play("box_break", -3.0))


func _stop_all_rumble() -> void:
	for dev in 8:
		Input.stop_joy_vibration(dev)


func _rumble_player(slot_or_id: int, weak: float, strong: float, duration: float) -> void:
	var mult := _menu.config.shake_multiplier()
	if mult <= 0.0:
		return
	var slot := slot_or_id - 1 if slot_or_id > 0 else slot_or_id
	var dev := _menu.config.pad_device(slot)
	if dev >= 0:
		Input.start_joy_vibration(dev, weak * mult, strong * mult, duration)


func _rumble_explosion(origin: Vector2i) -> void:
	var mult := _menu.config.shake_multiplier()
	if mult <= 0.0 or _world == null:
		return
	for id: int in _world.players:
		var player: SimPlayer = _world.players[id]
		if not player.alive:
			continue
		var dev := _menu.config.pad_device(id - 1)
		if dev < 0:
			continue
		var dist := origin.distance_to(player.cell)
		if dist <= 8.0:
			var factor := clampf(1.0 - (dist / 8.0), 0.0, 1.0)
			Input.start_joy_vibration(dev, 0.40 * factor * mult, 0.65 * factor * mult, 0.18)


func _update_hurry() -> void:
	if _round_over:
		return
	if _world.is_sudden_death():
		if _hurry_started:
			_hurry_started = false
			banner.modulate = Color.WHITE
		return
	if _world.round_time_ms > _hurry_threshold_ms:
		return
	if not _hurry_started:
		_hurry_started = true
		banner.text = I18n.text("HURRY_UP")
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.anchor_left = 0.0
		banner.anchor_right = 1.0
		banner.offset_left = 0.0
		banner.offset_right = 0.0
		_hurry_beep_at = 0
	if Time.get_ticks_msec() >= _hurry_beep_at:
		_hurry_beep_at = Time.get_ticks_msec() + HURRY_BEEP_INTERVAL_MS
		sfx.play("ui_select", -6.0)
	var blink := 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() / 180.0))
	banner.modulate = Color(1.0, 0.85, 0.3, blink)


var _showing_map_banner := false

func _update_countdown() -> void:
	if _world == null or _round_over or _hurry_started:
		return
	if _intro:
		if _showing_map_banner and banner != null and banner.text != "" and not banner.text.begins_with("HURRY") and not banner.text.begins_with("SUDDEN") and "s" not in banner.text or (_showing_map_banner and banner.text.find("s") == -1 and banner.text != I18n.text("HURRY_UP")):
			pass
	if _world.is_sudden_death():
		_showing_map_banner = false
		if banner == null: return
		banner.text = I18n.text("SUDDEN_DEATH")
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		banner.anchor_left = 1.0
		banner.anchor_right = 1.0
		banner.offset_left = -200.0
		banner.offset_right = -8.0
		banner.modulate = Color.WHITE
		return
	if _intro and _showing_map_banner:
		return
	_showing_map_banner = false
	if banner == null: return
	banner.text = "%d s" % ceili(_world.round_time_ms / 1000.0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	banner.anchor_left = 1.0
	banner.anchor_right = 1.0
	banner.offset_left = -200.0
	banner.offset_right = -8.0
	banner.modulate = Color.WHITE


func _check_round_end() -> void:
	if _round_over or not _match.update(_world):
		return
	_round_over = true
	_hurry_started = false
	Engine.time_scale = 1.0
	if view3d != null and view3d.effects != null:
		view3d.effects.cancel_hitstop()
	_stop_all_rumble()
	banner.modulate = Color.WHITE
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.offset_left = 8.0
	banner.offset_right = -8.0
	banner.text = ""
	_continue_unlock_at = Time.get_ticks_msec() + CONTINUE_LOCK_MS
	sfx.play("round_end")

	if not _match.last_winners.is_empty() and view3d != null and view3d.effects != null:
		for wid: int in _match.last_winners:
			var wpos := view3d.player_world_pos(wid)
			if wpos != Vector3.ZERO:
				view3d.effects.confetti(wpos)
		view3d.effects.hitstop(0.55, 0.35)

	_scoreboard.show_result(_match, _names())


# Testhilfe (F1): legt jeden Extra-Typ in eine Reihe neben Spieler 1.
func _debug_spawn_extras() -> void:
	var origin: Vector2i = _world.players[1].cell
	var type := 0
	for cell in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		var target: Vector2i = origin + cell
		if not _world.board.is_blocking(target) and type < 8:
			_world.extras[target] = type
		type += 1
