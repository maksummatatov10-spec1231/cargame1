extends Node
## Autoload `Sfx`: small pool of `AudioStreamPlayer`s that plays the
## procedurally generated WAV files in `res://assets/audio`.

const SOUND_PATHS := {
	"paddle": "res://assets/audio/paddle.wav",
	"wall": "res://assets/audio/wall.wav",
	"brick": "res://assets/audio/brick.wav",
	"brick_hit": "res://assets/audio/brick_hit.wav",
	"powerup": "res://assets/audio/powerup.wav",
	"life_lost": "res://assets/audio/life_lost.wav",
	"level_up": "res://assets/audio/level_up.wav",
	"click": "res://assets/audio/click.wav",
	"game_over": "res://assets/audio/game_over.wav",
}

const POOL_SIZE := 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_players.append(player)
	for key: String in SOUND_PATHS:
		var path: String = SOUND_PATHS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)

func play(sound: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not Save.sound_enabled:
		return
	if not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.5)
	player.volume_db = volume_db
	player.play()

func toggle_mute() -> bool:
	Save.sound_enabled = not Save.sound_enabled
	Save.save_data()
	return Save.sound_enabled
