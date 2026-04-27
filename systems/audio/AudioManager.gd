extends Node

var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in 8:
		var player = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play_shoot() -> void:
	_play_tone(440.0, 0.06, 0.08)


func play_hit() -> void:
	_play_tone(220.0, 0.04, 0.05)


func play_pop() -> void:
	_play_tone(880.0, 0.12, 0.18)


func _play_tone(frequency: float, volume: float, duration: float) -> void:
	var player = _get_free_player()
	if player == null:
		return

	var sample_rate: float = 44100.0
	var sample_count: int = int(sample_rate * duration)

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_rate)
	stream.stereo = false

	var bytes = PackedByteArray()
	bytes.resize(sample_count * 2)

	for i in sample_count:
		var t: float = float(i) / sample_rate
		var envelope: float = 1.0 - (t / duration)
		var sample: float = sin(TAU * frequency * t) * envelope * volume
		var value: int = clamp(int(sample * 32767.0), -32768, 32767)
		bytes[i * 2] = value & 0xFF
		bytes[i * 2 + 1] = (value >> 8) & 0xFF

	stream.data = bytes
	player.stream = stream
	player.play()


func _get_free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return null
