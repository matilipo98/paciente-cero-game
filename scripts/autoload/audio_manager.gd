extends Node
## Efectos de sonido 100 % originales, sintetizados al iniciar (sin archivos externos).
## Pool de reproductores + límite de frecuencia por sonido para que los contagios en
## cadena no saturen el audio.

const RATE := 22050
const SINE := 0
const SQUARE := 1
const TRIANGLE := 2

const MIN_INTERVAL := {
	"infect": 0.045, "bite": 0.05, "shoot": 0.07, "hurt": 0.08,
	"zombie_die": 0.07, "tap": 0.03, "police_down": 0.05,
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build()


func play(id: String, pitch_var: float = 0.0, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -10.0)) < float(MIN_INTERVAL.get(id, 0.0)):
		return
	_last[id] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.pitch_scale = maxf(0.1, pitch * (1.0 + randf_range(-pitch_var, pitch_var)))
	p.volume_db = vol_db
	p.play()


# ---------------------------------------------------------------------------
# Síntesis
# ---------------------------------------------------------------------------

func _build() -> void:
	var b := PackedFloat32Array()
	# Mordida: "ñam" corto con ruido
	_tone(b, 320, 140, 0.05, SQUARE, 0.25, 0.002, 1.2, 0.7)
	_tone(b, 190, 120, 0.05, SINE, 0.5)
	_streams["bite"] = _wav(b)

	b = PackedFloat32Array()
	# Contagio exitoso: "bloop!" ascendente
	_tone(b, 300, 720, 0.08, SINE, 0.55, 0.003, 0.6)
	_tone(b, 640, 1000, 0.12, TRIANGLE, 0.45, 0.003, 1.6)
	_streams["infect"] = _wav(b)

	b = PackedFloat32Array()
	for f in [1046.0, 1318.0, 1568.0]:
		_tone(b, f, f, 0.07, TRIANGLE, 0.45, 0.003, 1.0)
	_streams["combo"] = _wav(b)

	b = PackedFloat32Array()
	for f in [523.0, 659.0, 784.0, 1046.0]:
		_tone(b, f, f, 0.06, SQUARE, 0.18, 0.003, 0.8)
	_tone(b, 1318.0, 1400.0, 0.22, TRIANGLE, 0.45, 0.003, 1.4)
	_streams["fever"] = _wav(b)

	b = PackedFloat32Array()
	_tone(b, 420, 160, 0.16, SQUARE, 0.22, 0.002, 1.3)
	_streams["hurt"] = _wav(b)

	b = PackedFloat32Array()
	_tone(b, 480, 110, 0.24, SINE, 0.5, 0.002, 1.4, 0.15)
	_streams["zombie_die"] = _wav(b)

	b = PackedFloat32Array()
	_tone(b, 720, 360, 0.1, TRIANGLE, 0.5, 0.002, 0.8)
	_tone(b, 520, 240, 0.16, TRIANGLE, 0.5, 0.002, 1.5)
	_streams["police_down"] = _wav(b)

	b = PackedFloat32Array()
	_tone(b, 900, 380, 0.05, SQUARE, 0.2, 0.001, 1.8, 0.6)
	_streams["shoot"] = _wav(b)

	b = PackedFloat32Array()
	_tone(b, 784, 784, 0.11, SINE, 0.5, 0.004, 0.8)
	_tone(b, 1046, 1046, 0.24, SINE, 0.5, 0.004, 1.6)
	_streams["wave_start"] = _wav(b)

	b = PackedFloat32Array()
	for f in [523.0, 659.0, 784.0]:
		_tone(b, f, f, 0.08, TRIANGLE, 0.45, 0.003, 0.7)
	_tone(b, 1046, 1046, 0.3, TRIANGLE, 0.5, 0.003, 1.6)
	_streams["wave_clear"] = _wav(b)

	b = PackedFloat32Array()
	_tone(b, 880, 1320, 0.1, SINE, 0.5, 0.003, 1.2)
	_streams["select"] = _wav(b)

	b = PackedFloat32Array()
	_tone(b, 700, 640, 0.04, SINE, 0.35, 0.002, 1.5)
	_streams["tap"] = _wav(b)

	b = PackedFloat32Array()
	for f in [523.0, 440.0, 349.0]:
		_tone(b, f, f * 0.98, 0.18, TRIANGLE, 0.45, 0.004, 0.9)
	_tone(b, 262, 240, 0.45, TRIANGLE, 0.5, 0.004, 1.5)
	_streams["lose"] = _wav(b)

	b = PackedFloat32Array()
	for f in [523.0, 659.0, 784.0]:
		_tone(b, f, f, 0.1, TRIANGLE, 0.45, 0.003, 0.7)
	_tone(b, 1046, 1046, 0.18, TRIANGLE, 0.5, 0.003, 0.7)
	_tone(b, 784, 784, 0.1, TRIANGLE, 0.45, 0.003, 0.7)
	_tone(b, 1046, 1046, 0.45, TRIANGLE, 0.5, 0.003, 1.5)
	_streams["win"] = _wav(b)


func _tone(buf: PackedFloat32Array, f0: float, f1: float, dur: float, wave: int, vol: float,
		attack: float = 0.004, decay_pow: float = 1.2, noise: float = 0.0) -> void:
	var n := int(dur * RATE)
	var ph := 0.0
	var att := maxf(1.0, attack * RATE)
	for i in n:
		var t := float(i) / n
		ph += lerpf(f0, f1, t) / RATE
		var fr := ph - floorf(ph)
		var x := 0.0
		match wave:
			SINE:
				x = sin(fr * TAU)
			SQUARE:
				x = 0.6 if fr < 0.5 else -0.6
			TRIANGLE:
				x = 4.0 * absf(fr - 0.5) - 1.0
		if noise > 0.0:
			x = lerpf(x, randf_range(-1.0, 1.0), noise)
		var env := minf(1.0, i / att) * pow(1.0 - t, decay_pow)
		buf.append(x * env * vol)


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
