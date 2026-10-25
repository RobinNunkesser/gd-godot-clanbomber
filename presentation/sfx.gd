class_name Sfx
extends Node
## Einfacher Sound-Pool: kurze Effekte aus res://assets/audio/<name>.ogg mit leichter Tonhöhenvariation.

const DIR := "res://assets/audio/"
const POOL_SIZE := 12

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)


func play(sound: String, volume_db := 0.0, pitch_jitter := -1.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		var path := DIR + sound + ".ogg"
		if not ResourceLoader.exists(path):
			push_warning("Sound fehlt: " + path)
			return
		stream = load(path)
		_streams[sound] = stream
	var jitter := pitch_jitter
	if jitter < 0.0:
		if sound.begins_with("voice/"):
			jitter = 0.0
		else:
			match sound:
				"ui_select":
					jitter = 0.025
				"explosion":
					jitter = 0.10
				"box_break", "kick", "throw", "land":
					jitter = 0.08
				_:
					jitter = 0.06
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-jitter, jitter)
	player.play()
